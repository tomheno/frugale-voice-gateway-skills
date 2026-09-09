# Laravel usage (illustrative)

`FrugaleVoiceClient` calls the batch synth endpoint and stores each `opus_raw`
result on a Laravel disk. Adapt to your own conventions.

Put your key + the SYNTH base URL in `.env` (never commit a key):

```env
FRUGALE_SYNTH_URL=https://pro-tom--frugale-voice-gateway-prod.modal.run
FRUGALE_KEY=v1.pk_xxxx.xxxx.xxxx   # a CONSUMER bearer (shape v1.<kid>.<sig>.<payload>). NEVER the customer_admin key.
FRUGALE_VOICE=v-...             # a voice uid you enrolled (confirm via GET /v1/voices)
```

Keep your `customer_admin` key OFF the app backend. Use it once to mint a
consumer key, then put only the consumer key in `.env`. A consumer key can
synth. It can not mint, rotate, or revoke. The synth plane accepts the admin key
too, so a wrong paste works silently and buries a mint-capable key in your logs.

Call it from a job, command, or controller:

```php
use App\Services\FrugaleVoiceClient;

$client = new FrugaleVoiceClient(
    config('services.frugale.synth_url'),   // FRUGALE_SYNTH_URL
    config('services.frugale.key'),         // FRUGALE_KEY
    disk: 's3',                             // any Laravel storage disk
);

$stored = $client->synthesizeBatchAndStore(
    texts: ['Bonjour le monde.', 'Comment allez-vous ?', 'A bientot.'],
    voice: config('services.frugale.voice'),
    model: 'hulotte',                       // or 'chevechette'; both clone the same voice (README Models)
    keyPrefix: "tts/order-{$orderId}",
);
// The client stores opus_raw (small; the Flutter side decodes it). See README
// Formats for wav / mp3 / opus / pcm if you serve a different format.

// $stored = [['index' => 0, 'path' => 'tts/order-42/<batch-id>/0.opusraw', 'media_type' => 'audio/x-opus-raw'], ...]
// Persist $stored (DB), then serve each stored file to Flutter through YOUR OWN
// API endpoint. That serving route is up to you. It is not part of this bundle.
```

Notes:
- The FIRST call cold-boots the app (~150 s) and warms the TTS backend. The client
  handles the Modal 303 poll and the 503 backend-warm retry for you.
- Batch max is 16 items. `synthesizeBatchAndStore` warms with one single synth
  first, so the batch runs warm.
- Store the DECODED bytes (the client already `base64_decode`s `audio_data`). The
  stored file is the `OPUSRAW1` container the Flutter side decodes.
