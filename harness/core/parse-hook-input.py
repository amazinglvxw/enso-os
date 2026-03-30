#!/usr/bin/env python3
"""Enso shared hook input parser.

Reads Claude Code hook JSON from stdin, extracts requested fields,
outputs tab-separated values on a single line.

Usage:
  echo "$INPUT" | python3 parse-hook-input.py tool_name file_path
  # Output: Write\t/path/to/file.py

  echo "$INPUT" | python3 parse-hook-input.py tool_name file_path has_error tool_result duration_ms
  # Output: Bash\t/path\ttrue\tError: not found\t500

Supported fields:
  tool_name   - Name of the tool (Write, Edit, Read, Bash, etc.)
  file_path   - File path from tool_input (probes file_path, path, filename, command)
  has_error   - "true"/"false" based on content substring matching
  tool_result - Truncated tool result content (max 300 chars)
  duration_ms - Execution duration in milliseconds
"""
import json
import sys

ERROR_KEYWORDS = frozenset([
    "error", "failed", "traceback", "exception",
    "denied", "timeout", "refused",
])

FILE_PATH_KEYS = ("file_path", "path", "filename", "command")


def extract(data, field):
    if field == "tool_name":
        return data.get("tool_name", "") or data.get("tool", {}).get("name", "") or "unknown"

    if field == "file_path":
        params = data.get("tool_input", {})
        for key in FILE_PATH_KEYS:
            if key in params:
                return str(params[key])[:200]
        return ""

    if field == "tool_result":
        result = data.get("tool_result", {})
        content = result.get("content", "")
        if isinstance(content, list):
            content = " ".join(r.get("text", "") for r in content if isinstance(r, dict))
        return content[:300].replace("\n", " ").replace("\t", " ").replace('"', "'")

    if field == "has_error":
        result = data.get("tool_result", {})
        content = result.get("content", "")
        if isinstance(content, list):
            content = " ".join(r.get("text", "") for r in content if isinstance(r, dict))
        lower = content.lower()
        return "true" if any(kw in lower for kw in ERROR_KEYWORDS) else "false"

    if field == "duration_ms":
        return str(data.get("duration_ms", 0))

    return ""


def main():
    fields = sys.argv[1:] if len(sys.argv) > 1 else ["tool_name"]
    try:
        data = json.load(sys.stdin)
    except Exception:
        print("\t".join([""] * len(fields)))
        sys.exit(0)

    values = [extract(data, f) for f in fields]
    print("\t".join(values))


if __name__ == "__main__":
    main()
