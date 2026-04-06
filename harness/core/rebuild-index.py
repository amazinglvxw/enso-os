#!/usr/bin/env python3
"""Enso: Rebuild lessons/INDEX.md from active.md

Generates a one-line-per-lesson index for fast LLM routing.
Called after distillation or cleanup.
"""
import re, os, sys

lessons_file = os.environ.get("ENSO_LESSONS_FILE", os.path.expanduser("~/.enso/lessons/active.md"))
index_file = os.path.join(os.path.dirname(lessons_file), "INDEX.md")

if not os.path.exists(lessons_file):
    sys.exit(0)

lessons = []
with open(lessons_file) as f:
    for line in f:
        if not line.startswith("- "):
            continue
        # Extract date, hits, text
        m = re.match(r"^- \[(\d{4}-\d{2}-\d{2})\] \[hits:(\d+)\] (.+)", line.strip())
        if m:
            date, hits, text = m.group(1), int(m.group(2)), m.group(3)
            # Extract category if present [category] prefix
            cat_m = re.match(r"\[([^\]]+)\] (.+)", text)
            if cat_m:
                category, text = cat_m.group(1), cat_m.group(2)
            else:
                category = "general"
            # First 60 chars as summary
            summary = text[:60] + ("..." if len(text) > 60 else "")
            lessons.append((date, hits, category, summary, text))

# Sort by category then date
lessons.sort(key=lambda x: (x[2], x[0]))

with open(index_file, "w") as f:
    f.write("# Enso Lessons Index\n")
    f.write(f"# {len(lessons)} lessons | Auto-generated, do not edit\n")
    f.write(f"# Full details: active.md\n\n")

    current_cat = None
    for date, hits, cat, summary, full in lessons:
        if cat != current_cat:
            f.write(f"\n## [{cat}]\n")
            current_cat = cat
        hit_marker = f"×{hits}" if hits > 0 else ""
        f.write(f"- {summary} {hit_marker}\n")

print(f"[enso] INDEX.md rebuilt: {len(lessons)} lessons", file=sys.stderr)
