#!/usr/bin/env python3
"""Enso DIKW shared utilities. Pure stdlib, zero external deps.
CLI subcommands: semantic_dedup | categorize | update_utility |
                 merge_to_knowledge | prune_stale | sync_active_md
"""
import argparse, json, math, os, re, sys, uuid
from collections import Counter
from datetime import datetime, timedelta

# ── TF-IDF cosine similarity (stdlib only) ──────────────────────

STOPS = frozenset(
    "the and for that this with from have will been when before after "
    "always instead using avoid use are not can should".split()
)

def stem(word):
    """Minimal suffix stripping for better matching."""
    for suffix in ("ation", "tion", "ing", "ness", "ment", "ence", "ance",
                   "ity", "ous", "ive", "ful", "less", "able", "ible",
                   "ly", "es", "ed", "er", "al", "s"):
        if word.endswith(suffix) and len(word) - len(suffix) >= 4:
            return word[:-len(suffix)]
    return word

def tokenize(text):
    return [stem(w) for w in re.findall(r"[a-z]{3,}", text.lower()) if w not in STOPS]

def tfidf_cosine(text_a, text_b):
    wa, wb = tokenize(text_a), tokenize(text_b)
    if not wa or not wb:
        return 0.0
    ca, cb = Counter(wa), Counter(wb)
    vocab = set(ca) | set(cb)
    dot = sum(ca.get(w, 0) * cb.get(w, 0) for w in vocab)
    na = math.sqrt(sum(v * v for v in ca.values()))
    nb = math.sqrt(sum(v * v for v in cb.values()))
    return dot / (na * nb) if na and nb else 0.0

# ── Category taxonomy ───────────────────────────────────────────

TAXONOMY = {
    "browser-dom-safety": ["dom", "element", "null", "browser", "click",
                           "selector", "queryselector", "contenteditable",
                           "renderer", "cdp", "playwright"],
    "timeout-recovery":   ["timeout", "freeze", "hung", "unresponsive",
                           "watchdog", "retry", "backoff", "stall"],
    "file-io":            ["file", "read", "write", "offset", "limit",
                           "path", "directory", "token", "overflow"],
    "cli-safety":         ["command", "bash", "shell", "xargs", "pipe",
                           "argument", "flag"],
    "git-ops":            ["git", "commit", "branch", "merge", "push",
                           "rebase", "stash"],
    "api-usage":          ["api", "request", "response", "endpoint",
                           "header", "auth", "oauth", "rate"],
    "memory-mgmt":        ["memory", "compact", "context", "token",
                           "budget", "cache"],
    "mcp-tools":          ["mcp", "server", "tool", "plugin", "resource"],
    "testing":            ["test", "assert", "mock", "fixture", "coverage"],
    "security":           ["secret", "key", "password", "inject",
                           "sanitize", "permission"],
}

def categorize_text(text):
    words = set(tokenize(text))
    best, best_score = "uncategorized", 0
    for cat, keywords in TAXONOMY.items():
        score = len(words & set(keywords))
        if score > best_score:
            best, best_score = cat, score
    return best

# ── File I/O helpers ────────────────────────────────────────────

def read_jsonl(path):
    if not os.path.exists(path):
        return []
    entries = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if line:
                try:
                    entries.append(json.loads(line))
                except json.JSONDecodeError:
                    pass
    return entries

def write_jsonl(path, entries):
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        for e in entries:
            f.write(json.dumps(e, ensure_ascii=False) + "\n")
    os.replace(tmp, path)

def read_lessons(path):
    if not os.path.exists(path):
        return [], []
    with open(path) as f:
        lines = f.readlines()
    header = [l for l in lines if not l.startswith("- ")]
    lessons = [l for l in lines if l.startswith("- ")]
    return header, lessons

def write_lessons(path, header, lessons):
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        f.writelines(header)
        f.writelines(lessons)
    os.replace(tmp, path)

def extract_lesson_text(line):
    """Strip date/hits prefix from lesson line."""
    return re.sub(r"^- \[\d{4}-\d{2}-\d{2}\]\s*\[hits:\d+\]\s*", "", line.strip())

# ── Subcommands ─────────────────────────────────────────────────

def cmd_semantic_dedup(args):
    new = args.new_text
    thresh = args.threshold
    if os.path.exists(args.existing_file):
        with open(args.existing_file) as f:
            for line in f:
                if line.startswith("- "):
                    old = extract_lesson_text(line)
                    if tfidf_cosine(new, old) >= thresh:
                        print("DUP")
                        return
    for e in read_jsonl(args.info_file):
        if e.get("status") == "active" and tfidf_cosine(new, e.get("text", "")) >= thresh:
            print("DUP")
            return
    print("NEW")

def cmd_categorize(args):
    print(categorize_text(args.text))

def cmd_update_utility(args):
    if not os.path.exists(args.loaded_ids_file):
        return
    loaded_ids = set(open(args.loaded_ids_file).read().strip().split(","))
    loaded_ids.discard("")
    if not loaded_ids:
        return
    cat_errors = Counter()
    for e in read_jsonl(args.trace_file):
        if e.get("has_error") == "true":
            target = e.get("target", "")
            cat = categorize_text(target)
            cat_errors[cat] += 1
    entries = read_jsonl(args.info_file)
    id_to_entry = {e["id"]: e for e in entries}
    updated_ids = set()
    for eid in loaded_ids:
        if eid not in id_to_entry:
            continue
        entry = id_to_entry[eid]
        if entry.get("status") != "active":
            continue
        cat = entry.get("category", "")
        if cat_errors.get(cat, 0) > 0:
            entry["miss_streak"] = entry.get("miss_streak", 0) + 1
        else:
            entry["hits"] = entry.get("hits", 0) + 1
            entry["miss_streak"] = 0
        updated_ids.add(eid)
    write_jsonl(args.info_file, entries)
    if os.path.exists(args.lessons_file):
        header, lessons = read_lessons(args.lessons_file)
        updated_entries = [e for e in entries if e["id"] in updated_ids]
        for i, line in enumerate(lessons):
            text = extract_lesson_text(line)
            for entry in updated_entries:
                if tfidf_cosine(text, entry.get("text", "")) >= 0.7:
                    h = entry.get("hits", 0)
                    lessons[i] = re.sub(r"\[hits:\d+\]", f"[hits:{h}]", line)
                    break
        write_lessons(args.lessons_file, header, lessons)

def cmd_merge_to_knowledge(args):
    entries = read_jsonl(args.info_file)
    knowledge = json.load(open(args.knowledge_file)) if os.path.exists(args.knowledge_file) else []
    kid = f"k-{args.category}-{uuid.uuid4().hex[:6]}"
    source_ids = [e["id"] for e in entries
                   if e.get("category") == args.category and e.get("status") == "active"]
    if not source_ids:
        return
    source_set = set(source_ids)
    entries = [{**e, "status": f"merged_to:{kid}"} if e["id"] in source_set else e
               for e in entries]
    knowledge.append({
        "id": kid,
        "category": args.category,
        "rule": args.merged_text,
        "source_info_ids": source_ids,
        "confidence": 0.8,
        "created": datetime.now().strftime("%Y-%m-%d"),
        "verified": False,
        "hits": 0,
        "miss_streak": 0,
        "status": "active",
    })
    write_jsonl(args.info_file, entries)
    tmp = args.knowledge_file + ".tmp"
    with open(tmp, "w") as f:
        json.dump(knowledge, f, ensure_ascii=False, indent=2)
    os.replace(tmp, args.knowledge_file)
    print(kid)

def cmd_prune_stale(args):
    entries = read_jsonl(args.info_file)
    now = datetime.now()
    kept = []
    pruned_texts = []
    for e in entries:
        if e.get("status") != "active":
            kept.append(e)
            continue
        age = (now - datetime.fromisoformat(e["ts"].replace("Z", "+00:00")).replace(tzinfo=None)).days
        if e.get("miss_streak", 0) >= args.max_miss:
            pruned_texts.append(e.get("text", ""))
            continue
        if age > args.max_age_days and e.get("hits", 0) == 0:
            pruned_texts.append(e.get("text", ""))
            continue
        kept.append(e)
    write_jsonl(args.info_file, kept)
    if pruned_texts and os.path.exists(args.lessons_file):
        header, lessons = read_lessons(args.lessons_file)
        new_lessons = []
        for line in lessons:
            text = extract_lesson_text(line)
            should_remove = any(tfidf_cosine(text, pt) >= 0.7 for pt in pruned_texts)
            if not should_remove:
                new_lessons.append(line)
        write_lessons(args.lessons_file, header, new_lessons)
    if pruned_texts:
        print(f"Pruned {len(pruned_texts)} entries", file=sys.stderr)


def cmd_append_info(args):
    """Atomically append a new I-layer entry."""
    entry = {
        "id": f"i-{args.ts[:10]}-{uuid.uuid4().hex[:6]}",
        "ts": args.ts,
        "text": args.text,
        "category": args.category,
        "source_errors": args.source_errors,
        "hits": 0, "miss_streak": 0, "status": "active"
    }
    entries = read_jsonl(args.info_file)
    entries.append(entry)
    write_jsonl(args.info_file, entries)
    print(entry["id"])

def cmd_sync_active_md(args):
    entries = read_jsonl(args.info_file)
    if not os.path.exists(args.lessons_file):
        return
    header, lessons = read_lessons(args.lessons_file)
    for i, line in enumerate(lessons):
        text = extract_lesson_text(line)
        for e in entries:
            if tfidf_cosine(text, e.get("text", "")) >= 0.7:
                h = e.get("hits", 0)
                lessons[i] = re.sub(r"\[hits:\d+\]", f"[hits:{h}]", line)
                if "merged_to" in str(e.get("status", "")) and "[merged]" not in line:
                    lessons[i] = lessons[i].rstrip() + " [merged]\n"
                break
    write_lessons(args.lessons_file, header, lessons)

# ── CLI ─────────────────────────────────────────────────────────

def main():
    p = argparse.ArgumentParser(prog="dikw-utils")
    sub = p.add_subparsers(dest="cmd")

    s1 = sub.add_parser("semantic_dedup")
    s1.add_argument("--new-text", required=True)
    s1.add_argument("--existing-file", required=True)
    s1.add_argument("--info-file", required=True)
    s1.add_argument("--threshold", type=float, default=0.7)

    s2 = sub.add_parser("categorize")
    s2.add_argument("--text", required=True)

    s3 = sub.add_parser("update_utility")
    s3.add_argument("--loaded-ids-file", required=True)
    s3.add_argument("--trace-file", required=True)
    s3.add_argument("--info-file", required=True)
    s3.add_argument("--lessons-file", required=True)

    s4 = sub.add_parser("merge_to_knowledge")
    s4.add_argument("--info-file", required=True)
    s4.add_argument("--knowledge-file", required=True)
    s4.add_argument("--category", required=True)
    s4.add_argument("--merged-text", required=True)

    s5 = sub.add_parser("prune_stale")
    s5.add_argument("--info-file", required=True)
    s5.add_argument("--lessons-file", required=True)
    s5.add_argument("--max-miss", type=int, default=5)
    s5.add_argument("--max-age-days", type=int, default=60)

    s7 = sub.add_parser("append_info")
    s7.add_argument("--info-file", required=True)
    s7.add_argument("--text", required=True)
    s7.add_argument("--category", required=True)
    s7.add_argument("--ts", required=True)
    s7.add_argument("--source-errors", type=int, required=True)

    s6 = sub.add_parser("sync_active_md")
    s6.add_argument("--info-file", required=True)
    s6.add_argument("--lessons-file", required=True)

    args = p.parse_args()
    cmds = {
        "semantic_dedup": cmd_semantic_dedup,
        "categorize": cmd_categorize,
        "update_utility": cmd_update_utility,
        "merge_to_knowledge": cmd_merge_to_knowledge,
        "prune_stale": cmd_prune_stale,
        "append_info": cmd_append_info,
        "sync_active_md": cmd_sync_active_md,
    }
    if args.cmd in cmds:
        cmds[args.cmd](args)
    else:
        p.print_help()
        sys.exit(1)

if __name__ == "__main__":
    main()
