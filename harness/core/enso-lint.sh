#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# Enso Lint: Knowledge Health Check
# ═══════════════════════════════════════════════════════════════
# Checks lessons for: contradictions, missing context, orphans (never hit)
# Run weekly via scheduled task, not per-session.
# Output: ~/.enso/traces/lint-report-YYYY-MM-DD.md
set -euo pipefail

source "${ENSO_CORE:-$HOME/.enso/core}/env.sh"

REPORT="$ENSO_TRACES_DIR/lint-report-$ENSO_TODAY.md"
TOTAL_ISSUES=0

echo "# Enso Lint Report — $ENSO_TODAY" > "$REPORT"
echo "" >> "$REPORT"

# ─── 1. Orphan detection: lessons with hits:0 older than 7 days ───
echo "## Orphans (never hit, >7 days old)" >> "$REPORT"
ORPHANS=0
if [ -f "$ENSO_LESSONS_FILE" ]; then
    python3 -c "
import re, sys
from datetime import datetime, timedelta
cutoff = (datetime.now() - timedelta(days=7)).strftime('%Y-%m-%d')
with open('$ENSO_LESSONS_FILE') as f:
    for line in f:
        if not line.startswith('- '): continue
        if '[hits:0]' in line:
            m = re.match(r'^- \[(\d{4}-\d{2}-\d{2})\]', line)
            if m and m.group(1) < cutoff:
                print(line.strip())
" 2>/dev/null | while IFS= read -r line; do
        echo "- $line" >> "$REPORT"
        ORPHANS=$((ORPHANS + 1))
    done
fi
if [ "$ORPHANS" -eq 0 ]; then
    echo "None found." >> "$REPORT"
fi
TOTAL_ISSUES=$((TOTAL_ISSUES + ORPHANS))
echo "" >> "$REPORT"

# ─── 2. Duplicate/near-duplicate detection ───
echo "## Near-Duplicates (>60% keyword overlap)" >> "$REPORT"
DUPS=0
if [ -f "$ENSO_LESSONS_FILE" ]; then
    python3 -c "
import re, sys

stops = frozenset('the and for that this with from have will been when before after always instead using avoid use are not can should'.split())

lessons = []
with open('$ENSO_LESSONS_FILE') as f:
    for line in f:
        if not line.startswith('- '): continue
        text = re.sub(r'\[\d{4}-\d{2}-\d{2}\]\s*\[hits:\d+\]\s*', '', line[2:]).strip()
        words = set(w for w in re.findall(r'[a-z]{3,}', text.lower()) if w not in stops)
        lessons.append((text, words))

found = set()
for i in range(len(lessons)):
    for j in range(i+1, len(lessons)):
        t1, w1 = lessons[i]
        t2, w2 = lessons[j]
        if not w1 or not w2: continue
        overlap = len(w1 & w2) / min(len(w1), len(w2))
        if overlap >= 0.6:
            pair = (min(i,j), max(i,j))
            if pair not in found:
                found.add(pair)
                print(f'- [{overlap:.0%}] \"{t1[:60]}...\" ↔ \"{t2[:60]}...\"')
    " 2>/dev/null | while IFS= read -r line; do
        echo "$line" >> "$REPORT"
        DUPS=$((DUPS + 1))
    done
fi
if [ "$DUPS" -eq 0 ]; then
    echo "None found." >> "$REPORT"
fi
TOTAL_ISSUES=$((TOTAL_ISSUES + DUPS))
echo "" >> "$REPORT"

# ─── 3. Lessons without actionable verbs ───
echo "## Weak Lessons (no actionable verb)" >> "$REPORT"
WEAK=0
if [ -f "$ENSO_LESSONS_FILE" ]; then
    python3 -c "
import re
action_verbs = {'use','avoid','always','never','check','verify','ensure','replace','add','remove','run','call','set','pass','break','split','validate','test','wrap','handle'}
with open('$ENSO_LESSONS_FILE') as f:
    for line in f:
        if not line.startswith('- '): continue
        text = re.sub(r'\[\d{4}-\d{2}-\d{2}\]\s*\[hits:\d+\]\s*', '', line[2:]).lower()
        words = set(re.findall(r'[a-z]+', text))
        if not words & action_verbs:
            print(line.strip())
" 2>/dev/null | while IFS= read -r line; do
        echo "- $line" >> "$REPORT"
        WEAK=$((WEAK + 1))
    done
fi
if [ "$WEAK" -eq 0 ]; then
    echo "None found." >> "$REPORT"
fi
TOTAL_ISSUES=$((TOTAL_ISSUES + WEAK))
echo "" >> "$REPORT"

# ─── 4. MEMORY.md budget status ───
echo "## MEMORY.md Budget" >> "$REPORT"
MEMORY_FILE=""
for candidate in \
    "$HOME/.claude/projects/-$(echo "$PWD" | tr '/' '-' | sed 's/^-//')/memory/MEMORY.md" \
    "$PWD/memory/MEMORY.md"; do
    [ -f "$candidate" ] && MEMORY_FILE="$candidate" && break
done
if [ -n "$MEMORY_FILE" ]; then
    CHARS=$(wc -m < "$MEMORY_FILE" | tr -d ' ')
    PCT=$((CHARS * 100 / 6000))
    echo "- ${CHARS}/6000 chars (${PCT}%)" >> "$REPORT"
    [ "$PCT" -gt 80 ] && echo "- ⚠️ Approaching budget limit" >> "$REPORT"
else
    echo "- MEMORY.md not found" >> "$REPORT"
fi
echo "" >> "$REPORT"

# ─── 5. Summary ───
echo "## Summary" >> "$REPORT"
LESSON_COUNT=$(grep -c "^- " "$ENSO_LESSONS_FILE" 2>/dev/null || echo "0")
echo "- Active lessons: $LESSON_COUNT" >> "$REPORT"
echo "- Issues found: $TOTAL_ISSUES" >> "$REPORT"
echo "- Report: $REPORT" >> "$REPORT"

echo "[enso-lint] $TOTAL_ISSUES issue(s) found across $LESSON_COUNT lessons. Report: $REPORT" >&2
