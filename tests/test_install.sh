#!/usr/bin/env bats
# ═══════════════════════════════════════════════════════════════
# test_install.sh — Verify install.sh copies ALL required files
# ═══════════════════════════════════════════════════════════════

setup() {
    # Use a temp dir so we don't clobber the real ~/.enso
    export HOME="$(mktemp -d)"
    export ENSO_DIR="$HOME/.enso"
    REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    export REPO_ROOT
}

teardown() {
    # Clean up the temp HOME
    rm -rf "$HOME"
}

# ─── Helper: run install in generic mode ───
run_install() {
    bash "$REPO_ROOT/install.sh" --target generic
}

# ═══ Core files (7 total) ═══

@test "core: env.sh is installed" {
    run_install
    [ -f "$ENSO_DIR/core/env.sh" ]
}

@test "core: parse-hook-input.py is installed" {
    run_install
    [ -f "$ENSO_DIR/core/parse-hook-input.py" ]
}

@test "core: dikw-utils.py is installed" {
    run_install
    [ -f "$ENSO_DIR/core/dikw-utils.py" ]
}

@test "core: adapter.sh is installed" {
    run_install
    [ -f "$ENSO_DIR/core/adapter.sh" ]
}

@test "core: rebuild-index.py is installed" {
    run_install
    [ -f "$ENSO_DIR/core/rebuild-index.py" ]
}

@test "core: enso-lint.sh is installed" {
    run_install
    [ -f "$ENSO_DIR/core/enso-lint.sh" ]
}

@test "core: deleted-lessons-tracker.py is installed" {
    run_install
    [ -f "$ENSO_DIR/core/deleted-lessons-tracker.py" ]
}

# ═══ Hook scripts (10 total) ═══

@test "hook: pre-tool-use/core-readonly.sh is installed" {
    run_install
    [ -f "$ENSO_DIR/hooks/pre-tool-use/core-readonly.sh" ]
}

@test "hook: pre-tool-use/memory-budget-guard.sh is installed" {
    run_install
    [ -f "$ENSO_DIR/hooks/pre-tool-use/memory-budget-guard.sh" ]
}

@test "hook: pre-tool-use/memory-safety-scan.sh is installed" {
    run_install
    [ -f "$ENSO_DIR/hooks/pre-tool-use/memory-safety-scan.sh" ]
}

@test "hook: post-tool-use/physical-verification.sh is installed" {
    run_install
    [ -f "$ENSO_DIR/hooks/post-tool-use/physical-verification.sh" ]
}

@test "hook: post-tool-use/trace-emission.sh is installed" {
    run_install
    [ -f "$ENSO_DIR/hooks/post-tool-use/trace-emission.sh" ]
}

@test "hook: post-tool-use-failure/error-seed-capture.sh is installed" {
    run_install
    [ -f "$ENSO_DIR/hooks/post-tool-use-failure/error-seed-capture.sh" ]
}

@test "hook: stop/no-trace-no-truth.sh is installed" {
    run_install
    [ -f "$ENSO_DIR/hooks/stop/no-trace-no-truth.sh" ]
}

@test "hook: stop/distill-lessons.sh is installed" {
    run_install
    [ -f "$ENSO_DIR/hooks/stop/distill-lessons.sh" ]
}

@test "hook: stop/session-end-maintenance.sh is installed" {
    run_install
    [ -f "$ENSO_DIR/hooks/stop/session-end-maintenance.sh" ]
}

@test "hook: session-start/load-lessons.sh is installed" {
    run_install
    [ -f "$ENSO_DIR/hooks/session-start/load-lessons.sh" ]
}

# ═══ Aggregate check ═══

@test "all 7 core files exist after install" {
    run_install
    local missing=0
    for f in env.sh parse-hook-input.py dikw-utils.py adapter.sh \
             rebuild-index.py enso-lint.sh deleted-lessons-tracker.py; do
        [ -f "$ENSO_DIR/core/$f" ] || { echo "MISSING: $f"; missing=$((missing + 1)); }
    done
    [ "$missing" -eq 0 ]
}

@test "all 10 hook scripts exist after install" {
    run_install
    local missing=0
    local -a expected=(
        "pre-tool-use/core-readonly.sh"
        "pre-tool-use/memory-budget-guard.sh"
        "pre-tool-use/memory-safety-scan.sh"
        "post-tool-use/physical-verification.sh"
        "post-tool-use/trace-emission.sh"
        "post-tool-use-failure/error-seed-capture.sh"
        "stop/no-trace-no-truth.sh"
        "stop/distill-lessons.sh"
        "stop/session-end-maintenance.sh"
        "session-start/load-lessons.sh"
    )
    for h in "${expected[@]}"; do
        [ -f "$ENSO_DIR/hooks/$h" ] || { echo "MISSING: $h"; missing=$((missing + 1)); }
    done
    [ "$missing" -eq 0 ]
}
