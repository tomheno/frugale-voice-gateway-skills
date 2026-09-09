<!-- PUBLIC: distributable to customers. -->

# Runbook: synthesize

Turn text into audio. Use a `consumer` key. Synthesize one text (`/v1/audio/speech`)
or up to 16 texts in one call (`/v1/audio/speech/batch`).

Set your shell (see `../README.md`): `SYNTH`, `KEY` (a `consumer` bearer),
`VOICE` (a voice `uid` from `voices.md`, or `default`).

## One text

The endpoint is OpenAI-compatible. Set `model` and `response_format` from
`models-and-formats.md`. This example uses `wav`, which plays directly.

```bash
curl -sS -L --max-redirs 60 --retry 12 --retry-delay 15 --retry-all-errors \
  -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
  -X POST "$SYNTH/v1/audio/speech" \
  -d "{\"model\":\"hulotte\",\"input\":\"Bonjour le monde.\",\"voice\":\"$VOICE\",\"response_format\":\"wav\"}" \
  -o clip.wav
# verify: file clip.wav -> RIFF/WAVE ; play: afplay clip.wav
```

### Request fields

| field | type | notes |
|---|---|---|
| `input` | string | the text. Alias `text`. |
| `voice` | string | a voice `uid`, or `default`. Alias `voice_id`. |
| `model` | string | a model alias (see `models-and-formats.md`). Omit -> the default. An unknown alias -> 422. |
| `response_format` | string | `wav` / `mp3` / `opus` / `opus_raw` / `pcm` (see `models-and-formats.md`). |
| `speed` | float | 0.25 to 4.0. |
| `lang` | string | ISO 639-1 (for example `fr`). Alias `languages`. |

## A batch

Send up to 16 texts in one call. Run the single-synth call ONCE first to warm the
backend. A cold batch returns HTTP 200 with every item failed. `--retry` does not
retry a 200, so an un-warmed batch writes an all-failed file.

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
to get the audio bytes. For `opus_raw`, see `opus-raw-decode.md`.

## See also

- `models-and-formats.md`: pick a model + a format.
- `opus-raw-decode.md`: decode the compact batch format.
- `streaming.md`: stream audio as it renders.
