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
| PCM chunks | `POST /tts/stream` | chunked `audio/pcm`, headers `x-sample-rate: 24000` and `x-channels: 1`, 16-bit mono PCM |
| WAV frames | `POST /tts/stream/wav` | chunked `application/octet-stream`, each frame = `[4-byte big-endian length][WAV chunk]` |
| WSS mirror | `GET /v1/audio/speech/stream` (upgrade) | WebSocket, binary audio frames |
| OpenAI-Realtime | `GET /v1/realtime` (upgrade) | WebSocket, OpenAI-Realtime control frames |

The two `POST /tts/stream*` doors take the same body as `POST /v1/audio/speech`
(`synth.md`, `SpeechRequest`). The unary `POST /v1/audio/speech` does NOT stream.
It ignores a `"stream": true` key. To stream over HTTP, use `POST /tts/stream`
(PCM) or `POST /tts/stream/wav`.

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
then send the synth control frames. The browser ticket is planned and not yet
available. Today, connect from a server-side client with the
`Authorization: Bearer` header. Use `/v1/realtime` for an OpenAI-Realtime
client. Use `/v1/audio/speech/stream` for a plain synth mirror that returns
binary audio frames.

### Session contract (`/v1/audio/speech/stream`)

One session carries many utterances. The gateway keeps the socket open until
you send `session.close`, the idle limit passes, or the session maximum passes.
You do not reconnect for each utterance.

| you send | meaning |
|---|---|
| `{"type":"session.config","model":"hulotte","voice":"<voice id>","lang":"fr"}` | choose the model, the voice and the language. Send it once, first. |
| `{"type":"input.text","text":"..."}` | add text. Send as often as text arrives. |
| `{"type":"input.done"}` | flush the text that has no sentence end yet. |
| `{"type":"session.close"}` | end the session. |

| you receive | meaning |
|---|---|
| `{"type":"audio.start",...}` | audio of one sentence starts |
| binary frames | audio (16-bit mono PCM). The sample rate is the backend rate. Read it from `audio.start.sample_rate` |
| `{"type":"audio.done",...}` | audio of one sentence ends |
| `{"type":"session.done"}` | one utterance is complete. The socket stays open |
| `{"type":"error",...}` | the request failed |

The gateway synthesizes a sentence as soon as the text frame that completes it
arrives. A sentence ends at `.`, `!` or `?` when that mark is the last character
of the text so far, or when a space follows it. A sentence needs at least 4
characters, counting the mark (`Oui.` is a sentence, `Hi.` is not). A period after
a common abbreviation (`Mme.`, `Mr.`, `etc.`) does not end a sentence. Text with no sentence end waits for the next text
frame or for `input.done`.

The gateway sends a ping every 20 seconds. Your WebSocket library answers pings.
Pings and pongs do not count as activity. Send text or `session.close`, or the
session ends at the idle limit (60 seconds).

Limits today: a session ends after 60 seconds with no activity (no frame from you,
no audio in progress and no audio sent) and after 300 seconds in total (session
maximum). The limits can change. When a session ends,
open a new one and send `session.config` again.

## Latency: choose the path and tune the client

Measured on 2026-10-13. Client in Europe, EU gateway, 61 ms median round trip
to the gateway, backend warm, one stored voice, one French sentence of about 4
seconds of audio, 10 interleaved rounds per path. These are measurements, not
guarantees. Your numbers change with your network.

| path | you wait for | median | p90 |
|---|---|---|---|
| `POST /tts/stream` (or `POST /tts/stream/wav`) | the first chunk | 312.5 ms | 376.0 ms |
| `POST /v1/audio/speech` (unary) | the whole file | 420.8 ms | 498.7 ms |
| WSS, `session.config` sent before the text | first audio after the text frame | 317.9 ms | 342.5 ms |
| WSS, `session.config` sent in the same burst as the text | first audio after the text frame | 419.7 ms | 444.4 ms |
| WSS, new session (once per conversation) | the handshake: TCP, TLS and the upgrade, about 3 round trips | 203.2 ms | 206.8 ms |

Our own gateway time for the same request is about 270 ms (EU, backend warm).
The rest is your network.

### Choose the path

| your case | use |
|---|---|
| one short utterance, you play it as it arrives | HTTP stream (`POST /tts/stream`) |
| one long text, you play or save the whole file | unary `POST /v1/audio/speech` (or a batch) |
| an interactive agent, text arrives over time | ONE WSS session for the whole conversation. Send `session.config` once. |

HTTP calls on one kept-alive connection pay no handshake. A WSS session pays the
handshake once, then every utterance rides the open socket.

### Tune a WSS client

1. Open the socket early. Do it when the conversation starts, not when the first
   text exists. The handshake (203 ms in our test) then happens while the user
   still speaks.
2. Send `session.config` right after the socket opens, before you have text. The
   gateway does the session-start work (voice lookup and safety checks) when the
   config arrives. In our test this cost about 100 ms (419.7 ms against 317.9 ms)
   when the config arrived in the same burst as the text.
3. Keep the session open for the whole conversation. Send each text as it
   arrives. Do not reconnect per utterance.
4. End your text frames with a sentence mark when you want audio now. Send
   `input.done` only to flush text that has no sentence end. Do not wait for it
   when your text already ends in a mark.
5. Answer pings. Plan for the session limits above: when the gateway closes the
   session, open a new one and send `session.config` again.
6. Connect from the gateway region nearest to you. Each round trip costs your
   network round trip.

### Measure first audio the right way

Start the clock when you send the LAST text frame. Stop it at the first binary
frame. Report the handshake apart, as a once-per-conversation cost. This example
needs the `websockets` package (version 14 or later) and reads the key from the
environment, never from the command line.

```python
import asyncio, json, os, time, websockets

URL = os.environ["SYNTH"].replace("https://", "wss://") + "/v1/audio/speech/stream"
HDR = {"Authorization": "Bearer " + os.environ["KEY"]}

async def main():
    t = time.time()
    async with websockets.connect(URL, additional_headers=HDR) as ws:
        handshake_ms = (time.time() - t) * 1000          # once per conversation
        await ws.send(json.dumps({"type": "session.config", "model": "hulotte",
                                  "voice": os.environ["VOICE"], "lang": "fr"}))
        await asyncio.sleep(1)                           # your text is not ready yet
        await ws.send(json.dumps({"type": "input.text", "text": "Bonjour le monde."}))
        t0 = time.time()                                 # clock starts here
        async for message in ws:
            if isinstance(message, bytes):               # first binary frame
                print(f"handshake {handshake_ms:.0f} ms, first audio {(time.time() - t0) * 1000:.0f} ms")
                break
        await ws.send(json.dumps({"type": "session.close"}))

asyncio.run(main())
```

## See also

- `synth.md`: the unary + batch paths (the common case).
- `models-and-formats.md`: models + formats.
