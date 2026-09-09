<!-- PUBLIC: distributable to customers. Source of truth: this repo's public/ tree. -->

# Frugale voice gateway: agent runbooks

Drive the frugale text-to-speech API from your own agent or backend. Mint and
manage keys, add voices, synthesize one text or a batch, pick a model and a
format. Each runbook gives the exact request for one task.

This tree is PUBLIC. It documents only the customer API surface.

## The two apps

| App | Base URL | Serves |
|---|---|---|
| SYNTH | `https://pro-tom--frugale-voice-gateway-prod.modal.run` | synth, batch, streaming, voices, models |
| ADMIN | `https://pro-tom--frugale-voice-gateway-prod-admin.modal.run` | the key lifecycle (mint / rotate / revoke / list) |

## Auth

Every request carries one header. Your proxy key.

```
Authorization: Bearer <proxy-key>
```

Two key roles:

- `customer_admin`. Your admin key. Mint, rotate, and revoke your own consumer
  keys. Add and manage voices. The operator gives you ONE per tenant.
- `consumer`. A synth-only key. Put this in the backend that calls synth. Mint
  it yourself from your `customer_admin`.

A bearer prints ONCE, at mint or rotate. The gateway stores metadata only, never
the bearer, so you can not read it back. Store it in a vault. If a key leaks, rotate it.

Set your shell for the runbooks:

```bash
export ADMIN="https://pro-tom--frugale-voice-gateway-prod-admin.modal.run"
export SYNTH="https://pro-tom--frugale-voice-gateway-prod.modal.run"
export KEY="<your proxy key>"
```

## Cold start

The apps keep one warm replica. A first call after a long idle can still boot a
container (40 to 150 seconds). Every runbook cURL carries
`--retry 12 --retry-delay 15 --retry-all-errors` to re-send while the app boots,
and `-L --max-redirs 60` to follow the Modal boot redirect. If a first call
returns nothing, run it again.

## Runbooks

| runbook | task |
|---|---|
| `runbooks/keys-lifecycle.md` | mint / rotate / revoke / list consumer keys (customer_admin) |
| `runbooks/voices.md` | add / list / get / update / delete a voice (customer_admin) |
| `runbooks/synth.md` | synthesize one text or a batch (consumer) |
| `runbooks/models-and-formats.md` | the models + the audio formats, and how to pick |
| `runbooks/opus-raw-decode.md` | decode the compact `opus_raw` format in your app |
| `runbooks/streaming.md` | stream audio as it renders (advanced) |

## Limits

- A batch carries at most 16 items.
- A consumer key a customer_admin mints is capped at 90 days. Rotate before it
  expires.
- A voice reference clip MUST be 10 seconds or less (a longer clip is rejected
  with HTTP 400). See `runbooks/voices.md`.
- Voices and synth belong to your tenant.
