# AGENTS.md - ClawBots Development Instructions

## Project Overview

ClawBots is a containerized AI agent platform using Docker Compose. It orchestrates multiple services: ZeroClaw (agent core), SearXNG (search), Whisper (STT), and Piper (TTS).

## Architecture

```
ZeroClaw (orchestrator) → SearXNG (search)
                        → Whisper (STT)
                        → Piper (TTS)
```

All services use `network_mode: host` and are configured via `.env`.

## Development Rules

### Critical
- **NEVER modify `.env` directly** — only edit `.env.example`. The user will manually update `.env`.
- The `data/` directory is gitignored and contains runtime state. Do not modify files in `data/` during development.
- Model files (Whisper, Piper) are downloaded at runtime and stored in `data/`.

### File Operations
- Configuration changes go in `docker-compose.yml` or service-specific configs.
- New services: add to `docker-compose.yml`, create config dir under `data/` if needed, add health checks.

### Testing
```bash
# Verify services start correctly
docker-compose up -d
docker-compose ps

# Check logs for errors
docker-compose logs <service-name>
```

## Environment Variables

Refer to `.env.example` for all configurable options:
- `UID`/`GID`: Match host user
- `SEARXNG_PORT`, `WHISPER_PORT`, `TTS_PORT`: Service ports
- `WHISPER_MODEL`: STT model (e.g., `ggml-small`)
- `TTS_VOICE_EN`/`TTS_VOICE_HI`: Piper voice models
- `TZ`: Timezone

## Adding Services

1. Add service definition to `docker-compose.yml`
2. Use `network_mode: host` for consistency
3. Add health check
4. Reference env vars from `.env` using `${VAR}` syntax
5. Mount configs to `./data/<service>/` (writable) or read-only where appropriate
