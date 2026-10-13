---
name: frugale-tts-streaming
description: Stream frugale TTS audio as it renders — PCM/WAV chunks (/tts/stream, /tts/stream/wav) or WebSocket (/v1/audio/speech/stream, /v1/realtime). Use only when playing audio live as it arrives. Also the latency guide - choose HTTP stream or WSS and tune the client for the fastest first audio. Needs a consumer key.
---

<!-- PUBLIC: distributable to customers. Soft index. The runbook carries the requests. -->

# frugale-tts-streaming

Stream audio as it renders, instead of waiting for the whole clip. Advanced.
Most integrations use the unary synth (`frugale-tts-synth`). Use streaming
only when you play audio live.

Read `https://github.com/tomheno/frugale-voice-gateway-skills/blob/main/runbooks/streaming.md` for the four doors: PCM chunks, WAV frames,
the WSS mirror, and the OpenAI-Realtime WSS door, with the request shapes.

## Latency checklist

The runbook section "Latency: choose the path and tune the client" has the
measured numbers and the rules. In short:

- One short utterance you play live: HTTP stream (`"stream": true`).
- One long text, whole file: unary `POST /v1/audio/speech`.
- An interactive agent: ONE WSS session for the whole conversation.
- Open the WSS socket early. Send `session.config` once, before you have text.
- Send text as it arrives. A sentence ending in `.`, `!` or `?` plays at once.
- Send `input.done` only for text with no sentence end. Start your timer at the
  last text frame, not at `input.done`.
- Answer pings. A session ends after the idle limit or the session maximum:
  open a new one when it does.

Prerequisite: a `consumer` bearer and the shell setup in `https://github.com/tomheno/frugale-voice-gateway-skills/blob/main/README.md`.
