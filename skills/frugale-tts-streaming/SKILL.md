---
name: frugale-tts-streaming
description: Stream frugale TTS audio as it renders, as PCM/WAV chunks (/tts/stream, /tts/stream/wav) or over WebSocket (/v1/audio/speech/stream, /v1/realtime). The WebSocket stream door also gives G.711 mu-law audio (format mulaw). It takes a response.cancel frame for barge-in. It takes a later session.config that switches the language or the voice. Use only when you play audio live as it arrives. This skill also holds the latency guide. Choose the HTTP stream or WSS, and tune the client for the fastest first audio. Needs a consumer key.
---

<!-- PUBLIC: distributable to customers. Soft index. The runbook carries the requests. -->

# frugale-tts-streaming

Stream audio as it renders, instead of waiting for the whole clip. Advanced.
Most integrations use the unary synth (`frugale-tts-synth`). Use streaming
only when you play audio live.

Read `https://github.com/tomheno/frugale-voice-gateway-skills/blob/main/runbooks/streaming.md` for the four doors: PCM chunks, WAV frames,
the WSS stream door, and the Realtime door, with the request shapes. It
also has the sections on mu-law output, on a later `session.config`, and on
cancel.

## Latency checklist

The runbook section "Latency: choose the door and tune the client" has the
measured numbers and the rules. In short:

- One short utterance you play live: HTTP stream (`POST /tts/stream`).
- One long text, whole file: unary `POST /v1/audio/speech`.
- An interactive agent: ONE WSS session for the whole conversation.
- Open the WSS socket early. Send `session.config` at the start, before you have text.
- Send text as it arrives. A sentence ending in `.`, `!` or `?` plays at once.
- Send `input.done` only for text with no sentence end. Start your timer at the
  last text frame, not at `input.done`.
- Answer pings. A session ends after the idle limit or the session maximum:
  open a new one when it does.

## Stream door extras (`/v1/audio/speech/stream`)

- Audio is `pcm` by default. Add `"format":"mulaw"` to `session.config` for raw
  G.711 mu-law at 8000 Hz (a phone line). Write the value in lower case. An
  unknown value closes the socket (1008) in the first config.
- Send `{"type":"response.cancel"}` to stop the voice at once (barge-in). The
  socket stays open. The answer is a `session.done` with `cancelled`. It is not a
  real turn: do not count turns with it. Do not send more than 10 cancels in 10
  seconds.
- Send `session.config` again to change the language or the voice. A later config
  replaces the whole config: send `voice`, `lang` and `format` every time. The
  model does not change for the life of the socket. To change it, open a new socket.

A model can be outside its service hours or still starting. The HTTP stream
doors then return 503 with a `Retry-After` header. A new WSS session closes with
code 1013, and the close reason is a code that starts with `deployment_`. Wait,
then retry.

Prerequisite: a `consumer` key and the shell setup in `https://github.com/tomheno/frugale-voice-gateway-skills/blob/main/README.md`.
