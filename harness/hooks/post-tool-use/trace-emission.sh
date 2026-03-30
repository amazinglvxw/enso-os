#!/usr/bin/env bash
# Enso Emission Layer: Trace/Span Logger (PostToolUse)
# Fire-and-forget telemetry. Logs every tool call + captures error seeds.
set -euo pipefail

ENSO_INPUT=$(cat)
source "${ENSO_CORE:-$HOME/.enso/core}/env.sh"

IFS=$'\t' read -r TOOL_NAME TOOL_RESULT HAS_ERROR FILE_PATH DURATION <<< \
    "$(enso_parse tool_name tool_result has_error file_path duration_ms)"

TS=$(enso_ts)

# Write trace span (JSON-safe via enso_trace)
enso_trace "ts" "$TS" "span_type" "tool_call" "tool" "$TOOL_NAME" \
    "has_error" "$HAS_ERROR" "target" "$FILE_PATH" "duration_ms" "$DURATION"

# Error seed capture (synchronous, same-transaction)
if [ "$HAS_ERROR" = "true" ]; then
    # Cap error seeds at 20 entries per session
    if [ -f "$ENSO_ERROR_SEEDS" ]; then
        SEED_COUNT=$(wc -l < "$ENSO_ERROR_SEEDS" | tr -d ' ')
        [ "$SEED_COUNT" -ge 20 ] && exit 0
    fi
    printf '[%s] [%s] %s\n' "$TS" "$TOOL_NAME" "${TOOL_RESULT:0:500}" >> "$ENSO_ERROR_SEEDS"
fi
