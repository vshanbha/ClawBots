# ClawBots Docker Infrastructure

Four containers that make up the ClawBots appliance: the AI agent, a web search engine, speech-to-text, and text-to-speech. Everything is defined in `docker-compose.yml` and configured through `.env`.

## Projects & Documentation

| Project | Description | Links |
|---------|-------------|-------|
| **ClawBots** | AI agent orchestrator and reasoning engine | [Website](https://zeroclaw.ai) • [Docs](https://docs.zeroclaw.ai) • [GitHub](https://github.com/zeroclaw-labs/zeroclaw) |
| **Whisper CPP** | Fast, local speech-to-text inference | [GitHub](https://github.com/ggerganov/whisper.cpp) • [Models](https://huggingface.co/ggerganov/whisper.cpp) |
| **Piper** | Local text-to-speech synthesis | [GitHub](https://github.com/rhasspy/piper) • [Voices](https://huggingface.co/rhasspy/piper-voices) |
| **SearXNG** | Privacy-respecting metasearch engine | [Docs](https://docs.searxng.org) • [GitHub](https://github.com/searxng/searxng) |
| **Agent Browser** | Headless Chrome for web automation | [GitHub](https://github.com/nicholasgriffintn/agent-browser) |
| **Docker Compose** | Multi-container orchestration | [Docs](https://docs.docker.com/compose) • [GitHub](https://github.com/docker/compose) |

## What each container does

### zeroclaw — the AI agent
The main container. Runs the ClawBots daemon (the AI agent loop) and agent-browser (headless Chrome for web automation). Built from the official ClawBots Debian image, with Node.js, agent-browser, and Chrome added on top during the Docker build.

- **Port 42618** on the host maps to port 42617 inside the container. This is the gateway — Discord, Telegram, and other channels connect here.
- **Named volume `zeroclaw-data`** stores all persistent state: config, memory, skills, workspace. Docker manages this volume at `/var/lib/docker/volumes/docker_zeroclaw-data/_data` on the host.
- **CPU/memory capped** at 2 cores and 512MB to prevent runaway usage.
- **Health check** runs every 60 seconds — pings `zeroclaw status` to make sure the daemon is alive.

### searxng — web search
A self-hosted metasearch engine. When you ask the agent to search the web, it queries SearXNG, which fans out to Google, DuckDuckGo, Wikipedia, and others, then aggregates the results.

- **Host network** — binds directly to port 5321 on the host, no port mapping needed.
- **Config mounted** from `./data/searxng/` on the host into `/etc/searxng/` inside the container. Edit the config files there to change which search engines are enabled.

### whisper — speech-to-text
Runs OpenAI Whisper (via whisper.cpp) to convert voice messages into text. When someone sends a voice note on Discord or Telegram, it gets transcribed here.

- **Host network** — listens on port 9001.
- **Model baked into the image** — the `ggml-small.bin` model (about 1GB) is downloaded from Hugging Face during `docker build` and stored inside the image. To change the model size, rebuild with a different `WHISPER_MODEL` value in `.env` (tiny, base, small, medium, large).
- **No host volumes** — everything lives inside the container image.

### piper — text-to-speech
Converts the agent's text replies into natural-sounding speech. Uses the Piper TTS engine with OpenAI-compatible API.

- **Host network** — listens on port 5000.
- **Voice models mounted** from `./data/piper/` on the host into `/data/` inside the container. Place `.onnx` voice model files there to add or change voices.
- **Current voices**: `en_GB-alan-medium` (English) and `hi_IN-priyamvada-medium` (Hindi), configured in `.env`.

## File structure

```
docker/
├── docker-compose.yml      # Defines all four containers and how they talk
├── .env                    # Your local settings — ports, model sizes, paths (not committed)
├── .env.example            # Template to copy from
├── README.md               # This file
├── zeroclaw/
│   └── Dockerfile          # Builds the agent image (base + Node.js + agent-browser + Chrome)
├── whisper/
│   └── Dockerfile          # Builds the STT image (whisper.cpp binary + model download)
└── data/
    ├── searxng/            # SearXNG config (settings.yml, limiter.toml)
    └── piper/              # Piper voice model files (.onnx)
```

## Networking

| Container | Network mode | Port | Why |
|-----------|-------------|------|-----|
| zeroclaw | bridge (port mapping) | 42618→42617 | Gateway needs to be accessible but isolated |
| searxng | host | 5321 | Simpler — no mapping overhead for internal services |
| whisper | host | 9001 | Same — direct bind to localhost |
| piper | host | 5000 | Same — direct bind to localhost |

SearXNG, Whisper, and Piper all use `network_mode: host` because they only listen on localhost and don't need container isolation. ClawBots uses bridge networking with an explicit port mapping because it's the external-facing gateway.

## Quick start

```bash
# 1. Copy and edit the environment file
cp .env.example .env
nano .env

# 2. Build everything and start
docker compose up -d --build

# 3. Check all containers are running
docker compose ps

# 4. First-time setup — initialize ClawBots config
docker compose exec zeroclaw zeroclaw quickstart
```

## Changing the Whisper model

The speech-to-text model is downloaded during the Docker build, so changing it requires a rebuild:

```bash
# Edit .env: change WHISPER_MODEL=small to WHISPER_MODEL=medium
nano .env

# Rebuild just the whisper container
docker compose build whisper

# Restart with the new model
docker compose up -d whisper
```

Model sizes: `tiny` (~75MB, fast but less accurate), `base` (~142MB), `small` (~466MB, good balance), `medium` (~1.5GB), `large` (~3GB, best accuracy).

## Updating

```bash
# Pull latest base images
docker compose pull

# Rebuild zeroclaw and whisper (they have custom Dockerfiles)
docker compose build

# Restart everything
docker compose up -d
```

## Troubleshooting

```bash
# Check why a container isn't starting
docker compose logs zeroclaw

# Check Whisper is serving
curl http://localhost:9001/v1/models

# Check Piper is serving
curl http://localhost:5000/v1/models

# Check SearXNG is serving
curl http://localhost:5321/search?q=test

# Shell into a container for debugging
docker exec -it zeroclaw bash

# Check ClawBots's status
docker exec zeroclaw zeroclaw status
```
