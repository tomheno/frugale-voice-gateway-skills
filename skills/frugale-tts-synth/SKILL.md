---
name: frugale-tts-synth
description: Synthesize speech with the frugale voice gateway. Send one text (/v1/audio/speech) or a batch of up to 16 (/v1/audio/speech/batch). Use when an agent must turn text into audio. Needs a consumer key.
---

<!-- PUBLIC: distributable to customers. Soft index. The runbook carries the requests. -->

# frugale-tts-synth

Turn text into audio with a `consumer` key. One text, or a batch of up to 16 in
one call. Drop-in compatible request shape.

Read `https://github.com/tomheno/frugale-voice-gateway-skills/blob/main/runbooks/synth.md` for the exact requests + the `SpeechRequest`
fields (input, voice, model, response_format, lang).

Pick a model + a format with `frugale-tts-formats`. For the compact batch format,
decode with `frugale-tts-opus-raw`. To stream audio live, see
`frugale-tts-streaming`.

A model can be outside its service hours or still starting. A single call then
returns 503 with a `Retry-After` header. Wait that many seconds, then retry. A
batch returns 200 and fails the items of that model.

Run one single synth before a batch (after a long idle, a batch returns 200 with
every item failed).

Prerequisite: a `consumer` key and the shell setup in `https://github.com/tomheno/frugale-voice-gateway-skills/blob/main/README.md`.
