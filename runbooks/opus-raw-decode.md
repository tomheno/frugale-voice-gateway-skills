<!-- PUBLIC: distributable to customers. -->

# Runbook: decode opus_raw

`opus_raw` is the smallest format. It is bare libopus frames in an `OPUSRAW1`
container, not a playable file. Store it upstream (small), then decode it in your
client before playback, in any language. The batch path uses `opus_raw` by
default.

Use this when your backend stores synth output and your client decodes it. For a
directly-playable file, request `wav` or `mp3` instead (`models-and-formats.md`).

## The container (`OPUSRAW1`)

| field | bytes | notes |
|---|---|---|
| magic | 8 | ASCII `OPUSRAW1` |
| sample_rate | 4 (u32) | offset 8 |
| channels | 1 (u8) | offset 12 |
| pre_skip | 2 (u16) | offset 13, in 48 kHz units |
| frames | rest | repeated: u16 packet_len + that many libopus bytes |

All multi-byte fields are little-endian. The header is 15 bytes. A clip can carry
up to 20 ms of trailing silence (the container holds no end-trim marker). This is
inaudible. For sample-exact length, request `opus` (Ogg) instead.

## Decode

Any libopus binding decodes the container, in any language. The steps:

1. Read the 15-byte header: magic, `sample_rate`, `channels`, `pre_skip`.
2. Loop the frames. Read a u16 `packet_len`, then read that many bytes. Those
   bytes are one libopus packet.
3. Feed each packet to an Opus decoder at the header `sample_rate` and `channels`.
4. Concatenate the decoded PCM. Drop `pre_skip` samples (48 kHz units) from the
   front. Wrap the PCM in a WAV header to play it.

Guard a short or empty body, a zero-length packet, and a channel count outside
1 or 2.

## See also

- `synth.md`: request `opus_raw` (single or batch).
- `models-and-formats.md`: the other formats.
