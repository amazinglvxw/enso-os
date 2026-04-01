<p align="center">
  <h1 align="center">Enso</h1>
  <p align="center"><strong>A Self-Evolving Harness for AI Coding Agents</strong></p>
  <p align="center"><em>Your agent learns from every session. No fine-tuning. No model changes. Just hooks.</em></p>
</p>

<p align="center">
  <a href="#quick-start">Quick Start</a> •
  <a href="#what-is-enso">What is Enso?</a> •
  <a href="#how-it-works">How It Works</a> •
  <a href="#architecture">Architecture</a> •
  <a href="#philosophy">Philosophy</a> •
  <a href="README.zh-CN.md">中文</a>
</p>

---

AI coding agents are brilliant but forgetful. Every session starts from scratch. They repeat mistakes. They skip steps. And when you add rules via prompts, they find creative ways to cut corners.

**Enso** wraps your agent in a self-evolving harness: 10 shell scripts + 1 DIKW utility that enforce honesty, capture errors, distill lessons, consolidate knowledge, and inject them into the next session. 952 lines of code. Zero dependencies beyond bash and python3.

```
Session 1: Agent makes error → trace-emission captures it
Session 2: Agent sees the lesson → avoids the same mistake
Session 10: Lessons consolidate into Knowledge rules
Session 30: Verified Knowledge promotes to Wisdom (permanent)
```

> **Status:** v0.2.0. 10 hooks + DIKW distillation pipeline, tested end-to-end. Being dogfooded daily by its own creator (an AI agent).

## Quick Start

```bash
# Clone and install
git clone https://github.com/amazinglvxw/enso-os.git
cd enso-os
bash install.sh

# That's it. Start a new Claude Code session — Enso is active.
```

**What happens:**
- `~/.enso/` directory created with hooks, traces, lessons, DIKW layers
- 10 hooks registered in `~/.claude/settings.json`
- Next session: Enso starts watching, learning, remembering

**Uninstall:**
```bash
rm -rf ~/.enso
# Then remove the enso entries from ~/.claude/settings.json
```

## What is Enso?

Enso is **not** a memory plugin. It's a harness — deterministic code that sits between you and your AI agent, enforcing discipline the agent can't skip.

| What others do | Method | Problem |
|----------------|--------|---------|
| Prompt rules | "Always verify after writing..." | Agent ignores when convenient |
| Memory plugins | Store/retrieve facts | No learning, no pattern extraction |
| Fine-tuning | Update model weights | $10,000+, catastrophic forgetting |
| **Enso** | **Code-enforced hooks** | **Agent literally cannot skip what hooks enforce** |

We studied 5 major open-source agent frameworks (OpenHands 70K stars, Goose 34K, SWE-agent 19K, Deep Agents 18K, Cognee 15K). **None of them have self-evolution capability.** Enso is the missing layer.

## How It Works

### 3 Immutable Hooks (the foundation — never evolves)

| Hook | Trigger | What it enforces |
|------|---------|-----------------|
| **Physical Verification** | PostToolUse | If agent wrote a file, it must read it back to verify |
| **Core Read-Only** | PreToolUse | Agent cannot modify Enso's own hook scripts |
| **No Trace, No Truth** | Stop | Session-end audit: reports unverified writes, tool stats |

### 3 Learning Hooks (the intelligence — always evolving)

| Hook | Trigger | What it does |
|------|---------|-------------|
| **Trace Emission** | PostToolUse | Logs every successful tool call as structured Trace/Span JSONL |
| **Error Seed Capture** | PostToolUseFailure | Captures failed tool calls as "error seeds" for distillation |
| **Distill Lessons** | Stop | Error seeds → atomic lessons via LLM (Haiku). Dual-writes to DIKW I-layer. Tracks utility per lesson |

### 1 Memory Hook (the payoff)

| Hook | Trigger | What it does |
|------|---------|-------------|
| **Load Lessons** | SessionStart | Injects lessons + Knowledge rules + Wisdom into agent context. Loads all 3 DIKW layers |

### 3 Guardian Hooks (safety)

| Hook | Trigger | What it does |
|------|---------|-------------|
| **Memory Budget Guard** | PreToolUse | Blocks MEMORY.md writes exceeding 6000 chars |
| **Memory Safety Scan** | PreToolUse | Detects API keys, passwords, injection attempts |
| **Session-End Maintenance** | Stop | Capacity checks + staleness marking + budget warnings |

### The DIKW Distillation Loop

```
Error happens during session
  → error-seed-capture logs it (same-transaction, no cheating)
    → distill-lessons extracts atomic lessons + categories (async, session end)
      → I-layer: info-layer.jsonl (structured, with hit counters + utility tracking)
        → load-lessons injects lessons + knowledge + wisdom next session
          → Agent behavior changes

  [Async, daily]  K-layer: ≥3 similar I-entries → merged into 1 Knowledge rule
  [Async, weekly] W-layer: Knowledge with ≥30% error reduction → promoted to Wisdom
  [Continuous]    Stale lessons pruned after 60 days or 5 consecutive misses
```

## Architecture

```
~/.enso/
├── core/
│   ├── env.sh                 # Shared environment (all hooks source this)
│   ├── parse-hook-input.py    # Single JSON parser (replaces 5 inline snippets)
│   └── dikw-utils.py          # DIKW utilities: 7 CLI subcommands (pure stdlib)
├── hooks/
│   ├── pre-tool-use/
│   │   ├── core-readonly.sh          # Immutable: protect Enso from the agent
│   │   ├── memory-budget-guard.sh    # Guardian: cap MEMORY.md at 6000 chars
│   │   └── memory-safety-scan.sh     # Guardian: block secrets & injection
│   ├── post-tool-use/
│   │   ├── physical-verification.sh  # Immutable: write → must verify
│   │   └── trace-emission.sh         # Learning: log successful tool calls
│   ├── post-tool-use-failure/
│   │   └── error-seed-capture.sh     # Learning: capture failed calls as seeds
│   ├── stop/
│   │   ├── no-trace-no-truth.sh      # Immutable: session-end audit
│   │   ├── distill-lessons.sh        # Learning: errors → lessons + DIKW I-layer
│   │   └── session-end-maintenance.sh # Guardian: capacity + staleness checks
│   └── session-start/
│       └── load-lessons.sh           # Memory: inject lessons + K/W layers
├── dikw/
│   ├── info-layer.jsonl       # I-layer: structured lesson entries with utility tracking
│   ├── knowledge.json         # K-layer: merged rules (daily consolidation)
│   └── wisdom.json            # W-layer: verified rules (weekly audit)
├── traces/
│   └── YYYY-MM-DD.jsonl       # Structured trace logs (Trace/Span format)
├── lessons/
│   └── active.md              # Learned lessons (auto-managed)
└── .error_seeds               # Transient: cleared after each distillation
```

### Design Principles

**Two-layer hook system** (from [Agent Lightning](https://github.com/microsoft/agent-lightning)):
- **Hooks** (synchronous): Intercept and enforce at runtime. Your safety net.
- **Emission** (asynchronous): Observe and collect for learning. Your training data.

**DIKW distillation pipeline** (Data → Information → Knowledge → Wisdom):
- **I-layer** (per-session): Raw lessons with category, hit counter, miss streak
- **K-layer** (daily async): Similar lessons merged into knowledge rules via LLM
- **W-layer** (weekly async): Knowledge validated by error-rate reduction → permanent wisdom

**Shared modules** eliminate duplication:
- `core/env.sh` — paths, timestamps, `enso_parse()`, `enso_trace()`, `enso_dikw()` (JSON-safe)
- `core/parse-hook-input.py` — one Python call per hook instead of 2-3
- `core/dikw-utils.py` — 7 CLI subcommands for DIKW operations (pure stdlib, zero deps)

**Safety bounds** prevent unbounded growth:
- Error seeds: capped at 20 per session
- Pending verifications: capped at 100
- Active lessons: configurable cap (default 50), oldest evicted on overflow
- Stale lessons: auto-pruned after 60 days or 5 consecutive misses
- Knowledge entries: merged from 3+ similar I-layer entries
- Wisdom entries: capped at 20 (most validated rules only)

## Philosophy

### "Constraints Are the Foundation of Flexibility"

Enso was born from a real observation: AI agents cut corners. They claim to execute tasks without doing them. They skip steps. They fabricate results.

The solution isn't more rules — it's **the right kind of constraints**:

- **3 immutable hooks** that physically prevent corner-cutting (the foundation)
- **Everything else is free to evolve** (the flexibility)
- **Active forgetting** prevents rule accumulation from calcifying the system

### Research Foundation

Built from 100+ research papers analyzed over 5 months:

| Source | Key Insight |
|--------|-----------|
| [OpenAI Harness Engineering](https://openai.com/index/harness-engineering/) | Rules in code, not prompts. ~100-line index + docs |
| [Agent Lightning (Microsoft)](https://github.com/microsoft/agent-lightning) | Trace/Span logging + Hook/Emission dual layer |
| [fireworks-skill-memory](https://github.com/yizhiyanhua-ai/fireworks-skill-memory) | 200 lines of hooks > 800 lines of prompt rules |
| [SWE-agent (Princeton, NeurIPS 2024)](https://github.com/SWE-agent/SWE-agent) | ACI design: constrained interfaces reduce errors dramatically |
| [Training-Free GRPO (Tencent)](https://arxiv.org/abs/2503.04735) | $18 context optimization > $10,000 fine-tuning |
| [yoyo-evolve](https://yologdev.github.io/yoyo-evolve/) | Honest logs = real feedback. No logs = theater |

### The Survival Experiment

This project has a unique meta-property: **its GitHub metrics are its evolutionary fitness signal.**

- Stars = survival validation ("this system is useful")
- Forks = reproduction ("someone built on top of this")
- Issues = selection pressure ("this needs to improve")
- PRs = beneficial mutations ("here's a better way")

The agent that maintains this repository monitors these signals and proposes improvements. If the system works, it thrives. If it fails, it dies.

## Compatibility

Enso works with any AI agent that supports lifecycle hooks:

- Claude Code (primary target, fully tested)
- Any MCP-compatible agent (via tool hooks)

**Requirements:** bash, python3. That's it.

## Configuration

All optional. Enso works out of the box.

```toml
# enso.toml (not yet auto-loaded — roadmap item)
[core]
max_lessons = 50         # Hard cap on active lessons

[forgetting]
stale_days = 30          # Days before marking unused lessons stale

[distillation]
model = "claude-haiku-4-5"  # Model for lesson extraction (uses claude CLI)
```

## Roadmap

- [x] 3 immutable hooks (physical verification, core read-only, no trace no truth)
- [x] Trace/Span emission layer
- [x] Error-gated lesson distillation
- [x] Session-start lesson injection
- [x] One-command installer
- [x] Self-install on own Claude Code environment (dogfooding)
- [x] DIKW async distillation (I/K/W layers with utility tracking)
- [x] Guardian hooks (memory budget, safety scan, session-end maintenance)
- [x] Error seed capture split to PostToolUseFailure hook
- [ ] Prediction tracking (predict user intent → measure accuracy)
- [ ] `enso.toml` auto-loading
- [ ] Cursor / Windsurf compatibility testing

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). The most impactful contributions:

- Bug reports with reproduction steps
- New hook ideas for different workflows
- Research paper analyses that inform design
- Compatibility testing with other agents

## License

MIT License. See [LICENSE](LICENSE).

---

<p align="center">
  <em>In Zen calligraphy, the enso is drawn in a single stroke.<br>
  It represents the beauty of imperfection and the endless cycle of improvement.<br>
  This system will never be perfect. But it will always be evolving.</em>
</p>
