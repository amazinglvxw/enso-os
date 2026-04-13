#!/usr/bin/env bash
# Enso Stop Hook: Session-End Maintenance
# Cognitive-level forgetting: Lessons LRU + MEMORY.md Archive downsink
set -euo pipefail

# shellcheck disable=SC2034  # ENSO_INPUT consumed by sourced env.sh
ENSO_INPUT=""
source "${ENSO_CORE:-$HOME/.enso/core}/env.sh"

MAX_LESSONS="${ENSO_MAX_LESSONS:-50}"

# ─── 1. Lessons capacity enforcement (LRU: evict least-recently-used) ───
enso_enforce_lesson_cap "$MAX_LESSONS"

# ─── 2. Lessons stale cleanup: stale+7days → real delete ───
if [ -f "$ENSO_LESSONS_FILE" ] && grep -q '\[stale\]' "$ENSO_LESSONS_FILE" 2>/dev/null; then
    ENSO_LESSONS_FILE_EV="$ENSO_LESSONS_FILE" python3 -c '
import re, sys, os
from datetime import datetime, timedelta

lessons_file = os.environ["ENSO_LESSONS_FILE_EV"]
cutoff = (datetime.now() - timedelta(days=37)).strftime("%Y-%m-%d")

with open(lessons_file, "r") as f:
    lines = f.readlines()

kept, deleted = [], 0
for line in lines:
    if line.startswith("- ") and "[stale]" in line:
        m = re.match(r"^- \[(\d{4}-\d{2}-\d{2})\]", line)
        if m and m.group(1) < cutoff:
            deleted += 1
            continue
    kept.append(line)

if deleted > 0:
    with open(lessons_file, "w") as f:
        f.writelines(kept)
    print(f"[enso] Deleted {deleted} stale lesson(s) (>37 days)", file=sys.stderr)
' 2>/dev/null || true
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
        ENSO_MEMORY_FILE_EV="$MEMORY_FILE" python3 -c '
import re, sys, os
from datetime import datetime, timedelta

memory_file = os.environ["ENSO_MEMORY_FILE_EV"]
now = datetime.now()
cutoff_dt = now - timedelta(days=7)

with open(memory_file, "r") as f:
    lines = f.readlines()

archive_lines, kept_lines = [], []
for line in lines:
    # Match completed items (✅ emoji alone signals completion)
    if "\u2705" in line:
        # Extract [MM-DD] dates and compare with year awareness
        dates = re.findall(r"\[(\d{2}-\d{2})\]", line)
        if dates:
            last_date_str = dates[-1]
            month, day = int(last_date_str[:2]), int(last_date_str[3:])
            # Assume current year; if date is in future, assume last year
            try:
                candidate_dt = datetime(now.year, month, day)
                if candidate_dt > now:
                    candidate_dt = datetime(now.year - 1, month, day)
                if candidate_dt < cutoff_dt:
                    archive_lines.append(line)
                    continue
            except ValueError:
                pass
    kept_lines.append(line)

if archive_lines:
    archive_path = memory_file.replace("MEMORY.md", "archive/memory-retired.md")
    os.makedirs(os.path.dirname(archive_path), exist_ok=True)
    with open(archive_path, "a") as f:
        f.write(f"\n## Retired {now.strftime(\"%Y-%m-%d\")}\n")
        f.writelines(archive_lines)
    with open(memory_file, "w") as f:
        f.writelines(kept_lines)
    print(f"[enso] Downsunk {len(archive_lines)} completed item(s) to archive", file=sys.stderr)
' 2>/dev/null || true
    fi

    # Budget warning
    CHARS=$(wc -m < "$MEMORY_FILE" | tr -d ' ')
    if [ "$CHARS" -gt 4800 ]; then
        echo "[enso] MEMORY.md: ${CHARS}/6000 chars ($(( CHARS * 100 / 6000 ))%). Consider consolidation." >&2
    fi
fi

# ─── 4. Trace event ───
enso_trace "ts" "$(enso_ts)" "span_type" "maintenance" "memory_chars" "${CHARS:-0}"
