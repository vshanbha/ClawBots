# ClawBots

## Quick Start: Get Infrastructure Up and Running

### Prerequisites
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (macOS) or [Docker Engine](https://docs.docker.com/engine/install/) (Linux)
- Ollama (optional if using OpenCode) installed on host
- At least 8GB RAM recommended

### 1. Clone
```bash
git clone <repo-url>
cd ClawBots
```

### 2. Configure Environment
```bash
cp .env.example .env
```

Edit `.env` with your values:
```env
UID=$(id -u)
GID=$(id -g)
SEARXNG_PORT=5321
WHISPER_PORT=9001
AGENT_NAME=<your_agent_name>
SHARED_WORKSPACE_HOST=<absolute_path_to_workspace>
SHARED_WORKSPACE_CONTAINER=/workspace
TZ=UTC
```

### 3. Pull Local Model (Optional - only if using local models)
```bash
ollama serve &
ollama pull lfm3:latest
```

### 4. Start All Services
```bash
docker compose up -d --build
```

This will start:
- **zeroclaw** (port 42617) - Agent orchestrator
- **searxng** (port 5321) - Web search
- **whisper** (port 9001) - Speech-to-text

### 5. Verify Infrastructure
```bash
# Check all containers
docker compose ps

# Test services
curl http://localhost:9001/health
curl "http://localhost:5321/search?q=test&format=json"
curl http://localhost:42617/health
```

If all checks pass, your infrastructure is up and running. Continue to [YOUR_FIRST_AGENT_SETUP.md](docs/YOUR_FIRST_AGENT_SETUP.md) to configure agents, models, channels, and skills.
