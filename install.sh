#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# Enso Installer v0.2.0
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

ENSO_VERSION="0.2.0"
ENSO_DIR="$HOME/.enso"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo -e "${CYAN}○ Enso v${ENSO_VERSION}${NC}"
echo -e "${CYAN}  A Self-Evolving Harness for AI Agents${NC}"
echo ""

# ─── 1. Create directory structure ───
echo -e "${YELLOW}→${NC} Creating ~/.enso/ ..."
mkdir -p "$ENSO_DIR"/{hooks/{pre-tool-use,post-tool-use,post-tool-use-failure,stop,session-start},traces,lessons,memory,core,dikw}

# ─── 2. Determine source ───
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "$SCRIPT_DIR/harness/hooks/post-tool-use/trace-emission.sh" ]; then
    SOURCE="local"
    HOOK_SRC="$SCRIPT_DIR/harness/hooks"
    CORE_SRC="$SCRIPT_DIR/harness/core"
else
    SOURCE="remote"
    HOOK_SRC="$ENSO_DIR/.download_tmp/hooks"
    CORE_SRC="$ENSO_DIR/.download_tmp/core"
    mkdir -p "$HOOK_SRC"/{pre-tool-use,post-tool-use,post-tool-use-failure,stop,session-start} "$CORE_SRC"
    BASE_URL="https://raw.githubusercontent.com/amazinglvxw/enso-os/main/harness"
    echo -e "${YELLOW}→${NC} Downloading from GitHub..."
    # Core
    curl -fsSL "$BASE_URL/core/env.sh" -o "$CORE_SRC/env.sh"
    curl -fsSL "$BASE_URL/core/parse-hook-input.py" -o "$CORE_SRC/parse-hook-input.py"
    curl -fsSL "$BASE_URL/core/dikw-utils.py" -o "$CORE_SRC/dikw-utils.py"
    # Hooks
    curl -fsSL "$BASE_URL/hooks/pre-tool-use/core-readonly.sh" -o "$HOOK_SRC/pre-tool-use/core-readonly.sh"
    curl -fsSL "$BASE_URL/hooks/pre-tool-use/memory-budget-guard.sh" -o "$HOOK_SRC/pre-tool-use/memory-budget-guard.sh"
    curl -fsSL "$BASE_URL/hooks/pre-tool-use/memory-safety-scan.sh" -o "$HOOK_SRC/pre-tool-use/memory-safety-scan.sh"
    curl -fsSL "$BASE_URL/hooks/post-tool-use/physical-verification.sh" -o "$HOOK_SRC/post-tool-use/physical-verification.sh"
    curl -fsSL "$BASE_URL/hooks/post-tool-use/trace-emission.sh" -o "$HOOK_SRC/post-tool-use/trace-emission.sh"
    curl -fsSL "$BASE_URL/hooks/post-tool-use-failure/error-seed-capture.sh" -o "$HOOK_SRC/post-tool-use-failure/error-seed-capture.sh"
    curl -fsSL "$BASE_URL/hooks/stop/no-trace-no-truth.sh" -o "$HOOK_SRC/stop/no-trace-no-truth.sh"
    curl -fsSL "$BASE_URL/hooks/stop/distill-lessons.sh" -o "$HOOK_SRC/stop/distill-lessons.sh"
    curl -fsSL "$BASE_URL/hooks/stop/session-end-maintenance.sh" -o "$HOOK_SRC/stop/session-end-maintenance.sh"
    curl -fsSL "$BASE_URL/hooks/session-start/load-lessons.sh" -o "$HOOK_SRC/session-start/load-lessons.sh"
fi

# ─── 3. Copy core + hooks ───
echo -e "${YELLOW}→${NC} Installing from $SOURCE..."
# Core modules
cp "$CORE_SRC/env.sh" "$ENSO_DIR/core/"
cp "$CORE_SRC/parse-hook-input.py" "$ENSO_DIR/core/"
cp "$CORE_SRC/dikw-utils.py" "$ENSO_DIR/core/"
# Hooks (use globs to catch all scripts per directory)
cp "$HOOK_SRC/pre-tool-use/"*.sh "$ENSO_DIR/hooks/pre-tool-use/"
cp "$HOOK_SRC/post-tool-use/"*.sh "$ENSO_DIR/hooks/post-tool-use/"
cp "$HOOK_SRC/post-tool-use-failure/"*.sh "$ENSO_DIR/hooks/post-tool-use-failure/"
cp "$HOOK_SRC/stop/"*.sh "$ENSO_DIR/hooks/stop/"
cp "$HOOK_SRC/session-start/"*.sh "$ENSO_DIR/hooks/session-start/"
chmod +x "$ENSO_DIR/hooks"/{pre-tool-use,post-tool-use,post-tool-use-failure,stop,session-start}/*.sh "$ENSO_DIR/core/env.sh"

[ "$SOURCE" = "remote" ] && rm -r "$ENSO_DIR/.download_tmp"

# ─── 4. Register hooks in Claude Code settings ───
echo -e "${YELLOW}→${NC} Registering hooks..."

if [ ! -f "$CLAUDE_SETTINGS" ]; then
    mkdir -p "$(dirname "$CLAUDE_SETTINGS")"
    echo '{}' > "$CLAUDE_SETTINGS"
fi

python3 << 'PYEOF'
import json, os

settings_path = os.path.expanduser("~/.claude/settings.json")
enso_dir = os.path.expanduser("~/.enso")

with open(settings_path, "r") as f:
    settings = json.load(f)

hooks = settings.setdefault("hooks", {})

enso_hooks = {
    "PreToolUse": [
        {
            "matcher": "Write|Edit",
            "hooks": [
                {"type": "command", "command": f"bash {enso_dir}/hooks/pre-tool-use/core-readonly.sh"},
                {"type": "command", "command": f"bash {enso_dir}/hooks/pre-tool-use/memory-budget-guard.sh"},
                {"type": "command", "command": f"bash {enso_dir}/hooks/pre-tool-use/memory-safety-scan.sh"}
            ]
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
    "PostToolUseFailure": [
        {
            "matcher": "",
            "hooks": [
                {"type": "command", "command": f"bash {enso_dir}/hooks/post-tool-use-failure/error-seed-capture.sh"}
            ]
        }
    ],
    "Stop": [
        {
            "matcher": "",
            "hooks": [
                {"type": "command", "command": f"bash {enso_dir}/hooks/stop/no-trace-no-truth.sh"},
                {"type": "command", "command": f"bash {enso_dir}/hooks/stop/distill-lessons.sh"},
                {"type": "command", "command": f"bash {enso_dir}/hooks/stop/session-end-maintenance.sh"}
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

for event_type, new_rules in enso_hooks.items():
    existing = hooks.get(event_type, [])
    enso_registered = any(enso_dir in str(rule) for rule in existing)
    if not enso_registered:
        hooks[event_type] = existing + new_rules
    else:
        print(f"  ⏭  {event_type}: already registered")

settings["hooks"] = hooks

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)

print("  ✅ Hooks registered")
PYEOF

# ─── 5. Initialize data files ───
[ -f "$ENSO_DIR/lessons/active.md" ] || printf '# Enso Active Lessons\n# Format: - [YYYY-MM-DD] [hits:N] lesson text\n\n' > "$ENSO_DIR/lessons/active.md"
[ -f "$ENSO_DIR/dikw/info-layer.jsonl" ] || touch "$ENSO_DIR/dikw/info-layer.jsonl"
[ -f "$ENSO_DIR/dikw/knowledge.json" ] || echo '[]' > "$ENSO_DIR/dikw/knowledge.json"
[ -f "$ENSO_DIR/dikw/wisdom.json" ] || echo '[]' > "$ENSO_DIR/dikw/wisdom.json"

# ─── Done ───
HOOK_COUNT=$(find "$ENSO_DIR/hooks" -name "*.sh" | wc -l | tr -d ' ')
echo ""
echo -e "${GREEN}✅ Enso v${ENSO_VERSION} installed${NC}"
echo ""
echo "   Directory:  ~/.enso/"
echo "   Hooks:      $HOOK_COUNT scripts"
echo "   DIKW:       ~/.enso/dikw/ (info → knowledge → wisdom)"
echo "   Traces:     ~/.enso/traces/"
echo "   Lessons:    ~/.enso/lessons/active.md"
echo ""
echo -e "   ${CYAN}Start a new Claude Code session to begin.${NC}"
echo ""
