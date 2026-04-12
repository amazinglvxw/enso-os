#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# Enso Framework Adapter
# Centralizes all framework-specific behavior behind functions.
# Supported targets: claude-code, gemini-cli, hermes, openclaw, generic
# ═══════════════════════════════════════════════════════════════

ENSO_VALID_TARGETS="claude-code gemini-cli hermes openclaw generic"

# Read target (skip file read if already set, but ALWAYS validate)
if [ -z "${ENSO_TARGET:-}" ]; then
    if [ -f "$ENSO_DIR/.target" ]; then
        ENSO_TARGET=$(tr -d '[:space:]' < "$ENSO_DIR/.target")
    fi
    ENSO_TARGET="${ENSO_TARGET:-claude-code}"
fi
# Validate — even if pre-exported (defense against bad parent env)
case " $ENSO_VALID_TARGETS " in
    *" $ENSO_TARGET "*) ;;
    *) echo "⚠️  [enso] Unknown target '$ENSO_TARGET', falling back to claude-code" >&2
       ENSO_TARGET="claude-code" ;;
esac
export ENSO_TARGET

# Output format: lessons/knowledge/wisdom
enso_adapter_output_lessons() {
    local count="$1" content="$2" tag="${3:-enso-lessons}"
    case "$ENSO_TARGET" in
        claude-code|gemini-cli)
            printf '<%s count="%s">\n%s\n</%s>\n' "$tag" "$count" "$content" "$tag" ;;
        *)
            # Portable title case (no GNU sed \u dependency)
            local title
            title=$(python3 -c "print('$tag'.replace('-', ' ').replace('enso ', '').title())" 2>/dev/null || echo "$tag")
            printf '## Enso %s (%s active)\n%s\n' "$title" "$count" "$content" ;;
    esac
}

# Portable timeout: tries timeout → gtimeout (Homebrew) → python3 fallback
_enso_timeout() {
    local secs="$1"; shift
    if command -v timeout &>/dev/null; then
        timeout "$secs" "$@"
    elif command -v gtimeout &>/dev/null; then
        gtimeout "$secs" "$@"
    else
        python3 -c "
import subprocess, sys
try:
    r = subprocess.run(sys.argv[2:], timeout=int(sys.argv[1]), capture_output=False)
    sys.exit(r.returncode)
except subprocess.TimeoutExpired:
    sys.exit(124)
" "$secs" "$@"
    fi
}

# Distillation LLM backend (tries claude → llm → openai → fail)
enso_adapter_distill() {
    local context="$1" timeout_s="${2:-60}" prompt="$3"
    local -a backends=(
        "claude:--model claude-haiku-4-5 --print --max-turns 1"
        "llm:-m haiku"
        "openai:chat -m gpt-4o-mini"
    )
    for entry in "${backends[@]}"; do
        local cmd="${entry%%:*}"
        local args="${entry#*:}"
        if command -v "$cmd" &>/dev/null; then
            local result
            result=$(_enso_timeout "$timeout_s" bash -c \
                'printf "%s\n\n%s" "$2" "$1" | '"$cmd $args"' 2>/dev/null' \
                _ "$context" "$prompt") && {
                echo "$result"
                return 0
            }
        fi
    done
    return 1
}
