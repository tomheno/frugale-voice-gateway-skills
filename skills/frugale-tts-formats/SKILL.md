---
name: frugale-tts-formats
description: Pick a voice model and an audio format for frugale TTS synthesis (wav, mp3, opus, opus_raw, pcm; models discovered live via /v1/models). Use when choosing model or response_format for a synth call.
---

<!-- PUBLIC — distributable to customers. Soft index; the runbook carries the requests. -->

# frugale-tts-formats

Choose the `model` and `response_format` for a synth call. Both models clone the
same enrolled voice. Discover the live model aliases via `GET /v1/models` — do
NOT hardcode them.

Read `../../runbooks/models-and-formats.md` for the model list, the five formats
(`wav` / `mp3` / `opus` / `opus_raw` / `pcm`) + their content-types, and how to
pick.

Set the chosen values in the synth body (`frugale-tts-synth`).
