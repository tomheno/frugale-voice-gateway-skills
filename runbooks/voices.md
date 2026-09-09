<!-- PUBLIC: distributable to customers. -->

# Runbook: voices

Add and manage voices. Voice-CRUD needs your `customer_admin` key. A `consumer`
key can NOT add voices (it returns 403).

Set your shell (see `../README.md`): `SYNTH`, `KEY` (your `customer_admin`
bearer).

## Add a voice

Send a reference wav and its EXACT transcript. The reply carries the voice `uid`.

The reference wav MUST be 10 seconds or less. The transcript MUST be exactly the
words spoken in the clip. A longer clip breaks sync between the audio and the
text. Synth then speaks the leftover reference words BEFORE your target text. The
gateway rejects a reference over 10 seconds with HTTP 400. Trim the clip to a
clean pause under 10 seconds. Match the transcript to it.

```bash
curl -sS -L --max-redirs 60 --retry 12 --retry-delay 15 --retry-all-errors \
  -H "Authorization: Bearer $KEY" \
  -F name="my-voice" \
  -F consent_to_backend_mirror=true \
  -F transcript="the exact words spoken in the reference wav" \
  -F audio=@my_reference.wav \
  -X POST "$SYNTH/v1/voices/upload"
```

Send `consent_to_backend_mirror=true`. The backend needs the reference. The
reply carries the voice `uid`. Use that `uid` as the `voice` field at synth.

## List voices

```bash
curl -sS -L --max-redirs 60 --retry 12 --retry-delay 15 --retry-all-errors \
  -H "Authorization: Bearer $KEY" "$SYNTH/v1/voices"
```

## Get, update, delete a voice

```bash
# metadata
curl -sS -L --max-redirs 60 --retry 12 --retry-delay 15 --retry-all-errors \
  -H "Authorization: Bearer $KEY" "$SYNTH/v1/voices/<uid>"

# rename / favorite
curl -sS -L --max-redirs 60 --retry 12 --retry-delay 15 --retry-all-errors \
  -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
  -X PATCH "$SYNTH/v1/voices/<uid>" -d '{"name":"new-name"}'

# delete (GDPR erase)
curl -sS -L --max-redirs 60 --retry 12 --retry-delay 15 --retry-all-errors \
  -H "Authorization: Bearer $KEY" -X DELETE "$SYNTH/v1/voices/<uid>"
```

## Confirm a draft, check existence

```bash
curl -sS -L --max-redirs 60 --retry 12 --retry-delay 15 --retry-all-errors \
  -H "Authorization: Bearer $KEY" -X POST "$SYNTH/v1/voices/<uid>/confirm"

curl -sS -L --max-redirs 60 --retry 12 --retry-delay 15 --retry-all-errors \
  -H "Authorization: Bearer $KEY" "$SYNTH/v1/voices/<uid>/exists"
```

## See also

- `synth.md`: synthesize with the `uid` this runbook returns.
- `keys-lifecycle.md`: the `customer_admin` key that authorizes voice-CRUD.
