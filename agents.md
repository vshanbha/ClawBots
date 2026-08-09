# ZeroClaw Agent - Docker Architecture

## Overview

ZeroClaw Agent is an opinionated, containerized AI agent platform built on open-source solutions. This repository provides a complete, production-ready Docker deployment combining multiple services into a cohesive agent system.

## Services

### Core Agent
- **ZeroClaw Agent** - Primary AI agent orchestrator and reasoning engine

### Speech & Audio
- **Whisper CPP** - Fast, local speech-to-text (STT) inference
- **Piper** - Local text-to-speech (TTS) synthesis

### Search & Web
- **SearXNG** - Privacy-respecting metasearch engine
- **Agent Browser** - Web browsing and interaction capabilities for the agent

### Infrastructure
- **Docker Compose** - Multi-container orchestration
- **Persistent Data Volumes** - Model storage, configs, and runtime data

## Architecture

```
┌─────────────────────────────────────────────────┐
│                  ZeroClaw Agent                  │
│              (Orchestration Core)                │
└─────────────────┬───────────────────────────────┘
                  │
    ┌─────────────┼─────────────┬─────────────────┐
    │             │             │                 │
    ▼             ▼             ▼                 ▼
┌────────┐  ┌──────────┐  ┌─────────┐  ┌──────────────┐
│Whisper │  │  Piper   │  │SearXNG  │  │Agent Browser │
│  CPP   │  │  (TTS)   │  │ Search  │  │   (Web)      │
│ (STT)  │  │          │  │         │  │              │
└────────┘  └──────────┘  └─────────┘  └──────────────┘
```

## Data Directory

The `data/` directory contains:
- Model files (Whisper, Piper)
- Service configurations
- Runtime state and logs

**Important Rules:**
1. This directory is gitignored and must not be committed to version control
2. Do not modify, delete, or write to this directory during development
3. The data folder is read-only for development purposes - all runtime data persists here

## Getting Started

1. Clone this repository
2. Copy `.env.example` to `.env` and configure as needed
3. Run `docker-compose up -d`
4. Access services via configured ports

## Environment Variables

See `.env.example` for all configurable options including:
- API keys and credentials
- Port mappings
- Model selections
- Feature toggles

## Development

### Adding New Services

1. Add service definition to `docker-compose.yml`
2. Create configuration directory under `data/` if needed
3. Update this agents.md with service documentation
4. Add health checks and dependency ordering

### Testing

```bash
# Run tests
docker-compose -f docker-compose.test.yml up
```

## License

Proprietary - ZeroClaw Agent Platform
