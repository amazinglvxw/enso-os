#!/usr/bin/env bash
# Enso Slow Track: Async Lesson Distillation (Stop)
# Error seeds → atomic lessons via LLM. Error-signal gated.
set -euo pipefail

ENSO_INPUT=""
source "${ENSO_CORE:-$HOME/.enso/core}/env.sh"

MAX_LESSONS="${ENSO_MAX_LESSONS:-50}"
STALE_DAYS="${ENSO_STALE_DAYS:-30}"

# Error-signal gating: no errors → no distillation
if [ ! -f "$ENSO_ERROR_SEEDS" ] || [ ! -s "$ENSO_ERROR_SEEDS" ]; then
    exit 0
fi

ERROR_COUNT=$(wc -l < "$ENSO_ERROR_SEEDS" | tr -d ' ')
echo "🔬 [enso] $ERROR_COUNT error seed(s) found. Distilling..." >&2

# Prepare context (use printf, not echo -e)
CONTEXT=$(printf '=== ERROR SEEDS ===\n%s\n' "$(cat "$ENSO_ERROR_SEEDS")")
if [ -f "$ENSO_TRACE_FILE" ]; then
    CONTEXT=$(printf '%s\n\n=== RECENT TRACE (last 20) ===\n%s' "$CONTEXT" "$(tail -20 "$ENSO_TRACE_FILE")")
fi

# Distill via Claude CLI if available
DISTILLED=""
if command -v claude &>/dev/null; then
    DISTILLED=$(printf '%s' "$CONTEXT" | claude --model claude-haiku-4-5 --print --max-turns 1 \
        "Extract 1-3 atomic lessons from these error seeds. Each lesson: one line, under 30 words, actionable, specific. Format: '- lesson text'. No preamble. If errors are trivial, output nothing." 2>/dev/null) || true
fi

# Fallback: extract raw error messages
if [ -z "$DISTILLED" ]; then
    DISTILLED=""
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        MSG=$(echo "$line" | sed 's/^\[.*\] //' | cut -c1-80)
        [ -n "$MSG" ] && DISTILLED="${DISTILLED}
- [auto] ${MSG}"
    done < "$ENSO_ERROR_SEEDS"
fi

# Initialize lessons file if needed
if [ ! -f "$ENSO_LESSONS_FILE" ]; then
    printf '# Enso Active Lessons\n# Format: - [YYYY-MM-DD] [hits:N] lesson text\n\n' > "$ENSO_LESSONS_FILE"
fi

# Append deduplicated lessons
NEW_COUNT=0
while IFS= read -r lesson; do
    [ -z "$lesson" ] && continue
    # Skip non-lesson lines
    case "$lesson" in -\ *) ;; *) continue ;; esac
    # Deduplicate
    grep -qF "$lesson" "$ENSO_LESSONS_FILE" 2>/dev/null && continue
    echo "- [$ENSO_TODAY] [hits:0] ${lesson#- }" >> "$ENSO_LESSONS_FILE"
    NEW_COUNT=$((NEW_COUNT + 1))
done <<< "$DISTILLED"

[ "$NEW_COUNT" -gt 0 ] && echo "📝 [enso] Distilled $NEW_COUNT lesson(s)" >&2

# Capacity enforcement (shared function)
enso_enforce_lesson_cap "$MAX_LESSONS"

# Time decay: mark stale lessons
python3 -c "
import re, sys
from datetime import datetime, timedelta
cutoff = (datetime.now() - timedelta(days=$STALE_DAYS)).strftime('%Y-%m-%d')
with open('$ENSO_LESSONS_FILE', 'r') as f:
    lines = f.readlines()
changed = False
for i, line in enumerate(lines):
    m = re.match(r'^- \[(\d{4}-\d{2}-\d{2})\]', line)
    if m and m.group(1) < cutoff and '[stale]' not in line:
        lines[i] = line.rstrip() + ' [stale]\n'
        changed = True
if changed:
    with open('$ENSO_LESSONS_FILE', 'w') as f:
        f.writelines(lines)
" 2>/dev/null || true

# Clear processed error seeds
> "$ENSO_ERROR_SEEDS"

# Write trace event
enso_trace "ts" "$(enso_ts)" "span_type" "distillation" \
    "error_seeds" "$ERROR_COUNT" "lessons_added" "$NEW_COUNT"
