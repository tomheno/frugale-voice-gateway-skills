# Machine-readable API specs

Two spec files describe the full public API. Load them before you write a client.

| file | covers |
|---|---|
| `public/openapi.yaml` | OpenAPI 3.1. HTTP plane: synth, batch, voices, models, proxy keys |
| `public/asyncapi.yaml` | AsyncAPI 3.0. WSS plane: `/v1/audio/speech/stream` and `/v1/realtime` |

## Steps

1. Load `openapi.yaml` for any HTTP call.
2. Load `asyncapi.yaml` for any WebSocket stream.
3. Send `Authorization: Bearer <token>` on every call.
4. Use these hosts. Primary: `https://api-otem.confidential-intelligence.lu`
   and `wss://api-otem.confidential-intelligence.lu`. Secondary: the same host
   with the `.com` suffix.
5. Read the live model alias list with `GET /v1/models`. The `model` field is a
   free string. Do not hard-code a value.

## Hard limits

- A voice reference clip must be 12 seconds or less. A longer clip gives HTTP 400.
- A batch carries 1 to 16 items.
- The `input` text is 1 to 4096 characters.
- Streaming audio is `pcm`, 24000 Hz.

## See also

- `runbooks/synth.md`
- `runbooks/streaming.md`
- `runbooks/keys-lifecycle.md`
