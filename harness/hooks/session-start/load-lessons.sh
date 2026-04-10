#!/usr/bin/env bash
# Enso Session Start: Load Learned Lessons (SessionStart)
# Injects active lessons into agent context. Detects newly learned
# lessons and prompts the agent to proactively tell the user.
set -euo pipefail

ENSO_INPUT=""
source "${ENSO_CORE:-$HOME/.enso/core}/env.sh"

LAST_LOAD_TS_FILE="$ENSO_DIR/.last-load-ts"

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

# ─── Detect newly learned lessons (since last session load) ───
NEW_LESSONS=""
NEW_COUNT=0
if [ -f "$LAST_LOAD_TS_FILE" ] && [ "$LESSON_COUNT" -gt 0 ]; then
    LAST_TS=$(cat "$LAST_LOAD_TS_FILE" 2>/dev/null | tr -d '[:space:]')
    if [ -n "$LAST_TS" ]; then
        # Lessons with date > last load date are "new"
        NEW_LESSONS=$(printf '%s\n' "$ACTIVE" | while IFS= read -r line; do
            LDATE=$(echo "$line" | grep -oP '^\- \[\K\d{4}-\d{2}-\d{2}' 2>/dev/null || echo "$line" | sed -n 's/^- \[\([0-9-]*\)\].*/\1/p')
            [ -n "$LDATE" ] && [ "$LDATE" \> "$LAST_TS" ] && echo "$line"
        done || true)
        [ -n "$NEW_LESSONS" ] && NEW_COUNT=$(printf '%s\n' "$NEW_LESSONS" | wc -l | tr -d ' ')
    fi
fi

# Record this load timestamp for next session comparison
echo "$ENSO_TODAY" > "$LAST_LOAD_TS_FILE"

# ─── Output ───
if [ "$LESSON_COUNT" -gt 0 ]; then
    echo "OK: Enso loaded ($SESSION_COUNT sessions, $LESSON_COUNT active lessons)"
    echo ""
    enso_adapter_output_lessons "$LESSON_COUNT" "$ACTIVE" "enso-lessons"

    # If there are newly learned lessons, prompt the agent to tell the user
    if [ "$NEW_COUNT" -gt 0 ]; then
        STRIPPED=$(printf '%s\n' "$NEW_LESSONS" | sed 's/^- \[[0-9-]*\] \[hits:[0-9]*\] \(\[seed:[a-f0-9]*\] \)\?/- /')
        echo ""
        echo "<enso-newly-learned count=\"$NEW_COUNT\">"
        echo "The following lessons were learned from errors in recent sessions."
        echo "Find a natural moment to briefly tell the user what you learned — not as a dump,"
        echo "but as a short, conversational mention (e.g., \"By the way, I learned from last time"
        echo "that...\" or \"上次我学到了...\"). One sentence per lesson is enough."
        echo ""
        echo "$STRIPPED"
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
