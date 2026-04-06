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

# Prepare context
CONTEXT=$(printf '=== ERROR SEEDS ===\n%s\n' "$(cat "$ENSO_ERROR_SEEDS")")
if [ -f "$ENSO_TRACE_FILE" ]; then
    CONTEXT=$(printf '%s\n\n=== RECENT TRACE (last 20) ===\n%s' "$CONTEXT" "$(tail -20 "$ENSO_TRACE_FILE")")
fi

# Distill via Claude CLI if available
DISTILLED=""
if command -v claude &>/dev/null; then
    DISTILLED=$(printf '%s' "$CONTEXT" | claude --model claude-haiku-4-5 --print --max-turns 1 \
        "Extract 1-3 atomic lessons from these error seeds. Rules:
- One lesson per line, starting with '- '
- Under 30 words, actionable, specific
- MERGE similar errors into ONE lesson (don't repeat)
- If errors are trivial/transient (exit codes, temp failures), output NOTHING
- Before EACH lesson, output a category line: CATEGORY: kebab-case-tag
  Reuse: browser-dom-safety, file-io, timeout-recovery, cli-safety, git-ops, api-usage, memory-mgmt
- Bad: '- Exit code 1' (symptom not lesson)
- Good: '- Use offset/limit when reading files over 5000 lines to avoid token overflow'
Only output lessons + categories. No preamble." 2>/dev/null) || true
fi

# Fallback: skip if no CLI (raw errors are NOT lessons)
if [ -z "$DISTILLED" ]; then
    echo "⚠️  [enso] Claude CLI unavailable, skipping distillation (raw errors are not lessons)" >&2
    > "$ENSO_ERROR_SEEDS"
    exit 0
fi

# Initialize lessons file if needed
if [ ! -f "$ENSO_LESSONS_FILE" ]; then
    printf '# Enso Active Lessons\n# Format: - [YYYY-MM-DD] [hits:N] lesson text\n\n' > "$ENSO_LESSONS_FILE"
fi

# Append with SEMANTIC deduplication (not just exact match)
NEW_COUNT=0
NEXT_CATEGORY=""
while IFS= read -r lesson; do
    [ -z "$lesson" ] && continue
    # Capture CATEGORY line from LLM output
    case "$lesson" in
        CATEGORY:*) NEXT_CATEGORY="${lesson#CATEGORY: }"; NEXT_CATEGORY="${NEXT_CATEGORY# }"; continue ;;
    esac
    case "$lesson" in -\ *) ;; *) continue ;; esac

    LESSON_TEXT="${lesson#- }"

    # Semantic dedup via DIKW utils (graceful fallback to keyword overlap)
    if [ -f "${ENSO_DIKW_UTILS:-}" ]; then
        IS_DUP=$(python3 "$ENSO_DIKW_UTILS" semantic_dedup \
            --new-text "$LESSON_TEXT" \
            --existing-file "$ENSO_LESSONS_FILE" \
            --info-file "${ENSO_INFO_FILE:-/dev/null}" \
            --threshold 0.7 2>/dev/null || echo "NEW")
    else
        # Fallback: original keyword overlap
        IS_DUP=$(python3 -c "
import re, sys
new_lesson = sys.argv[1].lower()
stops = {'the','and','for','that','this','with','from','have','will','been','when','before','after','always','instead','using','avoid','use'}
new_words = set(w for w in re.findall(r'[a-z]{3,}', new_lesson) if w not in stops)
try:
    with open(sys.argv[2], 'r') as f:
        for line in f:
            if not line.startswith('- '): continue
            text = re.sub(r'\[\d{4}-\d{2}-\d{2}\]\s*\[hits:\d+\]\s*', '', line[2:]).lower()
            existing_words = set(w for w in re.findall(r'[a-z]{3,}', text) if w not in stops)
            if new_words and len(new_words & existing_words) / len(new_words) >= 0.6:
                print('DUP'); sys.exit(0)
except FileNotFoundError: pass
print('NEW')
" "$LESSON_TEXT" "$ENSO_LESSONS_FILE" 2>/dev/null || echo "NEW")
    fi

    if [ "$IS_DUP" = "NEW" ]; then
        echo "- [$ENSO_TODAY] [hits:0] $LESSON_TEXT" >> "$ENSO_LESSONS_FILE"
        # DIKW I-layer: dual write to info-layer.jsonl
        if [ -f "${ENSO_DIKW_UTILS:-}" ] && [ -n "${ENSO_INFO_FILE:-}" ]; then
            CATEGORY=""
            if [ -n "${NEXT_CATEGORY:-}" ]; then
                CATEGORY="$NEXT_CATEGORY"
                NEXT_CATEGORY=""
            else
                CATEGORY=$(python3 "$ENSO_DIKW_UTILS" categorize --text "$LESSON_TEXT" 2>/dev/null || echo "uncategorized")
            fi
            python3 "$ENSO_DIKW_UTILS" append_info \
                --info-file "$ENSO_INFO_FILE" \
                --text "$LESSON_TEXT" \
                --category "$CATEGORY" \
                --ts "$(enso_ts)" \
                --source-errors "$ERROR_COUNT" 2>/dev/null || true
        fi
        NEW_COUNT=$((NEW_COUNT + 1))
    fi
done <<< "$DISTILLED"

[ "$NEW_COUNT" -gt 0 ] && echo "📝 [enso] Distilled $NEW_COUNT lesson(s)" >&2

# Capacity enforcement
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

# DIKW: Update utility tracking for loaded lessons
if [ -f "${ENSO_DIKW_UTILS:-}" ] && [ -f "${ENSO_SESSION_LOADED_IDS:-/tmp/enso-session-loaded-ids}" ] && [ -f "${ENSO_INFO_FILE:-}" ]; then
    python3 "$ENSO_DIKW_UTILS" update_utility \
        --loaded-ids-file "${ENSO_SESSION_LOADED_IDS:-/tmp/enso-session-loaded-ids}" \
        --trace-file "$ENSO_TRACE_FILE" \
        --info-file "$ENSO_INFO_FILE" \
        --lessons-file "$ENSO_LESSONS_FILE" 2>/dev/null || true
fi

# Clear processed error seeds
> "$ENSO_ERROR_SEEDS"

# Rebuild lessons index for fast LLM routing
ENSO_LESSONS_FILE="$ENSO_LESSONS_FILE" python3 "$ENSO_CORE/rebuild-index.py" 2>/dev/null || true

# Write trace event
enso_trace "ts" "$(enso_ts)" "span_type" "distillation" \
    "error_seeds" "$ERROR_COUNT" "lessons_added" "$NEW_COUNT"
