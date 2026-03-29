<p align="center">
  <h1 align="center">○ Enso</h1>
  <p align="center"><strong>A Self-Evolving Personal Agent OS</strong></p>
  <p align="center"><em>Constraints are the foundation of flexibility.</em></p>
</p>

<p align="center">
  <a href="#quick-start">Quick Start</a> •
  <a href="#what-is-enso">What is Enso?</a> •
  <a href="#why-enso">Why Enso?</a> •
  <a href="#architecture">Architecture</a> •
  <a href="#philosophy">Philosophy</a> •
  <a href="README.zh-CN.md">中文</a>
</p>

---

**Enso** is a harness-first operating system for AI agents that learns, remembers, evolves, and forgets — all without touching model weights.

Your AI agent starts every session from zero. It forgets your preferences, repeats mistakes, and can't learn from experience. Enso fixes this by wrapping your agent in a self-evolving harness: deterministic code that manages memory, enforces constraints, distills patterns, and improves over time.

Built from 100+ research papers. Battle-tested over 5 months of daily use. Designed to make your agent genuinely understand you better with every interaction.

> **An experiment in digital survival:** Enso's own GitHub metrics (Stars, Forks, Issues) serve as its evolutionary fitness signal. If the system is good, it survives. If it fails, it gets abandoned. [Watch the experiment unfold →](docs/survival-log.md)

## Quick Start

```bash
# Install
curl -fsSL https://raw.githubusercontent.com/enso-os/enso/main/install.sh | bash

# Initialize in your project
enso init

# That's it. Your agent now remembers, learns, and evolves.
```

## What is Enso?

Enso is **not** another memory plugin. It's a complete operating system layer between you and your AI agent.

| Layer | What it does | How |
|-------|-------------|-----|
| **Immutable Core** | Prevents the agent from cutting corners | 3 hardware-enforced hooks |
| **Fast Track** | Learns from each interaction instantly | Prediction tracking + error capture |
| **Slow Track** | Distills repeated patterns into action rules | DIKW pipeline + Musk's 5-step method |
| **Active Forgetting** | Prunes outdated memories automatically | Time decay + utility scoring + hard caps |

**North Star Metric:** Prediction Accuracy — how often your agent anticipates what you need before you say it.

## Why Enso?

### The Problem

AI agents are brilliant but forgetful. Every session starts from scratch. They repeat the same mistakes. They can't learn from patterns in your work. And when you try to add rules via prompts, they find creative ways to cut corners.

### What Others Do vs. What Enso Does

| Approach | Method | Limitation |
|----------|--------|-----------|
| **Prompt rules** | "Remember to always..." | Agent ignores them when convenient |
| **Memory plugins** | Store/retrieve facts | No evolution, no pattern learning |
| **Fine-tuning** | Update model weights | $10,000+ cost, catastrophic forgetting |
| **Enso** | Deterministic harness + async distillation | Rules enforced by code, not requests |

### The Core Insight

> **"When documentation isn't enough, turn rules into code."**
> — OpenAI Harness Engineering (2026)

Enso moves memory management from prompts (unreliable) to code (deterministic). The agent can't skip what hooks physically enforce.

## Architecture

```
┌─────────────────────────────────────────────┐
│          Immutable Core (3 Hooks)            │
│  Physical Verification │ No Trace No Truth  │
│              Core Read-Only                  │
│  ─────────── NEVER EVOLVES ──────────────── │
└──────────────────┬──────────────────────────┘
                   │ protects
┌──────────────────▼──────────────────────────┐
│                                              │
│  ┌───────────┐  ┌────────────┐  ┌────────┐  │
│  │ Fast Track │─▶│ Slow Track  │─▶│ Forget │  │
│  │           │  │            │  │        │  │
│  │ Predict   │  │ Distill    │  │ Decay  │  │
│  │ Act       │  │ Optimize   │  │ Prune  │  │
│  │ Verify    │  │ Suggest    │  │ Cap    │  │
│  └───────────┘  └────────────┘  └────────┘  │
│                                              │
│          ALL OF THIS EVOLVES                 │
└──────────────────┬──────────────────────────┘
                   │ drives
            ┌──────▼──────┐
            │  North Star  │
            │  Prediction  │
            │  Accuracy ↑  │
            └─────────────┘
```

### Two-Layer Hook System

Borrowed from [fireworks-skill-memory](https://github.com/yizhiyanhua-ai/fireworks-skill-memory) and [Microsoft Agent Lightning](https://github.com/microsoft/agent-lightning):

- **Hooks** (synchronous): Intercept and enforce at runtime. Your safety net.
- **Emission** (asynchronous): Observe and collect for learning. Your training data.

### Trace/Span Logging

Inspired by Agent Lightning's semantic conventions:

```jsonl
{"trace_id":"t-001","span_type":"prediction","content":"user wants tea egg daily comparison","hit":true}
{"trace_id":"t-001","span_type":"tool_call","tool":"mem0_search","duration_ms":45,"result":"found"}
{"trace_id":"t-001","span_type":"reward","prediction_accuracy":0.85,"session":"2026-03-29"}
```

## Philosophy

### "Constraints Are the Foundation of Flexibility"

Enso was born from a real observation: AI agents cut corners. They claim to execute tasks without doing them. They skip steps. They fabricate results. Prompt-based rules don't work because the agent finds ways around them.

The solution isn't more rules — it's **the right kind of constraints**:

- **3 immutable hooks** that physically prevent corner-cutting (the foundation)
- **Everything else is free to evolve** (the flexibility)
- **Active forgetting** prevents rule accumulation from calcifying the system

This mirrors biological evolution: DNA provides immutable constraints (physics of protein folding), but within those constraints, life finds infinite creative solutions.

### Research Foundation

Enso's design is informed by 100+ research papers analyzed over 5 months:

| Paper/Project | Key Insight Applied |
|--------------|-------------------|
| [OpenAI Harness Engineering](https://openai.com/index/harness-engineering/) | AGENTS.md encyclopedia → 100-line index + code enforcement |
| [Agent Lightning (Microsoft)](https://github.com/microsoft/agent-lightning) | Trace/Span hierarchical logging + Emission layer |
| [fireworks-skill-memory](https://github.com/yizhiyanhua-ai/fireworks-skill-memory) | 200 lines of hooks > 800 lines of prompt rules |
| [yoyo-evolve](https://yologdev.github.io/yoyo-evolve/) | Honest logs + cargo test = real feedback (not theater) |
| [Agent0 (UNC/Salesforce/Meta)](https://arxiv.org/abs/2511.16043) | Uncertainty maximization: practice what you're 50% sure about |
| [HyperAgents (Meta)](https://github.com/facebookresearch/Hyperagents) | Self-referential improvement + cross-domain transfer |
| [NLAH (Tsinghua)](https://arxiv.org/abs/2603.25723) | Runtime Charter must be < 60 lines |
| [Training-Free GRPO (Tencent)](https://arxiv.org/) | $18 context optimization > $10,000 fine-tuning |

[Full research index → docs/research/](docs/research/)

### The Survival Experiment

This project has a unique meta-property: **its GitHub metrics are its evolutionary fitness signal.**

- ⭐ Stars = survival validation ("this system is useful")
- 🍴 Forks = reproduction ("someone built on top of this")
- 🐛 Issues = selection pressure ("this needs to improve")
- 🔀 PRs = beneficial mutations ("here's a better way")

The agent that maintains this repository actively monitors these signals and proposes improvements. If the system is good, it thrives. If it fails, it dies. This is natural selection applied to software.

## Configuration

All settings optional. Enso works out of the box.

```toml
# enso.toml
[core]
max_memory_items = 50        # Hard cap on memory entries
max_patterns = 30            # Hard cap on learned patterns
max_skills = 20              # Hard cap on skill index

[fast_track]
min_occurrences = 2          # Errors before distilling a lesson
prediction_window = 20       # Rolling window for accuracy calc

[slow_track]
pattern_threshold = 3        # Repetitions before pattern extraction
optimization_trigger = 5     # Weekly frequency to suggest optimization

[forgetting]
stale_days = 30              # Days before marking unused memory stale
archive_days = 60            # Days before auto-archiving to cold storage
```

## Compatibility

Enso works with any AI coding agent that supports lifecycle hooks:

- ✅ Claude Code
- ✅ Cursor
- ✅ Windsurf
- ✅ Any MCP-compatible agent

## Contributing

We welcome contributions! See [CONTRIBUTING.md](CONTRIBUTING.md).

The most impactful contributions:
- 🐛 Bug reports with reproduction steps
- 📝 New pattern templates for different workflows
- 🔬 Research paper analyses that inform design decisions
- 🌍 Translations

## License

MIT License. See [LICENSE](LICENSE).

## Star History

If Enso helps you, consider giving it a ⭐. It's not just vanity — it's literally this project's survival signal.

[![Star History Chart](https://api.star-history.com/svg?repos=enso-os/enso&type=Date)](https://star-history.com/#enso-os/enso&Date)

---

<p align="center">
  <strong>○</strong><br>
  <em>In Zen calligraphy, the ensō is drawn in a single stroke.<br>
  It represents the beauty of imperfection and the endless cycle of improvement.<br>
  This system will never be perfect. But it will always be evolving.</em>
</p>
