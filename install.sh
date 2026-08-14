#!/usr/bin/env bash
# install.sh — Diagnostic tool and setup for ClawBots Docker Infrastructure
# Checks dependencies, detects environment, writes .env, reports problems.
# Usage: bash install.sh

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
ENV_EXAMPLE="$SCRIPT_DIR/.env.example"

pass() { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}!${NC} $1"; }
fail() { echo -e "${RED}✗${NC} $1"; ERRORS=$((ERRORS + 1)); }

ERRORS=0

echo "=== ClawBots Installer ==="
echo ""

# ─── Check dependencies ────────────────────────────────────────

echo "--- Dependencies ---"

if command -v docker &>/dev/null; then
  DOCKER_VERSION=$(docker --version | grep -oP '\d+\.\d+\.\d+' | head -1)
  pass "docker $DOCKER_VERSION"
else
  fail "docker not found — install from https://docs.docker.com/get-docker/"
fi

if docker compose version &>/dev/null; then
  COMPOSE_VERSION=$(docker compose version | grep -oP '\d+\.\d+\.\d+' | head -1)
  pass "docker compose $COMPOSE_VERSION"
elif command -v docker-compose &>/dev/null; then
  warn "docker-compose (legacy) found — 'docker compose' (v2) recommended"
else
  fail "docker compose not found — install Docker Compose v2"
fi

if command -v curl &>/dev/null; then
  pass "curl"
else
  warn "curl not found — health checks may fail"
fi

if command -v bash &>/dev/null; then
  pass "bash"
else
  fail "bash not found"
fi

echo ""

# ─── Detect environment ────────────────────────────────────────

echo "--- Environment ---"

UID_VAL=$(id -u)
GID_VAL=$(id -g)
USER_NAME=$(id -un)
pass "user: $USER_NAME (UID=$UID_VAL, GID=$GID_VAL)"

if [ "$UID_VAL" -eq 0 ]; then
  warn "running as root — files will be owned by root. Run as a non-root user instead."
fi

KERNEL=$(uname -s)
ARCH=$(uname -m)
pass "platform: $KERNEL $ARCH"

if [ -f /etc/os-release ]; then
  DISTRO=$(grep ^PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')
  pass "os: $DISTRO"
fi

echo ""

# ─── Check Docker daemon ──────────────────────────────────────

echo "--- Docker daemon ---"

if docker info &>/dev/null; then
  pass "docker daemon running"
else
  fail "docker daemon not running — start Docker first"
fi

echo ""

# ─── Check existing containers ────────────────────────────────

echo "--- Existing containers ---"

for name in zeroclaw whisper piper searxng; do
  if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${name}$"; then
    STATUS=$(docker inspect --format '{{.State.Status}}' "$name" 2>/dev/null || echo "unknown")
    pass "$name: $STATUS"
  else
    warn "$name: not running"
  fi
done

echo ""

# ─── Check ports ──────────────────────────────────────────────

echo "--- Port availability ---"

PORTS=(42617:zeroclaw 5000:piper 5321:searxng 9001:whisper)
for entry in "${PORTS[@]}"; do
  PORT="${entry%%:*}"
  SVC="${entry##*:}"
  if ss -tlnp 2>/dev/null | grep -q ":${PORT} " || \
     netstat -tlnp 2>/dev/null | grep -q ":${PORT} "; then
    warn "port $PORT ($SVC) already in use"
  else
    pass "port $PORT ($SVC) available"
  fi
done

echo ""

# ─── Write .env ───────────────────────────────────────────────

echo "--- Configuration ---"

if [ ! -f "$ENV_EXAMPLE" ]; then
  fail ".env.example not found in $SCRIPT_DIR"
  echo ""
  echo "Errors found: $ERRORS"
  exit 1
fi

if [ -f "$ENV_FILE" ]; then
  pass ".env exists"
else
  cp "$ENV_EXAMPLE" "$ENV_FILE"
  pass "created .env from .env.example"
  echo "  Edit .env to set UID, GID, and other values for your system"
fi

echo ""

# ─── Check for missing variables ──────────────────────────────

echo "--- .env validation ---"

# Extract variable names from .env.example (lines with VAR=, excluding comments and empty)
REQUIRED_VARS=$(grep -E '^[A-Z_]+=' "$ENV_EXAMPLE" | sed 's/=.*//' | sort)

MISSING=()
for var in $REQUIRED_VARS; do
  if ! grep -q "^${var}=" "$ENV_FILE" 2>/dev/null; then
    MISSING+=("$var")
  fi
done

if [ ${#MISSING[@]} -gt 0 ]; then
  fail "missing variables in .env:"
  for var in "${MISSING[@]}"; do
    DEFAULT=$(grep "^${var}=" "$ENV_EXAMPLE" | sed 's/^[^=]*=//')
    echo "    ${var} (default: ${DEFAULT})"
  done
  echo ""
  echo "  Copy missing values from .env.example into .env"
else
  pass "all required variables present in .env"
fi

echo ""

# ─── Summary ──────────────────────────────────────────────────

if [ "$ERRORS" -gt 0 ]; then
  echo -e "${RED}Found $ERRORS error(s) — fix the issues above and re-run.${NC}"
  exit 1
fi

echo -e "${GREEN}All checks passed.${NC}"
echo ""

# ─── Build and start ──────────────────────────────────────────

echo "--- Building and starting containers ---"

cd "$SCRIPT_DIR"
docker compose up -d --build
echo ""

# ─── Run tests ────────────────────────────────────────────────

echo "--- Running health checks ---"
bash "$SCRIPT_DIR/tests/test-services.sh"
