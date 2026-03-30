#!/usr/bin/env bash
# Enso Hook: Memory Safety Scan (PreToolUse)
# Blocks writes containing secrets, injections, or suspicious patterns.
set -euo pipefail

ENSO_INPUT=$(cat)
source "${ENSO_CORE:-$HOME/.enso/core}/env.sh"

IFS=$'\t' read -r TOOL_NAME FILE_PATH <<< "$(enso_parse tool_name file_path)"

case "$TOOL_NAME" in Write|Edit) ;; *) exit 0 ;; esac

# Only scan memory-related files
case "$FILE_PATH" in
    *MEMORY.md*|*memory/*|*lessons/*|*.enso/*) ;;
    *) exit 0 ;;
esac

# Extract the content being written
CONTENT=$(echo "$ENSO_INPUT" | python3 -c '
import sys, json
try:
    data = json.load(sys.stdin)
    params = data.get("tool_input", {})
    print(params.get("content", params.get("new_string", "")))
except Exception:
    print("")
' 2>/dev/null || echo "")

[ -z "$CONTENT" ] && exit 0

# Scan for dangerous patterns
THREAT=$(echo "$CONTENT" | python3 -c '
import sys, re
text = sys.stdin.read()
patterns = [
    (r"sk-[a-zA-Z0-9]{20,}", "API key"),
    (r"(?i)password\s*[:=]\s*\S+", "password"),
    (r"(?i)token\s*[:=]\s*\S+", "token"),
    (r"(?i)ignore previous|system:|you are now|IMPORTANT:", "injection attempt"),
]
for pat, label in patterns:
    if re.search(pat, text):
        print(f"BLOCKED: {label} detected")
        break
' 2>/dev/null || echo "")

if [ -n "$THREAT" ]; then
    echo "ENSO SAFETY SCAN: $THREAT in write to $FILE_PATH" >&2
    exit 2
fi
