---
name: frugale-tts-synth
description: Synthesize speech with the frugale voice gateway — one text (/v1/audio/speech) or a batch of up to 16 (/v1/audio/speech/batch). Use when an agent must turn text into audio. Needs a consumer key.
---

<!-- PUBLIC: distributable to customers. Soft index. The runbook carries the requests. -->

# frugale-tts-synth

Turn text into audio with a `consumer` key. One text, or a batch of up to 16 in
one call. OpenAI-compatible request shape.

Read `https://github.com/tomheno/frugale-voice-gateway-skills/blob/main/runbooks/synth.md` for the exact requests + the `SpeechRequest`
fields (input, voice, model, response_format, lang).

Pick a model + a format with `frugale-tts-formats`. For the compact batch format,
decode with `frugale-tts-opus-raw`. To stream audio live, see
`frugale-tts-streaming`.

Run one single synth before a batch (after a long idle, a batch returns 200 with
every item failed).

Prerequisite: a `consumer` bearer and the shell setup in `https://github.com/tomheno/frugale-voice-gateway-skills/blob/main/README.md`.
