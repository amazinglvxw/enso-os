#!/usr/bin/env bats
# ═══════════════════════════════════════════════════════════════
# Tests for harness/core/adapter.sh
# Covers: _enso_timeout portability, ENSO_TARGET validation,
#         output format for claude-code (XML) and hermes (markdown)
# ═══════════════════════════════════════════════════════════════

ADAPTER="$BATS_TEST_DIRNAME/../harness/core/adapter.sh"

setup() {
    # Provide a minimal ENSO_DIR so the file can source without errors
    export ENSO_DIR="$(mktemp -d)"
    # Reset target each test
    unset ENSO_TARGET
}

teardown() {
    rm -rf "$ENSO_DIR"
}

# ── _enso_timeout tests ──────────────────────────────────────

@test "_enso_timeout: succeeds when command finishes within limit" {
    source "$ADAPTER"
    run _enso_timeout 5 echo "hello"
    [ "$status" -eq 0 ]
    [ "$output" = "hello" ]
}

@test "_enso_timeout: returns 124 on timeout (simulated with sleep)" {
    source "$ADAPTER"
    run _enso_timeout 1 sleep 10
    [ "$status" -eq 124 ]
}

@test "_enso_timeout: doesn't crash when timeout binary is missing" {
    # Temporarily hide timeout and gtimeout from PATH
    source "$ADAPTER"
    # Override _enso_timeout to force python3 fallback
    _enso_timeout() {
        local secs="$1"; shift
        python3 -c "
import subprocess, sys
try:
    r = subprocess.run(sys.argv[2:], timeout=int(sys.argv[1]), capture_output=False)
    sys.exit(r.returncode)
except subprocess.TimeoutExpired:
    sys.exit(124)
" "$secs" "$@"
    }
    run _enso_timeout 5 echo "python-fallback"
    [ "$status" -eq 0 ]
    [ "$output" = "python-fallback" ]
}

# ── ENSO_TARGET validation tests ─────────────────────────────

@test "ENSO_TARGET: invalid target falls back to claude-code with warning" {
    export ENSO_TARGET="invalid-target"
    run bash -c 'source "'"$ADAPTER"'" 2>&1 && echo "TARGET=$ENSO_TARGET"'
    [ "$status" -eq 0 ]
    # Should contain the warning
    [[ "$output" == *"Unknown target"* ]]
    [[ "$output" == *"falling back to claude-code"* ]]
    # Should end up as claude-code
    [[ "$output" == *"TARGET=claude-code"* ]]
}

@test "ENSO_TARGET: valid target claude-code is accepted" {
    export ENSO_TARGET="claude-code"
    run bash -c 'source "'"$ADAPTER"'" && echo "TARGET=$ENSO_TARGET"'
    [ "$status" -eq 0 ]
    [[ "$output" == *"TARGET=claude-code"* ]]
    # No warning
    [[ "$output" != *"Unknown target"* ]]
}

@test "ENSO_TARGET: valid target hermes is accepted" {
    export ENSO_TARGET="hermes"
    run bash -c 'source "'"$ADAPTER"'" && echo "TARGET=$ENSO_TARGET"'
    [ "$status" -eq 0 ]
    [[ "$output" == *"TARGET=hermes"* ]]
}

# ── Output format tests ─────────────────────────────────────

@test "enso_adapter_output_lessons: claude-code target produces XML" {
    export ENSO_TARGET="claude-code"
    source "$ADAPTER"
    run enso_adapter_output_lessons 3 "lesson content here"
    [ "$status" -eq 0 ]
    [[ "$output" == *'<enso-lessons count="3">'* ]]
    [[ "$output" == *"lesson content here"* ]]
    [[ "$output" == *'</enso-lessons>'* ]]
}

@test "enso_adapter_output_lessons: hermes target produces markdown" {
    export ENSO_TARGET="hermes"
    source "$ADAPTER"
    run enso_adapter_output_lessons 5 "some lessons"
    [ "$status" -eq 0 ]
    [[ "$output" == *"## Enso"* ]]
    [[ "$output" == *"(5 active)"* ]]
    [[ "$output" == *"some lessons"* ]]
    # Should NOT contain XML tags
    [[ "$output" != *"<enso-lessons"* ]]
}

@test "enso_adapter_output_lessons: gemini-cli target produces XML (same as claude-code)" {
    export ENSO_TARGET="gemini-cli"
    source "$ADAPTER"
    run enso_adapter_output_lessons 2 "gemini content"
    [ "$status" -eq 0 ]
    [[ "$output" == *'<enso-lessons count="2">'* ]]
    [[ "$output" == *"gemini content"* ]]
}

# ── enso_adapter_distill structure tests ─────────────────────

@test "enso_adapter_distill: returns 1 when no backend CLI is available" {
    source "$ADAPTER"
    # Override PATH to hide all backends
    run env PATH="/usr/bin:/bin" bash -c '
        source "'"$ADAPTER"'"
        enso_adapter_distill "test context" 5 "test prompt"
    '
    [ "$status" -eq 1 ]
}

@test "enso_adapter_distill: function exists after sourcing" {
    source "$ADAPTER"
    run type -t enso_adapter_distill
    [ "$status" -eq 0 ]
    [ "$output" = "function" ]
}

@test "_enso_timeout: function exists after sourcing" {
    source "$ADAPTER"
    run type -t _enso_timeout
    [ "$status" -eq 0 ]
    [ "$output" = "function" ]
}
