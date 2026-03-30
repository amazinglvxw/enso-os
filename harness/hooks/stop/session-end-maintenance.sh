#!/usr/bin/env bash
# Enso Stop Hook: Session-End Maintenance
# Automated memory hygiene: staleness marking, capacity enforcement, Q-value update.
set -euo pipefail

ENSO_INPUT=""
source "${ENSO_CORE:-$HOME/.enso/core}/env.sh"

MEMORY_FILE="${ENSO_MEMORY_FILE:-$HOME/.claude/projects/-Users-lusu-Desktop/memory/MEMORY.md}"
MAX_LESSONS="${ENSO_MAX_LESSONS:-50}"

# ─── 1. Staleness marking (>14 days for business entries) ───
if [ -f "$MEMORY_FILE" ]; then
    python3 -c "
import re, sys
from datetime import datetime, timedelta
cutoff_14 = (datetime.now() - timedelta(days=14)).strftime('%m-%d')
cutoff_30 = (datetime.now() - timedelta(days=30)).strftime('%m-%d')
with open('$MEMORY_FILE', 'r') as f:
    content = f.read()
# Count entries that might be stale (heuristic: contains date patterns)
stale = len(re.findall(r'\[0[0-9]-[0-3][0-9]\]', content))
if stale > 0:
    print(f'[enso] MEMORY.md has entries with date stamps — consider reviewing during consolidation', file=sys.stderr)
" 2>/dev/null || true
fi

# ─── 2. Lessons capacity enforcement ───
if [ -f "$ENSO_LESSONS_FILE" ]; then
    TOTAL=$(grep -c "^- " "$ENSO_LESSONS_FILE" 2>/dev/null || echo "0")
    if [ "$TOTAL" -gt "$MAX_LESSONS" ]; then
        OVERFLOW=$((TOTAL - MAX_LESSONS))
        echo "🗑️  [enso] Lessons: $TOTAL/$MAX_LESSONS, evicting $OVERFLOW oldest" >&2
        { head -3 "$ENSO_LESSONS_FILE"; grep "^- " "$ENSO_LESSONS_FILE" | tail -"$MAX_LESSONS"; } > "$ENSO_LESSONS_FILE.tmp"
        mv "$ENSO_LESSONS_FILE.tmp" "$ENSO_LESSONS_FILE"
    fi
fi

# ─── 3. MEMORY.md budget warning ───
if [ -f "$MEMORY_FILE" ]; then
    CHARS=$(wc -c < "$MEMORY_FILE" | tr -d ' ')
    if [ "$CHARS" -gt 4800 ]; then
        echo "⚠️  [enso] MEMORY.md: ${CHARS}/6000 chars ($(( CHARS * 100 / 6000 ))%). Consider consolidation." >&2
    fi
fi

# ─── 4. Trace event ───
enso_trace "ts" "$(enso_ts)" "span_type" "maintenance" "memory_chars" "${CHARS:-0}" "lessons" "${TOTAL:-0}"
