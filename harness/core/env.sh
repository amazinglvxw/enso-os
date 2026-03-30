#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# Enso shared environment preamble
# Source this in every hook: source "${ENSO_CORE:-$HOME/.enso/core}/env.sh"
# ═══════════════════════════════════════════════════════════════

export ENSO_DIR="${ENSO_DIR:-$HOME/.enso}"
export ENSO_CORE="${ENSO_CORE:-$ENSO_DIR/core}"
export ENSO_TRACES_DIR="$ENSO_DIR/traces"
export ENSO_LESSONS_DIR="$ENSO_DIR/lessons"
export ENSO_LESSONS_FILE="$ENSO_LESSONS_DIR/active.md"
export ENSO_ERROR_SEEDS="$ENSO_DIR/.error_seeds"
export ENSO_PENDING="$ENSO_DIR/.pending_verifications"
export ENSO_TODAY=$(date +%Y-%m-%d)
export ENSO_TRACE_FILE="$ENSO_TRACES_DIR/$ENSO_TODAY.jsonl"
export ENSO_PARSER="$ENSO_CORE/parse-hook-input.py"

# Ensure directories exist (once per session, not per tool call)
[ -d "$ENSO_TRACES_DIR" ] || mkdir -p "$ENSO_TRACES_DIR"
[ -d "$ENSO_LESSONS_DIR" ] || mkdir -p "$ENSO_LESSONS_DIR"

# Shared: generate ISO 8601 UTC timestamp
enso_ts() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

# Shared: parse hook input (single Python call for all fields)
# Usage: read -r FIELD1 FIELD2 <<< $(enso_parse tool_name file_path)
enso_parse() {
    echo "$ENSO_INPUT" | python3 "$ENSO_PARSER" "$@"
}

# Shared: write JSON trace span (safe — uses Python for escaping)
enso_trace() {
    local json_str
    json_str=$(python3 -c "
import json, sys
print(json.dumps({k: v for k, v in zip(sys.argv[1::2], sys.argv[2::2])}))
" "$@" 2>/dev/null) || return 0
    echo "$json_str" >> "$ENSO_TRACE_FILE"
}
