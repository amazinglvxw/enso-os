#!/usr/bin/env python3
"""
pac-analyzer.py — PAC Pattern Detection Engine

Scans execution-log, memory files, and session transcripts for 5 patterns
of self-limiting behavior. Outputs signals classified as constraint_optimal
(don't challenge) or self_limiting (must challenge).

Philosophy: Be a mirror, not a judge.

Usage:
    echo '{"session_text": "..."}' | python3 pac-analyzer.py

Stdlib only. No external deps.
"""
from __future__ import annotations

import json
import os
import re
import sys
from dataclasses import asdict, dataclass, field
from datetime import datetime, timedelta
from enum import Enum
from pathlib import Path
from typing import Any, Callable


# ============================================================================
# Configuration & Enums
# ============================================================================

MEMORY_DIR = Path(
    os.environ.get(
        "ENSO_MEMORY_DIR",
        str(Path.home() / ".claude/projects/-Users-user-Desktop/memory"),
    )
)
PAC_DIR = Path(os.environ.get("ENSO_PAC_DIR", str(Path.home() / ".enso/pac")))
PAC_DIR.mkdir(parents=True, exist_ok=True)

MIN_CONFIDENCE = float(os.environ.get("PAC_CONFIDENCE_THRESHOLD", "0.70"))
LOOKBACK_DAYS = int(os.environ.get("PAC_LOOKBACK_DAYS", "30"))


class Pattern(str, Enum):
    REPETITION = "repetition"
    CLAIM_ACTION_CONFLICT = "claim_action_conflict"
    CAPABILITY_MISMATCH = "capability_mismatch"
    SUNK_COST = "sunk_cost"
    DECISION_NODE = "decision_node"


class Classification(str, Enum):
    SELF_LIMITING = "self_limiting"
    CONSTRAINT_OPTIMAL = "constraint_optimal"
    UNKNOWN = "unknown"


# Self-limiting patterns are NEVER constraint-optimal
SELF_LIMITING_PATTERNS = {
    Pattern.REPETITION,
    Pattern.CLAIM_ACTION_CONFLICT,
    Pattern.CAPABILITY_MISMATCH,
    Pattern.SUNK_COST,
    Pattern.DECISION_NODE,
}


# ============================================================================
# Data Model
# ============================================================================

@dataclass
class Signal:
    pattern: Pattern
    confidence: float
    evidence: dict[str, Any]
    classification: Classification = Classification.UNKNOWN
    summary: str = ""

    def to_json(self) -> dict[str, Any]:
        d = asdict(self)
        d["pattern"] = self.pattern.value
        d["classification"] = self.classification.value
        return d


# ============================================================================
# Pre-compiled Regex (module-level; compiled once at import)
# ============================================================================

START_KEYWORDS = ("启动", "开新", "新业务", "新项目", "新产品",
                  "准备做", "打算做", "开始做", "新开")

DELEGATE_PATTERNS = [
    re.compile(r"让(TeamMemberA|TeamMemberB|TeamMemberC)(?:负责|管|做|处理|接手|扛)"),
    re.compile(r"交给(TeamMemberA|TeamMemberB|TeamMemberC)"),
]

STRATEGIC_KEYWORDS = ("战略", "风险", "供应商备选", "谈判", "合同",
                      "对账", "方向", "决策", "规划", "布局")

ZERO_GROWTH_PATTERNS = [
    re.compile(r"(\S{1,8}?)(\d+)天零增长"),
    re.compile(r"(\S{1,8}?)连续(\d+)天无起色"),
]

DECISION_PATTERNS = [
    (re.compile(r"准备签(\S{0,20}?)合同"), "contract_signing"),
    (re.compile(r"决定投(\S{0,10}?)万"), "investment_commit"),
    (re.compile(r"放弃(\S{1,15})"), "abandonment"),
    (re.compile(r"关闭(\S{1,15}业务)"), "business_closure"),
    (re.compile(r"(\S{1,15})融资"), "fundraising"),
]

BUSINESS_LINE_KEYWORDS: dict[str, tuple[str, ...]] = {
    "ProjectY": ("ProjectY", "SupplierH", "SupplierE", "SupplierF", "SupplierG"),
    "鸡蛋": ("鸡蛋", "SupplierA", "ItemA"),
    "ProjectW": ("ProjectW", "SupplierB", "SupplierD", "SupplierC"),
    "ProjectX": ("ProjectX", "PlatformA", "分销员"),
    "ProjectV": ("ProjectV", "ProjectV", "烤肠", "关东煮"),
    "Enso": ("enso", "Enso", "PAC"),
}

SURVIVAL_LINES = {"ProjectY", "鸡蛋", "ProjectW"}

# Constraint evidence patterns (presence → constraint_optimal, not self-limit)
USER_CONSTRAINT_SIGNALS = (
    "选择稳现金流", "先活下来", "不敢烧钱", "务实路径",
    "不融资", "不All-in", "保底", "合法合规", "风险合规",
)

EXECUTOR_ROLES = {"TeamMemberA"}  # Per user_biography.md: execution-layer strength


# ============================================================================
# Utilities
# ============================================================================

def parse_iso_timestamp(ts: str) -> datetime | None:
    """Parse ISO 8601 with optional Z suffix, return naive datetime."""
    try:
        t = datetime.fromisoformat(ts.replace("Z", "+00:00"))
        return t.replace(tzinfo=None) if t.tzinfo else t
    except (ValueError, AttributeError):
        return None


def read_jsonl(path: Path, days: int = LOOKBACK_DAYS) -> list[dict[str, Any]]:
    """Read JSONL filtered by ts within last N days. Malformed lines skipped."""
    if not path.exists():
        return []
    cutoff = datetime.now() - timedelta(days=days)
    out: list[dict[str, Any]] = []
    try:
        with open(path, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    rec = json.loads(line)
                except json.JSONDecodeError:
                    continue
                t = parse_iso_timestamp(rec.get("ts", ""))
                if t is None or t >= cutoff:
                    out.append(rec)
    except OSError:
        pass
    return out


def read_memory_file(name: str) -> str:
    """Read a memory file; empty string if missing or unreadable."""
    path = MEMORY_DIR / name
    try:
        return path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return ""


def load_session_input() -> dict[str, Any]:
    """Read session info from stdin JSON or env vars."""
    try:
        raw = sys.stdin.read().strip()
        if raw:
            return json.loads(raw)
    except (json.JSONDecodeError, OSError):
        pass
    return {
        "session_id": os.environ.get("CLAUDE_SESSION_ID", ""),
        "session_text": os.environ.get("CLAUDE_SESSION_TEXT", ""),
    }


def _text_of(rec: dict[str, Any]) -> str:
    return f"{rec.get('task', '')} {rec.get('detail', '')}"


# ============================================================================
# Confidence Calculators
# ============================================================================

def _conf_repetition(event_count: int) -> float:
    return min(0.95, 0.50 + 0.08 * event_count)


def _conf_capability_mismatch(count: int) -> float:
    return min(0.90, 0.70 + 0.10 * count)


def _conf_sunk_cost(days: int, action_count: int) -> float:
    return min(0.95, 0.60 + 0.015 * days + 0.05 * action_count)


# ============================================================================
# Pattern Detectors
# ============================================================================

def detect_repetition_pattern(
    execlog: list[dict[str, Any]],
    session_text: str,
) -> list[Signal]:
    """User repeatedly starts new business lines / switches focus."""
    new_events = [r for r in execlog if any(kw in _text_of(r) for kw in START_KEYWORDS)]
    if len(new_events) < 5:
        return []
    return [Signal(
        pattern=Pattern.REPETITION,
        confidence=_conf_repetition(len(new_events)),
        evidence={
            "new_events_count": len(new_events),
            "lookback_days": LOOKBACK_DAYS,
            "sample_events": [
                {"ts": e.get("ts"), "task": e.get("task", "")[:80]}
                for e in new_events[:3]
            ],
        },
        summary=f"过去{LOOKBACK_DAYS}天启动了{len(new_events)}个新事项",
    )]


def detect_claim_action_conflict(
    execlog: list[dict[str, Any]],
    memory: str,
) -> list[Signal]:
    """Stated priorities don't match observed time allocation."""
    if "生存层" not in memory:
        return []

    counts: dict[str, int] = {}
    for rec in execlog:
        text = _text_of(rec).lower()
        for line, kws in BUSINESS_LINE_KEYWORDS.items():
            if any(kw.lower() in text for kw in kws):
                counts[line] = counts.get(line, 0) + 1

    total = sum(counts.values()) or 1
    allocation = {k: v / total for k, v in counts.items()}
    conflicting = [
        (line, pct) for line, pct in allocation.items()
        if line not in SURVIVAL_LINES and pct > 0.35
    ]
    if not conflicting:
        return []

    return [Signal(
        pattern=Pattern.CLAIM_ACTION_CONFLICT,
        confidence=0.75,
        evidence={
            "declared_focus": "生存层(survival layer)",
            "actual_allocation": {k: round(v, 3) for k, v in allocation.items()},
            "conflicting_lines": [(l, round(p, 3)) for l, p in conflicting],
        },
        summary=f"声明聚焦生存层,但{conflicting[0][0]}占{conflicting[0][1]:.0%}精力",
    )]


def detect_capability_mismatch(
    session_text: str,
    biography: str,
) -> list[Signal]:
    """Delegating strategic task to someone not suited for it."""
    mismatch_count = 0
    evidence_quotes: list[dict[str, str]] = []

    for pattern in DELEGATE_PATTERNS:
        for match in pattern.finditer(session_text):
            person = match.group(1)
            if person not in EXECUTOR_ROLES:
                continue
            context = session_text[
                max(0, match.start() - 50) : min(len(session_text), match.end() + 100)
            ]
            if any(kw in context for kw in STRATEGIC_KEYWORDS):
                mismatch_count += 1
                evidence_quotes.append({
                    "person": person,
                    "context": context.strip(),
                })

    if mismatch_count < 1:
        return []

    return [Signal(
        pattern=Pattern.CAPABILITY_MISMATCH,
        confidence=_conf_capability_mismatch(mismatch_count),
        evidence={
            "mismatch_count": mismatch_count,
            "quotes": evidence_quotes[:3],
        },
        summary=f"战略任务委托给{evidence_quotes[0]['person']}(执行层擅长但非战略层)",
    )]


def detect_sunk_cost(
    execlog: list[dict[str, Any]],
    memory: str,
) -> list[Signal]:
    """Continuing investment in low-output business without strategic review."""
    signals: list[Signal] = []
    seen: set[tuple[str, int]] = set()  # dedupe by (business, days)

    for pattern in ZERO_GROWTH_PATTERNS:
        for match in pattern.finditer(memory):
            business = match.group(1).strip()
            days = int(match.group(2))
            if days < 14 or (business, days) in seen:
                continue
            seen.add((business, days))

            active = [
                r for r in execlog
                if business.lower() in _text_of(r).lower()
            ]
            if not active:
                continue
            signals.append(Signal(
                pattern=Pattern.SUNK_COST,
                confidence=_conf_sunk_cost(days, len(active)),
                evidence={
                    "business": business,
                    "zero_growth_days": days,
                    "recent_action_count": len(active),
                    "sample_actions": [a.get("task", "")[:80] for a in active[:3]],
                },
                summary=f"{business}连续{days}天零增长,但仍在加码({len(active)}次近期动作)",
            ))
    return signals


def detect_decision_node(session_text: str) -> list[Signal]:
    """User is about to make a major decision."""
    signals: list[Signal] = []
    for pattern, decision_type in DECISION_PATTERNS:
        for match in pattern.finditer(session_text):
            context = session_text[
                max(0, match.start() - 100) : min(len(session_text), match.end() + 150)
            ]
            signals.append(Signal(
                pattern=Pattern.DECISION_NODE,
                confidence=0.80,
                evidence={
                    "decision_type": decision_type,
                    "matched_text": match.group(0),
                    "context": context.strip(),
                },
                summary=f"重大决策节点: {match.group(0)}",
            ))
    return signals


# Detector registry (easier to extend + test)
DETECTORS: list[Callable[..., list[Signal]]] = [
    lambda execlog, session, memory, bio: detect_repetition_pattern(execlog, session),
    lambda execlog, session, memory, bio: detect_claim_action_conflict(execlog, memory),
    lambda execlog, session, memory, bio: detect_capability_mismatch(session, bio),
    lambda execlog, session, memory, bio: detect_sunk_cost(execlog, memory),
    lambda execlog, session, memory, bio: detect_decision_node(session),
]


# ============================================================================
# Classification
# ============================================================================

def classify_signal(signal: Signal, memory: str) -> Classification:
    """Classify as self_limiting (challenge) or constraint_optimal (skip).

    Safer default: when uncertain, lean toward SELF_LIMITING.
    This is better than silently skipping something that needs attention.
    """
    if signal.pattern in SELF_LIMITING_PATTERNS:
        return Classification.SELF_LIMITING

    # Only mark constraint_optimal when explicit constraint evidence exists
    evidence_str = str(signal.evidence)
    for kw in USER_CONSTRAINT_SIGNALS:
        if kw in evidence_str or kw in memory:
            return Classification.CONSTRAINT_OPTIMAL

    # Fallback: challenge rather than miss
    return Classification.SELF_LIMITING


# ============================================================================
# Main
# ============================================================================

def analyze() -> list[dict[str, Any]]:
    execlog = read_jsonl(MEMORY_DIR / "execution-log.jsonl", days=LOOKBACK_DAYS)
    memory = read_memory_file("MEMORY.md")
    biography = read_memory_file("user_biography.md")
    session = load_session_input()
    session_text = session.get("session_text", "")

    all_signals: list[Signal] = []
    for detector in DETECTORS:
        all_signals.extend(detector(execlog, session_text, memory, biography))

    for s in all_signals:
        s.classification = classify_signal(s, memory)

    actionable = sorted(
        (s for s in all_signals
         if s.classification == Classification.SELF_LIMITING
         and s.confidence >= MIN_CONFIDENCE),
        key=lambda s: s.confidence,
        reverse=True,
    )
    return [s.to_json() for s in actionable]


def main() -> None:
    print(json.dumps(analyze(), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
