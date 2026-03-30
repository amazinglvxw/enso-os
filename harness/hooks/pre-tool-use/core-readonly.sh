#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# Enso Immutable Hook #3: Core Read-Only
# ═══════════════════════════════════════════════════════════════
# Trigger: PreToolUse (Write, Edit)
# Rule: Agent CANNOT modify Enso's own hook scripts or core config.
#       The harness protects itself from the agent it governs.
#
# Blocked paths:
#   - ~/.enso/hooks/         (hook scripts)
#   - ~/.enso/core/          (core logic)
#   - enso-os/harness/       (source hooks)
#
# Source: Biological analogy — DNA repair mechanisms prevent
#         mutations to the replication machinery itself.
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

ENSO_DIR="${ENSO_DIR:-$HOME/.enso}"

# Read hook input
INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('tool_name', ''))
except:
    print('')
" 2>/dev/null || echo "")

# Only check write operations
case "$TOOL_NAME" in
    Write|Edit) ;;
    *) exit 0 ;;
esac

FILE_PATH=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    params = data.get('tool_input', {})
    for key in ('file_path', 'path', 'filename'):
        if key in params:
            print(params[key])
            break
    else:
        print('')
except:
    print('')
" 2>/dev/null || echo "")

[ -z "$FILE_PATH" ] && exit 0

# Protected paths (the harness protects itself)
PROTECTED_PATTERNS=(
    "$ENSO_DIR/hooks/"
    "$ENSO_DIR/core/"
    "enso-os/harness/hooks/"
    "enso-os/harness/core/"
)

for pattern in "${PROTECTED_PATTERNS[@]}"; do
    if [[ "$FILE_PATH" == *"$pattern"* ]]; then
        echo "ENSO CORE READONLY: Cannot modify protected path: $FILE_PATH" >&2
        echo "The harness protects itself. Modify Enso hooks through the repo, not the agent." >&2
        exit 2
    fi
done
