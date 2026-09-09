---
name: frugale-tts-keys
description: Mint, rotate, revoke, and list frugale voice gateway API keys (consumer keys) from a customer_admin key. Use when an agent must provision or manage its own inference keys for the frugale TTS API.
---

<!-- PUBLIC: distributable to customers. Soft index. The runbook carries the requests. -->

# frugale-tts-keys

Manage your tenant's `consumer` keys with your `customer_admin` key: mint a
synth-only key, rotate it with a grace window, revoke it, list metadata.

Read `https://github.com/tomheno/frugale-voice-gateway-skills/blob/main/runbooks/keys-lifecycle.md` for the exact requests (endpoints, bodies,
the 90-day expiry clamp, the 300-second rotate grace).

Prerequisite: a `customer_admin` bearer (the operator gives one per tenant) and
the shell setup in `https://github.com/tomheno/frugale-voice-gateway-skills/blob/main/README.md`.
