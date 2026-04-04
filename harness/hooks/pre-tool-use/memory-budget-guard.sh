#!/usr/bin/env bash
# Enso Hook: Memory Budget Guard (PreToolUse)
# Non-blocking warnings when MEMORY.md approaches or exceeds budget.
# NEVER blocks (exit 2) — blocking causes session deadlocks.
set -euo pipefail

ENSO_INPUT=$(cat)
source "${ENSO_CORE:-$HOME/.enso/core}/env.sh"

IFS=$'\t' read -r TOOL_NAME FILE_PATH <<< "$(enso_parse tool_name file_path)"

case "$TOOL_NAME" in Write|Edit) ;; *) exit 0 ;; esac

# Only guard MEMORY.md
[[ "$FILE_PATH" == *"MEMORY.md"* ]] || exit 0

BUDGET=6000
WARN_THRESHOLD=4800

if [ -f "$FILE_PATH" ]; then
    CURRENT=$(wc -m < "$FILE_PATH" | tr -d ' ')
    if [ "$CURRENT" -gt "$BUDGET" ]; then
        echo "🔴 MEMORY BUDGET EXCEEDED: MEMORY.md is ${CURRENT}/${BUDGET} chars. Consolidate NOW — move detail to separate files, keep MEMORY.md as index only." >&2
    elif [ "$CURRENT" -gt "$WARN_THRESHOLD" ]; then
        echo "🟡 MEMORY BUDGET WARNING: MEMORY.md is ${CURRENT}/${BUDGET} chars ($(( CURRENT * 100 / BUDGET ))%). Consider consolidating soon." >&2
    fi
fi

# Always allow the write — never exit 2
exit 0
