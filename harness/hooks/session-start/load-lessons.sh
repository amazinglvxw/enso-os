#!/usr/bin/env bash
# Enso Session Start: Load Learned Lessons (SessionStart)
# Injects active lessons into agent context. Detects newly learned
# lessons and prompts the agent to proactively tell the user.
set -euo pipefail

ENSO_INPUT=""
source "${ENSO_CORE:-$HOME/.enso/core}/env.sh"

ANNOUNCED_FILE="$ENSO_DIR/.announced-lessons"

# Load active lessons (skip stale)
ACTIVE=""
LESSON_COUNT=0
if [ -f "$ENSO_LESSONS_FILE" ]; then
    ACTIVE=$(grep "^- " "$ENSO_LESSONS_FILE" | grep -v "\[stale\]" || true)
    if [ -n "$ACTIVE" ]; then
        LESSON_COUNT=$(printf '%s\n' "$ACTIVE" | wc -l | tr -d ' ')
    fi
fi

# Count sessions
SESSION_COUNT=$(find "$ENSO_TRACES_DIR" -name "*.jsonl" 2>/dev/null | wc -l | tr -d ' ')

# ─── Detect newly learned lessons ───
# Compare lesson CORE TEXT against announced file (ignores date/hits/seed prefix changes).
NEW_LESSONS=""
NEW_COUNT=0
if [ "$LESSON_COUNT" -gt 0 ]; then
    touch "$ANNOUNCED_FILE"
    # Extract core text from each lesson, check if announced
    NEW_LESSONS=$(python3 -c "
import re, sys, os
announced_file = os.environ.get('ENSO_DIR','') + '/.announced-lessons'
announced = set()
if os.path.exists(announced_file):
    with open(announced_file) as f:
        announced = set(line.strip() for line in f if line.strip())
new_lines = []
for line in sys.stdin:
    line = line.strip()
    if not line.startswith('- '):
        continue
    # Strip prefix: - [date] [hits:N] [seed:XX] → core text
    core = re.sub(r'^- \[\d{4}-\d{2}-\d{2}\]\s*\[hits:\d+\]\s*(?:\[seed:[a-f0-9]+\]\s*)?', '', line)
    if core and core not in announced:
        new_lines.append(line)
if new_lines:
    print('\n'.join(new_lines))
" <<< "$ACTIVE" 2>/dev/null || true)
    [ -n "$NEW_LESSONS" ] && NEW_COUNT=$(printf '%s\n' "$NEW_LESSONS" | wc -l | tr -d ' ')
fi

# ─── Output ───
if [ "$LESSON_COUNT" -gt 0 ]; then
    echo "OK: Enso loaded ($SESSION_COUNT sessions, $LESSON_COUNT active lessons)"
    echo ""
    enso_adapter_output_lessons "$LESSON_COUNT" "$ACTIVE" "enso-lessons"

    # If there are newly learned lessons, prompt the agent to tell the user
    if [ "$NEW_COUNT" -gt 0 ]; then
        echo ""
        echo "<enso-newly-learned count=\"$NEW_COUNT\">"
        echo "The following lessons were learned from errors in recent sessions."
        echo "Find a natural moment to briefly tell the user what you learned — not as a dump,"
        echo "but as a short, conversational mention (e.g., \"By the way, I learned from last time"
        echo "that...\" or \"上次我学到了...\"). One sentence per lesson is enough."
        echo ""
        # Show stripped versions (no date/hits prefix)
        printf '%s\n' "$NEW_LESSONS" | python3 -c "
import re, sys
for line in sys.stdin:
    core = re.sub(r'^- \[\d{4}-\d{2}-\d{2}\]\s*\[hits:\d+\]\s*(?:\[seed:[a-f0-9]+\]\s*)?', '- ', line.strip())
    print(core)
" 2>/dev/null
        echo "</enso-newly-learned>"

        # Mark as announced (store core text only)
        printf '%s\n' "$NEW_LESSONS" | python3 -c "
import re, sys, os
announced_file = os.environ.get('ENSO_DIR','') + '/.announced-lessons'
with open(announced_file, 'a') as f:
    for line in sys.stdin:
        core = re.sub(r'^- \[\d{4}-\d{2}-\d{2}\]\s*\[hits:\d+\]\s*(?:\[seed:[a-f0-9]+\]\s*)?', '', line.strip())
        if core:
            f.write(core + '\n')
" 2>/dev/null || true
    fi
else
    echo "OK: Enso ready ($SESSION_COUNT sessions, no lessons yet)"
fi


# ─── DIKW: Load Knowledge layer ───
if [ -f "${ENSO_KNOWLEDGE_FILE:-}" ]; then
    K_RULES=$(python3 -c "
import json, os
kf = os.environ.get('ENSO_KNOWLEDGE_FILE','')
if os.path.exists(kf):
    for e in json.load(open(kf)):
        if e.get('status','active') == 'active':
            print(f\"- [{e['category']}] {e['rule']}\")
" 2>/dev/null || true)
    K_COUNT=0
    [ -n "$K_RULES" ] && K_COUNT=$(echo "$K_RULES" | grep -c "^- " 2>/dev/null || echo "0")
    if [ "$K_COUNT" -gt 0 ]; then
        echo ""
        enso_adapter_output_lessons "$K_COUNT" "$K_RULES" "enso-knowledge"
    fi
fi

# ─── DIKW: Load Wisdom layer ───
if [ -f "${ENSO_WISDOM_FILE:-}" ]; then
    W_RULES=$(python3 -c "
import json, os
wf = os.environ.get('ENSO_WISDOM_FILE','')
if os.path.exists(wf):
    for e in json.load(open(wf)):
        print(f\"- [VERIFIED] {e['rule']}\")
" 2>/dev/null || true)
    W_COUNT=0
    [ -n "$W_RULES" ] && W_COUNT=$(echo "$W_RULES" | grep -c "^- " 2>/dev/null || echo "0")
    if [ "$W_COUNT" -gt 0 ]; then
        echo ""
        enso_adapter_output_lessons "$W_COUNT" "$W_RULES" "enso-wisdom"
    fi
fi

# ─── DIKW: Record loaded IDs for utility tracking ───
python3 -c "
import json, os
info = os.environ.get('ENSO_INFO_FILE','')
if os.path.exists(info):
    ids = []
    with open(info) as f:
        for line in f:
            try:
                e = json.loads(line)
                if e.get('status') == 'active': ids.append(e['id'])
            except: pass
    with open(os.environ.get('ENSO_SESSION_LOADED_IDS', '/tmp/enso-session-loaded-ids'),'w') as f: f.write(','.join(ids))
" 2>/dev/null || true
