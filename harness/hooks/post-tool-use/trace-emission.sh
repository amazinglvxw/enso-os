#!/usr/bin/env bash
# Enso Emission Layer: Trace/Span Logger (PostToolUse)
# Fire-and-forget telemetry. Logs successful tool calls.
# Error capture is handled by PostToolUseFailure/error-seed-capture.sh
set -euo pipefail

ENSO_INPUT=$(cat)
source "${ENSO_CORE:-$HOME/.enso/core}/env.sh"

IFS=$'\t' read -r TOOL_NAME FILE_PATH DURATION <<< \
    "$(enso_parse tool_name file_path duration_ms)"

TS=$(enso_ts)

# Write trace span (JSON-safe via enso_trace)
enso_trace "ts" "$TS" "span_type" "tool_call" "tool" "$TOOL_NAME" \
    "has_error" "false" "target" "$FILE_PATH" "duration_ms" "$DURATION"
