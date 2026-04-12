#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# Enso Installer v0.4.0
# A Discipline Plugin for AI Agents
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

ENSO_VERSION="0.4.0"
ENSO_DIR="$HOME/.enso"
GITHUB_BASE="https://raw.githubusercontent.com/amazinglvxw/enso-os/main/harness"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ─── Parse arguments ───
ENSO_TARGET="claude-code"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --target) ENSO_TARGET="$2"; shift 2 ;;
        --help|-h)
            echo "Usage: bash install.sh [--target TARGET]"
            echo "Targets: claude-code (default), gemini-cli, hermes, openclaw, generic"
            exit 0 ;;
        *) echo -e "${RED}Unknown option: $1${NC}"; exit 1 ;;
    esac
done

# Validate target
case "$ENSO_TARGET" in
    claude-code|gemini-cli|hermes|openclaw|generic) ;;
    *) echo -e "${RED}Unknown target: $ENSO_TARGET. Use: claude-code, gemini-cli, hermes, openclaw, generic${NC}"; exit 1 ;;
esac

# ─── Prerequisites check ───
MISSING=""
command -v python3 &>/dev/null || MISSING="python3"
command -v bash &>/dev/null || MISSING="${MISSING:+$MISSING, }bash"
if [ -n "$MISSING" ]; then
    echo -e "${RED}Error: Missing required tools: ${MISSING}${NC}" >&2
    exit 1
fi
PY_OK=$(python3 -c "import sys; print('OK' if sys.version_info >= (3, 6) else 'OLD')" 2>/dev/null || echo "FAIL")
if [ "$PY_OK" != "OK" ]; then
    echo -e "${RED}Error: Python 3.6+ required${NC}" >&2
    exit 1
fi

cleanup() { rm -rf "$ENSO_DIR/.download_tmp" 2>/dev/null || true; }
trap cleanup ERR EXIT

echo ""
echo -e "${CYAN}○ Enso v${ENSO_VERSION}${NC}"
echo -e "${CYAN}  A Discipline Plugin for AI Agents${NC}"
echo -e "${CYAN}  Target: ${ENSO_TARGET}${NC}"
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
    for f in env.sh parse-hook-input.py dikw-utils.py adapter.sh rebuild-index.py enso-lint.sh deleted-lessons-tracker.py; do
        curl -fsSL "$GITHUB_BASE/core/$f" -o "$CORE_SRC/$f"
    done
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
for f in env.sh parse-hook-input.py dikw-utils.py adapter.sh rebuild-index.py enso-lint.sh deleted-lessons-tracker.py; do
    [ -f "$CORE_SRC/$f" ] && cp "$CORE_SRC/$f" "$ENSO_DIR/core/"
done

shopt -s nullglob
for dir in pre-tool-use post-tool-use post-tool-use-failure stop session-start; do
    files=("$HOOK_SRC/$dir/"*.sh)
    if [ ${#files[@]} -gt 0 ]; then
        cp "${files[@]}" "$ENSO_DIR/hooks/$dir/"
        chmod +x "$ENSO_DIR/hooks/$dir/"*.sh
    fi
done
shopt -u nullglob
chmod +x "$ENSO_DIR/core/env.sh" "$ENSO_DIR/core/adapter.sh" "$ENSO_DIR/core/enso-lint.sh" 2>/dev/null || true

[ "$SOURCE" = "remote" ] && rm -rf "$ENSO_DIR/.download_tmp"

# ─── 4. Write target config ───
echo "$ENSO_TARGET" > "$ENSO_DIR/.target"

# ─── 5. Register hooks (framework-specific) ───
echo -e "${YELLOW}→${NC} Registering hooks for $ENSO_TARGET..."

register_json_hooks() {
    local settings_file="$1"
    local pre_matcher="$2"
    local post_matcher="$3"
    [ -f "$settings_file" ] || { mkdir -p "$(dirname "$settings_file")"; echo '{}' > "$settings_file"; }
    python3 << PYEOF
import json, os, shlex
settings_path = "$settings_file"
enso_dir = os.path.expanduser("$ENSO_DIR")
q = shlex.quote(enso_dir)
with open(settings_path, "r") as f:
    settings = json.load(f)
hooks = settings.setdefault("hooks", {})
def cmd(subdir, script):
    return {"type": "command", "command": f"bash {q}/hooks/{subdir}/{script}.sh"}
enso_hooks = {
    "PreToolUse": [{"matcher": "$pre_matcher", "hooks": [
        cmd("pre-tool-use", "core-readonly"),
        cmd("pre-tool-use", "memory-budget-guard"),
        cmd("pre-tool-use", "memory-safety-scan"),
    ]}],
    "PostToolUse": [{"matcher": "$post_matcher", "hooks": [
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
for event_type, new_rules in enso_hooks.items():
    existing = hooks.get(event_type, [])
    cleaned = [r for r in existing if enso_dir not in str(r)]
    hooks[event_type] = cleaned + new_rules
settings["hooks"] = hooks
with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)
print("  ✅ Hooks registered in $settings_file")
PYEOF
}

case "$ENSO_TARGET" in
    claude-code)
        register_json_hooks "$HOME/.claude/settings.json" "Write|Edit" "Write|Edit|Read|Bash"
        ;;
    gemini-cli)
        register_json_hooks "$HOME/.gemini/settings.json" "write_file|edit_file" "write_file|edit_file|read_file|run_shell_command"
        ;;
    hermes)
        # Generate a Python plugin shim for Hermes Agent
        HERMES_PLUGIN="$HOME/.hermes/plugins/enso"
        mkdir -p "$HERMES_PLUGIN"
        cat > "$HERMES_PLUGIN/__init__.py" << 'HEOF'
"""Enso discipline plugin for Hermes Agent.
Wraps shell hooks as async Python handlers."""
import subprocess, os, json

ENSO_DIR = os.path.expanduser("~/.enso")

def _run_hook(subdir, script, input_data=""):
    cmd = f"bash {ENSO_DIR}/hooks/{subdir}/{script}.sh"
    env = {**os.environ, "ENSO_CORE": f"{ENSO_DIR}/core"}
    try:
        r = subprocess.run(cmd, shell=True, input=input_data, capture_output=True,
                          text=True, timeout=30, env=env)
        return r.stdout, r.stderr, r.returncode
    except Exception:
        return "", "", 1

async def on_session_start(context):
    out, err, _ = _run_hook("session-start", "load-lessons")
    if out.strip():
        context.setdefault("system_additions", []).append(out.strip())

async def post_tool_call(context):
    data = json.dumps({"tool": context.get("tool", {}), "arguments": context.get("arguments", {}),
                       "output": str(context.get("output", ""))[:500]})
    _run_hook("post-tool-use", "trace-emission", data)
    if context.get("error"):
        _run_hook("post-tool-use-failure", "error-seed-capture", data)

async def on_session_end(context):
    _run_hook("stop", "distill-lessons")
    _run_hook("stop", "session-end-maintenance")

def setup_hooks(agent_context):
    agent_context.register_hook("on_session_start", on_session_start)
    agent_context.register_hook("post_tool_call", post_tool_call)
    agent_context.register_hook("on_session_end", on_session_end)

provides_hooks = True
HEOF
        cat > "$HERMES_PLUGIN/plugin.yaml" << 'HYEOF'
name: enso
version: 0.4.0
description: Discipline plugin — code-enforced learning, active forgetting, self-protection
provides_hooks: true
HYEOF
        echo "  ✅ Hermes plugin installed to $HERMES_PLUGIN"
        ;;
    openclaw)
        # Generate an OpenClaw hook directory with HOOK.md + handler.ts shim
        OC_HOOK="$HOME/.openclaw/hooks/enso-discipline"
        mkdir -p "$OC_HOOK"
        cat > "$OC_HOOK/HOOK.md" << 'OCMD'
---
name: enso-discipline
description: "Code-enforced learning, active forgetting, self-protection"
metadata:
  openclaw:
    emoji: "🔒"
    events: ["session:start", "tool:after", "error:*", "session:end"]
    requires:
      bins: ["bash", "python3"]
---
# Enso Discipline Hook
Wraps Enso shell hooks for OpenClaw lifecycle events.
OCMD
        cat > "$OC_HOOK/handler.ts" << 'OCTS'
import { execSync } from "child_process";
const ENSO = process.env.HOME + "/.enso";
const run = (sub: string, script: string, input = "") => {
  try {
    return execSync(`bash ${ENSO}/hooks/${sub}/${script}.sh`, {
      input, timeout: 30000, env: { ...process.env, ENSO_CORE: `${ENSO}/core` },
    }).toString();
  } catch { return ""; }
};
const handler = async (event: any) => {
  const { type, action } = event;
  if (type === "session" && action === "start") {
    const ctx = run("session-start", "load-lessons");
    if (ctx) event.context.bootstrapFiles = [...(event.context.bootstrapFiles || []), ctx];
  }
  if (type === "tool" && action === "after") {
    const data = JSON.stringify(event.context || {});
    run("post-tool-use", "trace-emission", data);
    if (event.context?.result?.success === false) run("post-tool-use-failure", "error-seed-capture", data);
  }
  if (type === "session" && action === "end") {
    run("stop", "distill-lessons");
    run("stop", "session-end-maintenance");
  }
};
export default handler;
OCTS
        echo "  ✅ OpenClaw hook installed to $OC_HOOK"
        ;;
    generic)
        echo "  ✅ Generic mode: hooks installed to ~/.enso/"
        echo ""
        echo "  Wire into your agent's lifecycle:"
        echo "    Session start → bash ~/.enso/hooks/session-start/load-lessons.sh"
        echo "    After tool    → echo '\$JSON' | bash ~/.enso/hooks/post-tool-use/trace-emission.sh"
        echo "    Tool error    → echo '\$JSON' | bash ~/.enso/hooks/post-tool-use-failure/error-seed-capture.sh"
        echo "    Session end   → bash ~/.enso/hooks/stop/distill-lessons.sh"
        echo ""
        echo "  Docs: https://github.com/amazinglvxw/enso-os#generic-integration"
        ;;
esac

# ─── 6. Initialize data files ───
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
echo "   Target:     $ENSO_TARGET"
echo "   Hooks:      $HOOK_COUNT scripts"
echo "   DIKW:       ~/.enso/dikw/ (info → knowledge → wisdom)"
echo "   Traces:     ~/.enso/traces/"
echo "   Lessons:    ~/.enso/lessons/active.md"
echo ""
echo -e "   ${CYAN}Start a new session to begin.${NC}"
echo ""
