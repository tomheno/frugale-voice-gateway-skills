<!-- PUBLIC: distributable to customers. -->

# Runbook: voices

Add and manage voices. Voice-CRUD needs your `customer_admin` key. A `consumer`
key can NOT add voices (it returns 403).

Set your shell (see `../README.md`): `SYNTH`, `KEY` (your `customer_admin`
bearer).

## Add a voice

Send a reference wav. Always send its EXACT transcript too. The transcript is
optional, but an exact one gives the best result. The reply carries the voice `uid`.

The reference clip MUST be 12 seconds or less. The gateway checks this at
enrollment and rejects a longer clip with HTTP 400. The audio MUST be at most
10 MiB (the JSON base64 form counts the base64 text). The transcript MUST be
exactly the words spoken in the clip. A longer clip breaks sync between the audio
and the text. Synth then speaks the leftover reference words BEFORE your target
text. Trim the clip to a clean pause under 12 seconds. Match the transcript to it.

```bash
curl -sS -L --max-redirs 60 --retry 12 --retry-delay 15 --retry-all-errors \
  -H "Authorization: Bearer $KEY" \
  -F name="my-voice" \
  -F consent_to_backend_mirror=true \
  -F transcript="the exact words spoken in the reference wav" \
  -F audio=@my_reference.wav \
  -X POST "$SYNTH/v1/voices/upload"
```

Send `consent_to_backend_mirror=true` so the backend can hold the reference. The
optional `identifier` field is echoed back. The reply carries the voice `uid`.
Use that `uid` as the `voice` field at synth. A voice created through the gateway
is already `ready`.

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

## Confirm a legacy draft, check existence

Confirm applies only to a legacy draft. A voice created through the gateway is
already `ready`.

```bash
curl -sS -L --max-redirs 60 --retry 12 --retry-delay 15 --retry-all-errors \
  -H "Authorization: Bearer $KEY" -X POST "$SYNTH/v1/voices/<uid>/confirm"
```

To check that a voice exists, call `GET /v1/voices/<uid>` and read the status.
A 404 means the voice does not exist.

## See also

- `synth.md`: synthesize with the `uid` this runbook returns.
- `keys-lifecycle.md`: the `customer_admin` key that authorizes voice-CRUD.
