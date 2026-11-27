# Transcribe audio

Turn speech into text. Three doors:

| door | route | use it for |
|---|---|---|
| File | `POST /v1/audio/transcriptions` | one audio file: the text as JSON, plain text, subtitles, or a stream of text events |
| Speech-to-text stream | `GET /v1/speech-to-text/realtime` (WebSocket) | live audio: send chunks, receive partial and final text |
| Realtime, transcription mode | `GET /v1/realtime?intent=transcription` (WebSocket) | live audio in a realtime session: append audio, receive text deltas |

Auth: a `consumer` key. You can use the same key for synthesis. The full
contract is in `openapi.yaml` (the file door) and `asyncapi.yaml` (the two
WebSocket doors).

## Models

Read the speech-to-text ids from `GET /v1/models`: the entries with the
description `Speech-to-text model.`. Pass the id as `model` (the file door), as
`model_id` (the stream door), or as `session.audio.input.transcription.model`
(the realtime door).

| model | languages | state |
|---|---|---|
| `omni-asr` | any valid tag, for example `fr`, `de`, `en`, `lb` | available |
| `flash-asr` | `lb` | listed, not yet available: 503 `model_unavailable` |
| `light-asr` | `lb` | listed, not yet available: 503 `model_unavailable` |

## Language

Set the language of the speech on every call: `language` (the file door),
`language_code` (the stream door), or
`session.audio.input.transcription.language` (the realtime door). Use an ISO
639 code, for example `fr`, `de`, `en`, `lb`. A regional tag such as `fr-FR`
counts as `fr`.

- With no language, or with `auto`, the service transcribes Luxembourgish. It
  does not detect the language.
- `omni-asr` takes any valid tag. `flash-asr` and `light-asr` take `lb` only.
- A language that the model does not take: the file door returns 400
  `invalid_value` with `param` `language`. A WebSocket door sends an error
  event.

## Service hours

A speech-to-text model has service hours. Plan for these answers:

- Outside the service hours, the file door returns 503 `deployment_stopped`
  with a `Retry-After` header: the seconds until the next start. A WebSocket
  door closes a new session with code 1013 and the reason `deployment_stopped`.
- Around the start and the stop of the service hours, the file door returns 503
  `deployment_starting` or `deployment_stopping` with `Retry-After`. A
  WebSocket door closes with 1013 and that code as the reason.
- The first calls after the service hours start can get a short 503
  `backend_warming` with `Retry-After` (a WebSocket door: close 1013). Wait,
  then send the call again.

Wait the `Retry-After` seconds, then retry. A WebSocket close has no
`Retry-After`: wait a few seconds, then open a new session.

## Transcribe a file

Set your shell (see `../README.md`): `SYNTH` and `KEY` (a `consumer` key).

1. Write the key header to a file once. The key then stays out of the command line:

```bash
(umask 077 && printf 'Authorization: Bearer %s\n' "$KEY" > auth.hdr)
```

2. Send the file. Put `model` before `file`: the order of the `-F` options is the
   order of the form parts.

```bash
curl -sS "$SYNTH/v1/audio/transcriptions" -H @auth.hdr \
  -F model=omni-asr -F language=fr -F file=@clip.wav
```

3. Read the text in `text`:

```json
{"text":"Bonjour, ceci est un test de transcription."}
```

`response_format` picks the answer:

| `response_format` | answer |
|---|---|
| `json` (the default) | `{"text": "..."}` |
| `text` | plain text |
| `srt` | SubRip subtitles |
| `vtt` | WebVTT subtitles |
| `verbose_json` | JSON with `language`, `duration`, and `segments` |
| `ssml` | the text as SSML, built with the word times |

Word timestamps: add `-F response_format=verbose_json -F 'timestamp_granularities[]=word'`.
The answer has `words`, each with `word`, `start` and `end` in seconds.
`omni-asr` gives word times in every language. `words` is absent when the
service finds no word times in the audio. A timestamp field without
`verbose_json` returns 400 `timestamp_granularities_require_verbose_json`.

`prompt` is not supported: it returns 400 `unsupported_parameter`.

## Stream the text of a file

Use streaming for long files: the first words come before the full transcript.
You still send the whole file in one request.

1. Add `-F stream=true`, and send with `-N` so that cURL prints each event when
   it comes. `stream=true` needs `response_format` `json` (the default) or `text`.

```bash
curl -sS -N "$SYNTH/v1/audio/transcriptions" -H @auth.hdr \
  -F model=omni-asr -F language=fr -F stream=true -F file=@clip.wav
```

2. Read the events. The answer is `text/event-stream`. Each event is one line
   `data: <JSON>` and a blank line:

```log
data: {"type":"transcript.text.delta","delta":"Bonjour, ceci est"}

data: {"type":"transcript.text.delta","delta":" un test de transcription."}

data: {"type":"transcript.text.done","text":"Bonjour, ceci est un test de transcription."}
```

- Join the `delta` parts in order: they make the transcript.
- `transcript.text.done` carries the full text and ends the stream. There is no
  `[DONE]` line.
- If the transcription fails during the stream, the last event is
  `{"type":"error","error":{...}}`, with no `transcript.text.done`. Treat the
  transcript as incomplete and send the request again.
- Ignore an event type that you do not know.

## Custom vocabulary

Give the service names and terms that it must write correctly, for example a
brand. On the file door, add the `hotwords` query parameter:

```bash
curl -sS "$SYNTH/v1/audio/transcriptions?hotwords=Acme,Kirchberg" -H @auth.hdr \
  -F model=omni-asr -F language=fr -F file=@clip.wav
```

- Separate the terms with commas, or repeat the parameter.
- Each term has 1 to 50 characters: letters, digits, space, `'`, `.`, `&`, `+`,
  `-`, with at least one letter or digit. Encode `+` as `%2B` and `&` as `%26`.
- Currently at most 50 terms. A list that breaks these rules returns 400
  `invalid_value` with `param` `hotwords`.
- Send the terms in the query. A form field `hotwords` or `keywords` returns
  400 `unsupported_parameter`.
- Only `omni-asr` takes hotwords.
- The stream door takes the same terms in the `keyterms` query key. The
  realtime door takes them as an array in
  `session.audio.input.transcription.keywords`.

## Live audio: the speech-to-text stream door

The stream door takes live audio in chunks and sends the text back. Open it
with a WebSocket client. Set the model, the audio format and the language in
the query. The key goes in the `xi-api-key` header, or in
`Authorization: Bearer <key>`.

1. Convert a test clip to raw 16000 Hz mono PCM in a WAV file:

```bash
ffmpeg -i input.m4a -ar 16000 -ac 1 -c:a pcm_s16le clip16k.wav
```

2. Run the client. It needs Python 3.10 or later and `websockets` 14 or later.
   Set `KEY` in the environment. Use a clip shorter than 30 seconds.

```python
import asyncio
import base64
import json
import os
import wave

import websockets

URL = (
    "wss://api-otem.confidential-intelligence.com/v1/speech-to-text/realtime"
    "?model_id=omni-asr&audio_format=pcm_16000&language_code=fr"
)


async def main():
    headers = {"xi-api-key": os.environ["KEY"]}
    async with websockets.connect(URL, additional_headers=headers) as ws:
        print(json.loads(await ws.recv())["message_type"])  # session_started
        with wave.open("clip16k.wav") as wav:
            chunks = []
            while chunk := wav.readframes(8000):  # 0.5 s of audio
                chunks.append(chunk)
        for i, chunk in enumerate(chunks):
            await ws.send(json.dumps({
                "message_type": "input_audio_chunk",
                "audio_base_64": base64.b64encode(chunk).decode(),
                "commit": i == len(chunks) - 1,  # commit the last chunk
                "sample_rate": 16000,
            }))
            await asyncio.sleep(0.5)  # send at the speed of speech
        async for frame in ws:
            event = json.loads(frame)
            kind = event["message_type"]
            if kind == "partial_transcript":
                print("partial:", event["text"])
            elif kind == "committed_transcript":
                print("final:", event["text"])
                break
            elif kind not in ("session_started", "warning"):
                raise RuntimeError(f"{kind}: {event.get('error')}")


asyncio.run(main())
```

- `audio_format` is `pcm_16000` by default. Other rates and 8000 Hz mu-law are in
  `asyncapi.yaml`. `sample_rate` in each chunk must be the rate of `audio_format`.
- Send short chunks: currently at most 1 second of audio in one chunk.
- With `commit_strategy=manual` (the default), `commit: true` ends a segment.
  With `commit_strategy=vad`, the server commits at each pause in the speech.
- Each commit gives `partial_transcript` events, then one `committed_transcript`.
- Add `include_timestamps=true` for `committed_transcript_with_timestamps`,
  with the word times from the start of the session.
- The session closes with 1008 after currently 15 seconds with no message from
  you, and at its time limit (currently less than 10 minutes).

## Live audio: the realtime door, transcription mode

The realtime door has a transcription mode. Open `/v1/realtime` with
`?intent=transcription`, send `session.update`, then append audio.

1. Convert a test clip to raw 24000 Hz mono PCM in a WAV file:

```bash
ffmpeg -i input.m4a -ar 24000 -ac 1 -c:a pcm_s16le clip24k.wav
```

2. Run the client. It needs Python 3.10 or later and `websockets` 14 or later.
   Set `KEY` in the environment.

```python
import asyncio
import base64
import json
import os
import wave

import websockets

URL = "wss://api-otem.confidential-intelligence.com/v1/realtime?intent=transcription"
UPDATE = {
    "type": "session.update",
    "session": {
        "type": "transcription",
        "audio": {"input": {
            "format": {"type": "audio/pcm", "rate": 24000},
            "transcription": {"model": "omni-asr", "language": "fr"},
            "turn_detection": None,  # you commit
        }},
    },
}


async def main():
    headers = {"Authorization": f"Bearer {os.environ['KEY']}"}
    async with websockets.connect(URL, additional_headers=headers) as ws:
        print(json.loads(await ws.recv())["type"])  # session.created
        await ws.send(json.dumps(UPDATE))
        while (event := json.loads(await ws.recv()))["type"] != "session.updated":
            if event["type"] == "error":
                raise RuntimeError(event["error"]["code"])
        with wave.open("clip24k.wav") as wav:
            while chunk := wav.readframes(12000):  # 0.5 s of audio
                await ws.send(json.dumps({
                    "type": "input_audio_buffer.append",
                    "audio": base64.b64encode(chunk).decode(),
                }))
                await asyncio.sleep(0.5)  # send at the speed of speech
        await ws.send(json.dumps({"type": "input_audio_buffer.commit"}))
        async for frame in ws:
            event = json.loads(frame)
            if event["type"] == "conversation.item.input_audio_transcription.delta":
                print(event["delta"], end="", flush=True)
            elif event["type"] == "conversation.item.input_audio_transcription.completed":
                print("\nfinal:", event["transcript"])
                break
            elif event["type"] in ("error", "conversation.item.input_audio_transcription.failed"):
                raise RuntimeError(event["error"]["code"])


asyncio.run(main())
```

- `session.type` is `transcription` in every `session.update`. The audio is
  PCM16 at 24000 Hz (the default) or 16000 Hz, mono, base64 in `audio`.
- There is no default model: set `session.audio.input.transcription.model`.
- `turn_detection` `null` means that you commit with `input_audio_buffer.commit`.
  `{"type": "server_vad"}` makes the server commit at each pause.
- After the model is set, the config is locked: a `session.update` that changes
  it gets the error `session_config_locked`. Open a new session to change it.
- Use the `transcript` of the `completed` event as the final text.
- This door gives no word timestamps.
- The session closes with 1008 after currently 15 seconds with no event from
  you while no commit is in work. It also ends at its time limit (currently
  less than 10 minutes) with the error `session_time_limit_exceeded` and the
  close 1008.

## Limits

These are the current values. They can change.

- The file door body is currently at most 100000000 bytes (about 95 MiB).
  Above it: 413 `payload_too_large`. With a large file, send `model` before
  `file`, or add `?model=omni-asr`: else the call can fail with 413
  `model_must_precede_file`.
- A file call that takes more than 290 seconds ends with 504
  `request_timeout`. Send a shorter file.
- Too many calls at the same time: 503 `server_overloaded` with `Retry-After`.
  Too many calls for your key: 429 `rate_limit_exceeded` with `Retry-After`.
- A WebSocket session ends at its time limit, currently less than 10 minutes.
  Open a new one to go on.

## Errors (file door)

Every error is `{"error": {"message", "type", "code", "param"}}`. Test `code`.
`message` is text for people: do not parse it. `param` names the field at fault.

| status | code | next step |
|---|---|---|
| 400 | `missing_model` | Send `model`. |
| 400 | `invalid_value` | Fix the field in `param`: `language` (the model does not support it), `hotwords`, or `model`. |
| 400 | `invalid_multipart` | Send `multipart/form-data`. |
| 400 | `invalid_audio` | Send audio that the service can decode, or a shorter file. |
| 400 | `unsupported_response_format` | Use `json`, `text`, `srt`, `vtt`, `verbose_json`, or `ssml`. |
| 400 | `timestamp_granularities_require_verbose_json` | Add `response_format=verbose_json`. |
| 400 | `word_timestamps_unavailable` | The model gives no word times (for example `flash-asr`). Use `omni-asr`, or another format. |
| 400 | `stream_requires_json_or_text` | Use `json` or `text` with `stream=true`. |
| 400 | `unsupported_parameter` | Remove the field in `param` (for example `prompt`). |
| 401 | `invalid_api_key` | Use a valid, unexpired key. |
| 404 | `model_not_found` | Use a speech-to-text id of `GET /v1/models`. |
| 413 | `payload_too_large` | Send a smaller file. |
| 413 | `model_must_precede_file` | Send `model` before `file`, or add `?model=`. |
| 429 | `rate_limit_exceeded` | Wait `Retry-After` seconds. |
| 500 | `transcription_failed` | Send the call again. |
| 503 | `deployment_stopped` | Outside the service hours. Wait `Retry-After` seconds. |
| 503 | `deployment_starting`, `deployment_stopping` | Wait `Retry-After` seconds. |
| 503 | `backend_warming` | The service is getting ready. Wait `Retry-After` seconds. |
| 503 | `server_overloaded` | Wait `Retry-After` seconds. |
| 503 | `model_unavailable` | The model is not yet available. Use `omni-asr`. |
| 504 | `request_timeout` | Send a shorter file, or retry. |
