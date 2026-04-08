# Changelog

All notable changes to Enso will be documented in this file.

Format: [Semantic Versioning](https://semver.org/) — MAJOR.MINOR.PATCH
- MAJOR: Breaking changes to hook interface or install process
- MINOR: New features, new hooks, new mechanisms
- PATCH: Bug fixes, docs updates, performance improvements

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
