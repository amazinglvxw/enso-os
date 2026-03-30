#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# Enso Emission Layer: Trace/Span Logger
# ═══════════════════════════════════════════════════════════════
# Trigger: PostToolUse (every tool call)
# Behavior: Fire-and-forget telemetry. Does NOT block the agent.
#   1. Log every tool call as a Trace/Span entry
#   2. Detect errors and capture as error_seeds
#   3. Track session-level statistics
#
# This is the "training data pipeline" — raw material for
# the Slow Track distillation that runs at session end.
#
# Source: Agent Lightning (Microsoft) Trace/Span semantic conventions
# Source: fireworks-skill-memory error-seed synchronous capture
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

ENSO_DIR="${ENSO_DIR:-$HOME/.enso}"
TRACES_DIR="$ENSO_DIR/traces"
TODAY=$(date +%Y-%m-%d)
TRACE_FILE="$TRACES_DIR/$TODAY.jsonl"
ERROR_SEEDS="$ENSO_DIR/.error_seeds"

mkdir -p "$TRACES_DIR"

# Read hook input
INPUT=$(cat)

# Extract fields via Python (robust JSON parsing)
PARSED=$(echo "$INPUT" | python3 -c '
import sys, json

try:
    data = json.load(sys.stdin)
    tool_name = data.get("tool_name", "") or data.get("tool", {}).get("name", "") or "unknown"

    result = data.get("tool_result", {})
    content = result.get("content", "")
    if isinstance(content, list):
        content = " ".join([r.get("text", "") for r in content if isinstance(r, dict)])
    content = content[:300].replace("\n", " ").replace("\t", " ")

    has_error = "true" if any(s in content.lower() for s in
        ["error", "failed", "traceback", "exception", "denied", "timeout", "refused"]
    ) else "false"

    params = data.get("tool_input", {})
    file_path = ""
    for key in ("file_path", "path", "filename", "command"):
        if key in params:
            file_path = str(params[key])[:200]
            break

    duration = data.get("duration_ms", 0)
    print(tool_name + "\t" + content + "\t" + has_error + "\t" + file_path + "\t" + str(duration))
except Exception as e:
    print("unknown\tparse_error\tfalse\t\t0")
' 2>/dev/null || echo "unknown	parse_error	false		0")

TOOL_NAME=$(echo "$PARSED" | cut -f1)
TOOL_RESULT=$(echo "$PARSED" | cut -f2)
HAS_ERROR=$(echo "$PARSED" | cut -f3)
FILE_PATH=$(echo "$PARSED" | cut -f4)
DURATION=$(echo "$PARSED" | cut -f5)
DURATION=${DURATION:-0}

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# ─── Write trace span ───
cat >> "$TRACE_FILE" << EOF
{"ts":"$TIMESTAMP","span_type":"tool_call","tool":"$TOOL_NAME","has_error":$HAS_ERROR,"target":"$FILE_PATH","duration_ms":$DURATION}
EOF

# ─── Error seed capture (synchronous, same-transaction) ───
if [ "$HAS_ERROR" = "true" ]; then
    echo "[$TIMESTAMP] [$TOOL_NAME] $TOOL_RESULT" | head -c 500 >> "$ERROR_SEEDS"
    echo "" >> "$ERROR_SEEDS"
fi
