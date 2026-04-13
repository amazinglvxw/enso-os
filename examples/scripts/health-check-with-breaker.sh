#!/usr/bin/env zsh
# health-check.sh — L3 infrastructure health check (v2: with circuit breaker)
# Exit: 0=healthy, 1=issues found
# Outputs warnings to stdout (visible to Agent via SessionStart hook)
# v2 change: SYSTEM_OFFLINE errors are logged at most once per hour (circuit breaker)

EVOLUTION_LOG="${1:-$HOME/.claude/projects/-Users-lusu-Desktop/memory/evolution-log.md}"
BREAKER_DIR="/tmp/enso-health-breaker"
BREAKER_TTL=3600  # 1 hour cooldown per issue type
ISSUES=()

mkdir -p "$BREAKER_DIR"

# Circuit breaker helper: returns 0 if should log, 1 if suppressed
should_log() {
  local key="$1"
  local lockfile="$BREAKER_DIR/$key"
  if [[ -f "$lockfile" ]]; then
    local age=$(( $(date +%s) - $(stat -f %m "$lockfile" 2>/dev/null || stat -c %Y "$lockfile" 2>/dev/null || echo 0) ))
    if [[ "$age" -lt "$BREAKER_TTL" ]]; then
      return 1  # suppressed
    fi
  fi
  touch "$lockfile"
  return 0  # should log
}

# 1. Docker daemon
if ! timeout 3 docker info >/dev/null 2>&1; then
  ISSUES+=("Docker daemon not running")
fi

# 2. Qdrant container (try auto-restart if down)
if ! curl -s --max-time 2 http://localhost:6333/healthz >/dev/null 2>&1; then
  docker start qdrant >/dev/null 2>&1 || true
  # Poll instead of fixed sleep (0.5s intervals, 4 attempts = 2s max)
  QDRANT_UP=false
  for _i in 1 2 3 4; do
    sleep 0.5
    if curl -s --max-time 1 http://localhost:6333/healthz >/dev/null 2>&1; then
      QDRANT_UP=true; break
    fi
  done
  if [[ "$QDRANT_UP" != "true" ]]; then
    ISSUES+=("Qdrant unreachable at localhost:6333 (auto-restart failed)")
  else
    echo "INFO: Qdrant was down, auto-restarted successfully"
  fi
fi

# 3. Gemini API reachability
GEMINI_KEY="${GEMINI_API_KEY:-}"
if [[ -n "$GEMINI_KEY" ]]; then
  if ! curl -s --max-time 2 "https://generativelanguage.googleapis.com/v1beta/models?key=$GEMINI_KEY" >/dev/null 2>&1; then
    ISSUES+=("Gemini API unreachable (network/VPN issue?)")
  fi
fi

# Report
if [[ ${#ISSUES[@]} -gt 0 ]]; then
  DATE=$(date +"%m-%d")
  LOGGED=0
  SUPPRESSED=0
  mkdir -p "$(dirname "$EVOLUTION_LOG")"
  touch "$EVOLUTION_LOG"
  for issue in "${ISSUES[@]}"; do
    # Circuit breaker: deduplicate by issue hash
    key=$(echo "$issue" | tr ' /' '__' | tr -cd '[:alnum:]_')
    if should_log "$key"; then
      cat >> "$EVOLUTION_LOG" <<EOF

### [$DATE] SYSTEM_OFFLINE: $issue
- **Type**: infrastructure_check
- **Action**: auto-restart attempted
EOF
      LOGGED=$((LOGGED + 1))
    else
      SUPPRESSED=$((SUPPRESSED + 1))
    fi
  done
  if [[ "$SUPPRESSED" -gt 0 ]]; then
    echo "WARNING: ${#ISSUES[@]} issue(s): ${ISSUES[*]} ($SUPPRESSED suppressed by circuit breaker)"
  else
    echo "WARNING: ${#ISSUES[@]} infrastructure issue(s): ${ISSUES[*]}"
  fi
  EXIT_CODE=1
else
  echo "OK: All systems healthy (Docker, Qdrant, Gemini API)"
  # Clear breaker state when healthy
  rm -f "$BREAKER_DIR"/* 2>/dev/null
  EXIT_CODE=0
fi

# 记录会话开始时间戳（供 execlog-guard.sh 使用）
date +%s > /tmp/claude-session-start
rm -f /tmp/claude-execlog-reminded

# 检查 Nightly Review 是否有待审批的 ENFORCED 提案
PATTERN_COUNTS="$HOME/.claude/projects/-Users-lusu-Desktop/memory/nightly-reviews/pattern-counts.json"
if [[ -f "$PATTERN_COUNTS" ]]; then
  PENDING=$(python3 -c "
import json, sys
try:
    data = json.load(open('$PATTERN_COUNTS'))
    pending = [k for k, v in data.items() if v.get('level') == 'ENFORCED_PENDING']
    if pending:
        print('ENFORCED_PENDING: ' + ', '.join(pending))
except:
    pass
" 2>/dev/null)
  if [[ -n "$PENDING" ]]; then
    echo "⚠️ Nightly Review 有待审批的 ENFORCED 升级提案: $PENDING"
    echo "查看详情: cat ~/.claude/projects/-Users-lusu-Desktop/memory/nightly-reviews/$(date +%Y-%m-%d).md"
  fi
fi

exit $EXIT_CODE
