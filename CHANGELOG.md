# Changelog

All notable changes to Enso will be documented in this file.

Format: [Semantic Versioning](https://semver.org/) — MAJOR.MINOR.PATCH
- MAJOR: Breaking changes to hook interface or install process
- MINOR: New features, new hooks, new mechanisms
- PATCH: Bug fixes, docs updates, performance improvements

## [0.7.1] — 2026-04-24

### Fixed — PAC Silent-Killer Bug

Critical bug: every PAC challenge was being silently classified as
`constraint_optimal` and filtered out, because `classify_signal()` scanned
the entire MEMORY.md for constraint keywords without locality. If the user's
profile mentioned any constraint term anywhere (e.g. "economic downturn" in
their biography), **every unrelated signal got silenced**.

This was discovered during systematic debugging when a user reported PAC had
never raised a single challenge in two days of use. The detection pipeline
itself worked perfectly — all 5 patterns fired at 0.75–0.95 confidence — but
100% of them hit the false-positive constraint filter.

### Changed
- **`harness/core/pac-analyzer.py::classify_signal`** — constraint signals
  now require **locality**: either
  (a) the keyword appears inside the current signal's evidence, or
  (b) the keyword appears within 120 chars of the signal's subject
      (business-line / person name) in MEMORY.md
  Before: any constraint term anywhere in MEMORY.md silenced every challenge.
  After: constraint must apply to *this decision*, not the user's life backdrop.

### Upgrade
```bash
cd enso-os && git pull && bash install.sh
```

No config changes required. Existing `~/.enso/pac/config.json` keeps working,
but users are encouraged to narrow `constraint_signals` to decision-scoped
phrases ("此决策受限", "因资金约束选择") rather than lifestyle descriptors
("经济下行", "现金底薄").

---

## [0.7.0] — 2026-04-21

### The Mirror Release — AI That Speaks First

Every mainstream LLM is **query-response**. You ask, AI answers. Enso v0.7.0 adds the missing half: **observation-initiated dialogue**. The AI now raises the issue *you* haven't asked about — with anti-fatigue rate limits and a sharp distinction between real constraints (don't challenge) and self-limiting patterns (must challenge).

> "PAC is not a judge. It's a mirror."

### Added — PAC (Proactive Accountability Challenge) v0.1
- **`harness/core/pac-analyzer.py`** — Pattern detection engine that scans `execution-log.jsonl`, `MEMORY.md`, and session transcripts for 5 categories of self-limiting behavior: repetition (starting new without finishing old), claim-action conflict (say X do Y), capability-task mismatch (delegating strategy to executors), sunk cost (investing in zero-growth business), and critical decision nodes. Critically distinguishes **constraint-optimal** choices (don't challenge) from **self-limiting** choices (must challenge). Stdlib-only, no external deps.
- **`harness/core/pac-question-generator.py`** — Socratic challenge generator enforcing 5 quality rules: (1) based on observation not generic wisdom, (2) points to structure not instance, (3) challenges premise not options, (4) time dimension, (5) no answer given. Uses adapter LLM fallback chain (claude → llm) with template-based fallback for offline operation.
- **`harness/hooks/stop/pac-challenge-trigger.sh`** — Stop hook that runs analyzer → generator on each session end. Enforces rate limits: max 1 per 24h, 3 per week, 7-day same-pattern silence, 1-month cooldown after 3 rejections. Writes pending challenges to `~/.enso/pac/pending/` for next session injection.
- **`harness/hooks/session-start/pac-pending-check.sh`** — SessionStart hook that injects the latest unanswered pending PAC challenge into Claude's context as `<enso-pac-pending>` XML block. User is given 3 options: answer now, defer 3 days, or dismiss.
- **`docs/PAC_SPEC.md`** — Complete product specification: problem statement, 5 detection patterns, quality standards, frequency limits, architecture diagram, effectiveness KPIs, graduation path, philosophy, privacy.
- **Philosophy**: "PAC is not a judge. It's a mirror." Goal: let the user see themselves clearly. Once a month, PAC should ask a question that makes the user pause silent for 30 seconds. That silence is where growth begins.

### Added
- **`examples/scripts/execlog-guard.sh`** (Stop hook, v3.1) — execution-log.jsonl two-layer safety net: (1) enforces per-session log write via PostToolUse tracking + mtime fallback with `REMINDED_FLAG` anti-deadlock; (2) **tail JSON integrity check** — parses last 3 lines on every Stop, emits stderr warning if malformed (soft-fail, not blocking). Caught in production: concurrent appends from two sub-2-second Bash writes corrupting a single physical line. Paired with `business-closure-guard.sh` as the log-write enforcement layer.

### Changed
- **Examples now use `ENSO_MEMORY_DIR` env var** — `examples/hooks/stop/business-closure-guard.sh`, `examples/scripts/execlog-guard.sh`, `examples/scripts/health-check-with-breaker.sh` previously hard-coded the author's local project slug. They now read `${ENSO_MEMORY_DIR:-$HOME/.claude/projects/<YOUR-PROJECT>/memory}` so users can either `export ENSO_MEMORY_DIR=...` or replace the placeholder in-place.

## [0.6.0] — 2026-04-13

### Audit-Driven Examples Release

Born from a triple-AI health audit (Gemini ×2 + Codex) that scored the system 2.8/10 on value delivery. These examples demonstrate the fixes.

### Added
- **`examples/` directory** — production-tested hook examples from a real system overhaul
- **lesson-enforcer.sh** (PreToolUse): Converts passive lessons into deterministic runtime checks. Single python3 call extracts all JSON fields. Checks: directory-as-file-path, large-file-without-offset, git-pull-without-strategy. Demonstrates the core Enso principle: "code enforcement > prompt persuasion"
- **business-closure-guard.sh** (Stop): Enforces business output per session. Blocks (exit 2) if no execution-log entry or NOW.md update after 2+ minutes. REMINDED_FLAG anti-deadlock pattern prevents infinite blocking loops
- **health-check-with-breaker.sh** (SessionStart): Infrastructure health check with 1-hour circuit breaker. Prevents noise storms — real case eliminated 1,322 duplicate SYSTEM_OFFLINE log entries. Includes `timeout 3` for docker and polling restart for Qdrant
- **CI:** GitHub Actions pipeline — shellcheck + pytest + BATS + macOS install smoke test

### Patterns Demonstrated
- **Circuit breaker**: `/tmp/` lockfiles with TTL to suppress duplicate error logging
- **Anti-deadlock Stop hooks**: `exit 2` for real enforcement + `REMINDED_FLAG` for deadlock prevention (block once → agent fixes → second attempt passes)
- **Lesson-to-hook graduation**: When a lesson has 0 hits after 7+ days in the prompt, convert it to a PreToolUse hook that checks at runtime instead

## [0.5.0] — 2026-04-12

### Engineering Credibility Release

Zero new features. Every change fixes a broken promise or adds verification.

### Fixed
- **Install manifest:** All 7 core files now installed (rebuild-index.py, enso-lint.sh, deleted-lessons-tracker.py were missing)
- **macOS compatibility:** Portable timeout wrapper (GNU → gtimeout → python3 fallback)
- **DRY:** Distillation backend refactored from 3 copy-paste blocks to a loop
- **load-lessons.sh:** Merged 3 Python interpreter calls into 1 (saves ~100ms per session)
- **distill-lessons.sh:** Pre-load lessons outside dedup loop (O(N) instead of O(N*M) file reads)

### Changed
- **README:** Honest per-target capability matrix replaces misleading "✅ Full/Plugin/Hook" labels
- **README:** Separated "enforced" (exit 2 blocks) from "audited" (logged warnings)
- **enso.toml:** Moved to docs/spec/enso-config-spec.toml (was never read by the system)

### Added
- **Tests:** pytest suite for parse-hook-input.py (20 tests, 5 formats)
- **Tests:** BATS tests for adapter.sh (12 tests) and install.sh (19 tests)
- **CI:** GitHub Actions — shellcheck + pytest + BATS + macOS install smoke test

### Removed
- **memory/execution-log.jsonl** from git tracking (runtime artifact)
- **enso.toml** from project root (moved to docs/spec/)

## [0.4.0] — 2026-04-10

### Repositioned
- **"Discipline Plugin for AI Agents"** — from competitive "harness vs" framing to complementary plugin positioning
- New tagline: "Enso is not a memory system. It's a discipline system."
- README rewritten with "Works With" framing instead of "vs The Big Three"

### Added
- **Multi-framework support** (`install.sh --target`):
  - `claude-code` (default, unchanged behavior)
  - `gemini-cli` (auto-registers in `~/.gemini/settings.json`)
  - `hermes` (generates Python plugin shim at `~/.hermes/plugins/enso/`)
  - `openclaw` (generates TypeScript hook at `~/.openclaw/hooks/enso-discipline/`)
  - `generic` (installs hooks only, prints manual integration guide)
- **Framework adapter layer** (`adapter.sh`): centralizes output format + LLM backend selection
- **Multi-format input parser** (`parse-hook-input.py --format`): supports claude-code, gemini-cli, hermes, openclaw, generic JSON schemas
- **Lesson provenance** (`[seed:XXXXXX]`): hash tracks which error seeds generated each lesson
- **`applies_when` tags**: context-aware lesson metadata (e.g., "reading large files", "running git commands")
- **Multi-backend distillation**: tries claude → llm → openai CLI, graceful fallback

### Changed
- `install.sh`: backward-compatible (no args = claude-code), new `--target` flag
- `env.sh`: sources adapter.sh, passes `--format` to parser
- `load-lessons.sh`: uses adapter for output format (XML for Claude/Gemini, Markdown for others)
- `distill-lessons.sh`: uses adapter for LLM backend, adds provenance hash + applies_when to prompt
- Version: 0.3.0 → 0.4.0
- LOC: 1277 → 1401 (Shell 801 + Python 600)

### Backward Compatibility
- All existing Claude Code users: zero behavioral change
- `bash install.sh` with no arguments works identically to v0.3.0

## [0.3.0] — 2026-04-09

### Added
- **Three-way comparison** in README: honest assessment vs Claude Code, OpenClaw, Hermes Agent
- **Knowledge health check** (`enso-lint.sh`): weekly orphan/duplicate/weak lesson detection
- **Lessons index** (`rebuild-index.py`): auto-generated INDEX.md for fast LLM routing
- **Forgetting mechanism**: stale decay (37d), LRU eviction (50 cap), MEMORY.md downsink
- **Recovery safety net** (`deleted-lessons-tracker.py`): flags when deleted lessons reappear as errors
- **Log rotation** scheduled task: traces >14d deleted, execution-log >500 truncated
- **X outreach automation** scheduled task: daily hot post discovery + auto-reply
- FAQ section in both EN and CN READMEs

### Fixed
- **PID isolation bug** in env.sh: cross-hook state sharing now uses PWD hash instead of $$
- **enso-lint f-string crash**: lesson text with `{curly braces}` no longer crashes Python
- **Memory budget guard**: changed from blocking (exit 2) to non-blocking (warn only)
- **Semantic dedup**: keyword-overlap dedup + DIKW TF-IDF cosine for better duplicate detection
- **MM-DD year boundary bug** in MEMORY.md downsink: proper datetime comparison
- **Install.sh**: prerequisite checks (python3/bash), nullglob for empty dirs, shlex.quote for paths
- **DIKW info-layer**: backfilled 10 existing lessons (was empty for 11 days)
- **INDEX.md sync**: now rebuilds after every distillation

### Changed
- README restructured: "sell results not tech" (banner + demo-flow + before-after images)
- "Zero Dependencies" → "bash + python3" (honest about prerequisites)
- "AI Agents" → clarified Claude Code is primary target
- Philosophy and Survival Experiment sections folded into `<details>` tags
- Version bump: 0.2.1 → 0.3.0
- LOC: 952 → 1277

## [0.2.1] — 2026-04-08

### Fixed
- PID isolation bug (env.sh)
- Install.sh prerequisite checks
- "Zero Dependencies" honest relabeling

## [0.2.0] — 2026-04-02

### Added
- DIKW distillation pipeline (info-layer, knowledge, wisdom)
- Error seed capture via PostToolUseFailure hook
- Memory budget guard, safety scan, session-end maintenance hooks
- Chinese README (README.zh-CN.md)

### Changed
- Install.sh: copies DIKW files + registers PostToolUseFailure hook
- Version bump: 0.1.0 → 0.2.0

## [0.1.0] — 2026-03-30

### Added
- Initial MVP: 6 hooks (physical-verification, core-readonly, no-trace-no-truth, trace-emission, distill-lessons, load-lessons)
- One-command installer (install.sh)
- Shared modules (env.sh, parse-hook-input.py)
- README with architecture diagram and philosophy

### Foundation
- Built from 100+ research papers analyzed over 5 months
- Inspired by OpenAI Harness Engineering, Agent Lightning (Microsoft), fireworks-skill-memory, SWE-agent
