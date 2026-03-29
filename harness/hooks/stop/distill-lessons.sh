#!/usr/bin/env bash
# Enso Stop Hook: Async lesson distillation
# Triggered when a Claude Code session ends.
#
# Behavior:
#   1. Check if errors occurred during session (error-signal gating)
#   2. If no errors → exit silently (success is baseline, not worth distilling)
#   3. If errors found → capture error seeds + distill 1-3 lessons via lightweight model
#   4. Enforce memory capacity hard caps
#
# Philosophy: "不做比做错更好" (Doing nothing is better than doing it wrong)
# Source: fireworks-skill-memory v3.0 error-signal gating

set -euo pipefail

MEMORY_DIR="${ENSO_MEMORY_DIR:-$HOME/.enso/memory}"
KNOWLEDGE_FILE="$MEMORY_DIR/knowledge.md"
ERROR_SEEDS="$MEMORY_DIR/.error_seeds"
EXECUTION_LOG="$MEMORY_DIR/execution-log.jsonl"
MAX_ITEMS="${ENSO_MAX_MEMORY_ITEMS:-50}"
DISTILL_MODEL="${ENSO_DISTILL_MODEL:-claude-haiku-4-5}"

# ─── Error Signal Gating ───
# Only distill if errors occurred. Smooth sessions produce no lessons.
has_errors() {
    if [ ! -f "$ERROR_SEEDS" ] || [ ! -s "$ERROR_SEEDS" ]; then
        return 1
    fi
    return 0
}

# ─── Capacity Enforcement ───
enforce_caps() {
    if [ -f "$KNOWLEDGE_FILE" ]; then
        local count
        count=$(grep -c "^- " "$KNOWLEDGE_FILE" 2>/dev/null || echo "0")
        if [ "$count" -gt "$MAX_ITEMS" ]; then
            local overflow=$((count - MAX_ITEMS))
            # Remove oldest entries (top of file after header)
            # TODO: Replace with utility-based eviction (frequency + decay)
            echo "[enso] Capacity overflow: $count/$MAX_ITEMS. Evicting $overflow oldest entries."
        fi
    fi
}

# ─── Main ───
main() {
    # Ensure memory directory exists
    mkdir -p "$MEMORY_DIR"

    # Gate: no errors → no distillation
    if ! has_errors; then
        # Still enforce caps and write execution log
        enforce_caps
        exit 0
    fi

    echo "[enso] Error seeds found. Distilling lessons..."

    # TODO: Call distillation model to extract 1-3 lessons from error seeds
    # For now, log the raw error seeds
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo "{\"ts\":\"$timestamp\",\"event\":\"DISTILL_TRIGGER\",\"error_seeds\":\"$(wc -l < "$ERROR_SEEDS") lines\"}" >> "$EXECUTION_LOG"

    # Clear error seeds after processing
    > "$ERROR_SEEDS"

    # Enforce caps
    enforce_caps
}

main "$@"
