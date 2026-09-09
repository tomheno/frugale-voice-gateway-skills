---
name: frugale-tts-voices
description: Add and manage voices on the frugale voice gateway (upload a reference clip + transcript, list, get, update, delete). Use when an agent must enroll or manage a cloned voice for TTS. Needs a customer_admin key.
---

<!-- PUBLIC — distributable to customers. Soft index; the runbook carries the requests. -->

# frugale-tts-voices

Enroll a voice from a reference wav + its exact transcript, then list, get,
update, or delete voices. Voice-CRUD needs a `customer_admin` key (a consumer
key returns 403).

Read `../../runbooks/voices.md` for the exact requests. Note the hard rule: a
reference clip MUST be 10 seconds or less, or the gateway returns HTTP 400.

The add-voice reply carries the voice `uid` you pass as `voice` at synth
(`frugale-tts-synth`).
