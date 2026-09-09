<!-- PUBLIC: distributable to customers. -->

# Runbook: key lifecycle

Mint, rotate, revoke, and list your tenant's `consumer` keys. Use your
`customer_admin` key. The operator gives you the `customer_admin` key once. You
self-serve every consumer key from it.

Set your shell (see `../README.md`): `ADMIN`, `KEY` (your `customer_admin`
bearer).

## Mint a consumer key

The gateway caps a delegated key at 90 days. An omitted expiry defaults to 90 days. For
a shorter expiry, add `expires_at` (unix seconds).

```bash
curl -sS -L --max-redirs 60 --retry 12 --retry-delay 15 --retry-all-errors \
  -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
  -X POST "$ADMIN/admin/proxy-keys/mint" \
  -d '{"role":"consumer","customer_id":"<your-tenant>","tier":"standard"}'
```

The reply carries `kid`, `bearer`, and `expires_at`. The `bearer` is the consumer
key. Put it in the backend that calls synth. Never ship a `customer_admin` key to
a client.

## Rotate a key

Rotate by `kid`. You do NOT need the old bearer. `grace_secs` keeps the old key
alive for that window, so you replace the old key with no downtime. A
`customer_admin` rotate caps `grace_secs` at 300 seconds.

```bash
curl -sS -L --max-redirs 60 --retry 12 --retry-delay 15 --retry-all-errors \
  -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
  -X POST "$ADMIN/admin/proxy-keys/<kid>/rotate" \
  -d '{"grace_secs":300}'
```

The reply carries `new_kid` and `new_bearer`. The gateway emits the fresh key once.

## Revoke a key

Revoke by `kid`. The key stops. The revocation reaches the SYNTH app within
seconds.

```bash
curl -sS -L --max-redirs 60 --retry 12 --retry-delay 15 --retry-all-errors \
  -H "Authorization: Bearer $KEY" \
  -X DELETE "$ADMIN/admin/proxy-keys/<kid>"
```

## List your keys

Metadata only. Never a bearer. Paged: pass `cursor` from the reply, `limit` in
[1,200].

```bash
curl -sS -L --max-redirs 60 --retry 12 --retry-delay 15 --retry-all-errors \
  -H "Authorization: Bearer $KEY" \
  "$ADMIN/admin/proxy-keys?customer_id=<your-tenant>"
```

The reply carries `items` (each with `kid`, `role`, `tier`, `expires_at`,
revoked flag), `next_cursor`, and `total_estimate`.

## See also

- `synth.md`: use a consumer key to synthesize.
- `voices.md`: a `customer_admin` key adds voices.
