<!-- PUBLIC: distributable to customers. -->

# Runbook: synthesize

Turn text into audio. Use a `consumer` key. Synthesize one text (`/v1/audio/speech`)
or up to 16 texts in one call (`/v1/audio/speech/batch`).

Set your shell (see `../README.md`): `SYNTH`, `KEY` (a `consumer` key),
`VOICE` (a voice `uid` from `voices.md`, or `default`).

## One text

The route is drop-in compatible. Set `model` and `response_format` from
`models-and-formats.md`. This example uses `wav`, which plays directly.

```bash
curl -sS -L --max-redirs 60 --retry 12 --retry-delay 15 --retry-all-errors \
  -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
  -X POST "$SYNTH/v1/audio/speech" \
  -d "{\"model\":\"hulotte\",\"input\":\"Bonjour le monde.\",\"voice\":\"$VOICE\",\"response_format\":\"wav\"}" \
  -o clip.wav
# check: `file clip.wav` prints RIFF/WAVE. play clip.wav in any audio player.
```

### Request fields

| field | type | notes |
|---|---|---|
| `input` | string | the text. Alias `text`. |
| `voice` | string | a voice `uid`, or `default`. Alias `voice_id`. |
| `model` | string | a model alias (see `models-and-formats.md`). Omit it to use the default model. An unknown alias returns 400. |
| `response_format` | string | `wav` / `mp3` / `opus` / `opus_raw` / `pcm` (see `models-and-formats.md`). |
| `lang` | string | ISO 639-1 (for example `fr`). Alias `languages`. |
| `timestamp_granularities` | array | Set `["word"]` for word timestamps (see below). Omit for plain audio. |

A voice id that does not exist returns 404 `voice_not_found`. Create the voice,
or use a voice id that `GET /v1/voices` lists. A deleted voice returns 410. The
`detail` of that answer starts with `voice_tombstoned`.

## Word timestamps (opt-in)

Set `timestamp_granularities: ["word"]` to get the start and end time of each
word. The gateway then returns JSON instead of raw audio:

```json
{ "audio_data": "<base64>", "media_type": "audio/wav", "words": [
  { "word": "Bonjour", "start": 0.0, "end": 0.42 }
], "audio_duration": 1.23 }
```

`audio_data` is the base64 of your chosen `response_format`. `media_type` is its
MIME type. These are the SAME keys a batch result uses, so one parser reads both.
`words` are your exact input words, timed in seconds. Without the field, the
response is plain audio (unchanged).

The clip MUST be 30 minutes (1800 seconds) or less. A clip over the limit
returns HTTP 400. Word timestamps are
not available on the streaming routes. In a batch, set
`timestamp_granularities: ["word"]` at the top level. Each result then carries
`words` AND `audio_duration`. A failed batch item carries `error`. A succeeded
item whose alignment fails keeps its audio and `audio_duration`, omits `words`,
and carries `words_error`. If word timestamps are not available, the batch
returns HTTP 400.

## A batch

Send up to 16 texts in one call. Run the single-synth call ONCE first. After a long
idle, a batch returns HTTP 200 with every item failed. `--retry` does not retry a
200, so that batch writes an all-failed file.

An item with a voice id that does not exist fails on its own with `error.type`
`voice_not_found`. The call still returns 200, and the other items are not
affected.

```bash
curl -sS -L --max-redirs 60 --retry 12 --retry-delay 15 --retry-all-errors \
  -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
  -X POST "$SYNTH/v1/audio/speech/batch" \
  -d "{\"model\":\"hulotte\",\"voice\":\"$VOICE\",\"response_format\":\"opus_raw\",
       \"items\":[{\"input\":\"Une.\"},{\"input\":\"Deux.\"},{\"input\":\"Trois.\"}]}" \
  -o batch.json
```

The reply is JSON: `{id, total, succeeded, failed, results}`. Each result carries
`index`, `status`, `audio_data` (base64), and `media_type`. Decode `audio_data`
to get the audio bytes. For `opus_raw`, see `opus-raw-decode.md`. A failed result
has no audio. It carries `error`, an object with `message` and `type`.

## When a model is not available

A model can be outside its service hours or still starting.

- `POST /v1/audio/speech` returns 503. The `detail` is `deployment_stopped`,
  `deployment_starting`, or `deployment_stopping`. The `Retry-After` header gives
  the seconds to wait. Wait that long, then retry.
- A batch returns 200. Each item for that model fails, and the code is in
  `error.type` and `error.message`. The batch has no `Retry-After` header. Wait,
  then retry the failed items. A single call to the same model gives the wait
  in `Retry-After`.

## See also

- `models-and-formats.md`: pick a model + a format.
- `opus-raw-decode.md`: decode the compact batch format.
- `streaming.md`: stream audio as it renders, and the latency guide: which door
  gives the first audio fastest, and how to tune a WebSocket client.
