#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# Enso Installer
# ═══════════════════════════════════════════════════════════════
# One command: curl -fsSL https://raw.githubusercontent.com/enso-os/enso/main/install.sh | bash
#
# What it does:
#   1. Creates ~/.enso/ directory structure
#   2. Copies hook scripts
#   3. Registers hooks in Claude Code settings.json
#   4. Makes all hooks executable
#
# What it does NOT do:
#   - Modify any existing hooks or settings (non-destructive)
#   - Require sudo or elevated permissions
#   - Install any dependencies (pure bash)
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

ENSO_VERSION="0.1.0"
ENSO_DIR="$HOME/.enso"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo -e "${CYAN}○ Enso v${ENSO_VERSION}${NC}"
echo -e "${CYAN}  A Self-Evolving Personal Agent OS${NC}"
echo ""

# ─── 1. Create directory structure ───
echo -e "${YELLOW}→${NC} Creating ~/.enso/ ..."
mkdir -p "$ENSO_DIR"/{hooks/{pre-tool-use,post-tool-use,stop,session-start},traces,lessons,memory,core}

# ─── 2. Determine source directory ───
# If run from the repo, use local files. Otherwise, download from GitHub.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "$SCRIPT_DIR/harness/hooks/post-tool-use/trace-emission.sh" ]; then
    SOURCE="local"
    HOOK_SRC="$SCRIPT_DIR/harness/hooks"
    CORE_SRC="$SCRIPT_DIR/harness/core"
else
    SOURCE="remote"
    HOOK_SRC="$ENSO_DIR/.download_tmp/hooks"
    CORE_SRC="$ENSO_DIR/.download_tmp/core"
    mkdir -p "$HOOK_SRC"/{pre-tool-use,post-tool-use,stop,session-start} "$CORE_SRC"
    BASE_URL="https://raw.githubusercontent.com/enso-os/enso/main/harness"
    echo -e "${YELLOW}→${NC} Downloading from GitHub..."
    curl -fsSL "$BASE_URL/core/env.sh" -o "$CORE_SRC/env.sh"
    curl -fsSL "$BASE_URL/core/parse-hook-input.py" -o "$CORE_SRC/parse-hook-input.py"
    curl -fsSL "$BASE_URL/hooks/pre-tool-use/core-readonly.sh" -o "$HOOK_SRC/pre-tool-use/core-readonly.sh"
    curl -fsSL "$BASE_URL/hooks/post-tool-use/physical-verification.sh" -o "$HOOK_SRC/post-tool-use/physical-verification.sh"
    curl -fsSL "$BASE_URL/hooks/post-tool-use/trace-emission.sh" -o "$HOOK_SRC/post-tool-use/trace-emission.sh"
    curl -fsSL "$BASE_URL/hooks/stop/no-trace-no-truth.sh" -o "$HOOK_SRC/stop/no-trace-no-truth.sh"
    curl -fsSL "$BASE_URL/hooks/stop/distill-lessons.sh" -o "$HOOK_SRC/stop/distill-lessons.sh"
    curl -fsSL "$BASE_URL/hooks/session-start/load-lessons.sh" -o "$HOOK_SRC/session-start/load-lessons.sh"
fi

# ─── 3. Copy core + hooks ───
echo -e "${YELLOW}→${NC} Installing from $SOURCE..."
cp "$CORE_SRC/env.sh" "$ENSO_DIR/core/"
cp "$CORE_SRC/parse-hook-input.py" "$ENSO_DIR/core/"
cp "$HOOK_SRC/pre-tool-use/core-readonly.sh" "$ENSO_DIR/hooks/pre-tool-use/"
cp "$HOOK_SRC/post-tool-use/physical-verification.sh" "$ENSO_DIR/hooks/post-tool-use/"
cp "$HOOK_SRC/post-tool-use/trace-emission.sh" "$ENSO_DIR/hooks/post-tool-use/"
cp "$HOOK_SRC/stop/no-trace-no-truth.sh" "$ENSO_DIR/hooks/stop/"
cp "$HOOK_SRC/stop/distill-lessons.sh" "$ENSO_DIR/hooks/stop/"
cp "$HOOK_SRC/session-start/load-lessons.sh" "$ENSO_DIR/hooks/session-start/"
chmod +x "$ENSO_DIR/hooks"/{pre-tool-use,post-tool-use,stop,session-start}/*.sh "$ENSO_DIR/core/env.sh"

# Clean up download temp
[ "$SOURCE" = "remote" ] && rm -rf "$ENSO_DIR/.download_tmp"

# ─── 4. Register hooks in Claude Code settings ───
echo -e "${YELLOW}→${NC} Registering hooks in Claude Code settings..."

if [ ! -f "$CLAUDE_SETTINGS" ]; then
    mkdir -p "$(dirname "$CLAUDE_SETTINGS")"
    echo '{}' > "$CLAUDE_SETTINGS"
fi

# Use Python to safely merge hook config into settings.json
python3 << 'PYEOF'
import json, sys, os

settings_path = os.path.expanduser("~/.claude/settings.json")
enso_dir = os.path.expanduser("~/.enso")

with open(settings_path, "r") as f:
    settings = json.load(f)

hooks = settings.setdefault("hooks", {})

# Define Enso hooks
enso_hooks = {
    "PreToolUse": [
        {
            "matcher": "Write|Edit",
            "hooks": [{"type": "command", "command": f"bash {enso_dir}/hooks/pre-tool-use/core-readonly.sh"}]
        }
    ],
    "PostToolUse": [
        {
            "matcher": "Write|Edit|Read|Bash",
            "hooks": [
                {"type": "command", "command": f"bash {enso_dir}/hooks/post-tool-use/physical-verification.sh"},
                {"type": "command", "command": f"bash {enso_dir}/hooks/post-tool-use/trace-emission.sh"}
            ]
        }
    ],
    "Stop": [
        {
            "matcher": "",
            "hooks": [
                {"type": "command", "command": f"bash {enso_dir}/hooks/stop/no-trace-no-truth.sh"},
                {"type": "command", "command": f"bash {enso_dir}/hooks/stop/distill-lessons.sh"}
            ]
        }
    ],
    "SessionStart": [
        {
            "matcher": "",
            "hooks": [
                {"type": "command", "command": f"bash {enso_dir}/hooks/session-start/load-lessons.sh"}
            ]
        }
    ]
}

# Merge: add Enso hooks without overwriting existing ones
for event_type, new_rules in enso_hooks.items():
    existing = hooks.get(event_type, [])
    # Check if Enso hooks already registered (by checking for enso_dir in commands)
    enso_registered = any(enso_dir in str(rule) for rule in existing)
    if not enso_registered:
        hooks[event_type] = existing + new_rules
    else:
        print(f"  ⏭  {event_type}: Enso hooks already registered, skipping")

settings["hooks"] = hooks

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)

print("  ✅ Hooks registered in settings.json")
PYEOF

# ─── 5. Initialize lessons file ───
if [ ! -f "$ENSO_DIR/lessons/active.md" ]; then
    cat > "$ENSO_DIR/lessons/active.md" << 'INIT'
# Enso Active Lessons
# Auto-distilled from error seeds. Hit counter tracks usefulness.
# Format: - [YYYY-MM-DD] [hits:N] lesson text

INIT
fi

# ─── Done ───
echo ""
echo -e "${GREEN}✅ Enso v${ENSO_VERSION} installed successfully!${NC}"
echo ""
echo "   Directory:  ~/.enso/"
echo "   Hooks:      6 scripts registered"
echo "   Traces:     ~/.enso/traces/"
echo "   Lessons:    ~/.enso/lessons/active.md"
echo ""
echo -e "   ${CYAN}Your agent now learns from every session.${NC}"
echo -e "   ${CYAN}Start a new Claude Code session to begin.${NC}"
echo ""
echo -e "   Uninstall: ${YELLOW}rm -rf ~/.enso && # remove enso entries from ~/.claude/settings.json${NC}"
echo ""
