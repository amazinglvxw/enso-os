<p align="center">
  <img src="docs/assets/hero-banner.png" alt="Enso — Self-Evolving AI Agent Harness" width="100%">
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="MIT License"></a>
  <a href="#"><img src="https://img.shields.io/badge/LOC-1267-brightgreen" alt="1267 Lines of Code"></a>
  <a href="#"><img src="https://img.shields.io/badge/Hooks-10-orange" alt="10 Shell Hooks"></a>
  <a href="#"><img src="https://img.shields.io/badge/Dependencies-0-blue" alt="Zero Dependencies"></a>
</p>

<p align="center">
  <a href="#quickstart">Quickstart</a> •
  <a href="#how-it-works">How It Works</a> •
  <a href="#architecture">Architecture</a> •
  <a href="#forgetting">Forgetting</a> •
  <a href="#health-check">Health Check</a> •
  <a href="README.zh-CN.md">中文</a>
</p>

---

**Your AI agent makes the same mistake twice. Enso makes sure there's no third time.**

Install in 30 seconds. Zero dependencies. Your agent starts learning automatically.

<p align="center">
  <img src="docs/assets/demo-flow.png" alt="Enso: Session 1 error → Session 2 learned" width="85%">
</p>

## Quickstart

```bash
git clone https://github.com/amazinglvxw/enso-os.git
cd enso-os && bash install.sh
```

**That's it.** Start a new Claude Code session. Enso is active. Here's what happens:

```
Session 1:  You hit an error → Enso captures it automatically
            Session ends → Enso distills 1-3 lessons from the error

Session 2:  Enso injects the lessons → Agent avoids the same mistake
            You didn't do anything. The system learned by itself.
```

**For Claude Code users** — Enso registers as lifecycle hooks. No config needed.

## Why Enso?

<p align="center">
  <img src="docs/assets/before-after.png" alt="Without vs With Enso" width="85%">
</p>

| Feature | OpenHands (70K⭐) | Goose (34K⭐) | SWE-agent (19K⭐) | **Enso** |
|---------|:-:|:-:|:-:|:-:|
| Learns from past errors | ❌ | ❌ | ❌ | ✅ |
| Rules enforced by code | ❌ | Partial | ❌ | ✅ |
| Self-evolving memory | ❌ | ❌ | ❌ | ✅ |
| Active forgetting | ❌ | ❌ | ❌ | ✅ |
| Zero dependencies | ❌ | ❌ | ❌ | ✅ |

## How It Works

<p align="center">
  <img src="docs/assets/architecture.png" alt="Enso Architecture" width="85%">
</p>

**10 hooks, 4 layers.** The agent can't skip what code enforces.

| Layer | Hooks | What they do |
|-------|-------|-------------|
| 🔒 **Immutable** | 3 | Write→must verify. Can't modify own rules. Session-end audit. |
| 🧠 **Learning** | 3 | Log every tool call. Capture errors. Distill lessons via LLM. |
| 💡 **Memory** | 1 | Inject lessons + knowledge + wisdom into next session. |
| 🛡️ **Guard** | 3 | Memory budget cap. Block secrets/injection. Auto-maintenance. |

**The core loop:**
```
Error → Capture (code-enforced) → Distill (async) → Store → Inject next session → Avoid
```

Not "the agent *chooses* to learn." The system **makes it** learn.

## Forgetting

Most memory systems only grow. Enso actively forgets — because [not forgetting is more dangerous](https://arxiv.org/abs/2603.13428).

| Mechanism | What it does |
|-----------|-------------|
| Stale decay | Lessons unused >37 days → deleted |
| LRU eviction | Over 50 lessons → oldest evicted |
| MEMORY.md downsink | Completed items → archived |
| Trace rotation | >14 days → deleted (daily cron) |
| Recovery safety net | Deleted lesson reappears as error → flagged |

## Health Check

`enso-lint.sh` runs weekly — like CI/Lint for your knowledge base:

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
│   ├── enso-lint.sh               # 🔍 Weekly health check
│   ├── rebuild-index.py           # 📇 Auto-rebuild INDEX.md
│   └── deleted-lessons-tracker.py # 🔄 Recovery safety net
├── hooks/                         # 10 lifecycle hooks
│   ├── pre-tool-use/              # 🔒🛡️ core-readonly, budget-guard, safety-scan
│   ├── post-tool-use/             # 🔒🧠 physical-verification, trace-emission
│   ├── post-tool-use-failure/     # 🧠 error-seed-capture
│   ├── stop/                      # 🔒🧠🛡️ audit, distill, maintenance
│   └── session-start/             # 💡 load-lessons
├── dikw/                          # DIKW distillation (Info → Knowledge → Wisdom)
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
| [OpenAI Harness Engineering](https://openai.com/index/harness-engineering/) | Rules in code, not prompts |
| [Agent Lightning (Microsoft)](https://github.com/microsoft/agent-lightning) | Trace/Span + Hook/Emission dual layer |
| [fireworks-skill-memory](https://github.com/yizhiyanhua-ai/fireworks-skill-memory) | 200 lines of hooks > 800 lines of prompt |
| [SWE-agent (NeurIPS 2024)](https://github.com/SWE-agent/SWE-agent) | Constrained interfaces reduce errors |

</details>

<details>
<summary><strong>The Survival Experiment</strong></summary>

This project's GitHub metrics are its evolutionary fitness signal:

- ⭐ Stars = survival ("this is useful")
- 🍴 Forks = reproduction ("I'm building on this")
- 🐛 Issues = selection pressure ("improve this")

The agent maintaining this repo monitors these signals. If the system works, it thrives. If not, it dies.

</details>

## FAQ

**Q: What AI agents does this work with?**
Claude Code (primary, fully tested). Any agent with lifecycle hooks.

**Q: Where is my data stored?**
100% local. `~/.enso/` on your machine. No cloud, no Docker, no database.

**Q: How is this different from Mem0 or LangChain memory?**
Those store facts. Enso learns from mistakes — and forgets what's no longer useful.

**Q: Do I need to configure anything after install?**
No. `bash install.sh` registers all hooks. Next session, it starts learning.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Most impactful:
- 🐛 Bug reports with repro steps
- 💡 New hook ideas
- 🧪 Compatibility testing with other agents

## License

MIT. See [LICENSE](LICENSE).

---

<p align="center">
  <em>The ensō is drawn in a single stroke — imperfect, incomplete, beautiful.<br>
  This system will never be perfect. But it will always be evolving.</em>
</p>
