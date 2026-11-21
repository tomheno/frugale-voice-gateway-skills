<!-- PUBLIC: distributable to customers. -->

# Runbook: key lifecycle

Mint, rotate, revoke, and list your tenant's `consumer` keys. Use your
`customer_admin` key. We give you the `customer_admin` key once. You
self-serve every consumer key from it.

Set your shell (see `../README.md`): `ADMIN`, `KEY` (your `customer_admin`
key).

## Mint a consumer key

A consumer key you mint lives at most 90 days. An omitted expiry defaults to 90 days. For
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

A customer holds at most 1000 active consumer keys by default. Above that, the
mint returns 403 `customer_key_quota_exceeded`. Revoke a key that you do not use,
then mint again.

## Rotate a key

Rotate by `kid`. You do NOT need the old key. The default `grace_secs` is 0:
the gateway revokes the old key at once. Set `grace_secs` to keep the old key
alive for that window, so you replace it with no downtime. The gateway lowers a
`customer_admin` `grace_secs` above 300 to 300. If a key leaks, rotate it with
`grace_secs` 0 or revoke it.

```bash
curl -sS -L --max-redirs 60 --retry 12 --retry-delay 15 --retry-all-errors \
  -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
  -X POST "$ADMIN/admin/proxy-keys/<kid>/rotate" \
  -d '{"grace_secs":300}'
```

The reply carries `new_kid` and `new_bearer`. The gateway emits the fresh key once.

A key that you already rotated returns 409 `proxy_key_already_superseded`. A key
that you revoked returns 409 `proxy_key_revoked`.

A rotate that returns 500 can leave a successor key that you do not hold. List
your keys before you retry. Revoke any new key that you do not hold.

A retry after a 500 can return 409 `proxy_key_already_superseded`. Then the
rotate half finished. Read the old key with `GET /admin/proxy-keys/<kid>`. Its
`superseded_by` field names the successor. Revoke the successor, then mint a new
consumer key.

## Revoke a key

Revoke by `kid`. The key stops. The revoke takes effect within about 10
seconds. The 200 body is `{kid, revoked_at}`.

```bash
curl -sS -L --max-redirs 60 --retry 12 --retry-delay 15 --retry-all-errors \
  -H "Authorization: Bearer $KEY" \
  -X DELETE "$ADMIN/admin/proxy-keys/<kid>"
```

To replace a leaked `customer_admin` key, contact us.

## List your keys

Metadata only. Never a key. Paged: pass `cursor` from the reply, `limit` in
[1,200].

```bash
curl -sS -L --max-redirs 60 --retry 12 --retry-delay 15 --retry-all-errors \
  -H "Authorization: Bearer $KEY" \
  "$ADMIN/admin/proxy-keys?customer_id=<your-tenant>"
```

The reply carries `items` (each with `kid`, `role`, `tier`, `expires_at`,
revoked flag), `next_cursor`, and `total_estimate`.

## Limits

- A consumer key that you mint lives at most 90 days.
- The gateway lowers a `customer_admin` `grace_secs` above 300 to 300.
- A customer holds at most 1000 active consumer keys by default.

## See also

- `synth.md`: use a consumer key to synthesize.
- `voices.md`: a `customer_admin` key adds voices.
