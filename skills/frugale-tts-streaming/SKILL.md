---
name: frugale-tts-streaming
description: Stream frugale TTS audio as it renders — PCM/WAV chunks (/tts/stream, /tts/stream/wav) or WebSocket (/v1/audio/speech/stream, /v1/realtime). Use only when playing audio live as it arrives. Needs a consumer key.
---

<!-- PUBLIC: distributable to customers. Soft index. The runbook carries the requests. -->

# frugale-tts-streaming

Stream audio as it renders, instead of waiting for the whole clip. Advanced.
Most integrations use the unary synth (`frugale-tts-synth`). Use streaming
only when you play audio live.

Read `https://github.com/tomheno/frugale-voice-gateway-skills/blob/main/runbooks/streaming.md` for the four doors: PCM chunks, WAV frames,
the WSS mirror, and the OpenAI-Realtime WSS door, with the request shapes.

Prerequisite: a `consumer` bearer and the shell setup in `https://github.com/tomheno/frugale-voice-gateway-skills/blob/main/README.md`.
