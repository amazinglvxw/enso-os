#!/usr/bin/env bash
# Enso Stop Hook: Session-End Maintenance
# Automated: capacity enforcement + budget warning.
set -euo pipefail

ENSO_INPUT=""
source "${ENSO_CORE:-$HOME/.enso/core}/env.sh"

MAX_LESSONS="${ENSO_MAX_LESSONS:-50}"

# ─── 1. Lessons capacity enforcement (shared function) ───
enso_enforce_lesson_cap "$MAX_LESSONS"

# ─── 2. MEMORY.md budget warning ───
# Auto-detect MEMORY.md location
MEMORY_FILE=""
for candidate in \
    "$HOME/.claude/projects/-$(echo "$PWD" | tr '/' '-' | sed 's/^-//')/memory/MEMORY.md" \
    "$PWD/memory/MEMORY.md" \
    "$HOME/.claude/memory/MEMORY.md"; do
    [ -f "$candidate" ] && MEMORY_FILE="$candidate" && break
done

if [ -n "$MEMORY_FILE" ]; then
    CHARS=$(wc -m < "$MEMORY_FILE" | tr -d ' ')
    if [ "$CHARS" -gt 4800 ]; then
        echo "[enso] MEMORY.md: ${CHARS}/6000 chars ($(( CHARS * 100 / 6000 ))%). Consider consolidation." >&2
    fi
fi

# ─── 3. Trace event ───
enso_trace "ts" "$(enso_ts)" "span_type" "maintenance" "memory_chars" "${CHARS:-0}"
