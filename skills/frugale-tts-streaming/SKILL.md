---
name: frugale-tts-streaming
description: Stream frugale TTS audio as it renders — PCM/WAV chunks (/tts/stream, /tts/stream/wav) or WebSocket (/v1/audio/speech/stream, /v1/realtime). Use only when playing audio live as it arrives. Needs a consumer key.
---

<!-- PUBLIC — distributable to customers. Soft index; the runbook carries the requests. -->

# frugale-tts-streaming

Stream audio as it renders, instead of waiting for the whole clip. Advanced —
most integrations use the unary synth (`frugale-tts-synth`). Reach for streaming
only when you play audio live.

Read `../../runbooks/streaming.md` for the four doors: PCM chunks, WAV frames,
the WSS mirror, and the OpenAI-Realtime WSS door, with the request shapes.
