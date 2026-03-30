#!/usr/bin/env bash
# Enso Session Start: Load Learned Lessons (SessionStart)
# Injects active lessons + prediction accuracy into agent context.
set -euo pipefail

ENSO_INPUT=""
source "${ENSO_CORE:-$HOME/.enso/core}/env.sh"

# Load active lessons (skip stale)
ACTIVE=""
LESSON_COUNT=0
if [ -f "$ENSO_LESSONS_FILE" ]; then
    ACTIVE=$(grep "^- " "$ENSO_LESSONS_FILE" | grep -v "\[stale\]" || true)
    LESSON_COUNT=0
    if [ -n "$ACTIVE" ]; then
        LESSON_COUNT=$(printf '%s\n' "$ACTIVE" | grep -c "^- " 2>/dev/null || echo "0")
    fi
fi

# Count sessions
SESSION_COUNT=$(find "$ENSO_TRACES_DIR" -name "*.jsonl" 2>/dev/null | wc -l | tr -d ' ')

# Output
if [ "$LESSON_COUNT" -gt 0 ]; then
    echo "OK: Enso loaded ($SESSION_COUNT sessions, $LESSON_COUNT active lessons)"
    echo ""
    printf '<enso-lessons count="%s">\n%s\n</enso-lessons>\n' "$LESSON_COUNT" "$ACTIVE"
else
    echo "OK: Enso ready ($SESSION_COUNT sessions, no lessons yet)"
fi
