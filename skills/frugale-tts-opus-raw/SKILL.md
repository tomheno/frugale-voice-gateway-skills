---
name: frugale-tts-opus-raw
description: Decode the frugale opus_raw audio format (OPUSRAW1 container of bare libopus frames) to playable audio in an app. Use when consuming stored opus_raw synth output, e.g. a Flutter client.
---

<!-- PUBLIC: distributable to customers. Soft index. The runbook carries the details. -->

# frugale-tts-opus-raw

Decode `opus_raw`. It is the smallest synth format, an `OPUSRAW1` container of bare
libopus frames. It is not a playable file. Decode it in the app before playback.
The batch path uses it by default.

Read `../../runbooks/opus-raw-decode.md` for the container layout + a Dart/Flutter
decoder (`../../code/flutter/opus_raw_decoder.dart`) and a playback example.

For a directly-playable file instead, request `wav` or `mp3` (`frugale-tts-formats`).

Prerequisite: stored `opus_raw` synth output (see `frugale-tts-synth`).
