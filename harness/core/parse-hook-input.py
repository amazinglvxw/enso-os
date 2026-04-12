#!/usr/bin/env python3
"""Enso shared hook input parser.

Reads hook JSON from stdin, extracts requested fields,
outputs tab-separated values on a single line.

Supports multiple frameworks via --format flag:
  claude-code (default), gemini-cli, hermes, openclaw, generic

Usage:
  echo "$INPUT" | python3 parse-hook-input.py --format claude-code tool_name file_path
"""
import json
import sys

ERROR_KEYWORDS = frozenset([
    "error", "failed", "traceback", "exception",
    "denied", "timeout", "refused",
])

FILE_PATH_KEYS = ("file_path", "path", "filename", "command")


_SENTINEL = object()

def _get_nested(d, *keys, default=""):
    """Safely traverse nested dicts. Preserves falsy values (False, 0, '')."""
    for key in keys:
        if isinstance(d, dict):
            d = d.get(key, _SENTINEL)
            if d is _SENTINEL:
                return default
        else:
            return default
    return default if d is _SENTINEL or (isinstance(d, dict) and not d) else d


def _detect_error(content):
    """Check if content contains error keywords."""
    lower = str(content).lower()
    return "true" if any(kw in lower for kw in ERROR_KEYWORDS) else "false"


def _extract_content(data, fmt):
    """Extract tool result content based on format."""
    if fmt in ("claude-code", "gemini-cli"):
        result = data.get("tool_result", {})
        content = result.get("content", "")
        if isinstance(content, list):
            content = " ".join(r.get("text", "") for r in content if isinstance(r, dict))
        return content
    if fmt == "openclaw":
        return str(_get_nested(data, "context", "result", "output", default=""))
    if fmt == "hermes":
        return str(data.get("output", data.get("result", "")))
    # generic: try all known paths
    for path in [("tool_result", "content"), ("context", "result", "output"), ("output",), ("result",)]:
        val = _get_nested(data, *path)
        if val:
            return str(val)
    return ""


# ── Format-aware field extraction ────────────────────────────────

def extract(data, field, fmt="claude-code"):
    if field == "tool_name":
        if fmt in ("claude-code", "gemini-cli"):
            return data.get("tool_name", "") or _get_nested(data, "tool", "name") or "unknown"
        if fmt == "hermes":
            return _get_nested(data, "tool", "name") or data.get("name", "unknown")
        if fmt == "openclaw":
            return data.get("action", "") or _get_nested(data, "context", "toolCallId") or "unknown"
        # generic: try everything
        for key in ["tool_name", "name", "action"]:
            if data.get(key):
                return str(data[key])
        return _get_nested(data, "tool", "name") or "unknown"

    if field == "file_path":
        if fmt in ("claude-code", "gemini-cli"):
            params = data.get("tool_input", {})
        elif fmt == "hermes":
            params = data.get("arguments", {})
        elif fmt == "openclaw":
            params = _get_nested(data, "context") or {}
        else:
            params = data.get("tool_input", data.get("arguments", data.get("context", {})))
        if isinstance(params, dict):
            for key in ("file", "target") + FILE_PATH_KEYS + ("workspaceDir",):
                if key in params:
                    return str(params[key])[:200]
        return ""

    if field == "tool_result":
        content = _extract_content(data, fmt)
        return str(content)[:300].replace("\n", " ").replace("\t", " ").replace('"', "'")

    if field == "has_error":
        if fmt == "openclaw":
            success = _get_nested(data, "context", "result", "success", default=True)
            if success is False:
                return "true"
        content = _extract_content(data, fmt)
        return _detect_error(content)

    if field == "duration_ms":
        if fmt == "openclaw":
            return str(_get_nested(data, "context", "result", "durationMs", default=0))
        return str(data.get("duration_ms", 0))

    return ""


def main():
    # Parse --format flag, rest are field names
    fmt = "claude-code"
    fields = []
    args = sys.argv[1:]
    i = 0
    while i < len(args):
        if args[i] == "--format" and i + 1 < len(args):
            fmt = args[i + 1]
            i += 2
        else:
            fields.append(args[i])
            i += 1
    if not fields:
        fields = ["tool_name"]

    try:
        data = json.load(sys.stdin)
    except Exception:
        print("\t".join([""] * len(fields)))
        sys.exit(0)

    values = [extract(data, f, fmt) for f in fields]
    print("\t".join(values))


if __name__ == "__main__":
    main()
