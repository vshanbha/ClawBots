# Your First Agent Setup

This guide covers everything after infrastructure is running - models, providers, agents, peer groups, channels, external services, skills, and troubleshooting. Based on a working configuration.

## Prerequisites
Infrastructure from README.md must be up and running. Ollama must be running with models pulled.

## 0. Core Settings
```toml
schema_version = 3

[tools]
optional = ["*"]

[onboard_state]
quickstart_completed = true
completed_sections = ["memory"]

[media_pipeline]
enabled = true

[skills]
prompt_injection_mode = "compact"
```

## 1. Configure Models & Providers

Edit `data/zeroclaw/.zeroclaw/config.toml`.

### Ollama (Local - Optional if using OpenCode)
```toml
[providers.models.ollama.default]
uri = "http://host.docker.internal:11434"
model = "lfm3:latest"
context_window = 262144
fallback_models = ["gemma4:e4b"]
```

### OpenCode Inference (Cloud)
```toml
[providers.models.opencode.default]
api_key = "<your_openai_compatible_key>"
uri = "https://opencode.ai/inference/go/openai/v1/chat/completions"
model = "beam-free"
context_window = 1048576
live_pricing = true
vision = true
think = true
fallback = ["mimo-v2.6-flash"]
```

## 2. Configure Memory
```toml
[memory]
backend = "markdown"
auto_save = true
hygiene_enabled = true
search_mode = "hybrid"
retrieval_stages = ["fts", "vector"]
archive_after_days = 7
conversation_retention_days = 30
```

```toml
[memory.policy]
redact_categories = ["secret", "api_key", "private_key", "email", "phone"]
redact_on_write = false
threat_scan = "on"
```

## 3. Configure Skills & MCP

### Global Skills Bundle
```toml
[skill_bundles.global_tools]
```
This bundle references skills in `shared/skills/global_tools/`. Skills are installed via `npx skills add` (not manually placing files):
```bash
# Install agent-browser skill
npx skills add vercel-labs/agent-browser -g --bundle global_tools

# Install browseros-neo skill (from BrowserOS Neo MCP connection)
# BrowserOS Neo installs this skill automatically when connected
```

These are shared skills loaded for any agent listing this bundle in `skill_bundles`. To add custom skills, use `zeroclaw skills install <source> --bundle global_tools`.

### MCP Bundles
```toml
[mcp_bundles.host_tools]
servers = ["browseros_neo"]
```

### BrowserOS Neo MCP (Browser Automation)
Start [BrowserOS Neo](https://browseros.com/) separately on host, listening on port 9010.
```toml
[mcp]

[[mcp.servers]]
name = "browseros_neo"
transport = "http"
url = "http://host.docker.internal:9010/mcp"
headers = { Host = "localhost:9010" }
```

## 4. Configure External Services

### Web Search (SearXNG)
```toml
[web_search]
searxng_instance_url = "http://host.docker.internal:5321"
search_provider = "searxng"
```
SearXNG is already running from docker-compose. Config at `data/searxng/settings.yml`.

### Speech-to-Text (Whisper)
```toml
[transcription]
api_url = "http://host.docker.internal:9001/v1/audio/transcriptions"
transcribe_non_ptt_audio = true
model = "ggml-small"
enabled = true
```

### Media Pipeline (see Core Settings above)

## 5. Configure Agents

### Agent Definitions
```toml
[agents.<agent_name>]
model_provider = "opencode.default"
runtime_profile = "<agent_name>"
risk_profile = "<agent_name>"
channels = ["discord.default"]
mcp_bundles = ["host_tools"]
skill_bundles = ["global_tools"]
transcription_provider = "default"
delegate_same_risk_profile = true

[[agents.<agent_name>.delegates]]
agent = "<subagent_name>"
mode = "bounded"
```

### Runtime Profile
```toml
[runtime_profiles.<agent_name>]
agentic = true
max_tool_iterations = 50
max_actions_per_hour = 20
max_cost_per_day_cents = 500
max_delegation_depth = 3
shell_timeout_secs = 60
strict_tool_parsing = false
max_context_tokens = 262144
token_budget = 262144
# Adjust max_context_tokens/token_budget to match your model's context window
deferred_builtin_tools = false

[runtime_profiles.<agent_name>.context_compression]
enabled = true
threshold_ratio = 0.9
max_passes = 1
protect_first_n = 5
protect_last_n = 6
source_max_chars = 30000
summary_max_chars = 2000
tool_result_retrim_chars = 1000
identifier_policy = "strict"
timeout_secs = 60

[runtime_profiles.<agent_name>.thinking]
default_level = "medium"
display = "off"
native_thinking = false

[runtime_profiles.<agent_name>.history_pruning]
enabled = false
collapse_tool_results = true
keep_recent = 4
max_tokens = 262144
```

### Risk Profile
```toml
[risk_profiles.<agent_name>]
level = "supervised"
sandbox_enabled = true
workspace_only = true
block_high_risk_commands = true
require_approval_for_medium_risk = true
allowed_tools = ["*"]
allowed_commands = ["git", "npm", "cargo", "ls", "cat", "grep", "find", "echo", "pwd", "wc", "head", "tail", "date", "df", "du", "uname", "uptime", "hostname", "python", "python3", "pip", "node", "free"]
forbidden_paths = ["/etc", "/root", "/home", "/usr", "/bin", "/sbin", "/lib", "/opt", "/boot", "/dev", "/proc", "/sys", "/var", "/tmp", "~/.ssh", "~/.gnupg", "~/.aws", "~/.config"]
auto_approve = ["file_read", "memory_recall", "web_search_tool", "web_fetch", "calculator", "glob_search", "content_search", "image_info", "weather", "tool_search", "browser_open", "memory_store", "git_operations", "canvas", "TodoWrite", "sessions_list", "sessions_current", "sessions_history", "ask_user", "escalate_to_human", "mcp_resources", "mcp_prompts", "browseros_neo__navigate", "browseros_neo__run_skill", "browseros_neo__windows", "browseros_neo__mark_skill_run", "browseros_neo__tabs", "browseros_neo__read", "browseros_neo__name_session", "browseros_neo__request_human_help", "browseros_neo__save_skill", "browseros_neo__pdf", "browseros_neo__screenshot", "browseros_neo__snapshot", "browseros_neo__run", "browseros_neo__tab_groups", "browseros_neo__await_human_help"]

[risk_profiles.<agent_name>.delegation_policy]
mode = "allow"
```

## 6. Configure Channels

### Discord
```toml
[channels.discord.default]
enabled = true
bot_token = "<your_discord_bot_token>"
slash_commands = true
mention_only = false
listen_to_bots = false
approval_timeout_secs = 3600
stream_mode = "multi_message"
```

Get bot token from Discord Developer Portal. Enable Message Content Intent and Server Members Intent.

### Peer Groups
```toml
[peer_groups.<group_name>]
agents = ["<agent_name>", "<subagent_name>"]
channel = "discord.default"
external_peers = ["*"]
output_modality = "mirror"
admin_for_agent_scope = false
```

## 7. Gateway Configuration
```toml
[gateway]
host = "0.0.0.0"
allow_remote_admin = true
paired_tokens = ["<paired_tokens>"]
```

## 8. Apply Configuration

```bash
# Remove config lock if present
docker exec zeroclaw-test rm -f /zeroclaw-data/.zeroclaw/data/.lifecycle/config-lifecycle.lock

# Restart ZeroClaw
docker compose restart zeroclaw

# Verify
docker compose logs zeroclaw --tail 40
docker exec zeroclaw-test zeroclaw status
docker exec zeroclaw-test zeroclaw agents list
```

## 9. Troubleshooting & Tweaks

| Issue | Fix |
|-------|-----|
| Context window exceeded | Verify `context_window` matches model (lfm3: 262144, beam-free: 1048576). Enable/tune context compression. |
| Provider rejects compressed request | Use conservative compression (threshold 0.9, max_passes 1). |
| Tools not available | Check risk profile `allowed_tools` and permissions. |
| Delegation failing | Set `delegation_policy.mode = "allow"` and increase `max_delegation_depth`. |
| MCP browser tools failing | Ensure BrowserOS Neo running at `:9010`, check MCP config headers. |
| SearXNG 403 | Check `data/searxng/settings.yml` - disable bot detection/limiter for local use. |
| Whisper issues | Verify `http://localhost:9001/health`, check model download. |
| Config lock stuck | Remove lifecycle lock file and restart. |
| Ollama unreachable from container | Use `host.docker.internal:11434` on macOS/Docker Desktop. |

## Tips
- Match context windows exactly to model capabilities
- Use conservative compression settings with free/strict models
- Keep skills in global bundle for reuse across agents
- Browser automation requires separate BrowserOS Neo instance
- Test after each major config change with a restart
