<p align="center">
  <img src="docs/assets/hero-banner.png" alt="Enso" width="100%">
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="MIT License"></a>
  <a href="#"><img src="https://img.shields.io/badge/LOC-1514-brightgreen" alt="1514 Lines of Code"></a>
  <a href="#"><img src="https://img.shields.io/badge/Hooks-10-orange" alt="10 Shell Hooks"></a>
  <a href="#"><img src="https://img.shields.io/badge/Deps-bash%20%2B%20python3-blue" alt="bash + python3"></a>
  <a href="#"><img src="https://img.shields.io/badge/Frameworks-5-purple" alt="5 Frameworks"></a>
</p>

<p align="center">
  <a href="#quickstart">Quickstart</a> &bull;
  <a href="#what-enso-adds">What Enso Adds</a> &bull;
  <a href="#works-with">Works With</a> &bull;
  <a href="#how-it-works">How It Works</a> &bull;
  <a href="#forgetting">Forgetting</a> &bull;
  <a href="README.zh-CN.md">中文</a>
</p>

---

**Enso is not a memory system. It's a discipline system.**

A lightweight plugin that wraps around any AI agent — Claude Code, Hermes, OpenClaw, Gemini CLI — to add code-enforced learning, active forgetting, and self-protection.

Your agent makes the same mistake twice. Enso makes sure there's no third time. Install in 30 seconds. Just bash + python3 (pre-installed on macOS/Linux). Your agent starts learning automatically.

<p align="center">
  <img src="docs/assets/demo-flow.png" alt="Enso: Session 1 error -> Session 2 learned" width="85%">
</p>

## Quickstart

```bash
# Claude Code (default)
git clone https://github.com/amazinglvxw/enso-os.git
cd enso-os && bash install.sh

# Gemini CLI
bash install.sh --target gemini-cli

# Hermes Agent
bash install.sh --target hermes

# OpenClaw
bash install.sh --target openclaw

# Any agent with lifecycle hooks
bash install.sh --target generic
```

**That's it.** Start a new session. Enso is active:

```
Session 1:  You hit an error -> Enso captures it automatically
            Session ends -> Enso distills 1-3 lessons from the error

Session 2:  Enso injects the lessons -> Agent avoids the same mistake
            You didn't do anything. The system learned by itself.
```

## What Enso Adds

Enso is a plugin, not a platform. It adds discipline to your existing agent without replacing anything.

| What Enso adds | What your host agent handles |
|----------------|------------------------------|
| Code-enforced error learning | Context management |
| Active forgetting (stale decay, LRU) | Multi-model orchestration |
| Immutable self-protection (3 hooks) | Platform integrations |
| Knowledge quality checks (weekly lint) | Tool execution |

| What Enso enforces (blocks violations) | What Enso audits (logs + warns) |
|----------------------------------------|---------------------------------|
| Self-protection: agent can't modify its own hooks | Write verification: tracks unverified writes |
| Safety scan: blocks secrets/injection in memory files | Memory budget: warns when MEMORY.md is too large |

Enso doesn't replace your agent. It makes it more disciplined. Like SELinux for your AI — invisible when things go right, invaluable when they go wrong. Your agent keeps doing what it does best (context, tools, models). Enso adds the layer it's missing: learning from failure, forgetting what's stale, and protecting its own rules from itself.

## Works With

| Capability | Claude Code | Gemini CLI | Hermes | OpenClaw | Generic |
|------------|:-----------:|:----------:|:------:|:--------:|:-------:|
| Error capture + distillation | ✅ | ✅ | ✅ | ✅ | ✅ |
| Lesson injection (SessionStart) | ✅ | ✅ | ✅ | ✅ | ✅ |
| Tool call tracing | ✅ | ✅ | ✅ | ✅ | ✅ |
| Active forgetting + maintenance | ✅ | ✅ | ✅ | ✅ | ✅ |
| Self-protection (core-readonly) | ✅ | ✅ | — | — | — |
| Memory safety scan | ✅ | ✅ | — | — | — |
| Memory budget guard | ✅ | ✅ | — | — | — |
| Write verification audit | ✅ | ✅ | — | — | — |

Pre-tool-use hooks (self-protection, safety scan, budget guard, write verification) require the framework to support a "before tool execution" lifecycle event. Hermes, OpenClaw, and generic targets get the full learning + forgetting loop but not the guard layer.

```
Your Agent (Claude Code / Hermes / OpenClaw / Gemini CLI / ...)
       ↕ every tool call passes through
┌──────────────────────────────────────┐
│         Enso Discipline Layer        │
│  🔒 Can't skip  🧠 Learns  🗑️ Forgets │
└──────────────────────────────────────┘
```

## How It Works

<p align="center">
  <img src="docs/assets/architecture.png" alt="Enso Architecture" width="85%">
</p>

**10 hooks, 4 layers.** The agent can't skip what code enforces.

| Layer | Hooks | What they do |
|-------|-------|-------------|
| Immutable | 3 | Write must verify. Can't modify own rules. Session-end audit. |
| Learning | 3 | Log every tool call. Capture errors. Distill lessons via LLM. |
| Memory | 1 | Inject lessons + knowledge + wisdom into next session. |
| Guard | 3 | Memory budget cap. Block secrets/injection. Auto-maintenance. |

**The core loop:**

```
Error -> Capture (code-enforced) -> Distill (async) -> Store -> Inject next session -> Avoid
```

## Forgetting

Most memory systems only grow. Enso actively forgets — because not forgetting is more dangerous.

| Mechanism | What it does |
|-----------|-------------|
| Stale decay | Lessons unused >37 days deleted |
| LRU eviction | Over 50 lessons, oldest evicted |
| MEMORY.md downsink | Completed items archived |
| Trace rotation | >14 days deleted (daily cron) |
| Recovery safety net | Deleted lesson reappears as error, flagged |

## Health Check

`enso-lint.sh` runs weekly — like CI for your knowledge base:

| Check | What it finds |
|-------|--------------|
| Orphans | Lessons never used (hits:0, >7 days) |
| Duplicates | >60% keyword overlap between lessons |
| Weak lessons | No actionable verb — not useful |
| Budget | MEMORY.md capacity status |

Every distillation auto-rebuilds `lessons/INDEX.md` for fast routing.

## Architecture

```
~/.enso/
├── core/                          # Shared modules
│   ├── env.sh                     # Paths, enso_parse(), enso_find_memory_file()
│   ├── parse-hook-input.py        # JSON parser for all hooks
│   ├── dikw-utils.py              # DIKW operations (7 subcommands)
│   ├── enso-lint.sh               # Weekly health check
│   ├── rebuild-index.py           # Auto-rebuild INDEX.md
│   └── deleted-lessons-tracker.py # Recovery safety net
├── hooks/                         # 10 lifecycle hooks
│   ├── pre-tool-use/              # core-readonly, budget-guard, safety-scan
│   ├── post-tool-use/             # physical-verification, trace-emission
│   ├── post-tool-use-failure/     # error-seed-capture
│   ├── stop/                      # audit, distill, maintenance
│   └── session-start/             # load-lessons
├── dikw/                          # DIKW distillation (Info -> Knowledge -> Wisdom)
├── traces/                        # Tool call logs + lint reports
└── lessons/                       # active.md + INDEX.md
```

<details>
<summary><strong>Philosophy: "Constraints are the foundation of flexibility"</strong></summary>

Like biological evolution: DNA provides immutable constraints (protein folding physics), but within those constraints, life finds infinite creative solutions.

- **3 immutable hooks** = the foundation (never changes)
- **Everything else** = free to evolve
- **Active forgetting** = prevents calcification

Built from 100+ papers analyzed over 5 months:

| Source | Key Insight |
|--------|-----------|
| OpenAI Harness Engineering | Rules in code, not prompts |
| Agent Lightning (Microsoft) | Trace/Span + Hook/Emission dual layer |
| fireworks-skill-memory | 200 lines of hooks > 800 lines of prompt |
| SWE-agent (NeurIPS 2024) | Constrained interfaces reduce errors |

</details>

<details>
<summary><strong>The Survival Experiment</strong></summary>

This project's GitHub metrics are its evolutionary fitness signal:

- Stars = survival ("this is useful")
- Forks = reproduction ("I'm building on this")
- Issues = selection pressure ("improve this")

The agent maintaining this repo monitors these signals. If the system works, it thrives. If not, it dies.

</details>

## FAQ

**Q: What agents does this work with?**
Five targets out of the box: Claude Code (default, fully tested), Gemini CLI, Hermes Agent, OpenClaw, and a generic target for any agent with lifecycle hooks.

**Q: Does Enso compete with Mem0, Hermes memory, or OpenClaw Dreaming?**
No. Those are memory systems — they store facts and context. Enso is a discipline system — it enforces error learning, active forgetting, and self-protection. They are complementary.

**Q: Can I use Hermes memory + Enso together?**
Yes, that's exactly the point. Hermes handles context and skill creation. Enso adds code-enforced error capture, stale decay, and immutable self-protection on top. Same with Claude Code's Auto Memory or OpenClaw's Dreaming.

**Q: Where is my data stored?**
100% local. `~/.enso/` on your machine. No cloud, no Docker, no database.

**Q: What are the prerequisites?**
`bash` and `python3` (3.6+). Both are pre-installed on macOS and most Linux distros. No pip install, no npm, no Docker.

**Q: Do I need to configure anything after install?**
No. `bash install.sh` registers all hooks. Next session, it starts learning.

**Q: Why not just use my agent's built-in memory?**
Built-in memory stores facts. Enso adds what's missing: code-enforced error learning, active forgetting with quality checks, and immutable self-protection hooks that the agent cannot bypass.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Most impactful:
- Bug reports with repro steps
- New hook ideas
- Compatibility testing with other agents
- DIKW pipeline improvements

## License

MIT. See [LICENSE](LICENSE).

---

<p align="center">
  <em>The enso is drawn in a single stroke — imperfect, incomplete, beautiful.<br>
  This system will never be perfect. But it will always be evolving.</em>
</p>
