#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# Enso shared environment preamble
# Source this in every hook: source "${ENSO_CORE:-$HOME/.enso/core}/env.sh"
# ═══════════════════════════════════════════════════════════════

export ENSO_DIR="${ENSO_DIR:-$HOME/.enso}"
export ENSO_CORE="${ENSO_CORE:-$ENSO_DIR/core}"

# Skip re-initialization if already set (hot path: multiple hooks per tool call)
if [ -z "${_ENSO_INIT_DONE:-}" ]; then
    export ENSO_TRACES_DIR="$ENSO_DIR/traces"
    export ENSO_LESSONS_DIR="$ENSO_DIR/lessons"
    export ENSO_LESSONS_FILE="$ENSO_LESSONS_DIR/active.md"
    export ENSO_ERROR_SEEDS="$ENSO_DIR/.error_seeds"
    export ENSO_PENDING="$ENSO_DIR/.pending_verifications"
    ENSO_TODAY=$(date +%Y-%m-%d)
    export ENSO_TODAY
    export ENSO_TRACE_FILE="$ENSO_TRACES_DIR/$ENSO_TODAY.jsonl"
    export ENSO_PARSER="$ENSO_CORE/parse-hook-input.py"

    [ -d "$ENSO_TRACES_DIR" ] || mkdir -p "$ENSO_TRACES_DIR"
    [ -d "$ENSO_LESSONS_DIR" ] || mkdir -p "$ENSO_LESSONS_DIR"

    # DIKW Layer paths
    export ENSO_DIKW_DIR="$ENSO_DIR/dikw"
    export ENSO_INFO_FILE="$ENSO_DIKW_DIR/info-layer.jsonl"
    export ENSO_KNOWLEDGE_FILE="$ENSO_DIKW_DIR/knowledge.json"
    export ENSO_WISDOM_FILE="$ENSO_DIKW_DIR/wisdom.json"
    export ENSO_DIKW_UTILS="$ENSO_CORE/dikw-utils.py"

    [ -d "$ENSO_DIKW_DIR" ] || mkdir -p "$ENSO_DIKW_DIR"

    # Session hash (stable per PWD, exported to avoid recomputation)
    ENSO_SESSION_HASH=$(echo "$PWD" | md5sum 2>/dev/null | awk '{print $1}' || echo "$PWD" | md5 -q 2>/dev/null || echo "default")
    export ENSO_SESSION_HASH
    export ENSO_SESSION_LOADED_IDS="${TMPDIR:-/tmp}/enso-session-${ENSO_SESSION_HASH}.ids"

    export _ENSO_INIT_DONE=1
fi

# Load framework adapter (also uses export guard internally)
source "$ENSO_CORE/adapter.sh"

# Shared: generate ISO 8601 UTC timestamp
enso_ts() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

# Shared: parse hook input with format flag
enso_parse() {
    echo "$ENSO_INPUT" | python3 "$ENSO_PARSER" --format "$ENSO_TARGET" "$@"
}

# Shared: write JSON trace span
enso_trace() {
    local json_str
    json_str=$(python3 -c "
import json, sys
print(json.dumps({k: v for k, v in zip(sys.argv[1::2], sys.argv[2::2])}))
" "$@" 2>/dev/null) || return 0
    echo "$json_str" >> "$ENSO_TRACE_FILE"
}

# Shared: enforce lessons capacity cap
enso_enforce_lesson_cap() {
    local max="${1:-50}"
    [ -f "$ENSO_LESSONS_FILE" ] || return 0
    local total
    total=$(grep -c "^- " "$ENSO_LESSONS_FILE" 2>/dev/null || echo "0")
    if [ "$total" -gt "$max" ]; then
        local overflow=$((total - max))
        echo "🗑️  [enso] Lessons: $total/$max, evicting $overflow oldest" >&2
        { head -3 "$ENSO_LESSONS_FILE"; grep "^- " "$ENSO_LESSONS_FILE" | tail -"$max"; } > "$ENSO_LESSONS_FILE.tmp"
        mv "$ENSO_LESSONS_FILE.tmp" "$ENSO_LESSONS_FILE"
    fi
}

enso_dikw() {
    python3 "$ENSO_DIKW_UTILS" "$@"
}

# Shared: find MEMORY.md across known locations
enso_find_memory_file() {
    for candidate in \
        "$HOME/.claude/projects/-$(echo "$PWD" | tr '/' '-' | sed 's/^-//')/memory/MEMORY.md" \
        "$PWD/memory/MEMORY.md" \
        "$HOME/.claude/memory/MEMORY.md"; do
        [ -f "$candidate" ] && echo "$candidate" && return
    done
}
