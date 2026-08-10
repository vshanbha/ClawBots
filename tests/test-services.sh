#!/usr/bin/env bash
# test-services.sh — Health checks + TTS→STT round-trip (WAV and OGG) for all ClawBots Docker services
# Usage: bash test-services.sh
# Requirements: docker, curl, ffmpeg (for OGG testing)

set -euo pipefail

PIPER_URL="http://localhost:5000"
WHISPER_URL="http://localhost:9001"
WORK_DIR=$(mktemp -d)

PASS="✅"
FAIL="❌"
WARN="⚠️"
RESULTS=()

cleanup() { rm -rf "$WORK_DIR"; }
trap cleanup EXIT

log() { echo -e "\n=== $1 ==="; }
result() {
  local status=$1 name=$2 detail=$3
  RESULTS+=("$status $name: $detail")
  echo "$status $name: $detail"
}

# ─── ClawBots ──────────────────────────────────────────────────

log "ClawBots (agent runtime)"

if docker ps --format '{{.Names}}' | grep -q '^zeroclaw$'; then
  result "$PASS" "Container" "running"

  if docker exec zeroclaw zeroclaw status >/dev/null 2>&1; then
    result "$PASS" "zeroclaw status" "exit code 0"
    VERSION=$(docker exec zeroclaw zeroclaw status 2>&1 | grep -oP 'Version:\s+\K.*' || echo "unknown")
    SERVICE=$(docker exec zeroclaw zeroclaw status 2>&1 | grep -oP 'Service:\s+\K.*' || echo "unknown")
    result "$PASS" "Version" "$VERSION"
    if [ "$SERVICE" = "stopped" ]; then
      result "$WARN" "Service mode" "containerized (daemon runs as PID 1, not systemd)"
    elif [ "$SERVICE" = "running" ]; then
      result "$PASS" "Service state" "$SERVICE"
    else
      result "$PASS" "Service state" "$SERVICE"
    fi
  else
    result "$FAIL" "zeroclaw status" "non-zero exit"
  fi

  if docker exec zeroclaw test -f /zeroclaw-data/.zeroclaw/config.toml 2>/dev/null; then
    result "$PASS" "Config mount" "/zeroclaw-data/.zeroclaw/config.toml exists"
  else
    result "$WARN" "Config mount" "config.toml not found"
  fi

  DAEMON_STATE=$(docker exec zeroclaw cat /zeroclaw-data/.zeroclaw/state/daemon_state.json 2>/dev/null || echo "")
  if [ -n "$DAEMON_STATE" ]; then
    DAEMON_STATUS=$(echo "$DAEMON_STATE" | grep -A5 '"daemon"' | grep -oP '"status":\s*"\K[^"]+' || echo "unknown")
    GATEWAY_STATUS=$(echo "$DAEMON_STATE" | grep -A5 '"gateway"' | grep -oP '"status":\s*"\K[^"]+' || echo "unknown")
    DISCORD_RAMLAL=$(echo "$DAEMON_STATE" | grep -A5 '"channel:discord.ramlal_zeroclaw"' | grep -oP '"status":\s*"\K[^"]+' || echo "unknown")
    DISCORD_REVERMO=$(echo "$DAEMON_STATE" | grep -A5 '"channel:discord.revermo_buddy"' | grep -oP '"status":\s*"\K[^"]+' || echo "unknown")

    if [ "$DAEMON_STATUS" = "ok" ]; then
      result "$PASS" "Daemon" "ok"
    else
      result "$FAIL" "Daemon" "$DAEMON_STATUS"
    fi

    if [ "$GATEWAY_STATUS" = "ok" ]; then
      result "$PASS" "Gateway" "ok"
    else
      result "$FAIL" "Gateway" "$GATEWAY_STATUS"
    fi

    if [ "$DISCORD_RAMLAL" = "ok" ]; then
      result "$PASS" "Discord (ramlal)" "connected"
    else
      result "$FAIL" "Discord (ramlal)" "$DISCORD_RAMLAL"
    fi

    if [ "$DISCORD_REVERMO" = "ok" ]; then
      result "$PASS" "Discord (revermo_buddy)" "connected"
    else
      result "$FAIL" "Discord (revermo_buddy)" "$DISCORD_REVERMO"
    fi
  else
    result "$WARN" "Daemon state" "could not read daemon_state.json"
  fi
else
  result "$FAIL" "Container" "not running"
fi

# ─── Whisper (STT) ────────────────────────────────────────────

log "Whisper (speech-to-text)"

if docker ps --format '{{.Names}}' | grep -q '^whisper$'; then
  result "$PASS" "Container" "running"

  WHISPER_HEALTH=$(curl -sf http://localhost:9001/health 2>/dev/null || echo "FAIL")
  if echo "$WHISPER_HEALTH" | grep -q "OK"; then
    result "$PASS" "Health endpoint" "$WHISPER_HEALTH"
  else
    result "$FAIL" "Health endpoint" "unreachable or error"
  fi

  WHISPER_UI_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9001/ 2>/dev/null) || WHISPER_UI_CODE="000"
  if [ "$WHISPER_UI_CODE" = "200" ]; then
    result "$PASS" "Server UI" "HTTP $WHISPER_UI_CODE"
  else
    result "$FAIL" "Server UI" "HTTP $WHISPER_UI_CODE"
  fi
else
  result "$FAIL" "Container" "not running"
fi

# ─── Piper (TTS) ──────────────────────────────────────────────

log "Piper (text-to-speech)"

PIPER_RUNNING=false
if docker ps --format '{{.Names}}' | grep -q '^piper$'; then
  result "$PASS" "Container" "running"
  PIPER_RUNNING=true

  # Test TTS endpoint directly (root returns 404, that's normal)
  PIPER_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "$PIPER_URL/v1/audio/speech" \
    -H "Content-Type: application/json" \
    -d '{"input":"test","model":"tts-1","voice":"en_GB-alan-medium"}' \
    2>/dev/null) || PIPER_CODE="000"
  if [ "$PIPER_CODE" = "200" ]; then
    result "$PASS" "TTS endpoint" "HTTP $PIPER_CODE (speech generation working)"
  else
    result "$FAIL" "TTS endpoint" "HTTP $PIPER_CODE"
  fi
else
  result "$FAIL" "Container" "not running"
fi

# ─── SearXNG (search) ────────────────────────────────────────

log "SearXNG (web search)"

if docker ps --format '{{.Names}}' | grep -q '^searxng$'; then
  result "$PASS" "Container" "running"

  SEARCH_RESULT=$(curl -sf "http://localhost:5321/search?q=hello+world&format=json" 2>/dev/null || echo "FAIL")
  if echo "$SEARCH_RESULT" | grep -qi '"results"'; then
    RESULT_COUNT=$(echo "$SEARCH_RESULT" | grep -oP '"url"' | wc -l)
    result "$PASS" "Search endpoint" "returned $RESULT_COUNT results"
  else
    result "$FAIL" "Search endpoint" "no results or unreachable"
  fi
else
  result "$FAIL" "Container" "not running"
fi

# ─── Round-trip: Piper TTS → Whisper STT ─────────────────────

ROUNDTRIP_OK=0
ROUNDTRIP_FAIL=0
ROUNDTRIP_SKIP=0

# Only run if both services are up
WHISPER_UP=false
docker ps --format '{{.Names}}' | grep -q '^whisper$' && WHISPER_UP=true

if $PIPER_RUNNING && $WHISPER_UP; then

  log "Round-trip: Piper → Whisper"

  PHRASES=(
    "Hello this is a test of the speech loop"
    "Testing one two three"
    "The quick brown fox jumps over the lazy dog"
  )

  for i in "${!PHRASES[@]}"; do
    phrase="${PHRASES[$i]}"
    wav="$WORK_DIR/rt_test_$i.wav"

    # TTS: Piper generates WAV
    TTS_CODE=$(curl -s -o "$wav" -w "%{http_code}" \
      -X POST "$PIPER_URL/v1/audio/speech" \
      -H "Content-Type: application/json" \
      -d "{\"input\":\"$phrase\",\"model\":\"tts-1\",\"voice\":\"en_GB-alan-medium\"}" \
      2>/dev/null) || TTS_CODE="000"

    if [ "$TTS_CODE" != "200" ] || [ ! -s "$wav" ]; then
      echo "  ❌ TTS failed for phrase $((i+1)) (HTTP $TTS_CODE)"
      ROUNDTRIP_FAIL=$((ROUNDTRIP_FAIL + 1))
      continue
    fi

    # STT: Whisper transcribes WAV
    STT_RESPONSE=$(curl -s \
      -X POST "$WHISPER_URL/v1/audio/transcriptions" \
      -H "Content-Type: multipart/form-data" \
      -F "file=@$wav" \
      -F "model=ggml-small" \
      -F "temperature=0.0" \
      -F "response_format=json" \
      2>/dev/null) || STT_RESPONSE=""

    heard=$(echo "$STT_RESPONSE" | grep -oP '"text"\s*:\s*"\K[^"]+' || echo "")

    if [ -z "$heard" ]; then
      echo "  ❌ STT failed for phrase $((i+1)) — no text returned"
      ROUNDTRIP_FAIL=$((ROUNDTRIP_FAIL + 1))
      continue
    fi

    # Normalize: strip punctuation, lowercase
    phrase_norm=$(echo "$phrase" | tr -d '[:punct:]' | tr '[:upper:]' '[:lower:]')
    heard_norm=$(echo "$heard" | tr -d '[:punct:]' | tr '[:upper:]' '[:lower:]')

    # Count overlapping words (handles number/word conversions)
    MATCHED_WORDS=0
    TOTAL_WORDS=$(echo "$phrase_norm" | wc -w)
    for word in $phrase_norm; do
      if echo "$heard_norm" | grep -qw "$word" 2>/dev/null; then
        MATCHED_WORDS=$((MATCHED_WORDS + 1))
      fi
    done

    # Pass if more than half the words match
    THRESHOLD=$((TOTAL_WORDS / 2))
    if [ "$MATCHED_WORDS" -gt "$THRESHOLD" ]; then
      echo "  ✅ Phrase $((i+1)): \"$phrase\" → \"$heard\" ($MATCHED_WORDS/$TOTAL_WORDS words)"
      ROUNDTRIP_OK=$((ROUNDTRIP_OK + 1))
    else
      echo "  ❌ Phrase $((i+1)): \"$phrase\" → \"$heard\" ($MATCHED_WORDS/$TOTAL_WORDS words)"
      ROUNDTRIP_FAIL=$((ROUNDTRIP_FAIL + 1))
    fi
  done

  result "$PASS" "Round-trip WAV" "$ROUNDTRIP_OK/${#PHRASES[@]} matched"

else
  log "Round-trip: Piper → Whisper"
  echo "  ⏭️  Skipped — both Piper and Whisper must be running"
  ROUNDTRIP_SKIP=1
fi

# ─── Round-trip: Piper TTS → OGG → Whisper STT ───────────────
# Tests native OGG support via faster-whisper/speaches
# ffmpeg is only needed to create the OGG file from Piper's WAV output
# speaches handles OGG natively — no conversion back to WAV needed

OGG_ROUNDTRIP_OK=0
OGG_ROUNDTRIP_FAIL=0
OGG_ROUNDTRIP_SKIP=0

if $PIPER_RUNNING && $WHISPER_UP; then

  log "Round-trip: Piper → OGG → Whisper"

  # Check if ffmpeg is available for WAV→OGG conversion
  FFMPEG_CMD=""
  if command -v ffmpeg &>/dev/null; then
    FFMPEG_CMD="ffmpeg"
  elif docker ps --format '{{.Names}}' | grep -q ffmpeg; then
    FFMPEG_CMD="docker run --rm -i -v $WORK_DIR:/data jrottenberg/ffmpeg:alpine"
  else
    echo "  ⏭️  Skipped — ffmpeg not found (needed to convert WAV→OGG for testing)"
    OGG_ROUNDTRIP_SKIP=1
  fi

  if [ "$OGG_ROUNDTRIP_SKIP" -eq 0 ]; then
    for i in "${!PHRASES[@]}"; do
      phrase="${PHRASES[$i]}"
      wav="$WORK_DIR/rt_test_$i.wav"
      ogg="$WORK_DIR/rt_test_$i.ogg"

      # TTS: Piper generates WAV (reuse if already exists)
      if [ ! -s "$wav" ]; then
        TTS_CODE=$(curl -s -o "$wav" -w "%{http_code}" \
          -X POST "$PIPER_URL/v1/audio/speech" \
          -H "Content-Type: application/json" \
          -d "{\"input\":\"$phrase\",\"model\":\"tts-1\",\"voice\":\"en_GB-alan-medium\"}" \
          2>/dev/null) || TTS_CODE="000"

        if [ "$TTS_CODE" != "200" ] || [ ! -s "$wav" ]; then
          echo "  ❌ TTS failed for phrase $((i+1)) (HTTP $TTS_CODE)"
          OGG_ROUNDTRIP_FAIL=$((OGG_ROUNDTRIP_FAIL + 1))
          continue
        fi
      fi

      # Convert WAV → OGG using ffmpeg
      if [ "$FFMPEG_CMD" = "ffmpeg" ]; then
        $FFMPEG_CMD -y -i "$wav" -c:a libopus "$ogg" 2>/dev/null
      else
        docker run --rm -i -v "$WORK_DIR":/data jrottenberg/ffmpeg:alpine \
          -i /data/rt_test_$i.wav -c:a libopus /data/rt_test_$i.ogg 2>/dev/null
      fi

      if [ ! -s "$ogg" ]; then
        echo "  ❌ WAV→OGG conversion failed for phrase $((i+1))"
        OGG_ROUNDTRIP_FAIL=$((OGG_ROUNDTRIP_FAIL + 1))
        continue
      fi

      # STT: Whisper transcribes OGG directly (speaches handles format conversion)
      STT_RESPONSE=$(curl -s \
        -X POST "$WHISPER_URL/v1/audio/transcriptions" \
        -H "Content-Type: multipart/form-data" \
        -F "file=@$ogg" \
        -F "model=ggml-small" \
        -F "temperature=0.0" \
        -F "response_format=json" \
        2>/dev/null) || STT_RESPONSE=""

      heard=$(echo "$STT_RESPONSE" | grep -oP '"text"\s*:\s*"\K[^"]+' || echo "")

      if [ -z "$heard" ]; then
        echo "  ❌ STT failed for phrase $((i+1)) — no text returned"
        OGG_ROUNDTRIP_FAIL=$((OGG_ROUNDTRIP_FAIL + 1))
        continue
      fi

      # Normalize: strip punctuation, lowercase
      phrase_norm=$(echo "$phrase" | tr -d '[:punct:]' | tr '[:upper:]' '[:lower:]')
      heard_norm=$(echo "$heard" | tr -d '[:punct:]' | tr '[:upper:]' '[:lower:]')

      # Count overlapping words
      MATCHED_WORDS=0
      TOTAL_WORDS=$(echo "$phrase_norm" | wc -w)
      for word in $phrase_norm; do
        if echo "$heard_norm" | grep -qw "$word" 2>/dev/null; then
          MATCHED_WORDS=$((MATCHED_WORDS + 1))
        fi
      done

      # Pass if more than half the words match
      THRESHOLD=$((TOTAL_WORDS / 2))
      if [ "$MATCHED_WORDS" -gt "$THRESHOLD" ]; then
        echo "  ✅ Phrase $((i+1)): \"$phrase\" → \"$heard\" ($MATCHED_WORDS/$TOTAL_WORDS words)"
        OGG_ROUNDTRIP_OK=$((OGG_ROUNDTRIP_OK + 1))
      else
        echo "  ❌ Phrase $((i+1)): \"$phrase\" → \"$heard\" ($MATCHED_WORDS/$TOTAL_WORDS words)"
        OGG_ROUNDTRIP_FAIL=$((OGG_ROUNDTRIP_FAIL + 1))
      fi
    done

    result "$PASS" "Round-trip OGG" "$OGG_ROUNDTRIP_OK/${#PHRASES[@]} matched"
  fi

else
  log "Round-trip: Piper → OGG → Whisper"
  echo "  ⏭️  Skipped — both Piper and Whisper must be running"
  OGG_ROUNDTRIP_SKIP=1
fi

# ─── Summary ───────────────────────────────────────────────────

log "Summary"

TOTAL=${#RESULTS[@]}
PASSED=$(printf '%s\n' "${RESULTS[@]}" | grep -c "^✅" || true)
FAILED=$(printf '%s\n' "${RESULTS[@]}" | grep -c "^❌" || true)
WARNED=$(printf '%s\n' "${RESULTS[@]}" | grep -c "^⚠️" || true)

echo "Total: $TOTAL | Pass: $PASSED | Fail: $FAILED | Warn: $WARNED"

if [ "$ROUNDTRIP_SKIP" -eq 0 ]; then
  echo "Round-trip WAV: ${#PHRASES[@]} phrases | Matched: $ROUNDTRIP_OK | Failed: $ROUNDTRIP_FAIL"
fi

if [ "$OGG_ROUNDTRIP_SKIP" -eq 0 ]; then
  echo "Round-trip OGG: ${#PHRASES[@]} phrases | Matched: $OGG_ROUNDTRIP_OK | Failed: $OGG_ROUNDTRIP_FAIL"
fi

if [ "$FAILED" -gt 0 ]; then
  echo ""
  echo "Some services failed. Check the output above."
  exit 1
else
  echo ""
  echo "All services healthy."
  exit 0
fi
