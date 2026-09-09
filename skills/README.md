<!-- PUBLIC: distributable to customers. -->

# Frugale voice: agent skills (soft index)

These skills are a soft index to the frugale voice gateway capabilities. Each
skill is thin: it names one capability and points to the runbook that carries
the exact requests. The runbooks are the content. The skills are the index.

Load a skill when its capability matches the task, then follow the runbook it
points to.

| skill | capability | runbook |
|---|---|---|
| `frugale-tts-keys` | mint / rotate / revoke / list consumer keys | `https://github.com/tomheno/frugale-voice-gateway-skills/blob/main/runbooks/keys-lifecycle.md` |
| `frugale-tts-voices` | add / manage a voice | `https://github.com/tomheno/frugale-voice-gateway-skills/blob/main/runbooks/voices.md` |
| `frugale-tts-synth` | synthesize one text or a batch | `https://github.com/tomheno/frugale-voice-gateway-skills/blob/main/runbooks/synth.md` |
| `frugale-tts-formats` | pick a model + an audio format | `https://github.com/tomheno/frugale-voice-gateway-skills/blob/main/runbooks/models-and-formats.md` |
| `frugale-tts-opus-raw` | decode the compact `opus_raw` format | `https://github.com/tomheno/frugale-voice-gateway-skills/blob/main/runbooks/opus-raw-decode.md` |
| `frugale-tts-streaming` | stream audio as it renders | `https://github.com/tomheno/frugale-voice-gateway-skills/blob/main/runbooks/streaming.md` |

Start at `https://github.com/tomheno/frugale-voice-gateway-skills/blob/main/README.md` for the two apps, auth, and cold-start.
