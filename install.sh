#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# Enso Installer v0.2.0
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

ENSO_VERSION="0.2.0"
ENSO_DIR="$HOME/.enso"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
GITHUB_BASE="https://raw.githubusercontent.com/amazinglvxw/enso-os/main/harness"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Cleanup trap for partial installs
cleanup() { rm -rf "$ENSO_DIR/.download_tmp" 2>/dev/null || true; }
trap cleanup ERR EXIT

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
    echo -e "${YELLOW}→${NC} Downloading from GitHub..."
    curl -fsSL "$GITHUB_BASE/core/env.sh" -o "$CORE_SRC/env.sh"
    curl -fsSL "$GITHUB_BASE/core/parse-hook-input.py" -o "$CORE_SRC/parse-hook-input.py"
    curl -fsSL "$GITHUB_BASE/core/dikw-utils.py" -o "$CORE_SRC/dikw-utils.py"
    curl -fsSL "$GITHUB_BASE/hooks/pre-tool-use/core-readonly.sh" -o "$HOOK_SRC/pre-tool-use/core-readonly.sh"
    curl -fsSL "$GITHUB_BASE/hooks/pre-tool-use/memory-budget-guard.sh" -o "$HOOK_SRC/pre-tool-use/memory-budget-guard.sh"
    curl -fsSL "$GITHUB_BASE/hooks/pre-tool-use/memory-safety-scan.sh" -o "$HOOK_SRC/pre-tool-use/memory-safety-scan.sh"
    curl -fsSL "$GITHUB_BASE/hooks/post-tool-use/physical-verification.sh" -o "$HOOK_SRC/post-tool-use/physical-verification.sh"
    curl -fsSL "$GITHUB_BASE/hooks/post-tool-use/trace-emission.sh" -o "$HOOK_SRC/post-tool-use/trace-emission.sh"
    curl -fsSL "$GITHUB_BASE/hooks/post-tool-use-failure/error-seed-capture.sh" -o "$HOOK_SRC/post-tool-use-failure/error-seed-capture.sh"
    curl -fsSL "$GITHUB_BASE/hooks/stop/no-trace-no-truth.sh" -o "$HOOK_SRC/stop/no-trace-no-truth.sh"
    curl -fsSL "$GITHUB_BASE/hooks/stop/distill-lessons.sh" -o "$HOOK_SRC/stop/distill-lessons.sh"
    curl -fsSL "$GITHUB_BASE/hooks/stop/session-end-maintenance.sh" -o "$HOOK_SRC/stop/session-end-maintenance.sh"
    curl -fsSL "$GITHUB_BASE/hooks/session-start/load-lessons.sh" -o "$HOOK_SRC/session-start/load-lessons.sh"
fi

# ─── 3. Copy core + hooks ───
echo -e "${YELLOW}→${NC} Installing from $SOURCE..."
cp "$CORE_SRC/env.sh" "$ENSO_DIR/core/"
cp "$CORE_SRC/parse-hook-input.py" "$ENSO_DIR/core/"
cp "$CORE_SRC/dikw-utils.py" "$ENSO_DIR/core/"

# Copy hooks (use nullglob to handle empty directories gracefully)
shopt -s nullglob
for dir in pre-tool-use post-tool-use post-tool-use-failure stop session-start; do
    files=("$HOOK_SRC/$dir/"*.sh)
    if [ ${#files[@]} -gt 0 ]; then
        cp "${files[@]}" "$ENSO_DIR/hooks/$dir/"
        chmod +x "$ENSO_DIR/hooks/$dir/"*.sh
    fi
done
shopt -u nullglob
chmod +x "$ENSO_DIR/core/env.sh"

# Clean up download temp
if [ "$SOURCE" = "remote" ]; then
    rm -rf "$ENSO_DIR/.download_tmp"
fi

# ─── 4. Register hooks in Claude Code settings ───
echo -e "${YELLOW}→${NC} Registering hooks..."

if [ ! -f "$CLAUDE_SETTINGS" ]; then
    mkdir -p "$(dirname "$CLAUDE_SETTINGS")"
    echo '{}' > "$CLAUDE_SETTINGS"
fi

python3 << PYEOF
import json, os, shlex

settings_path = os.path.expanduser("$CLAUDE_SETTINGS")
enso_dir = os.path.expanduser("$ENSO_DIR")
q = shlex.quote(enso_dir)

with open(settings_path, "r") as f:
    settings = json.load(f)

hooks = settings.setdefault("hooks", {})

def cmd(subdir, script):
    return {"type": "command", "command": f"bash {q}/hooks/{subdir}/{script}.sh"}

enso_hooks = {
    "PreToolUse": [{"matcher": "Write|Edit", "hooks": [
        cmd("pre-tool-use", "core-readonly"),
        cmd("pre-tool-use", "memory-budget-guard"),
        cmd("pre-tool-use", "memory-safety-scan"),
    ]}],
    "PostToolUse": [{"matcher": "Write|Edit|Read|Bash", "hooks": [
        cmd("post-tool-use", "physical-verification"),
        cmd("post-tool-use", "trace-emission"),
    ]}],
    "PostToolUseFailure": [{"matcher": "", "hooks": [
        cmd("post-tool-use-failure", "error-seed-capture"),
    ]}],
    "Stop": [{"matcher": "", "hooks": [
        cmd("stop", "no-trace-no-truth"),
        cmd("stop", "distill-lessons"),
        cmd("stop", "session-end-maintenance"),
    ]}],
    "SessionStart": [{"matcher": "", "hooks": [
        cmd("session-start", "load-lessons"),
    ]}],
}

# On re-install: remove old Enso hooks, then add fresh (supports upgrades)
for event_type, new_rules in enso_hooks.items():
    existing = hooks.get(event_type, [])
    cleaned = [r for r in existing if enso_dir not in str(r)]
    hooks[event_type] = cleaned + new_rules

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
