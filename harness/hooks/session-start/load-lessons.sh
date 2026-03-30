#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# Enso Session Start: Load Learned Lessons
# ═══════════════════════════════════════════════════════════════
# Trigger: SessionStart (via Claude Code hook)
# Behavior: Inject active lessons into agent context so it
#           starts every session with accumulated wisdom.
#
# What gets injected:
#   1. Active lessons (not stale) from lessons/active.md
#   2. Session count + prediction accuracy trend
#
# Philosophy: "记忆的价值不在于记住，而在于改变行为"
#             (Memory's value isn't remembering — it's changing behavior)
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

ENSO_DIR="${ENSO_DIR:-$HOME/.enso}"
LESSONS_FILE="$ENSO_DIR/lessons/active.md"
TRACES_DIR="$ENSO_DIR/traces"

# ─── Load active lessons (skip stale) ───
LESSONS=""
if [ -f "$LESSONS_FILE" ]; then
    # Filter out stale and header lines, keep only active lessons
    ACTIVE=$(grep "^\- " "$LESSONS_FILE" | grep -v "\[stale\]" || true)
    LESSON_COUNT=$(echo "$ACTIVE" | grep -c "^\- " 2>/dev/null || echo "0")

    if [ "$LESSON_COUNT" -gt 0 ]; then
        LESSONS="<enso-lessons count=\"$LESSON_COUNT\">
$ACTIVE
</enso-lessons>"
    fi
fi

# ─── Calculate prediction accuracy trend (last 7 days) ───
TREND=""
if [ -d "$TRACES_DIR" ]; then
    # Read session_end events from recent trace files
    # Aggregate prediction stats from recent trace files
    read -r TOTAL_PREDICTIONS TOTAL_HITS <<< $(python3 -c "
import json, glob, os
traces_dir = os.path.expanduser('$TRACES_DIR')
files = sorted(glob.glob(os.path.join(traces_dir, '*.jsonl')), reverse=True)[:7]
tp, th = 0, 0
for f in files:
    for line in open(f):
        try:
            d = json.loads(line)
            if d.get('span_type') == 'session_end':
                tp += d.get('predictions', 0)
                th += d.get('prediction_hits', 0)
        except: pass
print(tp, th)
" 2>/dev/null || echo "0 0")

    if [ "$TOTAL_PREDICTIONS" -gt 0 ]; then
        ACCURACY=$(python3 -c "print(f'{$TOTAL_HITS/$TOTAL_PREDICTIONS*100:.0f}')" 2>/dev/null || echo "?")
        TREND="<enso-stats>
Prediction accuracy (7d): ${ACCURACY}% ($TOTAL_HITS/$TOTAL_PREDICTIONS)
</enso-stats>"
    fi
fi

# ─── Count total sessions ───
SESSION_COUNT=$(ls "$TRACES_DIR"/*.jsonl 2>/dev/null | wc -l | tr -d ' ' || echo "0")

# ─── Output ───
# Only output if there's something to inject
if [ -n "$LESSONS" ] || [ -n "$TREND" ]; then
    echo "OK: Enso loaded ($SESSION_COUNT sessions, $(echo "$ACTIVE" | grep -c "^\- " 2>/dev/null || echo 0) active lessons)"
    echo ""
    if [ -n "$TREND" ]; then
        echo "$TREND"
    fi
    if [ -n "$LESSONS" ]; then
        echo "$LESSONS"
    fi
else
    echo "OK: Enso ready (first session — no lessons yet)"
fi
