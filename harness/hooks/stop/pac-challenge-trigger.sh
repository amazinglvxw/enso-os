#!/usr/bin/env bash
# pac-challenge-trigger.sh — Stop Hook: PAC 主动问责挑战触发器
#
# 流程:
#   1. 会话结束时,运行 pac-analyzer.py 扫描 5 种自我限制模式
#   2. 若有 confidence >= threshold 的 self_limiting 信号,生成 Socratic 挑战
#   3. 将挑战写入 ~/.enso/pac/pending/ 供下次 SessionStart 注入
#   4. 频率控制: 24h / 3-per-week / 7天同主题沉默期 / 3次拒绝1月熔断
#
# 设计原则:
#   - 静默优先: 没有信号 → 安静退出,不打扰用户
#   - 频率控制: 宁可漏发,不要刷屏
#   - 可禁用: PAC_ENABLED=false 则完全跳过
#   - 并发安全: flock 保护 rate-state 防止多 session 同时写入
#
# 依赖:
#   - harness/core/pac-analyzer.py
#   - harness/core/pac-question-generator.py (经由 adapter.sh 走 LLM fallback)
#   - harness/core/env.sh (提供 enso_ts)

set -euo pipefail

# shellcheck disable=SC2034  # ENSO_INPUT consumed by env.sh
ENSO_INPUT=""
# shellcheck disable=SC1091
source "${ENSO_CORE:-$HOME/.enso/core}/env.sh" 2>/dev/null || true

PAC_ENABLED="${PAC_ENABLED:-true}"
[ "$PAC_ENABLED" != "true" ] && exit 0

ENSO_MEMORY_DIR="${ENSO_MEMORY_DIR:-$HOME/.claude/projects/-Users-user-Desktop/memory}"

PAC_DIR="${ENSO_PAC_DIR:-$HOME/.enso/pac}"
mkdir -p "$PAC_DIR/pending" "$PAC_DIR/history"

RATE_STATE="$PAC_DIR/rate-state"
RATE_LOCK="$PAC_DIR/rate-state.lock"
COOLDOWN_FLAG="$PAC_DIR/cooldown-until"

NOW=$(date +%s)

# Use enso_ts() from env.sh if available, else portable inline
_ts() {
    if declare -F enso_ts &>/dev/null; then
        enso_ts
    else
        date -u +"%Y-%m-%dT%H:%M:%SZ"
    fi
}

# ----------------------------------------------------------------------------
# 1. 熔断检查: 连续 3 次被拒绝 → 1 个月沉默
# ----------------------------------------------------------------------------
if [ -f "$COOLDOWN_FLAG" ]; then
    COOLDOWN_UNTIL=$(cat "$COOLDOWN_FLAG" 2>/dev/null || echo "0")
    case "$COOLDOWN_UNTIL" in ''|*[!0-9]*) COOLDOWN_UNTIL=0 ;; esac
    if [ "$NOW" -lt "$COOLDOWN_UNTIL" ]; then
        exit 0
    fi
    rm -f "$COOLDOWN_FLAG"
fi

# ----------------------------------------------------------------------------
# 2. 频率控制 (flock 保护): 24h 最少间隔 + 每周上限 3 次
# ----------------------------------------------------------------------------
MIN_INTERVAL_HOURS="${PAC_MIN_INTERVAL_HOURS:-24}"
MAX_PER_WEEK="${PAC_MAX_PER_WEEK:-3}"
MIN_INTERVAL_SEC=$((MIN_INTERVAL_HOURS * 3600))
WEEK_START=$((NOW - 7 * 86400))

# Atomic check-and-reserve: prevents race when two sessions end simultaneously.
_rate_check_and_reserve() {
    local state="$1" lock="$2"
    if command -v flock &>/dev/null; then
        exec 9>"$lock"
        flock -n 9 || return 1
    else
        mkdir "$lock.d" 2>/dev/null || return 1
        trap 'rmdir "$lock.d" 2>/dev/null || true' EXIT
    fi

    if [ -s "$state" ]; then
        local last
        last=$(tail -1 "$state" 2>/dev/null | grep -E '^[0-9]+$' || echo "0")
        if [ "$last" != "0" ] && [ $((NOW - last)) -lt "$MIN_INTERVAL_SEC" ]; then
            return 2
        fi
    fi

    local week_count=0
    if [ -s "$state" ]; then
        while IFS= read -r ts; do
            case "$ts" in ''|*[!0-9]*) continue ;; esac
            [ "$ts" -ge "$WEEK_START" ] && week_count=$((week_count + 1))
        done < "$state"
    fi
    if [ "$week_count" -ge "$MAX_PER_WEEK" ]; then
        return 2
    fi

    echo "$NOW" >> "$state"
    tail -14 "$state" > "$state.tmp" && mv "$state.tmp" "$state"
    return 0
}

_rate_check_and_reserve "$RATE_STATE" "$RATE_LOCK" || exit 0

# ----------------------------------------------------------------------------
# 3. 扫描模式 (调用 analyzer)
# ----------------------------------------------------------------------------
ANALYZER="${ENSO_CORE:-$HOME/.enso/core}/pac-analyzer.py"
if [ ! -f "$ANALYZER" ]; then
    ANALYZER="$(dirname "$(dirname "$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")")")/core/pac-analyzer.py"
fi
[ ! -f "$ANALYZER" ] && exit 0

SESSION_TEXT=""
if [ -n "${CLAUDE_TRANSCRIPT_PATH:-}" ] && [ -r "${CLAUDE_TRANSCRIPT_PATH}" ]; then
    # Line-based (more stable than byte truncation when regex crosses boundaries)
    SESSION_TEXT=$(tail -n 200 "${CLAUDE_TRANSCRIPT_PATH}" 2>/dev/null || echo "")
fi

# Stream session_text as JSON → analyzer. Keeps quoting clean.
SIGNALS=$(
    printf '%s' "$SESSION_TEXT" | python3 -c '
import json, sys
print(json.dumps({"session_text": sys.stdin.read()}))
' | ENSO_MEMORY_DIR="$ENSO_MEMORY_DIR" \
    PAC_CONFIDENCE_THRESHOLD="${PAC_CONFIDENCE_THRESHOLD:-0.70}" \
    python3 "$ANALYZER" 2>/dev/null
) || SIGNALS="[]"
SIGNALS="${SIGNALS:-[]}"

SIGNAL_COUNT=$(echo "$SIGNALS" | python3 -c '
import json, sys
try:
    print(len(json.loads(sys.stdin.read())))
except Exception:
    print(0)
' 2>/dev/null || echo "0")

[ "$SIGNAL_COUNT" = "0" ] && exit 0

# ----------------------------------------------------------------------------
# 4. 7 天同主题沉默期
# ----------------------------------------------------------------------------
TOP_PATTERN=$(echo "$SIGNALS" | python3 -c '
import json, sys
try:
    d = json.loads(sys.stdin.read())
    print(d[0]["pattern"] if d else "")
except Exception:
    print("")
' 2>/dev/null || echo "")

if [ -n "$TOP_PATTERN" ]; then
    LAST_PATTERN_FILE="$PAC_DIR/last-pattern-$TOP_PATTERN"
    if [ -f "$LAST_PATTERN_FILE" ]; then
        LAST_SAME_TS=$(cat "$LAST_PATTERN_FILE" 2>/dev/null || echo "0")
        case "$LAST_SAME_TS" in ''|*[!0-9]*) LAST_SAME_TS=0 ;; esac
        if [ $((NOW - LAST_SAME_TS)) -lt $((7 * 86400)) ]; then
            exit 0
        fi
    fi
    echo "$NOW" > "$LAST_PATTERN_FILE"
fi

# ----------------------------------------------------------------------------
# 5. 生成挑战 (调用 question-generator)
# ----------------------------------------------------------------------------
GENERATOR="${ENSO_CORE:-$HOME/.enso/core}/pac-question-generator.py"
[ ! -f "$GENERATOR" ] && GENERATOR="$(dirname "$ANALYZER")/pac-question-generator.py"
[ ! -f "$GENERATOR" ] && exit 0

CHALLENGE_ID="pac-$(date +%Y%m%d)-$(printf '%03d' $((RANDOM % 1000)))"
PENDING_FILE="$PAC_DIR/pending/${CHALLENGE_ID}.xml"

if ! echo "$SIGNALS" | python3 "$GENERATOR" > "$PENDING_FILE" 2>/dev/null; then
    rm -f "$PENDING_FILE"
    exit 0
fi

[ ! -s "$PENDING_FILE" ] && { rm -f "$PENDING_FILE"; exit 0; }

# ----------------------------------------------------------------------------
# 6. 记录历史 (Python encodes JSONL safely — no shell escape pitfalls)
# ----------------------------------------------------------------------------
HISTORY_FILE="$PAC_DIR/history.jsonl"
python3 -c '
import json, sys
from pathlib import Path
ts, cid, pattern, hist_path, signals_raw, pending_path = sys.argv[1:7]
record = {
    "ts": ts,
    "challenge_id": cid,
    "pattern": pattern,
    "signals": json.loads(signals_raw),
    "challenge_text": Path(pending_path).read_text(encoding="utf-8"),
    "user_response": None,
    "follow_up_at": None,
    "effectiveness_score": None,
}
with open(hist_path, "a", encoding="utf-8") as f:
    f.write(json.dumps(record, ensure_ascii=False) + "\n")
' "$(_ts)" "$CHALLENGE_ID" "$TOP_PATTERN" "$HISTORY_FILE" "$SIGNALS" "$PENDING_FILE" \
    2>/dev/null || true

# ----------------------------------------------------------------------------
# 7. 通知用户 (下次 SessionStart 会读取 pending/ 并注入)
# ----------------------------------------------------------------------------
cat >&2 <<MSG
🪞 [PAC] 检测到 ${SIGNAL_COUNT} 个自我限制模式信号 (top: ${TOP_PATTERN}).
   挑战已保存至 pending: ${CHALLENGE_ID}
   下次 session 启动时会主动呈现.
MSG

exit 0
