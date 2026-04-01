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
    [ "$K_COUNT" -gt 0 ] && printf '\n<enso-knowledge count="%s">\n%s\n</enso-knowledge>\n' "$K_COUNT" "$K_RULES"
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
    [ "$W_COUNT" -gt 0 ] && printf '\n<enso-wisdom count="%s">\n%s\n</enso-wisdom>\n' "$W_COUNT" "$W_RULES"
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
