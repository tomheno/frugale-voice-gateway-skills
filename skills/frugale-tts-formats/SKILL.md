---
name: frugale-tts-formats
description: Pick a voice model and an audio format for frugale TTS synthesis. The formats are wav, mp3, opus, opus_raw, and pcm. Read the models live from /v1/models. Use when choosing model or response_format for a synth call.
---

<!-- PUBLIC: distributable to customers. Soft index. The runbook carries the requests. -->

# frugale-tts-formats

Choose the `model` and `response_format` for a synth call. Both models clone the
same enrolled voice. Discover the live model aliases via `GET /v1/models`. Do
NOT hardcode them.

Read `https://github.com/tomheno/frugale-voice-gateway-skills/blob/main/runbooks/models-and-formats.md` for the model list, the five formats
(`wav` / `mp3` / `opus` / `opus_raw` / `pcm`) + their content-types, and how to
pick.

Set the chosen values in the synth body (`frugale-tts-synth`).

A model can be outside its service hours or still starting. A synth call to it
returns 503 with a `Retry-After` header.

Prerequisite: the synth setup in `https://github.com/tomheno/frugale-voice-gateway-skills/blob/main/README.md` (a `consumer` key).
