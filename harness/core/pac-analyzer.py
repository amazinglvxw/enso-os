#!/usr/bin/env python3
"""
pac-analyzer.py — PAC Pattern Detection Engine

Scans execution-log, memory files, and session transcripts for 5 patterns
of self-limiting behavior. Outputs signals classified as constraint_optimal
(don't challenge) or self_limiting (must challenge).

Philosophy: Be a mirror, not a judge.

Business/role lexicon is user-specific and loaded from:
  ~/.enso/pac/config.json       (user-owned, gitignored)
  $ENSO_PAC_CONFIG              (env override)

Ship with a generic example schema; users fill in their own domain terms.

Usage:
    echo '{"session_text": "..."}' | python3 pac-analyzer.py

Stdlib only. No external deps.
"""
from __future__ import annotations

import json
import os
import re
import sys
from dataclasses import asdict, dataclass
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
        str(Path.home() / ".claude/projects/default/memory"),
    )
)
PAC_DIR = Path(os.environ.get("ENSO_PAC_DIR", str(Path.home() / ".enso/pac")))
PAC_DIR.mkdir(parents=True, exist_ok=True)

MIN_CONFIDENCE = float(os.environ.get("PAC_CONFIDENCE_THRESHOLD", "0.70"))
LOOKBACK_DAYS = int(os.environ.get("PAC_LOOKBACK_DAYS", "30"))

CONFIG_PATH = Path(
    os.environ.get("ENSO_PAC_CONFIG", str(PAC_DIR / "config.json"))
)


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


SELF_LIMITING_PATTERNS = {
    Pattern.REPETITION,
    Pattern.CLAIM_ACTION_CONFLICT,
    Pattern.CAPABILITY_MISMATCH,
    Pattern.SUNK_COST,
    Pattern.DECISION_NODE,
}


# ============================================================================
# User Config (loaded from ~/.enso/pac/config.json, never committed)
# ============================================================================

@dataclass(frozen=True)
class PacConfig:
    """User-specific lexicon. Generic defaults ship; users override locally."""
    start_keywords: tuple[str, ...]
    delegate_regexes: tuple[re.Pattern, ...]
    strategic_keywords: tuple[str, ...]
    zero_growth_regexes: tuple[re.Pattern, ...]
    decision_patterns: tuple[tuple[re.Pattern, str], ...]
    business_lines: dict[str, tuple[str, ...]]
    survival_lines: frozenset[str]
    constraint_signals: tuple[str, ...]
    executor_roles: frozenset[str]
    claim_focus_marker: str


_DEFAULT_CONFIG = PacConfig(
    start_keywords=(
        "start new", "new line", "new project", "new product",
        "launch", "kickoff", "spinning up",
    ),
    delegate_regexes=(
        re.compile(r"(?:delegating|handing|giving) (?:to|over) (\w+)", re.I),
        re.compile(r"(\w+) (?:will handle|is handling|takes over)", re.I),
    ),
    strategic_keywords=(
        "strategy", "risk", "negotiation", "contract",
        "direction", "decision", "roadmap", "planning",
    ),
    zero_growth_regexes=(
        re.compile(
            r"([A-Za-z0-9_]{1,20})\s*:?\s*(\d+)\s*days?\s*(?:of\s*)?zero\s*growth",
            re.I,
        ),
    ),
    decision_patterns=(
        (re.compile(r"about to sign", re.I), "contract_signing"),
        (re.compile(r"committing \$?(\d+)[kKmM]?", re.I), "investment_commit"),
        (re.compile(r"(?:shutting down|closing) (\S+)", re.I), "business_closure"),
        (re.compile(r"(?:fundrais|raise) (?:round|capital)", re.I), "fundraising"),
    ),
    business_lines={},
    survival_lines=frozenset(),
    constraint_signals=(
        "stable cashflow chosen", "no runway for risk", "staying lean",
        "family obligations", "compliance first",
    ),
    executor_roles=frozenset(),
    claim_focus_marker="survival layer",
)


def _compile_regexes(patterns: list, flags: int = 0) -> tuple:
    compiled = []
    for p in patterns:
        try:
            compiled.append(re.compile(p, flags))
        except re.error:
            continue
    return tuple(compiled)


def load_config() -> PacConfig:
    """Load user-specific lexicon; fall back to generic English defaults."""
    if not CONFIG_PATH.exists():
        return _DEFAULT_CONFIG
    try:
        raw = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return _DEFAULT_CONFIG

    flags = re.IGNORECASE if raw.get("case_insensitive", True) else 0

    decision_compiled = []
    for item in raw.get("decision_patterns", []):
        if isinstance(item, dict) and "regex" in item and "type" in item:
            try:
                decision_compiled.append(
                    (re.compile(item["regex"], flags), str(item["type"]))
                )
            except re.error:
                continue

    business_lines_raw = raw.get("business_lines", {})
    business_lines = {
        str(k): tuple(str(x) for x in v)
        for k, v in business_lines_raw.items()
        if isinstance(v, (list, tuple))
    }

    return PacConfig(
        start_keywords=tuple(raw.get("start_keywords", _DEFAULT_CONFIG.start_keywords)),
        delegate_regexes=_compile_regexes(
            raw.get("delegate_regexes", []), flags
        ) or _DEFAULT_CONFIG.delegate_regexes,
        strategic_keywords=tuple(
            raw.get("strategic_keywords", _DEFAULT_CONFIG.strategic_keywords)
        ),
        zero_growth_regexes=_compile_regexes(
            raw.get("zero_growth_regexes", []), flags
        ) or _DEFAULT_CONFIG.zero_growth_regexes,
        decision_patterns=tuple(decision_compiled) or _DEFAULT_CONFIG.decision_patterns,
        business_lines=business_lines,
        survival_lines=frozenset(raw.get("survival_lines", [])),
        constraint_signals=tuple(
            raw.get("constraint_signals", _DEFAULT_CONFIG.constraint_signals)
        ),
        executor_roles=frozenset(raw.get("executor_roles", [])),
        claim_focus_marker=str(
            raw.get("claim_focus_marker", _DEFAULT_CONFIG.claim_focus_marker)
        ),
    )


# ============================================================================
# Data Model
# ============================================================================

@dataclass
class Signal:
    pattern: Pattern
    confidence: float
    evidence: dict
    classification: Classification = Classification.UNKNOWN
    summary: str = ""

    def to_json(self) -> dict:
        d = asdict(self)
        d["pattern"] = self.pattern.value
        d["classification"] = self.classification.value
        return d


# ============================================================================
# Utilities
# ============================================================================

def parse_iso_timestamp(ts: str):
    try:
        t = datetime.fromisoformat(ts.replace("Z", "+00:00"))
        return t.replace(tzinfo=None) if t.tzinfo else t
    except (ValueError, AttributeError):
        return None


def read_jsonl(path: Path, days: int = LOOKBACK_DAYS) -> list:
    if not path.exists():
        return []
    cutoff = datetime.now() - timedelta(days=days)
    out = []
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
    path = MEMORY_DIR / name
    try:
        return path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return ""


def load_session_input() -> dict:
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


def _text_of(rec: dict) -> str:
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
    execlog: list, session_text: str, config: PacConfig
) -> list:
    new_events = [
        r for r in execlog
        if any(kw.lower() in _text_of(r).lower() for kw in config.start_keywords)
    ]
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
        summary=f"Started {len(new_events)} new items in the past {LOOKBACK_DAYS} days",
    )]


def detect_claim_action_conflict(
    execlog: list, memory: str, config: PacConfig
) -> list:
    if not config.business_lines or not config.survival_lines:
        return []
    if config.claim_focus_marker.lower() not in memory.lower():
        return []

    counts = {}
    for rec in execlog:
        text = _text_of(rec).lower()
        for line, kws in config.business_lines.items():
            if any(kw.lower() in text for kw in kws):
                counts[line] = counts.get(line, 0) + 1

    total = sum(counts.values()) or 1
    allocation = {k: v / total for k, v in counts.items()}
    conflicting = [
        (line, pct) for line, pct in allocation.items()
        if line not in config.survival_lines and pct > 0.35
    ]
    if not conflicting:
        return []

    return [Signal(
        pattern=Pattern.CLAIM_ACTION_CONFLICT,
        confidence=0.75,
        evidence={
            "declared_focus": config.claim_focus_marker,
            "actual_allocation": {k: round(v, 3) for k, v in allocation.items()},
            "conflicting_lines": [(l, round(p, 3)) for l, p in conflicting],
        },
        summary=(
            f"Declared focus on {config.claim_focus_marker}, but "
            f"{conflicting[0][0]} absorbs {conflicting[0][1]:.0%}"
        ),
    )]


def detect_capability_mismatch(
    session_text: str, biography: str, config: PacConfig
) -> list:
    if not config.executor_roles:
        return []

    mismatch_count = 0
    evidence_quotes = []

    for pattern in config.delegate_regexes:
        for match in pattern.finditer(session_text):
            if not match.groups():
                continue
            person = match.group(1)
            if person not in config.executor_roles:
                continue
            context = session_text[
                max(0, match.start() - 50) : min(len(session_text), match.end() + 100)
            ]
            if any(kw.lower() in context.lower() for kw in config.strategic_keywords):
                mismatch_count += 1
                evidence_quotes.append({"person": person, "context": context.strip()})

    if mismatch_count < 1:
        return []

    return [Signal(
        pattern=Pattern.CAPABILITY_MISMATCH,
        confidence=_conf_capability_mismatch(mismatch_count),
        evidence={"mismatch_count": mismatch_count, "quotes": evidence_quotes[:3]},
        summary=(
            f"Strategic task delegated to {evidence_quotes[0]['person']} "
            f"(configured as executor-layer, not strategic)"
        ),
    )]


def detect_sunk_cost(
    execlog: list, memory: str, config: PacConfig
) -> list:
    signals = []
    seen = set()

    for pattern in config.zero_growth_regexes:
        for match in pattern.finditer(memory):
            groups = match.groups()
            if len(groups) < 2:
                continue
            line = str(groups[0]).strip()
            try:
                days = int(groups[1])
            except (TypeError, ValueError):
                continue
            if days < 14 or (line, days) in seen:
                continue
            seen.add((line, days))

            active = [
                r for r in execlog
                if line.lower() in _text_of(r).lower()
            ]
            if not active:
                continue
            signals.append(Signal(
                pattern=Pattern.SUNK_COST,
                confidence=_conf_sunk_cost(days, len(active)),
                evidence={
                    "line": line,
                    "zero_growth_days": days,
                    "recent_action_count": len(active),
                    "sample_actions": [a.get("task", "")[:80] for a in active[:3]],
                },
                summary=(
                    f"{line} at {days} days zero growth but still receiving "
                    f"{len(active)} recent tactical actions"
                ),
            ))
    return signals


def detect_decision_node(session_text: str, config: PacConfig) -> list:
    signals = []
    for pattern, decision_type in config.decision_patterns:
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
                summary=f"Major decision node: {match.group(0)}",
            ))
    return signals


DETECTORS: list = [
    lambda execlog, session, memory, bio, cfg: detect_repetition_pattern(execlog, session, cfg),
    lambda execlog, session, memory, bio, cfg: detect_claim_action_conflict(execlog, memory, cfg),
    lambda execlog, session, memory, bio, cfg: detect_capability_mismatch(session, bio, cfg),
    lambda execlog, session, memory, bio, cfg: detect_sunk_cost(execlog, memory, cfg),
    lambda execlog, session, memory, bio, cfg: detect_decision_node(session, cfg),
]


# ============================================================================
# Classification
# ============================================================================

def classify_signal(signal: Signal, memory: str, config: PacConfig) -> Classification:
    evidence_str = str(signal.evidence)
    for kw in config.constraint_signals:
        if kw.lower() in evidence_str.lower() or kw.lower() in memory.lower():
            return Classification.CONSTRAINT_OPTIMAL
    if signal.pattern in SELF_LIMITING_PATTERNS:
        return Classification.SELF_LIMITING
    return Classification.SELF_LIMITING


# ============================================================================
# Main
# ============================================================================

def analyze() -> list:
    config = load_config()
    execlog = read_jsonl(MEMORY_DIR / "execution-log.jsonl", days=LOOKBACK_DAYS)
    memory = read_memory_file("MEMORY.md")
    biography = read_memory_file("user_biography.md")
    session = load_session_input()
    session_text = session.get("session_text", "")

    all_signals = []
    for detector in DETECTORS:
        all_signals.extend(detector(execlog, session_text, memory, biography, config))

    for s in all_signals:
        s.classification = classify_signal(s, memory, config)

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
