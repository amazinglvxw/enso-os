#!/usr/bin/env bash
# Enso Immutable Hook #1: Physical Verification (PostToolUse)
# Write/Edit must be followed by Read. Tracks pending verifications.
set -euo pipefail

ENSO_INPUT=$(cat)
source "${ENSO_CORE:-$HOME/.enso/core}/env.sh"

IFS=$'\t' read -r TOOL_NAME FILE_PATH <<< "$(enso_parse tool_name file_path)"

case "$TOOL_NAME" in
    Write|Edit)
        if [ -n "$FILE_PATH" ]; then
            # Cap pending list at 100 entries to prevent unbounded growth
            if [ -f "$ENSO_PENDING" ]; then
                tail -99 "$ENSO_PENDING" > "$ENSO_PENDING.tmp" && mv "$ENSO_PENDING.tmp" "$ENSO_PENDING"
            fi
            echo "$FILE_PATH" >> "$ENSO_PENDING"
        fi
        ;;
    Read)
        if [ -f "$ENSO_PENDING" ] && [ -n "$FILE_PATH" ]; then
            grep -vF "$FILE_PATH" "$ENSO_PENDING" > "$ENSO_PENDING.tmp" 2>/dev/null || true
            mv "$ENSO_PENDING.tmp" "$ENSO_PENDING"
        fi
        ;;
esac
