#!/usr/bin/env bash
# Enso Immutable Hook #2: No Trace, No Truth (Stop)
# Session-end audit: unverified writes, tool stats, prediction accuracy.
set -euo pipefail

ENSO_INPUT=""
source "${ENSO_CORE:-$HOME/.enso/core}/env.sh"

# 1. Report unverified writes
if [ -f "$ENSO_PENDING" ] && [ -s "$ENSO_PENDING" ]; then
    UNVERIFIED=$(wc -l < "$ENSO_PENDING" | tr -d ' ')
    if [ "$UNVERIFIED" -gt 0 ]; then
        echo "⚠️  [enso] $UNVERIFIED file(s) written but never verified:" >&2
        head -5 "$ENSO_PENDING" >&2
    fi
fi
> "$ENSO_PENDING" 2>/dev/null || true

# 2. Session trace summary
if [ -f "$ENSO_TRACE_FILE" ]; then
    TOOL_CALLS=$(grep -c '"tool_call"' "$ENSO_TRACE_FILE" 2>/dev/null || echo "0")
    ERRORS=$(grep -c '"true"' "$ENSO_TRACE_FILE" 2>/dev/null || echo "0")

    TS=$(enso_ts)
    enso_trace "ts" "$TS" "span_type" "session_end" \
        "tool_calls" "$TOOL_CALLS" "errors" "$ERRORS"

    if [ "$TOOL_CALLS" -gt 0 ]; then
        echo "📊 [enso] Session: $TOOL_CALLS tool calls, $ERRORS errors" >&2
    fi
fi

# 3. Count active lessons
if [ -f "$ENSO_LESSONS_FILE" ]; then
    LESSON_COUNT=$(grep -c "^- " "$ENSO_LESSONS_FILE" 2>/dev/null || echo "0")
    echo "🧠 [enso] Active lessons: $LESSON_COUNT" >&2
fi
