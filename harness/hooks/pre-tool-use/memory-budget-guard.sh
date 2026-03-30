#!/usr/bin/env bash
# Enso Hook: Memory Budget Guard (PreToolUse)
# Blocks writes to MEMORY.md if it would exceed 6000 characters.
set -euo pipefail

ENSO_INPUT=$(cat)
source "${ENSO_CORE:-$HOME/.enso/core}/env.sh"

IFS=$'\t' read -r TOOL_NAME FILE_PATH <<< "$(enso_parse tool_name file_path)"

case "$TOOL_NAME" in Write|Edit) ;; *) exit 0 ;; esac

# Only guard MEMORY.md
[[ "$FILE_PATH" == *"MEMORY.md"* ]] || exit 0

BUDGET=6000
if [ -f "$FILE_PATH" ]; then
    CURRENT=$(wc -m < "$FILE_PATH" | tr -d ' ')
    if [ "$CURRENT" -gt "$BUDGET" ]; then
        echo "ENSO MEMORY BUDGET: MEMORY.md is ${CURRENT}/${BUDGET} chars. Consolidate before adding." >&2
        exit 2
    fi
fi
