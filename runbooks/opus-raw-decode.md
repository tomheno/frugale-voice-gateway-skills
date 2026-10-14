<!-- PUBLIC: distributable to customers. -->

# Runbook: decode opus_raw

`opus_raw` is the smallest format. It is bare libopus frames in an `OPUSRAW1`
container, not a playable file. Store it upstream (small), then decode it in your
client before playback, in any language. A batch returns `wav` unless you set
`response_format`. Set `response_format: opus_raw` for the smallest payload.

Use this when your backend stores synth output and your client decodes it. For a
directly-playable file, request `wav` or `mp3` instead (`models-and-formats.md`).

## The container (`OPUSRAW1`)

| field | bytes | notes |
|---|---|---|
| magic | 8 | ASCII `OPUSRAW1` |
| sample_rate | 4 (u32) | offset 8. One of 8000, 12000, 16000, 24000, 48000 |
| channels | 1 (u8) | offset 12. Always 1 (mono) |
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
4. Concatenate the decoded PCM. Drop `pre_skip * sample_rate / 48000` samples
   from the front (`pre_skip` is in 48000 Hz units). Wrap the PCM in a WAV header to play it.

A packet length is at most 4000 bytes. Guard a short or empty body, a
zero-length packet, a packet over 4000 bytes, and a channel count other than 1.

## See also

- `synth.md`: request `opus_raw` (single or batch).
- `models-and-formats.md`: the other formats.
