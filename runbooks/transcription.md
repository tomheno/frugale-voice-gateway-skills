# Transcribe audio (preview)

Turn one audio clip into text. The `/v0` routes are a preview. A stable `/v1`
transcription route replaces them later.

Auth: a `consumer` key. You can use the same key for synthesis.

## Steps

1. Convert the clip to WAV, mono, 16000 Hz:

```bash
ffmpeg -i input.m4a -ar 16000 -ac 1 -c:a pcm_s16le clip.wav
```

2. Build the request. Put the audio in a base64 `data:` URL. The `text` part
   is your instruction. Set `max_tokens` to 10 per second of audio plus 32, at
   most 2048.

```bash
B64="$(base64 < clip.wav | tr -d '\n')"
cat > req.json <<EOF
{"messages":[{"role":"user","content":[
  {"type":"text","text":"Audio transcription. Output: transcript only."},
  {"type":"audio_url","audio_url":{"url":"data:audio/wav;base64,${B64}"}}]}],
 "max_tokens":200,"temperature":0}
EOF
```

3. Write the key header to a file once. The key then stays out of the command line:

```bash
(umask 077 && printf 'Authorization: Bearer %s\n' "$KEY" > auth.hdr)
```

4. Send the request. Set the spoken language with `X-Language` (or `?language=`):

```bash
curl -sS "$SYNTH/v0/chat/completions" \
  -H @auth.hdr -H "Content-Type: application/json" \
  -H "X-Language: fr" --data-binary @req.json
```

5. Read the transcript in `choices[0].message.content`.

## Language

| `X-Language` or `?language=` | route |
|---|---|
| `lb`, `ltz`, or none | Luxembourgish |
| any other code, for example `fr`, `de`, `en` | multilingual |

A regional tag such as `fr-FR` counts as `fr`.

## Stream the text

Use streaming for long clips: the first words come before the full transcript. You still send the whole clip in one
request. On a short clip, the full text comes almost at once.

1. Add `"stream": true` to the request. Add `"stream_options": {"include_usage": true}` for the token counts.

```bash
python3 -c 'import json; d = json.load(open("req.json")); d["stream"] = True; d["stream_options"] = {"include_usage": True}; json.dump(d, open("req-stream.json", "w"))'
```

2. Send it with `-N`, so that cURL prints each event when it comes:

```bash
curl -sS -N "$SYNTH/v0/chat/completions" \
  -H @auth.hdr -H "Content-Type: application/json" \
  -H "X-Language: fr" --data-binary @req-stream.json
```

3. Read the events. The answer is `text/event-stream`. Each event is one line `data: <JSON>` and a blank line. A real
   answer:

```log
data: {"id":"chatcmpl-4c786dd6f00b478a982e94962699fe36","object":"chat.completion.chunk","created":1794485689,"model":"omni-asr","choices":[{"index":0,"delta":{"role":"assistant","content":""},"finish_reason":null}]}

data: {"id":"chatcmpl-4c786dd6f00b478a982e94962699fe36","object":"chat.completion.chunk","created":1794485689,"model":"omni-asr","choices":[{"index":0,"delta":{"content":"Bon"},"finish_reason":null}]}

data: {"id":"chatcmpl-4c786dd6f00b478a982e94962699fe36","object":"chat.completion.chunk","created":1794485689,"model":"omni-asr","choices":[{"index":0,"delta":{"content":"jour, ceci est un test de transcription en"},"finish_reason":null}]}

data: {"id":"chatcmpl-4c786dd6f00b478a982e94962699fe36","object":"chat.completion.chunk","created":1794485689,"model":"omni-asr","choices":[{"index":0,"delta":{"content":" direct, le douze novembre."},"finish_reason":"stop"}]}

data: {"id":"chatcmpl-4c786dd6f00b478a982e94962699fe36","object":"chat.completion.chunk","created":1794485689,"model":"omni-asr","choices":[],"usage":{"prompt_tokens":89,"completion_tokens":17,"total_tokens":106}}

data: [DONE]
```

- Join the `choices[0].delta.content` parts in order: they make the transcript.
- `finish_reason` is `stop` at the end of the text, or `length` when the text hit `max_tokens`.
- With `include_usage`, the last chunk before `[DONE]` has `"choices": []` and the token counts.
- `data: [DONE]` ends a good stream.
- If the service fails during the stream, the last event is `data: {"detail":"upstream_error"}` and no `[DONE]` comes
  after it. Treat the transcript as incomplete and send the request again.

### Python

Needs `requests`. Set `SYNTH` and `KEY` in the environment.

```python
import json
import os

import requests

body = json.load(open("req.json"))
body["stream"] = True
body["stream_options"] = {"include_usage": True}
headers = {"Authorization": f"Bearer {os.environ['KEY']}", "X-Language": "fr"}

with requests.post(f"{os.environ['SYNTH']}/v0/chat/completions", headers=headers, json=body, stream=True, timeout=300) as r:
    r.raise_for_status()
    r.encoding = "utf-8"  # the events are UTF-8 JSON
    for line in r.iter_lines(decode_unicode=True):
        if not line.startswith("data: "):
            continue
        data = line[len("data: "):]
        if data == "[DONE]":
            break
        event = json.loads(data)
        if "detail" in event:
            raise RuntimeError(f"stream failed: {event['detail']}")
        for choice in event["choices"]:
            print(choice["delta"].get("content", ""), end="", flush=True)
        if "usage" in event:
            print(f"\n{event['usage']['completion_tokens']} tokens")
```

Keep `r.encoding = "utf-8"`. Without it, `requests` reads the events as Latin-1 and breaks accented letters.

### JavaScript (Node.js 18 or later)

Set `SYNTH` and `KEY` in the environment. Save as `stream.mjs`.

```js
import { readFileSync } from "node:fs";

const body = JSON.parse(readFileSync("req.json", "utf8"));
body.stream = true;
body.stream_options = { include_usage: true };

const res = await fetch(`${process.env.SYNTH}/v0/chat/completions`, {
  method: "POST",
  headers: { Authorization: `Bearer ${process.env.KEY}`, "Content-Type": "application/json", "X-Language": "fr" },
  body: JSON.stringify(body),
});
if (!res.ok) throw new Error(`${res.status} ${await res.text()}`);

const decoder = new TextDecoder();
let buffer = "";
read: for await (const chunk of res.body) {
  buffer += decoder.decode(chunk, { stream: true });
  let end;
  while ((end = buffer.indexOf("\n\n")) !== -1) {
    const line = buffer.slice(0, end);
    buffer = buffer.slice(end + 2);
    if (!line.startsWith("data: ")) continue;
    const data = line.slice("data: ".length);
    if (data === "[DONE]") break read;
    const event = JSON.parse(data);
    if (event.detail) throw new Error(`stream failed: ${event.detail}`);
    for (const choice of event.choices) process.stdout.write(choice.delta.content ?? "");
    if (event.usage) console.log(`\n${event.usage.completion_tokens} tokens`);
  }
}
```

An event can arrive in more than one network chunk. Keep the text after the last blank line in the buffer, as above.

## Limits

- At most 120 calls a minute per key. Above it: 429 `rate_limited`. Wait the
  `Retry-After` seconds.
- `max_tokens` at most 2048. A clip longer than about 200 seconds needs more:
  split it into parts.
- The body is JSON in UTF-8. Send `Content-Type: application/json`. Do not
  compress the body.
- The audio is a WAV `data:` URL. Do not send a web URL.

## Errors

Every error is `{"detail": "<code>"}`.

| status | code | next step |
|---|---|---|
| 400 | `invalid_request` | The body breaks a rule: no audio part, no `max_tokens`, `max_tokens` above 2048, a field outside the request schema (for example `model` or `n`), or not UTF-8 JSON. Fix the body. |
| 400 | `bad_request` | The service refused the request. Check the message shape. |
| 401 | `unauthorized` | Use a valid, unexpired `consumer` key. |
| 413 | `body_too_large` | Send a shorter clip. |
| 429 | `rate_limited` | Wait `Retry-After` seconds. |
| 502 | `upstream_error` | Retry. |
| 503 | `asr_unavailable` | The service is busy or starting. Retry after `Retry-After` when present. |
| 503 | `auth_unavailable` | Retry. |
