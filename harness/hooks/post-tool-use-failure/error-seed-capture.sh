#!/usr/bin/env bash
# Enso: Capture error seeds from PostToolUseFailure events.
# These feed into distill-lessons.sh at session end.
set -euo pipefail

ENSO_INPUT=$(cat)
source "${ENSO_CORE:-$HOME/.enso/core}/env.sh"

IFS=$'\t' read -r TOOL_NAME FILE_PATH <<< "$(enso_parse tool_name file_path)"

# Extract error message directly from hook JSON (PostToolUseFailure has "error" field)
ERROR_MSG=$(echo "$ENSO_INPUT" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(d.get('error', 'unknown error')[:500])
" 2>/dev/null) || ERROR_MSG="parse error"

TS=$(enso_ts)

# Write trace span for the failure
enso_trace "ts" "$TS" "span_type" "tool_call" "tool" "$TOOL_NAME" \
    "has_error" "true" "target" "$FILE_PATH" "error" "$ERROR_MSG"

# Cap error seeds at 20 entries per session
if [ -f "$ENSO_ERROR_SEEDS" ]; then
    SEED_COUNT=$(wc -l < "$ENSO_ERROR_SEEDS" | tr -d ' ')
    [ "$SEED_COUNT" -ge 20 ] && exit 0
fi

printf '[%s] [%s] %s\n' "$TS" "$TOOL_NAME" "$ERROR_MSG" >> "$ENSO_ERROR_SEEDS"
echo "🔴 [enso] Error seed captured: $TOOL_NAME" >&2
