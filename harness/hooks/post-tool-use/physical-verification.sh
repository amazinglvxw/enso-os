#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# Enso Immutable Hook #1: Physical Verification
# ═══════════════════════════════════════════════════════════════
# Trigger: PostToolUse (Write, Edit, Bash)
# Rule: If agent wrote/edited a file, it MUST read-back to verify.
#       We track pending verifications and warn if skipped.
#
# Mechanism:
#   - On Write/Edit: record the file path as "pending verification"
#   - On Read of a pending file: clear the pending flag
#   - On session end: report any unverified writes
#
# Source: yoyo-evolve "cargo test = honest feedback"
# Source: OpenAI Harness Engineering "discipline in supporting structure"
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

ENSO_DIR="${ENSO_DIR:-$HOME/.enso}"
PENDING_FILE="$ENSO_DIR/.pending_verifications"

mkdir -p "$ENSO_DIR"

# Read hook input from stdin (Claude Code passes JSON)
INPUT=$(cat)

# Extract tool name and file path
TOOL_NAME=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('tool_name', ''))
except:
    print('')
" 2>/dev/null || echo "")

FILE_PATH=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    params = data.get('tool_input', {})
    # Try common field names for file paths
    for key in ('file_path', 'path', 'filename'):
        if key in params:
            print(params[key])
            break
    else:
        print('')
except:
    print('')
" 2>/dev/null || echo "")

case "$TOOL_NAME" in
    Write|Edit)
        # Agent wrote a file → mark as pending verification
        if [ -n "$FILE_PATH" ]; then
            echo "$FILE_PATH" >> "$PENDING_FILE"
        fi
        ;;
    Read)
        # Agent read a file → check if it was pending verification
        if [ -f "$PENDING_FILE" ] && [ -n "$FILE_PATH" ]; then
            # Remove this file from pending (verified)
            grep -vF "$FILE_PATH" "$PENDING_FILE" > "$PENDING_FILE.tmp" 2>/dev/null || true
            mv "$PENDING_FILE.tmp" "$PENDING_FILE"
        fi
        ;;
esac
