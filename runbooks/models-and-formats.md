<!-- PUBLIC: distributable to customers. -->

# Runbook: models and formats

Pick a voice model and an audio format at synth. Set the `model` and
`response_format` fields in the synth body (`synth.md`).

## Models

A model is an ALIAS. All models clone the SAME enrolled voice, so you
switch models without re-enrolling. Discover the live aliases. Do NOT hardcode them:

```bash
curl -sS -L --max-redirs 60 --retry 12 --retry-delay 15 --retry-all-errors \
  -H "Authorization: Bearer $KEY" "$SYNTH/v1/models"
```

The reply is `{object:"list", data:[{id, object:"model", owned_by:"frugale", description}]}`.
The `id` is the alias you pass as `model`. Omit `model` to use the default model.

An unknown alias returns HTTP 400 on `/v1/audio/speech`. The `detail` text is
`invalid input: unknown model: <alias>`. In a batch, every item fails with the
same text in `error.message`, and the call still returns 200.

Current aliases:

| model | tier | languages | best for |
|---|---|---|---|
| `hulotte` | default, fast | de, en, es, fr, it, ja, ko, pt, ru, zh | real-time and general use. Start here. |
| `chevechette` | recommended | de, en, fr, it, ja, ko, pt, ru, zh | narration, non real-time, and batch. |
| `linotte` | recommended | de, en, fr, it, ja, ko, pt, ru, zh | narration, non real-time, and batch. |
| `lyre` | experimental | none listed | early adopters only. |
| `hulotte-lb-preview` | experimental | lb (Luxembourgish), de, en, es, it, ja, ko, pt, ru, zh | early adopters only. Luxembourgish first. |

`hulotte-lb-preview` detects the language from the text when `lang` is `fr` or when
the request has no language.

A model can be outside its service hours or still starting. A synth call to it
returns 503 with a `Retry-After` header (see `synth.md`).

### Luxembourgish

Use `hulotte-lb-preview` for Luxembourgish speech, and set `"lang": "lb"`. Enroll the voice with `lang` set to `lb` (see the voices
guide). `hulotte` does not speak Luxembourgish: a request with `lang` `lb` on `hulotte` returns HTTP 400.

```bash
curl -sS -L --max-redirs 60 -H @auth.hdr -H "Content-Type: application/json" \
  -X POST "$SYNTH/v1/audio/speech" \
  -d "{\"model\":\"hulotte-lb-preview\",\"input\":\"Moien, wéi geet et?\",\"voice\":\"$VOICE\",\"lang\":\"lb\",\"response_format\":\"wav\"}" \
  -o lb.wav
```

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

On `/v1/audio/speech` an unknown value returns 400. In a batch, that item fails
with an `error` object and the batch is still 200.

A batch returns `wav` unless you set `response_format`. Use `opus` or `mp3` for a
small payload.

## See also

- `synth.md`: set `model` + `response_format`.
- `opus-raw-decode.md`: decode `opus_raw`.
