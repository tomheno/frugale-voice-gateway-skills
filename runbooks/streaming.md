<!-- PUBLIC: distributable to customers. -->

# Runbook: streaming (advanced)

Stream audio as it renders, instead of waiting for the whole clip. Use a
`consumer` key. Most integrations use the unary `POST /v1/audio/speech`
(`synth.md`). Use streaming only when you play audio live as it arrives.

Set your shell (see `../README.md`): `SYNTH`, `KEY` (a `consumer` bearer),
`VOICE`.

## Four doors

| door | route + method | wire |
|---|---|---|
| PCM chunks | `POST /tts/stream` | chunked `application/octet-stream`, 16-bit 24 kHz mono PCM |
| WAV frames | `POST /tts/stream/wav` | chunked, each frame = 4-byte big-endian length + a WAV chunk |
| WSS mirror | `GET /v1/audio/speech/stream` (upgrade) | WebSocket, binary audio frames |
| OpenAI-Realtime | `GET /v1/realtime` (upgrade) | WebSocket, OpenAI-Realtime control frames |

The two `POST /tts/stream*` doors take the same body as `POST /v1/audio/speech`
(`synth.md`, `SpeechRequest`).

## PCM stream

```bash
curl -sS -N -L --max-redirs 60 --retry 12 --retry-delay 15 --retry-all-errors \
  -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
  -X POST "$SYNTH/tts/stream" \
  -d "{\"model\":\"hulotte\",\"input\":\"Bonjour le monde.\",\"voice\":\"$VOICE\"}" \
  -o out.pcm
# out.pcm = raw 16-bit 24000 Hz mono. Wrap in a WAV header or feed a PCM player.
```

`-N` disables curl buffering so chunks arrive live.

## WSS doors

`GET /v1/audio/speech/stream` and `GET /v1/realtime` are WebSocket upgrades, not
cURL calls. Open a WebSocket with the `Authorization: Bearer <consumer>` header,
then send the synth control frames. Use `/v1/realtime` for an OpenAI-Realtime
client. Use `/v1/audio/speech/stream` for a plain synth mirror that returns
binary audio frames.

## See also

- `synth.md`: the unary + batch paths (the common case).
- `models-and-formats.md`: models + formats.
