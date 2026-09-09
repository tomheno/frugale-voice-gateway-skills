<!-- PUBLIC: distributable to customers. -->

# Runbook: models and formats

Pick a voice model and an audio format at synth. Set the `model` and
`response_format` fields in the synth body (`synth.md`).

## Models

A model is a routing ALIAS. Both models clone the SAME enrolled voice, so you
switch models without re-enrolling. Discover the live aliases. Do NOT hardcode them:

```bash
curl -sS -L --max-redirs 60 --retry 12 --retry-delay 15 --retry-all-errors \
  -H "Authorization: Bearer $KEY" "$SYNTH/v1/models"
```

The reply is `{object:"list", data:[{id, owned_by:"frugale", description}]}`. The
`id` is the alias you pass as `model`. An unknown alias returns HTTP 422
`unknown_model_alias`.

Current aliases:

| model | notes |
|---|---|
| `hulotte` | the default. Balanced quality and speed. Use it first. |
| `chevechette` | an alternate model with a different character. Try it when `hulotte` does not suit a text. |

## Formats

Set `response_format`. Five values. The synth transcodes server-side, so pick the
one your player or pipeline wants.

| response_format | content-type | use it for |
|---|---|---|
| `wav` | `audio/wav` | the universal default. Plays everywhere. Best for a quick test. |
| `mp3` | `audio/mpeg` | small and widely playable. |
| `opus` | `audio/ogg` | Ogg/Opus. Small. Safari and iOS need a decoder. |
| `opus_raw` | `audio/x-opus-raw` | the smallest. Bare libopus frames (`OPUSRAW1`). Decode in the app (`opus-raw-decode.md`). Plays on every platform after the decode. |
| `pcm` | `audio/pcm` | raw PCM16 samples, no header. For a pipeline that wants raw samples. |

Any other value returns HTTP 400.

The batch path uses `opus_raw`. It is small to store. The app decodes it.

## See also

- `synth.md`: set `model` + `response_format`.
- `opus-raw-decode.md`: decode `opus_raw`.
