#!/usr/bin/env bash
# Enso PostToolUse Hook: Error seed capture + physical verification
#
# Two responsibilities:
#   1. CAPTURE: When a tool returns an error, append to .error_seeds (synchronous, same-transaction)
#   2. VERIFY: When agent claims a write operation, ensure a read-back follows
#
# Design principle: "日志同事务写入" (Log in the same transaction as the action)
# Source: yoyo-evolve (cargo test = honest feedback) + fireworks (error-seed capture)

set -euo pipefail

MEMORY_DIR="${ENSO_MEMORY_DIR:-$HOME/.enso/memory}"
ERROR_SEEDS="$MEMORY_DIR/.error_seeds"

# Read hook input from stdin
INPUT=$(cat)

# ─── Error Seed Capture ───
# If the tool result contains error signals, capture immediately
capture_errors() {
    local tool_result
    tool_result=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    result = data.get('tool_result', {}).get('content', '')
    if isinstance(result, list):
        result = ' '.join([r.get('text', '') for r in result if isinstance(r, dict)])
    print(result)
except:
    print('')
" 2>/dev/null)

    # Error signal detection (regex matching)
    if echo "$tool_result" | grep -qiE "error|failed|traceback|exception|denied|timeout|refused"; then
        mkdir -p "$MEMORY_DIR"
        local timestamp
        timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        echo "[$timestamp] $tool_result" | head -c 500 >> "$ERROR_SEEDS"
        echo "" >> "$ERROR_SEEDS"
    fi
}

# ─── Main ───
capture_errors
