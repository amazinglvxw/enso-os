#!/usr/bin/env bash
# Enso Immutable Hook #3: Core Read-Only (PreToolUse)
# Agent cannot modify Enso's own hooks or core config.
set -euo pipefail

# shellcheck disable=SC2034  # ENSO_INPUT consumed by sourced env.sh
ENSO_INPUT=$(cat)
source "${ENSO_CORE:-$HOME/.enso/core}/env.sh"

IFS=$'\t' read -r TOOL_NAME FILE_PATH <<< "$(enso_parse tool_name file_path)"

# Only guard write operations
case "$TOOL_NAME" in
    Write|Edit) ;;
    *) exit 0 ;;
esac

[ -z "$FILE_PATH" ] && exit 0

PROTECTED_PATTERNS=(
    "$ENSO_DIR/hooks/"
    "$ENSO_DIR/core/"
    "enso-os/harness/hooks/"
    "enso-os/harness/core/"
)

for pattern in "${PROTECTED_PATTERNS[@]}"; do
    if [[ "$FILE_PATH" == *"$pattern"* ]]; then
        echo "ENSO CORE READONLY: Cannot modify protected path: $FILE_PATH" >&2
        echo "The harness protects itself. Modify Enso hooks through the repo, not the agent." >&2
        exit 2
    fi
done
