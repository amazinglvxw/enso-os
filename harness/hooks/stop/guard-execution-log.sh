#!/usr/bin/env bash
# Enso Stop Hook: Execution log guard
# Ensures every session produces at least one execution log entry.
#
# Immutable Core Hook #2: "No Trace, No Truth"
# If the agent claims to have done work but the log is empty,
# something was skipped.
#
# Source: INS-099 yoyo-evolve "日志同事务写入"

set -euo pipefail

EXECUTION_LOG="${ENSO_MEMORY_DIR:-$HOME/.enso/memory}/execution-log.jsonl"

if [ ! -f "$EXECUTION_LOG" ]; then
    echo "Warning: execution-log.jsonl does not exist. No work was tracked this session." >&2
    exit 0
fi

# Count entries from today
TODAY=$(date +%Y-%m-%d)
TODAY_COUNT=$(grep -c "\"ts\":\"${TODAY}" "$EXECUTION_LOG" 2>/dev/null || echo "0")

if [ "$TODAY_COUNT" -eq 0 ]; then
    echo "Warning: No execution log entries for today ($TODAY). Please log at least one entry." >&2
    echo "Format: {\"ts\":\"ISO\",\"skill\":\"SESSION\",\"task\":\"description\",\"status\":\"success|fail\"}" >&2
fi
