#!/usr/bin/env bash
# Enso Stop Hook: Session-End Maintenance
# Cognitive-level forgetting: Lessons LRU + MEMORY.md Archive downsink
set -euo pipefail

ENSO_INPUT=""
source "${ENSO_CORE:-$HOME/.enso/core}/env.sh"

MAX_LESSONS="${ENSO_MAX_LESSONS:-50}"

# ─── 1. Lessons capacity enforcement (LRU: evict least-recently-used) ───
enso_enforce_lesson_cap "$MAX_LESSONS"

# ─── 2. Lessons stale cleanup: stale+7days → real delete ───
if [ -f "$ENSO_LESSONS_FILE" ]; then
    python3 -c "
import re, sys
from datetime import datetime, timedelta

cutoff = (datetime.now() - timedelta(days=37)).strftime('%Y-%m-%d')  # 30 days stale + 7 days grace
with open('$ENSO_LESSONS_FILE', 'r') as f:
    lines = f.readlines()

kept = []
deleted = 0
for line in lines:
    if line.startswith('- ') and '[stale]' in line:
        m = re.match(r'^- \[(\d{4}-\d{2}-\d{2})\]', line)
        if m and m.group(1) < cutoff:
            deleted += 1
            continue
    kept.append(line)

if deleted > 0:
    with open('$ENSO_LESSONS_FILE', 'w') as f:
        f.writelines(kept)
    print(f'[enso] Deleted {deleted} stale lesson(s) (>37 days)', file=sys.stderr)
" 2>/dev/null || true
fi

# ─── 3. MEMORY.md: downsink completed items to Archive section ───
MEMORY_FILE=""
for candidate in \
    "$HOME/.claude/projects/-$(echo "$PWD" | tr '/' '-' | sed 's/^-//')/memory/MEMORY.md" \
    "$PWD/memory/MEMORY.md" \
    "$HOME/.claude/memory/MEMORY.md"; do
    [ -f "$candidate" ] && MEMORY_FILE="$candidate" && break
done

if [ -n "$MEMORY_FILE" ]; then
    CHARS=$(wc -m < "$MEMORY_FILE" | tr -d ' ')

    # Only trigger downsink when approaching budget (>83%)
    if [ "$CHARS" -gt 5000 ]; then
        python3 -c "
import re, sys
from datetime import datetime, timedelta

cutoff_7d = (datetime.now() - timedelta(days=7)).strftime('%m-%d')

with open('$MEMORY_FILE', 'r') as f:
    lines = f.readlines()

archive_lines = []
kept_lines = []
for line in lines:
    # Downsink completed items older than 7 days
    if '✅' in line and '完成' in line:
        # Check if there's a date pattern [MM-DD] older than 7 days
        dates = re.findall(r'\[(\d{2}-\d{2})\]', line)
        if dates and dates[-1] < cutoff_7d:
            archive_lines.append(line)
            continue
    kept_lines.append(line)

if archive_lines:
    # Append to archive file instead of deleting
    archive_path = '$MEMORY_FILE'.replace('MEMORY.md', 'archive/memory-retired.md')
    with open(archive_path, 'a') as f:
        f.write(f'\n## Retired {datetime.now().strftime(\"%Y-%m-%d\")}\n')
        f.writelines(archive_lines)
    with open('$MEMORY_FILE', 'w') as f:
        f.writelines(kept_lines)
    print(f'[enso] Downsunk {len(archive_lines)} completed item(s) to archive', file=sys.stderr)
" 2>/dev/null || true
    fi

    # Budget warning
    CHARS=$(wc -m < "$MEMORY_FILE" | tr -d ' ')
    if [ "$CHARS" -gt 4800 ]; then
        echo "[enso] MEMORY.md: ${CHARS}/6000 chars ($(( CHARS * 100 / 6000 ))%). Consider consolidation." >&2
    fi
fi

# ─── 4. Trace event ───
enso_trace "ts" "$(enso_ts)" "span_type" "maintenance" "memory_chars" "${CHARS:-0}"
