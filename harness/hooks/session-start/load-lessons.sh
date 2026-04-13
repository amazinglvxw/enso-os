#!/usr/bin/env bash
# Enso Session Start: Load Learned Lessons (SessionStart)
# Injects active lessons into agent context. Detects newly learned
# lessons and prompts the agent to proactively tell the user.
set -euo pipefail

# shellcheck disable=SC2034  # ENSO_INPUT consumed by sourced env.sh
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

# ─── Detect newly learned lessons (single Python call) ───
# One Python process: reads .announced-lessons, finds new lessons,
# appends new core texts to .announced-lessons, outputs count + stripped text.
# Output format: first line = count, remaining lines = stripped lesson text.
NEW_OUTPUT=""
NEW_COUNT=0
if [ "$LESSON_COUNT" -gt 0 ]; then
    touch "$ANNOUNCED_FILE"
    NEW_OUTPUT=$(python3 -c "
import re, sys, os
announced_file = os.environ.get('ENSO_DIR','') + '/.announced-lessons'
strip_re = re.compile(r'^- \[\d{4}-\d{2}-\d{2}\]\s*\[hits:\d+\]\s*(?:\[seed:[a-f0-9]+\]\s*)?')

# Read announced set
announced = set()
if os.path.exists(announced_file):
    with open(announced_file) as f:
        announced = set(line.strip() for line in f if line.strip())

# Find new lessons and collect core texts
new_cores = []
for line in sys.stdin:
    line = line.strip()
    if not line.startswith('- '):
        continue
    core = strip_re.sub('', line)
    if core and core not in announced:
        new_cores.append(core)

# Output: first line = count, remaining lines = stripped text for display
print(len(new_cores))
for core in new_cores:
    print('- ' + core)

# Append new core texts to announced file
if new_cores:
    with open(announced_file, 'a') as f:
        for core in new_cores:
            f.write(core + '\n')
" <<< "$ACTIVE" 2>/dev/null || true)
    if [ -n "$NEW_OUTPUT" ]; then
        NEW_COUNT=$(printf '%s\n' "$NEW_OUTPUT" | head -1)
        # Validate count is numeric
        case "$NEW_COUNT" in ''|*[!0-9]*) NEW_COUNT=0 ;; esac
    fi
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
        # Display stripped lessons (skip first line which is the count)
        printf '%s\n' "$NEW_OUTPUT" | tail -n +2
        echo "</enso-newly-learned>"
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
