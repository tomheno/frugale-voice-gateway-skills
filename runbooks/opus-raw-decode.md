<!-- PUBLIC: distributable to customers. -->

# Runbook: decode opus_raw

`opus_raw` is the smallest format. It is bare libopus frames in an `OPUSRAW1`
container, not a playable file. Store it upstream (small), then decode it in your
app before playback. The batch path uses `opus_raw` by default.

Use this when your backend stores synth output and your client decodes it (for
example a Laravel backend + a Flutter app). For a directly-playable file, request
`wav` or `mp3` instead (`models-and-formats.md`).

## The container (`OPUSRAW1`)

| field | bytes | notes |
|---|---|---|
| magic | 8 | ASCII `OPUSRAW1` |
| sample_rate | 4 (u32) | offset 8 |
| channels | 1 (u8) | offset 12 |
| pre_skip | 2 (u16) | offset 13, in 48 kHz units |
| frames | rest | repeated: u16 packet_len + that many libopus bytes |

A clip can carry up to 20 ms of trailing silence (the container holds no
end-trim marker). This is inaudible. For sample-exact length, request `opus`
(Ogg) instead.

## Decode it

`code/flutter/opus_raw_decoder.dart` decodes an `OPUSRAW1` clip to wav in Dart /
Flutter. `OpusRaw.decode(bytes)` returns PCM + rate + channels.
`OpusRaw.toWav(bytes)` returns playable wav bytes. It guards a short/empty body,
a bad channel count, and a zero-length packet.

`code/flutter/playback_example.dart` fetches a stored clip from your backend,
decodes it, and plays it. `code/flutter/pubspec_snippet.yaml` lists the packages.

The decoder is illustrative. Any libopus binding decodes the same container.
Read the header. Then feed each length-prefixed packet to the Opus decoder at the
header sample rate and channel count.

## See also

- `synth.md`: request `opus_raw` (single or batch).
- `code/laravel/USAGE.md`: a backend that stores `opus_raw`.
- `models-and-formats.md`: the other formats.
