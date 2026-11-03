# Your First Agent Setup — ZeroClaw on Docker (macOS)

This document captures the complete setup process for running a ZeroClaw agent ("Gibbs") inside Docker on macOS, including all the deviations from the original `weshall.build` blog post approach.

## Prerequisites

- macOS with Docker Desktop
- `.env` file copied from `.env.example` with `AGENT_NAME=gibbs` (or your agent name)
- All images pre-pulled (never pull on stage)

## 1. Docker Compose Configuration

### Key difference from original blog post
The original blog post assumes Linux with `network_mode: host`. On macOS Docker Desktop, host networking shares the VM's network namespace, not your Mac's. This means:
- `localhost:<port>` on your Mac does NOT reach containers
- Containers can't reach your Mac's `localhost:<port>` services

### Solution: Bridge networking for zeroclaw only

Only `zeroclaw` uses bridge networking with port publishing. `searxng` and `whisper` stay on `network_mode: host`.

```yaml
services:
  zeroclaw:
    build:
      context: ./zeroclaw
      dockerfile: Dockerfile
      args:
        - UID=${UID}
        - GID=${GID}
    container_name: zeroclaw-test
    restart: unless-stopped
    ports:
      - "42617:42617"
    extra_hosts:
      - "host.docker.internal:host-gateway"
    environment:
      - ZEROCLAW_gateway__allow_public_bind=true
    volumes:
      - ./data/zeroclaw/.zeroclaw:/zeroclaw-data/.zeroclaw
      - ${SHARED_WORKSPACE_HOST}:/zeroclaw-data/.zeroclaw/agents/${AGENT_NAME}/workspace/${SHARED_WORKSPACE_CONTAINER}
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 512M
        reservations:
          cpus: '0.5'
          memory: 32M
    healthcheck:
      test: ["CMD", "zeroclaw", "status", "--format=exit-code"]
      interval: 60s
      timeout: 10s
      retries: 3
      start_period: 10s

  searxng:
    image: searxng/searxng:latest
    container_name: searxng
    restart: unless-stopped
    ports:
      - "${SEARXNG_PORT}:${SEARXNG_PORT}"
    volumes:
      - ./data/searxng:/etc/searxng:rw
    environment:
      - SEARXNG_BASE_URL=http://localhost:${SEARXNG_PORT}/
      - GRANIAN_PORT=${SEARXNG_PORT}
      - TZ=${TZ}

  whisper:
    image: ghcr.io/speaches-ai/speaches:latest-cpu
    container_name: whisper
    restart: unless-stopped
    ports:
      - "${WHISPER_PORT}:${WHISPER_PORT}"
    volumes:
      - ./whisper/model_aliases.json:/home/ubuntu/speaches/model_aliases.json
      - hf-hub-cache:/home/ubuntu/.cache/huggingface/hub
    environment:
      - UVICORN_HOST=0.0.0.0
      - UVICORN_PORT=${WHISPER_PORT}
      - WHISPER__INFERENCE_DEVICE=cpu
      - WHISPER__CPU_THREADS=${WHISPER_CPU_THREADS}
      - STT_MODEL_TTL=-1
      - ENABLE_UI=true
      - TZ=${TZ}

volumes:
  hf-hub-cache:
```

**Key changes from original:**
- `zeroclaw`: removed `network_mode: host`, added `ports: ["42617:42617"]` and `extra_hosts: host.docker.internal:host-gateway`
- `searxng`: removed `network_mode: host`, added `ports: ["${SEARXNG_PORT}:${SEARXNG_PORT}"]`
- `whisper`: removed `network_mode: host`, added `ports: ["${WHISPER_PORT}:${WHISPER_PORT}"]`
- **No `command` override** — let the container use its default entrypoint. The gateway bind address is set via config instead.

## 2. Dockerfile Changes

The original Dockerfile used `agent-browser install --with-deps` which fails on ARM64 because Chrome for Testing doesn't provide Linux ARM64 builds. We added a fallback to install Chromium from the system package manager:

```dockerfile
# Install Chromium for fallback (ARM64)
RUN apt-get update \
    && apt-get install -y --no-install-recommends chromium \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV AGENT_BROWSER_EXECUTABLE_PATH=/usr/bin/chromium
ENV CHROME_BIN=/usr/bin/chromium

RUN . "${NVM_DIR}/nvm.sh" \
    && agent-browser install --with-deps || true
```

## 3. ZeroClaw Configuration

### Gateway binding (required for Mac access)
```bash
docker exec zeroclaw-test zeroclaw config set gateway.host 0.0.0.0
docker exec zeroclaw-test zeroclaw config set gateway.allow_remote_admin true
```

### Remote admin (required for dashboard reloads on Mac)
```bash
docker exec zeroclaw-test zeroclaw config set gateway.allow_remote_admin true
```

### Context window (required for MCP tools + skills)
```bash
docker exec zeroclaw-test zeroclaw config set providers.models.opencode.default.context_window 128000
```

### Compact skill injection (reduces prompt size)
```bash
docker exec zeroclaw-test zeroclaw config set skills.prompt_injection_mode compact
```

### Max tool iterations (for browser tasks)
```bash
docker exec zeroclaw-test zeroclaw config set runtime_profiles.balanced.max_tool_iterations 50
```

### Risk profile (locked_down requires approval for browser actions)
Set to `locked_down` (default) — browser actions require approval. For demo, this is fine since Gibbs will ask for approval.

## 4. Discord Setup

Follow the blog post's Discord setup, but note:
- The bot token is stored encrypted in `config.toml`
- Peer groups gate by **sender (user ID)**, not channel ID
- To allow everyone in a channel: set `external_peers = ["*"]` in the peer group
- Channel filtering is done via `channel_ids` in the Discord channel config
- After config changes, `docker compose restart zeroclaw` is required (no daemon supervisor with standalone gateway)

### Config applied:
```toml
[channels.discord.default]
enabled = true
bot_token = "enc2:..."
slash_commands = true
stream_mode = "multi_message"
mention_only = false

[peer_groups.gibbs_allow_discord]
channel = "discord.default"
agents = ["gibbs"]
external_peers = ["*"]
```

## 5. BrowserOS Neo MCP Integration

BrowserOS Neo MCP only binds to `127.0.0.1:9010`. Since `zeroclaw` is on bridge networking, it can't reach `127.0.0.1` on the Mac directly.

### Solution: Use `host.docker.internal`

1. BrowserOS MCP endpoint: `http://127.0.0.1:9010/mcp` (on Mac)
2. From inside the container, use: `http://host.docker.internal:9010/mcp`
3. **Critical**: BrowserOS neo only accepts `Host: localhost:9010` header. Add to config:

```toml
[[mcp.servers]]
name = "browseros_neo"
transport = "http"
url = "http://host.docker.internal:9010/mcp"
headers = { Host = "localhost:9010" }
```

4. Add MCP bundle to agent:
```toml
[mcp_bundles.host_tools]
servers = ["browseros_neo"]

[agents.gibbs]
mcp_bundles = ["host_tools"]
```

5. Restart container to pick up changes.

### Verification:
```bash
docker exec zeroclaw-test curl -s http://host.docker.internal:9010/mcp
# Should return MCP server info, not 403
```

## 6. Skills Installation

### BrowserOS Neo skill
```bash
docker exec zeroclaw-test zeroclaw skills bundle add global_tools
docker exec zeroclaw-test zeroclaw skills install https://github.com/browseros-ai/BrowserOS --skill browseros-neo --bundle global_tools
docker exec zeroclaw-test zeroclaw config set agents.gibbs.skill_bundles '["global_tools"]'
```

### agent-browser skill
```bash
docker exec zeroclaw-test zeroclaw skills install https://github.com/vercel-labs/agent-browser --skill agent-browser --bundle global_tools
```

### Trip Planner skill (agent-specific)
Created manually at:
```
data/zeroclaw/.zeroclaw/agents/gibbs/workspace/skills/trip-planner/SKILL.md
```

### Skills are loaded at session construction time — restart required after any skill change.

## 7. Transcription (Voice Input)

### Enable transcription
```bash
docker exec zeroclaw-test zeroclaw config set transcription.enabled true
docker exec zeroclaw-test zeroclaw config set transcription.transcribe_non_ptt_audio true
docker exec zeroclaw-test zeroclaw config set media_pipeline.enabled true
```

### Create transcription provider
```bash
docker exec zeroclaw-test zeroclaw providers create transcription openai default
docker exec zeroclaw-test zeroclaw config set --no-interactive providers.transcription.openai.default.api_key "dummy"
docker exec zeroclaw-test zeroclaw config set providers.transcription.openai.default.model "ggml-small"
```

### Set transcription provider for agent
```bash
docker exec zeroclaw-test zeroclaw config set agents.gibbs.transcription_provider default
```

### Whisper model download
The model is auto-downloaded on first use, but can be pre-downloaded:
```bash
docker exec zeroclaw-test curl -s -X POST http://host.docker.internal:9001/v1/models/Systran/faster-whisper-small
```

### Known issue: Voice transcription may fail with "no speech-to-text tools available"
This happens when the transcription provider isn't properly registered. Check logs for:
```
typed transcription provider skipped (config error): Missing API key
```

## 8. Ollama Integration (Local Model)

```bash
docker exec zeroclaw-test zeroclaw config set providers.models.ollama.default.uri "http://host.docker.internal:11434"
docker exec zeroclaw-test zeroclaw config set providers.models.ollama.default.model "gemma4:e4b"
docker exec zeroclaw-test zeroclaw config set providers.models.ollama.default.context_window 200000
```

## 9. Key Differences from Blog Post

| Aspect | Blog Post (Linux) | This Setup (macOS Docker Desktop) |
|--------|-------------------|-----------------------------------|
| Networking | `network_mode: host` | Bridge + port publishing for zeroclaw, host for searxng/whisper |
| Web UI access | `localhost:42617` | `localhost:42617` (via port publishing) |
| Host service access | `localhost:<port>` | `host.docker.internal:<port>` |
| Discord connectivity | Works with host networking | Works with bridge networking (bot connects outbound) |
| Daemon reload | `zeroclaw service restart` | `docker compose restart zeroclaw` (no daemon supervisor) |
| Config changes | Via UI or CLI | Via CLI only (`docker exec`) — UI reload returns 503 |
| Agent risk profile | balanced | locked_down (requires approval for browser actions) |
| TTS (Piper) | OpenAI-compatible image | Removed (ARM64 incompatible) |

## 10. Common Issues and Fixes

### "This request exceeds the selected model's context window"
- Set `context_window` on the provider: `zeroclaw config set providers.models.opencode.default.context_window 128000`
- Set `skills.prompt_injection_mode` to `compact`

### "Turn stopped: reached maximum tool iterations (10)"
- Set `max_tool_iterations` higher: `zeroclaw config set runtime_profiles.balanced.max_tool_iterations 50`

### "MCP server returned HTTP 403 Forbidden" (BrowserOS)
- Add `headers = { Host = "localhost:9010" }` to the MCP server config

### "no daemon supervisor — running as standalone gateway"
- This is expected with `gateway start` command. Use `docker compose restart zeroclaw` instead of UI reload.

### "config lifecycle is already owned"
- Remove the lock file: `docker exec zeroclaw-test rm -f /zeroclaw-data/.zeroclaw/data/.lifecycle/config-lifecycle.lock`

### Discord bot offline
- Check Message Content Intent and Server Members Intent are enabled
- Re-invite the bot with proper permissions
- Check the bot token is correct
- Restart container after config changes

### Voice transcription empty
- Ensure whisper model is downloaded: `POST /v1/models/Systran/faster-whisper-small`
- Ensure transcription provider has API key set
- Check media_pipeline.enabled = true

## 11. Quick Reference Commands

```bash
# Start everything
docker compose up -d

# Restart zeroclaw (after config changes)
docker exec zeroclaw-test rm -f /zeroclaw-data/.zeroclaw/data/.lifecycle/config-lifecycle.lock
docker compose restart zeroclaw

# Check health
docker exec zeroclaw-test zeroclaw channel doctor
docker exec zeroclaw-test zeroclaw status

# Get pairing code
docker exec zeroclaw-test zeroclaw gateway get-paircode --new --port 42617

# List skills
docker exec zeroclaw-test zeroclaw skills list --agent gibbs

# List agents
docker exec zeroclaw-test zeroclaw agents list

# Check logs
docker compose logs zeroclaw --tail 50
```