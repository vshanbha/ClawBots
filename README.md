# ClawBots Docker Infrastructure

## Why This Project

We use Docker Compose to create a **repeatable, batteries-included** environment for testing *Claw tools. The goals:

- **Ready out of the box** — SearXNG, Whisper, and Piper are pre-configured and start with a single command. No manual setup required.
- **Minimal attack surface** — containerized services don't pollute the host system. Dependencies stay isolated.
- **Consistent across machines** — same setup on any machine with Docker installed.

## What We're Doing

1. **Test *Claw tools quickly** — spin up ZeroClaw (and soon OpenClaw) with search, STT, and TTS ready to go
2. **Productionize what works** — identify winning configurations and deploy them properly
3. **Iterate fast** — dev compose for experimentation, prod compose for stable deployments

---

## Documentation

- [Decision Log](docs/DECISIONS.md) — architectural and tooling decisions with rationale

---

## Quick Start

```bash
bash install.sh
```

The installer checks dependencies, writes `.env`, builds containers, and runs health checks.

## Development vs Production

| File | Purpose | Services |
|------|---------|----------|
| `docker-compose.yml` | Dev/experimentation | ZeroClaw only (`zeroclaw-dev`) |
| `docker-compose.prod.yml` | Full stack | ZeroClaw + SearXNG + Whisper + Piper |

```bash
# Dev mode — just ZeroClaw, connects to existing prod services
docker compose up -d

# Prod mode — full stack
docker compose -f docker-compose.prod.yml up -d
```

Both can run simultaneously (different container names, same host network).

---

## Architecture

```
┌─────────────────────────────────────────────────┐
│                  ZeroClaw                        │
│              (Orchestration Core)                │
└─────────────────┬───────────────────────────────┘
                  │
    ┌─────────────┼─────────────┬─────────────────┐
    │             │             │                 │
    ▼             ▼             ▼                 ▼
┌────────┐  ┌──────────┐  ┌─────────┐  ┌──────────────┐
│Whisper │  │  Piper   │  │SearXNG  │  │Agent Browser │
│  STT   │  │   TTS    │  │ Search  │  │    Web       │
└────────┘  └──────────┘  └─────────┘  └──────────────┘
```

## Services

### zeroclaw — the AI agent
The main container. Runs the ClawBots daemon and agent-browser (headless Chrome).

- **Port 42618** — gateway for Discord, Telegram, and other channels
- **CPU/memory capped** — 2 cores, 512MB limit
- **Health check** — `zeroclaw status` every 60s

### searxng — web search
Self-hosted metasearch engine (Google, DuckDuckGo, Wikipedia, etc.).

- **Port 5321** — host network
- **Config** — `./data/searxng/`

### whisper — speech-to-text
Speaches (faster-whisper) for voice message transcription.

- **Port 9001** — host network
- **Models** — auto-download from HuggingFace, cached in `hf-hub-cache`

### piper — text-to-speech
Local TTS with OpenAI-compatible API.

- **Port 5000** — host network
- **Voices** — `en_GB-alan-medium` (English), `hi_IN-priyamvada-medium` (Hindi)

---

## Configuration

All settings live in `.env` (copy from `.env.example`):

| Variable | Purpose | Default |
|----------|---------|---------|
| `UID`/`GID` | Match host user | `1000` |
| `SEARXNG_PORT` | Search engine port | `5321` |
| `WHISPER_PORT` | STT port | `9001` |
| `TTS_PORT` | TTS port | `5000` |
| `WHISPER_MODEL` | STT model size | `ggml-small` |

## Changing the Whisper Model

Edit `whisper/model_aliases.json` and restart:

```bash
docker compose restart whisper
```

Available: `tiny` (~75MB), `base` (~150MB), `small` (~500MB), `medium` (~1.5GB), `large-v3` (~3GB).

## Updating

```bash
docker compose pull                    # Update images
docker compose build zeroclaw          # Rebuild custom image
docker compose up -d                   # Restart
```

## Testing

```bash
bash tests/test-services.sh
```

Verifies: containers running, health endpoints, TTS audio generation, STT transcription (WAV + OGG).

## Troubleshooting

```bash
docker compose logs zeroclaw           # Check logs
curl http://localhost:9001/health      # Whisper health
curl http://localhost:5000/v1/models   # Piper health
curl http://localhost:5321/search?q=test  # SearXNG health
docker exec -it zeroclaw bash          # Shell into container
```

---

## Projects & Documentation

| Project | Description | Links |
|---------|-------------|-------|
| **ZeroClaw** | AI agent orchestrator | [Website](https://zeroclaw.ai) • [Docs](https://docs.zeroclaw.ai) • [GitHub](https://github.com/zeroclaw-labs/zeroclaw) |
| **Speaches** | OpenAI-compatible STT | [GitHub](https://github.com/speaches-ai/speaches) |
| **Piper** | Local TTS synthesis | [GitHub](https://github.com/rhasspy/piper) • [Voices](https://huggingface.co/rhasspy/piper-voices) |
| **SearXNG** | Metasearch engine | [Docs](https://docs.searxng.org) • [GitHub](https://github.com/searxng/searxng) |
