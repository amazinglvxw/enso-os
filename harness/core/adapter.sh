#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# Enso Framework Adapter
# Centralizes all framework-specific behavior behind functions.
# Supported targets: claude-code, gemini-cli, hermes, openclaw, generic
# ═══════════════════════════════════════════════════════════════

# Read target from config, default to claude-code (backward compat)
if [ -f "$ENSO_DIR/.target" ]; then
    ENSO_TARGET=$(cat "$ENSO_DIR/.target" | tr -d '[:space:]')
fi
export ENSO_TARGET="${ENSO_TARGET:-claude-code}"

# ─── Output format: lessons/knowledge/wisdom ───
enso_adapter_output_lessons() {
    local count="$1" content="$2" tag="${3:-enso-lessons}"
    case "$ENSO_TARGET" in
        claude-code|gemini-cli)
            printf '<%s count="%s">\n%s\n</%s>\n' "$tag" "$count" "$content" "$tag" ;;
        *)
            local title
            title=$(echo "$tag" | sed 's/-/ /g; s/enso //; s/\b\(.\)/\u\1/g')
            printf '## Enso %s (%s active)\n%s\n' "$title" "$count" "$content" ;;
    esac
}

# ─── Distillation LLM backend ───
enso_adapter_distill() {
    local context="$1" timeout_s="${2:-60}" prompt="$3"
    local result=""
    # Try backends in order: claude → llm → openai → skip
    if command -v claude &>/dev/null; then
        result=$(timeout "$timeout_s" bash -c \
            'printf "%s" "$1" | claude --model claude-haiku-4-5 --print --max-turns 1 "$2" 2>/dev/null' \
            _ "$context" "$prompt") || true
    elif command -v llm &>/dev/null; then
        result=$(timeout "$timeout_s" bash -c \
            'printf "%s\n\n%s" "$2" "$1" | llm -m haiku 2>/dev/null' \
            _ "$context" "$prompt") || true
    elif command -v openai &>/dev/null; then
        result=$(timeout "$timeout_s" bash -c \
            'printf "%s\n\n%s" "$2" "$1" | openai chat -m gpt-4o-mini 2>/dev/null' \
            _ "$context" "$prompt") || true
    fi
    echo "$result"
}
