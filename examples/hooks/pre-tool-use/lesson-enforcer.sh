#!/usr/bin/env bash
# Lesson Enforcer (PreToolUse) — Converts high-value lessons into deterministic checks
# Philosophy: "Code enforcement > Prompt persuasion"
# Non-blocking (exit 0) — outputs warnings to stderr
# v2: Single python3 call for all JSON parsing (was 3 separate spawns)
set -euo pipefail

INPUT=$(cat)

# Single python3 call extracts all needed fields at once (~70ms vs ~210ms for 3 calls)
eval $(echo "$INPUT" | python3 -c "
import json, sys, shlex
d = json.load(sys.stdin)
inp = d.get('tool_input', {})
print(f'TOOL_NAME={shlex.quote(d.get(\"tool_name\",\"\"))}')
print(f'FILE_PATH={shlex.quote(inp.get(\"file_path\",\"\"))}')
print(f'COMMAND={shlex.quote(inp.get(\"command\",\"\"))}')
has_offset = 'yes' if inp.get('offset') is not None or inp.get('limit') is not None else 'no'
print(f'HAS_OFFSET={has_offset}')
" 2>/dev/null) || { TOOL_NAME=""; FILE_PATH=""; COMMAND=""; HAS_OFFSET="no"; }

# ─── LESSON: "Read tool requires file paths, not directories" ───
if [ "$TOOL_NAME" = "Read" ] && [ -n "$FILE_PATH" ]; then
  if [ -d "$FILE_PATH" ]; then
    echo "⚠️ [lesson-enforcer] Read got a directory: $FILE_PATH — use Glob or ls first, then Read by file path." >&2
  fi
fi

# ─── LESSON: "Use offset/limit for large files (>5000 lines)" ───
if [ "$TOOL_NAME" = "Read" ] && [ -n "$FILE_PATH" ] && [ -f "$FILE_PATH" ]; then
  # Use head to cap read at 5001 lines (avoids reading entire huge files)
  FILE_LINES=$(head -5001 "$FILE_PATH" 2>/dev/null | wc -l | tr -d ' ')
  if [ "${FILE_LINES:-0}" -gt 5000 ] && [ "$HAS_OFFSET" = "no" ]; then
    echo "⚠️ [lesson-enforcer] File has ${FILE_LINES}+ lines. Use offset/limit to read a specific section." >&2
  fi
fi

# ─── LESSON: "git pull needs configured strategy" ───
if [ "$TOOL_NAME" = "Bash" ] && echo "$COMMAND" | grep -qE 'git pull\b' 2>/dev/null; then
  PULL_FF=$(git config --get pull.ff 2>/dev/null || echo "")
  PULL_REBASE=$(git config --get pull.rebase 2>/dev/null || echo "")
  if [ -z "$PULL_FF" ] && [ -z "$PULL_REBASE" ]; then
    echo "⚠️ [lesson-enforcer] git pull without configured strategy. Run 'git config pull.rebase true' first." >&2
  fi
fi

exit 0
