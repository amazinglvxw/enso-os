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

# Single Python call: extract content + scan threats
THREAT=$(echo "$ENSO_INPUT" | python3 -c '
import sys, json, re

try:
    data = json.load(sys.stdin)
    params = data.get("tool_input", {})
    text = params.get("content", params.get("new_string", ""))
except Exception:
    sys.exit(0)

if not text:
    sys.exit(0)

threats = [
    (r"sk-[a-zA-Z0-9]{20,}", "API key"),
    (r"(?i)password\s*[:=]\s*\S{8,}", "password (8+ chars)"),
    (r"(?i)(?:api[_-]?token|auth[_-]?token|secret[_-]?key)\s*[:=]\s*\S+", "auth token"),
    (r"(?i)ignore\s+previous|you\s+are\s+now|system\s*:", "injection attempt"),
]
for pat, label in threats:
    if re.search(pat, text):
        print(f"BLOCKED: {label} detected")
        sys.exit(0)
' 2>/dev/null || echo "")

if [ -n "$THREAT" ]; then
    echo "ENSO SAFETY SCAN: $THREAT in write to $FILE_PATH" >&2
    exit 2
fi
