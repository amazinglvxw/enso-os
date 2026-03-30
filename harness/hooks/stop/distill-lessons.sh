#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# Enso Slow Track: Async Lesson Distillation
# ═══════════════════════════════════════════════════════════════
# Trigger: Stop (session ending)
# Behavior:
#   1. Error-signal gating: no errors → no distillation (success is baseline)
#   2. If errors found → call lightweight LLM to extract 1-3 atomic lessons
#   3. Append lessons to active.md with hit counters
#   4. Enforce hard caps (evict lowest-utility lessons on overflow)
#   5. Run time-decay on stale lessons
#
# Philosophy: "错误是唯一值得记住的东西" (Only mistakes are worth remembering)
# Source: fireworks-skill-memory error-signal gating
# Source: Training-Free GRPO "$18 context > $10,000 fine-tuning"
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

ENSO_DIR="${ENSO_DIR:-$HOME/.enso}"
ERROR_SEEDS="$ENSO_DIR/.error_seeds"
LESSONS_DIR="$ENSO_DIR/lessons"
LESSONS_FILE="$LESSONS_DIR/active.md"
TRACES_DIR="$ENSO_DIR/traces"
TODAY=$(date +%Y-%m-%d)
TRACE_FILE="$TRACES_DIR/$TODAY.jsonl"

MAX_LESSONS="${ENSO_MAX_LESSONS:-50}"
STALE_DAYS="${ENSO_STALE_DAYS:-30}"

mkdir -p "$LESSONS_DIR"

# ─── Error-signal gating ───
# No errors → no distillation. Smooth sessions don't produce lessons.
if [ ! -f "$ERROR_SEEDS" ] || [ ! -s "$ERROR_SEEDS" ]; then
    exit 0
fi

ERROR_COUNT=$(wc -l < "$ERROR_SEEDS" | tr -d ' ')
echo "🔬 [enso] $ERROR_COUNT error seed(s) found. Distilling..." >&2

# ─── Prepare context for distillation ───
# Combine error seeds + recent trace for context
CONTEXT=""
CONTEXT+="=== ERROR SEEDS ===\n"
CONTEXT+=$(cat "$ERROR_SEEDS")
CONTEXT+="\n\n"

if [ -f "$TRACE_FILE" ]; then
    CONTEXT+="=== RECENT TRACE (last 20 events) ===\n"
    CONTEXT+=$(tail -20 "$TRACE_FILE")
fi

# ─── Distill via CLI (uses Claude's own API) ───
# We use a heredoc prompt to Claude via the `claude` CLI if available,
# otherwise fall back to a simple pattern-matching distillation.

DISTILLED=""

if command -v claude &>/dev/null; then
    DISTILLED=$(echo -e "$CONTEXT" | claude --model claude-haiku-4-5 --print --max-turns 1 \
        "You are a lesson extractor for an AI agent. Given error seeds from a coding session, extract 1-3 atomic lessons. Each lesson must be:
- One line, under 30 words
- Actionable (tells the agent what to DO or AVOID)
- Specific (not generic advice)

Format: One lesson per line, starting with '- '
Example:
- When editing Python files, always check indentation matches surrounding context
- The Qdrant container must be running before mem0 searches

Only output lessons. No preamble. If errors are trivial/transient, output nothing." 2>/dev/null) || true
fi

# Fallback: simple keyword extraction if CLI unavailable or failed
if [ -z "$DISTILLED" ]; then
    DISTILLED=""
    # Extract unique error patterns
    while IFS= read -r line; do
        # Skip empty lines
        [ -z "$line" ] && continue
        # Extract the core error message (first 80 chars after timestamp)
        MSG=$(echo "$line" | sed 's/^\[.*\] //' | head -c 80)
        if [ -n "$MSG" ]; then
            DISTILLED+="- [auto] $MSG\n"
        fi
    done < "$ERROR_SEEDS"
fi

# ─── Append lessons with metadata ───
if [ -n "$DISTILLED" ]; then
    # Initialize lessons file if needed
    if [ ! -f "$LESSONS_FILE" ]; then
        cat > "$LESSONS_FILE" << 'HEADER'
# Enso Active Lessons
# Auto-distilled from error seeds. Hit counter tracks usefulness.
# Format: - [YYYY-MM-DD] [hits:N] lesson text

HEADER
    fi

    # Append each lesson with date and initial hit counter
    echo -e "$DISTILLED" | while IFS= read -r lesson; do
        [ -z "$lesson" ] && continue
        # Skip if duplicate (exact match already exists)
        if grep -qF "$lesson" "$LESSONS_FILE" 2>/dev/null; then
            continue
        fi
        echo "- [$TODAY] [hits:0] ${lesson#- }" >> "$LESSONS_FILE"
    done

    NEW_COUNT=$(echo -e "$DISTILLED" | grep -c "^- " || echo "0")
    echo "📝 [enso] Distilled $NEW_COUNT lesson(s)" >&2
fi

# ─── Capacity enforcement ───
if [ -f "$LESSONS_FILE" ]; then
    TOTAL=$(grep -c "^\- " "$LESSONS_FILE" 2>/dev/null || echo "0")
    if [ "$TOTAL" -gt "$MAX_LESSONS" ]; then
        OVERFLOW=$((TOTAL - MAX_LESSONS))
        echo "🗑️  [enso] Lessons overflow: $TOTAL/$MAX_LESSONS. Evicting $OVERFLOW oldest." >&2
        # Keep header + newest lessons (remove oldest after header)
        HEAD_LINES=$(grep -n "^$" "$LESSONS_FILE" | head -1 | cut -d: -f1 || echo "3")
        {
            head -n "$HEAD_LINES" "$LESSONS_FILE"
            tail -n "$MAX_LESSONS" <(grep "^\- " "$LESSONS_FILE")
        } > "$LESSONS_FILE.tmp"
        mv "$LESSONS_FILE.tmp" "$LESSONS_FILE"
    fi
fi

# ─── Time decay: mark stale lessons ───
if [ -f "$LESSONS_FILE" ] && command -v python3 &>/dev/null; then
    python3 -c "
import re, sys
from datetime import datetime, timedelta

stale_days = $STALE_DAYS
cutoff = (datetime.now() - timedelta(days=stale_days)).strftime('%Y-%m-%d')

with open('$LESSONS_FILE', 'r') as f:
    lines = f.readlines()

stale_count = 0
for i, line in enumerate(lines):
    m = re.match(r'^- \[(\d{4}-\d{2}-\d{2})\]', line)
    if m and m.group(1) < cutoff and '[stale]' not in line:
        lines[i] = line.rstrip() + ' [stale]\n'
        stale_count += 1

if stale_count > 0:
    with open('$LESSONS_FILE', 'w') as f:
        f.writelines(lines)
    print(f'⏰ [enso] Marked {stale_count} lesson(s) as stale (>{stale_days} days)', file=sys.stderr)
" 2>/dev/null || true
fi

# ─── Clear error seeds (processed) ───
> "$ERROR_SEEDS"

# ─── Write trace event ───
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
if [ -f "$TRACE_FILE" ]; then
    echo "{\"ts\":\"$TIMESTAMP\",\"span_type\":\"distillation\",\"error_seeds\":$ERROR_COUNT,\"lessons_added\":${NEW_COUNT:-0}}" >> "$TRACE_FILE"
fi
