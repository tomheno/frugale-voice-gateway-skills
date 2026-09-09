<?php

namespace App\Services;

use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Storage;
use RuntimeException;

/**
 * Minimal example: call the frugale voice gateway BATCH synth endpoint for many
 * texts, then STORE each opus_raw result. Ownweb agents adapt this to their own
 * conventions (queue jobs, DB rows, S3 disk, etc.). This is illustrative, not a
 * finished service.
 *
 * The tricky parts this example gets right:
 *   1. Auth = ONE header: Authorization: Bearer <proxy-key>. No Modal creds.
 *   2. Modal cold-start: the first request to a scaled-to-zero app returns HTTP
 *      303 to a poll URL. Follow it with a SAME-ORIGIN GET loop (with a sleep).
 *      Do NOT use Guzzle auto-redirect. It hammers the poll URL with no delay.
 *   3. Backend warming: a synth to a cold TTS backend returns 503. Retry. A COLD
 *      batch fails EVERY item, so warm with one single synth first.
 *   4. opus_raw result = base64 in `audio_data`. Store the DECODED bytes; the
 *      Flutter side decodes the OPUSRAW1 container to PCM/wav.
 */
class FrugaleVoiceClient
{
    private string $synthBase;   // https://pro-tom--frugale-voice-gateway-prod.modal.run
    private string $bearer;      // the CONSUMER proxy key. NEVER the customer_admin key.
    private string $disk;        // Laravel storage disk for the audio
    private int $deadlineSecs;

    public function __construct(string $synthBase, string $bearer, string $disk = 'local', int $deadlineSecs = 300)
    {
        $this->synthBase = rtrim($synthBase, '/');
        $this->bearer = $bearer;
        $this->disk = $disk;
        $this->deadlineSecs = $deadlineSecs;
    }

    /**
     * Synthesize a batch of texts (max 16) and store each opus_raw result.
     * Returns [['index' => int, 'path' => string, 'media_type' => string], ...].
     *
     * @param string[] $texts
     */
    public function synthesizeBatchAndStore(array $texts, string $voice, string $model = 'hulotte', string $keyPrefix = 'tts'): array
    {
        // 16 is the gateway default (GATEWAY_BATCH_MAX_ITEMS, batch.rs). If the
        // operator retuned it, drop this client cap and let the gateway 422.
        if (count($texts) === 0 || count($texts) > 16) {
            throw new RuntimeException('batch takes 1..16 items (gateway default)');
        }

        // Warm the backend with ONE single synth first. A cold batch fails every item.
        $this->warm($voice, $model);

        $resp = $this->call('POST', '/v1/audio/speech/batch', [
            'model' => $model,
            'voice' => $voice,
            'response_format' => 'opus_raw',
            'items' => array_map(fn ($t) => ['input' => $t], array_values($texts)),
        ]);
        if ($resp->status() !== 200) {
            throw new RuntimeException("batch HTTP {$resp->status()}: " . substr($resp->body(), 0, 300));
        }

        $doc = $resp->json();
        $stored = [];
        foreach (($doc['results'] ?? []) as $item) {
            if (($item['status'] ?? '') !== 'success' || empty($item['audio_data'])) {
                continue; // ownweb decides how to handle a per-item failure
            }
            $bytes = base64_decode($item['audio_data']); // the OPUSRAW1 container
            $path = "{$keyPrefix}/" . ($doc['id'] ?? 'batch') . '/' . $item['index'] . '.opusraw';
            Storage::disk($this->disk)->put($path, $bytes);
            $stored[] = [
                'index' => $item['index'],
                'path' => $path,
                'media_type' => $item['media_type'] ?? 'audio/x-opus-raw',
            ];
        }
        return $stored;
    }

    /** Wake the TTS backend so the batch runs warm (one throwaway single synth). */
    public function warm(string $voice, string $model = 'hulotte'): void
    {
        $this->call('POST', '/v1/audio/speech', [
            'model' => $model,
            'input' => 'Bonjour.',
            'voice' => $voice,
            'response_format' => 'opus_raw',
        ]);
    }

    /**
     * One HTTP call + the Modal cold-start poll. On 303, GET the same-origin poll
     * URL (no body) with a sleep until it resolves; on 503, retry the original
     * request (backend still warming), all under one deadline.
     */
    private function call(string $method, string $path, ?array $json = null)
    {
        $origin = parse_url($this->synthBase);
        $deadline = time() + $this->deadlineSecs;
        $curUrl = $this->synthBase . $path;
        $curMethod = $method;
        $curJson = $json;
        $connRetries = 0;

        for ($hop = 0; $hop < 400; $hop++) {
            $req = Http::withHeaders(['Authorization' => "Bearer {$this->bearer}"])
                ->withOptions(['allow_redirects' => false]) // we poll 303 ourselves
                ->timeout(120);

            try {
                $resp = $curMethod === 'POST' ? $req->post($curUrl, $curJson ?? []) : $req->get($curUrl);
            } catch (ConnectionException $e) {
                // Transient connect reset or timeout during a cold boot. Retry the
                // ORIGINAL request under the same deadline, up to 20 times.
                if (++$connRetries > 20 || time() > $deadline) {
                    throw new RuntimeException('connection failed during cold start: ' . $e->getMessage());
                }
                $curUrl = $this->synthBase . $path;
                $curMethod = $method;
                $curJson = $json;
                sleep(3);
                continue;
            }
            $status = $resp->status();

            if ($status === 303) {
                $loc = $resp->header('Location');
                $next = $this->resolveUrl($curUrl, $loc);
                if (!$this->sameOrigin($next, $origin)) {
                    // scheme+host+port must all match, so a scheme downgrade or a
                    // port swap can never leak the Bearer to another origin.
                    throw new RuntimeException('cold-start 303 crossed origin (refused)');
                }
                $curUrl = $next;
                $curMethod = 'GET'; // poll with a bare GET (the POST body was buffered)
                $curJson = null;
                if (time() > $deadline) {
                    throw new RuntimeException('cold-start poll timed out');
                }
                sleep(2);
                continue;
            }

            if ($status === 503 && time() < $deadline) {
                // TTS backend still warming. Retry the ORIGINAL request.
                $curUrl = $this->synthBase . $path;
                $curMethod = $method;
                $curJson = $json;
                sleep(5);
                continue;
            }

            return $resp;
        }
        throw new RuntimeException('too many cold-start poll hops');
    }

    /** True iff $url has the same scheme + host + port as the parsed $origin. */
    private function sameOrigin(string $url, array $origin): bool
    {
        $u = parse_url($url);
        $port = static fn(?array $p): int => $p['port'] ?? ((($p['scheme'] ?? '') === 'https') ? 443 : 80);
        return ($u['scheme'] ?? null) === ($origin['scheme'] ?? null)
            && ($u['host'] ?? null) === ($origin['host'] ?? null)
            && $port($u) === $port($origin);
    }

    /** Resolve a relative Location against $base (RFC-3986-style, enough for Modal). */
    private function resolveUrl(string $base, ?string $loc): string
    {
        if ($loc === null || $loc === '') {
            throw new RuntimeException('303 without a Location header');
        }
        if (str_starts_with($loc, 'http://') || str_starts_with($loc, 'https://')) {
            return $loc; // absolute
        }
        $p = parse_url($base);
        $root = "{$p['scheme']}://{$p['host']}" . (isset($p['port']) ? ":{$p['port']}" : '');
        $basePath = $p['path'] ?? '/';
        if (str_starts_with($loc, '/')) {
            return $root . $loc; // root-relative
        }
        if (str_starts_with($loc, '?')) {
            return $root . $basePath . $loc; // query-only: keep the base path
        }
        $slash = strrpos($basePath, '/');
        $dir = $slash === false ? '/' : substr($basePath, 0, $slash + 1);
        return $root . $dir . $loc; // path-relative to the base directory
    }
}
