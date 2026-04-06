#!/usr/bin/env bash
# Enso Lint: Knowledge Health Check
set -euo pipefail

source "${ENSO_CORE:-$HOME/.enso/core}/env.sh"

REPORT="$ENSO_TRACES_DIR/lint-report-$ENSO_TODAY.md"

# Single Python call for all checks (fixes pipe-subshell counter bug + shell injection)
ENSO_LESSONS_FILE_EV="$ENSO_LESSONS_FILE" python3 -c '
import re, sys, os
from datetime import datetime, timedelta

lessons_file = os.environ["ENSO_LESSONS_FILE_EV"]
if not os.path.exists(lessons_file):
    print("TOTAL_LESSONS:0"); print("ORPHANS:0"); print("DUPS:0"); print("WEAK:0")
    sys.exit(0)

stops = frozenset("the and for that this with from have will been when before after always instead using avoid use are not can should".split())
action_verbs = {"use","avoid","check","verify","ensure","replace","add","remove","run","call","set","pass","break","split","validate","test","wrap","handle","create","delete","update","return","configure","retry","skip","prefer","include","exclude","apply","reset","initialize","sanitize","escape"}
cutoff_7d = (datetime.now() - timedelta(days=7)).strftime("%Y-%m-%d")

lessons = []
with open(lessons_file) as f:
    for line in f:
        if not line.startswith("- "): continue
        if "[stale]" in line: continue
        raw = line.strip()
        text = re.sub(r"\[\d{4}-\d{2}-\d{2}\]\s*\[hits:\d+\]\s*", "", raw[2:]).strip()
        words = set(w for w in re.findall(r"[a-z]{3,}", text.lower()) if w not in stops)
        m_date = re.match(r"^- \[(\d{4}-\d{2}-\d{2})\]", raw)
        date = m_date.group(1) if m_date else ""
        hits_m = re.search(r"\[hits:(\d+)\]", raw)
        hits = int(hits_m.group(1)) if hits_m else 0
        lessons.append({"raw": raw, "text": text, "words": words, "date": date, "hits": hits})

orphans = [l for l in lessons if l["hits"] == 0 and l["date"] and l["date"] < cutoff_7d]
dups = []
for i in range(len(lessons)):
    for j in range(i+1, len(lessons)):
        w1, w2 = lessons[i]["words"], lessons[j]["words"]
        if not w1 or not w2: continue
        overlap = len(w1 & w2) / min(len(w1), len(w2))
        if overlap >= 0.6:
            dups.append(f"[{overlap:.0%}] \"{lessons[i][\"text\"][:60]}\" <> \"{lessons[j][\"text\"][:60]}\"")
weak = [l for l in lessons if not (set(re.findall(r"[a-z]+", l["text"].lower())) & action_verbs)]

print(f"TOTAL_LESSONS:{len(lessons)}")
print(f"ORPHANS:{len(orphans)}")
for o in orphans: print(f"  ORPHAN:{o[\"raw\"]}")
print(f"DUPS:{len(dups)}")
for d in dups: print(f"  DUP:{d}")
print(f"WEAK:{len(weak)}")
for w in weak: print(f"  WEAK:{w[\"raw\"]}")
' 2>/dev/null > /tmp/enso-lint-output.txt || echo "TOTAL_LESSONS:0" > /tmp/enso-lint-output.txt

TOTAL_LESSONS=$(grep "^TOTAL_LESSONS:" /tmp/enso-lint-output.txt | cut -d: -f2)
ORPHAN_COUNT=$(grep "^ORPHANS:" /tmp/enso-lint-output.txt | cut -d: -f2)
DUP_COUNT=$(grep "^DUPS:" /tmp/enso-lint-output.txt | cut -d: -f2)
WEAK_COUNT=$(grep "^WEAK:" /tmp/enso-lint-output.txt | cut -d: -f2)
TOTAL_ISSUES=$(( ${ORPHAN_COUNT:-0} + ${DUP_COUNT:-0} + ${WEAK_COUNT:-0} ))

{
echo "# Enso Lint Report — $ENSO_TODAY"
echo ""
echo "## Orphans (never hit, >7 days old)"
if [ "${ORPHAN_COUNT:-0}" -gt 0 ]; then
    grep "^  ORPHAN:" /tmp/enso-lint-output.txt | sed 's/^  ORPHAN:/- /'
else echo "None found."; fi
echo ""
echo "## Near-Duplicates (>60% keyword overlap)"
if [ "${DUP_COUNT:-0}" -gt 0 ]; then
    grep "^  DUP:" /tmp/enso-lint-output.txt | sed 's/^  DUP:/- /'
else echo "None found."; fi
echo ""
echo "## Weak Lessons (no actionable verb)"
if [ "${WEAK_COUNT:-0}" -gt 0 ]; then
    grep "^  WEAK:" /tmp/enso-lint-output.txt | sed 's/^  WEAK:/- /'
else echo "None found."; fi
echo ""
echo "## MEMORY.md Budget"
MEMORY_FILE=$(enso_find_memory_file 2>/dev/null || echo "")
if [ -n "$MEMORY_FILE" ]; then
    CHARS=$(wc -m < "$MEMORY_FILE" | tr -d ' ')
    echo "- ${CHARS}/6000 chars ($((CHARS * 100 / 6000))%)"
else echo "- MEMORY.md not found"; fi
echo ""
echo "## Summary"
echo "- Active lessons: ${TOTAL_LESSONS:-0}"
echo "- Issues found: $TOTAL_ISSUES"
} > "$REPORT"

rm -f /tmp/enso-lint-output.txt
echo "[enso-lint] $TOTAL_ISSUES issue(s) across ${TOTAL_LESSONS:-0} lessons. Report: $REPORT" >&2
