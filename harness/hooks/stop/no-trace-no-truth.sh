#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# Enso Immutable Hook #2: No Trace, No Truth
# ═══════════════════════════════════════════════════════════════
# Trigger: Stop (session ending)
# Rule: Check for unverified writes. Report prediction accuracy.
#       Produce a session summary trace.
#
# This hook is the "honest mirror" — it tells you what actually
# happened vs what the agent claimed to do.
#
# Checks:
#   1. Pending verifications (writes without read-back)
#   2. Session trace summary (tool calls, errors, duration)
#   3. Prediction accuracy (if predictions were made)
#
# Source: yoyo-evolve "cargo test = 不说谎的反馈源"
# Source: Claudini "RewardHacking = 自进化必然天花板"
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

ENSO_DIR="${ENSO_DIR:-$HOME/.enso}"
PENDING_FILE="$ENSO_DIR/.pending_verifications"
TRACES_DIR="$ENSO_DIR/traces"
TODAY=$(date +%Y-%m-%d)
TRACE_FILE="$TRACES_DIR/$TODAY.jsonl"
LESSONS_FILE="$ENSO_DIR/lessons/active.md"

# ─── 1. Report unverified writes ───
if [ -f "$PENDING_FILE" ] && [ -s "$PENDING_FILE" ]; then
    UNVERIFIED=$(wc -l < "$PENDING_FILE" | tr -d ' ')
    if [ "$UNVERIFIED" -gt 0 ]; then
        echo "⚠️  [enso] $UNVERIFIED file(s) written but never read back to verify:" >&2
        head -5 "$PENDING_FILE" >&2
        if [ "$UNVERIFIED" -gt 5 ]; then
            echo "   ... and $((UNVERIFIED - 5)) more" >&2
        fi
    fi
fi
# Clear pending for next session
> "$PENDING_FILE" 2>/dev/null || true

# ─── 2. Session trace summary ───
if [ -f "$TRACE_FILE" ]; then
    TOOL_CALLS=$(grep -c '"span_type":"tool_call"' "$TRACE_FILE" 2>/dev/null || echo "0")
    ERRORS=$(grep -c '"has_error":true' "$TRACE_FILE" 2>/dev/null || echo "0")
    PREDICTIONS=$(grep -c '"span_type":"prediction"' "$TRACE_FILE" 2>/dev/null || echo "0")
    HITS=$(grep -c '"prediction_hit":true' "$TRACE_FILE" 2>/dev/null || echo "0")

    # Write session summary trace
    mkdir -p "$TRACES_DIR"
    TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    cat >> "$TRACE_FILE" << EOF
{"ts":"$TIMESTAMP","span_type":"session_end","tool_calls":$TOOL_CALLS,"errors":$ERRORS,"predictions":$PREDICTIONS,"prediction_hits":$HITS}
EOF

    # Report
    if [ "$TOOL_CALLS" -gt 0 ]; then
        echo "📊 [enso] Session: $TOOL_CALLS tool calls, $ERRORS errors" >&2
    fi

    # Prediction accuracy
    if [ "${PREDICTIONS:-0}" -gt 0 ] 2>/dev/null; then
        ACCURACY=$(python3 -c "print(f'{int($HITS)/int($PREDICTIONS)*100:.0f}%')" 2>/dev/null || echo "?")
        echo "🎯 [enso] Prediction accuracy: $ACCURACY ($HITS/$PREDICTIONS)" >&2
    fi
fi

# ─── 3. Count active lessons ───
if [ -f "$LESSONS_FILE" ]; then
    LESSON_COUNT=$(grep -c "^- " "$LESSONS_FILE" 2>/dev/null || echo "0")
    echo "🧠 [enso] Active lessons: $LESSON_COUNT" >&2
fi
