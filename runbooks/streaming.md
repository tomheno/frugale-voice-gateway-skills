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
| PCM chunks | `POST /tts/stream` | chunked `audio/pcm`, headers `x-sample-rate` (the rate depends on the model) and `x-channels: 1`, 16-bit mono PCM |
| WAV frames | `POST /tts/stream/wav` | chunked `application/octet-stream`, each frame = `[4-byte big-endian length][WAV chunk]` |
| WSS mirror | `GET /v1/audio/speech/stream` (upgrade) | WebSocket, binary audio frames (`pcm` or `mulaw`) |
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
# out.pcm = raw 16-bit mono. Add -D headers.txt to read the x-sample-rate response header.
# Wrap in a WAV header at that rate, or feed a PCM player.
```

`-N` disables curl buffering so chunks arrive live.

## WSS doors

`GET /v1/audio/speech/stream` and `GET /v1/realtime` are WebSocket upgrades, not
cURL calls. Open a WebSocket with the `Authorization: Bearer <consumer>` header,
then send the synth control frames. Connect from a server-side client. Use `/v1/realtime` for an OpenAI-Realtime
client. Use `/v1/audio/speech/stream` for a plain synth mirror that returns
binary audio frames.

### Session contract (`/v1/audio/speech/stream`)

One session carries many utterances. The gateway keeps the socket open until
you send `session.close`, the idle limit passes, or the session maximum passes.
You do not reconnect for each utterance.

| you send | meaning |
|---|---|
| `{"type":"session.config","model":"hulotte","voice":"<voice id>","lang":"fr"}` | choose the model, the voice and the language. Send it first. Add `"format":"mulaw"` for G.711 mu-law. You can send it again later. |
| `{"type":"input.text","text":"..."}` | add text. Send as often as text arrives. |
| `{"type":"input.done"}` | flush the text that has no sentence end yet. |
| `{"type":"response.cancel"}` | stop the response now. The socket stays open. |
| `{"type":"session.close"}` | end the session. |

| you receive | meaning |
|---|---|
| `{"type":"audio.start",...}` | audio of one sentence starts |
| binary frames | audio. 16-bit mono PCM by default, or G.711 mu-law with `format` `mulaw`. Read the format and the sample rate from `audio.start` |
| `{"type":"audio.done",...}` | audio of one sentence ends |
| `{"type":"session.done"}` | one utterance is complete. The socket stays open. The answer to `response.cancel` is also a `session.done`. It is not a real turn |
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
no audio in progress and no audio sent) and after 600 seconds in total (session
maximum). The limits can change. When a session ends,
open a new one and send `session.config` again.

### Choose the audio format

The `format` key of `session.config` sets the audio that you get. Write the value
in lower case.

| `format` | audio |
|---|---|
| `pcm` (the default) | raw 16-bit little-endian PCM, mono, no header, at the rate in `audio.start.sample_rate` |
| `mulaw` | raw G.711 mu-law, 8000 Hz, mono, 1 byte per sample, no header |

Use `mulaw` for a phone line. Send it in the config:

```json
{"type":"session.config","model":"hulotte","voice":"<voice id>","lang":"fr","format":"mulaw"}
```

- With `mulaw`, each `audio.start` says `"format":"mulaw"` and `"sample_rate":8000`.
- Join the binary frames in the order that they arrive.
- `audio.done.total_bytes` counts the bytes that you got for that sentence.
- An unknown `format` value in the first config closes the socket with code
  1008. In a later config it gives a non-fatal `error` frame with `error_type`
  `client_frame_error`. The session keeps its format. Check your client configs:
  older gateway versions ignored a `format` value that was not `pcm` or `mulaw`.
- If one sentence cannot go out whole as `mulaw`, its `audio.done` has
  `"error":true`. A non-fatal `error` frame with `error_type`
  `format_unavailable` usually comes first. That sentence can have no
  `audio.start`, or only some of its audio. The socket stays open.

### Change the language, the voice or the format

Send `session.config` again on the open socket. You do not reconnect.

```json
{"type":"session.config","model":"hulotte","voice":"<voice id>","lang":"en"}
```

- A later config replaces the whole config. Send `voice` in every config. Send
  `lang` and `format` again if you want to keep them. A config with no `format`
  goes back to `pcm`.
- A language or voice change applies from the next commit. A commit is the
  moment that the server takes your buffered text to speak. Text that you sent
  and the server did not start to speak is spoken in the new language. A
  sentence in progress does not change.
- A `format` change applies at the next `audio.start`, never inside a sentence.
  In the middle of a response it takes effect at a later sentence of that
  response. Each sentence is self-consistent: its `audio.start` names its format.
- A language that the model does not support closes the socket with code 1008.
- An unknown voice gives a non-fatal `error` frame with `error_type`
  `voice_not_found`. A deleted voice gives `voice_tombstoned`. The session keeps
  its voice. New `error_type` values can appear.
- The model is fixed for the life of the socket. A different `model` in a later
  config has no effect. To use another model, open a new socket.

### Cancel a response

Send `{"type":"response.cancel"}` when the voice must stop, for example when the
caller speaks over it.

- The server stops the response in flight at once. No more audio of it comes.
- The server drops text that you sent and that it did not start to speak.
- The socket stays open. Send the next text as usual.
- The server answers with a `session.done` that has `cancelled`:

```json
{"type":"session.done","utterance_index":0,"total_sentences":0,"cancelled":true}
```

`cancelled` is `true` when the cancel stopped a response or dropped text. It is
`false` when nothing was in flight and no text waited. Nothing changes then.

This `session.done` is NOT a real turn. It has `utterance_index` 0 and
`total_sentences` 0. Do not count turns with it.

- Audio frames that you already got stay valid. Drop the audio that your player
  holds for that response.
- A `session.config` that you sent before the cancel still applies after it.
- A cancel does not drop the audio of a turn that already finished. A cancel
  that arrives after the response ended changes nothing. One exception: when
  your client reads slowly, the server can still hold audio of an earlier
  finished turn that it did not send yet. A cancel of a later response can drop
  that audio.
- A cancel that arrives while the server shuts down for a restart gets no
  `session.done`. The server closes the socket with code 1001. Open a new
  session.

Limits:

- At most 10 cancels in any 10 seconds per session. Above it, the server
  refuses the cancel with a non-fatal `error` frame with `error_type`
  `cancel_rate_limited`. Nothing is cut.
- A cancel can arrive while the server still has frames that you sent before
  it. The server drops the `input.text` and `input.done` frames. It keeps
  `session.close`. It holds each `session.config` frame, and each frame that does
  not parse, until the cancel is done. It holds at most 16 frames and 1 MiB in
  all. A held frame counts the length of its text plus 256 bytes. The first held
  frame is always held, whatever its size. Above the limit the socket closes with
  code 1008. Wait for the `session.done` of the cancel before you send more
  frames.

## Latency: choose the path and tune the client

Measured on 2026-10-13. Client in Europe, EU gateway, 61 ms median round trip
to the gateway, one stored voice, one French sentence of about 4 seconds of
audio, 10 interleaved rounds per path. The service was in regular use, not idle.
These are measurements, not guarantees. Your numbers change with your network.

| path | you wait for | median | p90 |
|---|---|---|---|
| `POST /tts/stream` (or `POST /tts/stream/wav`) | the first chunk | 312.5 ms | 376.0 ms |
| `POST /v1/audio/speech` (unary) | the whole file | 420.8 ms | 498.7 ms |
| WSS, `session.config` sent before the text | first audio after the text frame | 317.9 ms | 342.5 ms |
| WSS, `session.config` sent in the same burst as the text | first audio after the text frame | 419.7 ms | 444.4 ms |
| WSS, new session (once per conversation) | the handshake: TCP, TLS and the upgrade, about 3 round trips | 203.2 ms | 206.8 ms |

Our own gateway time for the same request is about 270 ms (EU, service not idle).
The rest is your network.

The first audio of a session can arrive later after a long idle. The first audio
after a language or voice change, or after a cancel that cut a response, can come
later than after a normal turn.

### Choose the path

| your case | use |
|---|---|
| one short utterance, you play it as it arrives | HTTP stream (`POST /tts/stream`) |
| one long text, you play or save the whole file | unary `POST /v1/audio/speech` (or a batch) |
| an interactive agent, text arrives over time | ONE WSS session for the whole conversation. Send `session.config` at the start. |

HTTP calls on one kept-alive connection pay no handshake. A WSS session pays the
handshake once, then every utterance rides the open socket.

### Tune a WSS client

1. Open the socket early. Do it when the conversation starts, not when the first
   text exists. The handshake (203 ms in our test) then happens while the user
   still speaks.
2. Send `session.config` right after the socket opens, before you have text. In
   our test, a config that arrived in the same burst as the text cost about
   100 ms more (419.7 ms against 317.9 ms). After a long idle, the first audio of
   a session can arrive later, so send the config as early as you can.
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
