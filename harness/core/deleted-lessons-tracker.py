"""Enso: Track deleted lessons for recovery safety net.

Usage:
  python3 deleted-lessons-tracker.py log_deletion --text "lesson text" --reason "stale"
  python3 deleted-lessons-tracker.py check_recovery --new-text "new lesson" --threshold 0.6
"""
import json, os, re, sys
from datetime import datetime

DELETED_LOG = os.path.expanduser("~/.enso/lessons/deleted-lessons.jsonl")

def log_deletion(text, reason):
    """Log a deleted lesson for potential recovery."""
    entry = {
        "ts": datetime.utcnow().isoformat() + "Z",
        "text": text,
        "reason": reason
    }
    with open(DELETED_LOG, "a") as f:
        f.write(json.dumps(entry) + "\n")

def check_recovery(new_text, threshold=0.6):
    """Check if a new lesson is similar to a previously deleted one."""
    if not os.path.exists(DELETED_LOG):
        print("NEW")
        return

    stops = {'the','and','for','that','this','with','from','have','will','been',
             'when','before','after','always','instead','using','avoid','use'}
    new_words = set(w for w in re.findall(r'[a-z]{3,}', new_text.lower()) if w not in stops)

    if not new_words:
        print("NEW")
        return

    for line in open(DELETED_LOG):
        try:
            entry = json.loads(line)
            old_words = set(w for w in re.findall(r'[a-z]{3,}', entry["text"].lower()) if w not in stops)
            if old_words and len(new_words & old_words) / len(new_words) >= threshold:
                print(f"RECOVERY:{entry['text'][:80]}")
                return
        except Exception:
            continue

    print("NEW")

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "log_deletion":
        text = ""
        reason = "unknown"
        i = 2
        while i < len(sys.argv):
            if sys.argv[i] == "--text" and i+1 < len(sys.argv):
                text = sys.argv[i+1]; i += 2
            elif sys.argv[i] == "--reason" and i+1 < len(sys.argv):
                reason = sys.argv[i+1]; i += 2
            else:
                i += 1
        if text:
            log_deletion(text, reason)
    elif cmd == "check_recovery":
        new_text = ""
        threshold = 0.6
        i = 2
        while i < len(sys.argv):
            if sys.argv[i] == "--new-text" and i+1 < len(sys.argv):
                new_text = sys.argv[i+1]; i += 2
            elif sys.argv[i] == "--threshold" and i+1 < len(sys.argv):
                threshold = float(sys.argv[i+1]); i += 2
            else:
                i += 1
        if new_text:
            check_recovery(new_text, threshold)
