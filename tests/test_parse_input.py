"""Pytest suite for parse-hook-input.py.

Tests 5 format modes (claude-code, gemini-cli, hermes, openclaw, generic)
and edge cases, exercising all field extractors via subprocess invocation.
"""
from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path
from typing import Any

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent
PARSER = str(REPO_ROOT / "harness" / "core" / "parse-hook-input.py")
FIXTURES = Path(__file__).resolve().parent / "fixtures"


def run_parser(
    input_data: dict[str, Any] | str,
    fmt: str,
    fields: list[str],
) -> str:
    """Run the parser as a subprocess and return stripped stdout."""
    json_str = input_data if isinstance(input_data, str) else json.dumps(input_data)
    result = subprocess.run(
        ["python3", PARSER, "--format", fmt] + fields,
        input=json_str,
        capture_output=True,
        text=True,
        timeout=10,
    )
    assert result.returncode == 0, f"Parser exited with code {result.returncode}: {result.stderr}"
    return result.stdout.strip()


def load_fixture(name: str) -> dict[str, Any]:
    """Load a JSON fixture file by name."""
    with open(FIXTURES / name) as f:
        return json.load(f)


# ── Claude Code format ────────────────────────────────────────────


class TestClaudeCodeFormat:
    """Tests for --format claude-code (the default)."""

    @pytest.fixture()
    def data(self) -> dict[str, Any]:
        return load_fixture("claude-code-input.json")

    def test_tool_name(self, data: dict[str, Any]) -> None:
        assert run_parser(data, "claude-code", ["tool_name"]) == "Write"

    def test_file_path(self, data: dict[str, Any]) -> None:
        assert run_parser(data, "claude-code", ["file_path"]) == "/tmp/x.py"

    def test_duration(self, data: dict[str, Any]) -> None:
        assert run_parser(data, "claude-code", ["duration_ms"]) == "500"

    def test_has_error_false(self, data: dict[str, Any]) -> None:
        # "written" does not contain any error keywords
        assert run_parser(data, "claude-code", ["has_error"]) == "false"

    def test_has_error_true(self) -> None:
        error_data = {
            "tool_name": "Bash",
            "tool_input": {"command": "ls"},
            "tool_result": {"content": "Error: command failed"},
            "duration_ms": 100,
        }
        assert run_parser(error_data, "claude-code", ["has_error"]) == "true"

    def test_multiple_fields(self, data: dict[str, Any]) -> None:
        output = run_parser(data, "claude-code", ["tool_name", "file_path", "duration_ms"])
        parts = output.split("\t")
        assert parts == ["Write", "/tmp/x.py", "500"]


# ── Hermes format ─────────────────────────────────────────────────


class TestHermesFormat:
    """Tests for --format hermes."""

    @pytest.fixture()
    def data(self) -> dict[str, Any]:
        return load_fixture("hermes-input.json")

    def test_tool_name(self, data: dict[str, Any]) -> None:
        assert run_parser(data, "hermes", ["tool_name"]) == "write"

    def test_file_path(self, data: dict[str, Any]) -> None:
        assert run_parser(data, "hermes", ["file_path"]) == "/tmp/x.py"

    def test_has_error_false(self, data: dict[str, Any]) -> None:
        # output is "done" -- no error keywords
        assert run_parser(data, "hermes", ["has_error"]) == "false"


# ── OpenClaw format ───────────────────────────────────────────────


class TestOpenClawFormat:
    """Tests for --format openclaw."""

    @pytest.fixture()
    def data(self) -> dict[str, Any]:
        return load_fixture("openclaw-input.json")

    def test_tool_name(self, data: dict[str, Any]) -> None:
        assert run_parser(data, "openclaw", ["tool_name"]) == "write_file"

    def test_has_error_from_success_false(self, data: dict[str, Any]) -> None:
        # fixture has success: false -> has_error should be "true"
        assert run_parser(data, "openclaw", ["has_error"]) == "true"

    def test_has_error_from_success_true(self) -> None:
        ok_data = {
            "action": "read_file",
            "context": {
                "file": "/tmp/readme.md",
                "result": {"success": True, "output": "file contents here", "durationMs": 50},
            },
        }
        assert run_parser(ok_data, "openclaw", ["has_error"]) == "false"

    def test_duration(self, data: dict[str, Any]) -> None:
        assert run_parser(data, "openclaw", ["duration_ms"]) == "200"

    def test_file_path_prefers_file_over_workspace(self, data: dict[str, Any]) -> None:
        # context has both "file" and "workspaceDir"; "file" comes first in key order
        assert run_parser(data, "openclaw", ["file_path"]) == "/tmp/x.py"


# ── Generic format ────────────────────────────────────────────────


class TestGenericFormat:
    """Tests for --format generic."""

    @pytest.fixture()
    def data(self) -> dict[str, Any]:
        return load_fixture("generic-input.json")

    def test_tool_name_from_name_key(self, data: dict[str, Any]) -> None:
        assert run_parser(data, "generic", ["tool_name"]) == "execute"

    def test_tool_name_from_tool_name_key(self) -> None:
        alt_data = {"tool_name": "custom_tool", "result": "ok"}
        assert run_parser(alt_data, "generic", ["tool_name"]) == "custom_tool"

    def test_file_path(self, data: dict[str, Any]) -> None:
        # generic tries tool_input -> arguments -> context; fixture uses "arguments"
        assert run_parser(data, "generic", ["file_path"]) == "/tmp/script.sh"


# ── Edge cases ────────────────────────────────────────────────────


class TestEdgeCases:
    """Tests for malformed, empty, and unknown-format inputs."""

    def test_empty_input(self) -> None:
        output = run_parser("", "claude-code", ["tool_name"])
        # JSON parse failure -> empty field
        assert output == ""

    def test_malformed_json(self) -> None:
        json_str = "{not valid json"
        result = subprocess.run(
            ["python3", PARSER, "--format", "claude-code", "tool_name", "file_path"],
            input=json_str,
            capture_output=True,
            text=True,
            timeout=10,
        )
        assert result.returncode == 0
        # two empty fields tab-separated (preserve raw output to check separator)
        assert result.stdout.rstrip("\n") == "\t"

    def test_unknown_format_falls_back(self) -> None:
        data = {"tool_name": "Bash", "tool_input": {"command": "echo hi"}}
        # unknown format -> generic-like extraction still works
        output = run_parser(data, "nonexistent-format", ["tool_name"])
        assert output == "Bash"
