<p align="center">
  <img src="docs/assets/hero-banner.png" alt="Enso — Self-Evolving AI Agent Harness" width="100%">
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="MIT License"></a>
  <a href="#"><img src="https://img.shields.io/badge/LOC-1277-brightgreen" alt="1277 Lines of Code"></a>
  <a href="#"><img src="https://img.shields.io/badge/Hooks-10-orange" alt="10 Shell Hooks"></a>
  <a href="#"><img src="https://img.shields.io/badge/Deps-bash%20%2B%20python3-blue" alt="bash + python3"></a>
</p>

<p align="center">
  <a href="#quickstart">Quickstart</a> •
  <a href="#enso-vs-the-big-three">Comparison</a> •
  <a href="#how-it-works">How It Works</a> •
  <a href="#forgetting">Forgetting</a> •
  <a href="README.zh-CN.md">中文</a>
</p>

---

**Your AI agent makes the same mistake twice. Enso makes sure there's no third time.**

Install in 30 seconds. Just bash + python3 (pre-installed on macOS/Linux). Your agent starts learning automatically.

<p align="center">
  <img src="docs/assets/demo-flow.png" alt="Enso: Session 1 error → Session 2 learned" width="85%">
</p>

## Quickstart

```bash
git clone https://github.com/amazinglvxw/enso-os.git
cd enso-os && bash install.sh
```

**That's it.** Start a new Claude Code session. Enso is active:

```
Session 1:  You hit an error → Enso captures it automatically
            Session ends → Enso distills 1-3 lessons from the error

Session 2:  Enso injects the lessons → Agent avoids the same mistake
            You didn't do anything. The system learned by itself.
```

## Enso vs. The Big Three

We built Enso after studying how Claude Code, OpenClaw, and Hermes Agent handle memory and learning. Here's an honest comparison — **what they do better than us, and what we do that they don't.**

### The Comparison

| Capability | Claude Code | OpenClaw | Hermes Agent (30K⭐) | **Enso** |
|------------|:-----------:|:--------:|:-------------------:|:--------:|
| **Learns from errors** | ❌ No | ❌ No | ✅ Auto-creates skills | ✅ Code-enforced |
| **Forgetting** | Silent truncation at 200 lines | ❌ No | ❌ Skills only grow | ✅ Stale decay + LRU + health checks |
| **Context compression** | ✅ 5-layer pipeline | ✅ Compaction | ❌ Basic | ❌ Relies on host agent |
| **Dreaming / consolidation** | ✅ AutoDream (4-phase) | ✅ Light→REM→Deep | ❌ No | Partial (DIKW distillation) |
| **Multi-platform** | Terminal only | Terminal + UI | 6 platforms | Terminal only (Claude Code) |
| **Model support** | Anthropic only | Multiple | 200+ providers | Any (harness is model-agnostic) |
| **Self-protection** | ❌ Agent can edit memory | ❌ No | ❌ No | ✅ Immutable hooks (agent blocked itself) |
| **Knowledge quality checks** | ❌ No | ❌ No | ❌ No | ✅ Weekly lint (orphans, duplicates, weak) |
| **Install complexity** | Built-in | npm + config | pip + API keys | `bash install.sh` (30 seconds) |
| **Codebase size** | ~512K lines TS | ~50K lines | ~50K lines Python | **1,267 lines** Shell+Python |
| **Dependencies** | Node.js runtime | Node.js + plugins | Python + RL framework | **bash + python3** |

### What They Do Better (honestly)

**Claude Code** has the most sophisticated context management we've seen — a [5-layer compression pipeline](https://openai.com/index/harness-engineering/) (tool-result budgeting → snip-compact → micro-compact → context-collapse → auto-compact) that Enso doesn't attempt to replicate. Its AutoDream 4-phase memory consolidation (Orient→Gather→Consolidate→Prune) is production-grade. Enso relies on Claude Code's own compression; it doesn't add its own.

**OpenClaw** has the most elegant memory promotion system — its [Dreaming mechanism](https://docs.openclaw.ai/concepts/dreaming) uses 3 phases (Light→REM→Deep) with 6-signal weighted scoring to decide what becomes long-term memory. The staging buffer (Light/REM don't write to MEMORY.md, only Deep does) prevents memory fragmentation. Enso writes lessons more eagerly, which can cause duplication until the dedup catches it.

**Hermes Agent** goes furthest in self-improvement — its [trajectory→RL training pipeline](https://github.com/NousResearch/hermes-agent) lets the agent fine-tune its own model from usage data. It also has a Mixture-of-Agents tool (4 frontier models in parallel) and a Skills Hub marketplace with security scanning. Enso doesn't modify model weights and has no marketplace.

### What Enso Does That They Don't

**1. Code-enforced learning (not optional)**

Claude Code's Auto Memory, OpenClaw's Dreaming, and Hermes's skill creation are all **agent-initiated** — the model decides whether to remember. Enso's hooks are **code-enforced** — the agent literally cannot skip the capture/distill/inject loop. Our agent actually tried to modify its own safety hooks during a bug fix and got blocked by its own `core-readonly` hook.

**2. Active forgetting with quality verification**

All three major agents have memory that only grows (Claude Code silently truncates at 200 lines; Hermes skills accumulate; OpenClaw has no forgetting). Enso actively prunes: stale lessons decay after 37 days, LRU evicts beyond 50 entries, and weekly `enso-lint` checks for contradictions, orphans, and duplicates. A `deleted-lessons-tracker` flags when a deleted lesson's error recurs.

**3. Immutable self-protection**

None of the three agents prevent themselves from modifying their own rules. Enso's 3 immutable hooks are code-level constraints that cannot be overridden: physical verification (write→must read back), core read-only (agent can't modify hooks), and no-trace-no-truth (session-end audit).

**4. Radical simplicity**

1,267 lines of Shell + Python. No npm, no pip, no Docker, no database. The entire system is `grep`-searchable text files. You can read, edit, and understand every line. This is a deliberate trade-off: we sacrifice features (no multi-platform, no RL training, no context compression) for transparency and portability.

### Where Enso Fits

Enso is **not** a replacement for Claude Code, OpenClaw, or Hermes Agent. It's a **complementary layer** — a harness that wraps around your existing agent to add learning, forgetting, and self-protection.

```
Your Agent (Claude Code / OpenClaw / any)
       ↕ every tool call passes through
┌──────────────────────────────────────┐
│           Enso Harness               │
│  🔒 Can't skip  🧠 Learns  🗑️ Forgets │
└──────────────────────────────────────┘
```

Currently optimized for Claude Code. Architecture is portable to any agent with lifecycle hooks.

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
Claude Code (primary target, fully tested and dogfooded daily). Architecture is portable to any agent with lifecycle hooks, but install.sh currently targets Claude Code's settings.json.

**Q: Where is my data stored?**
100% local. `~/.enso/` on your machine. No cloud, no Docker, no database.

**Q: How is this different from Mem0 or LangChain memory?**
Those store facts. Enso learns from mistakes — and forgets what's no longer useful.

**Q: What are the prerequisites?**
`bash` and `python3` (3.6+). Both are pre-installed on macOS and most Linux distros. No pip install, no npm, no Docker.

**Q: Do I need to configure anything after install?**
No. `bash install.sh` registers all hooks. Next session, it starts learning.

**Q: Why not just use Claude Code's built-in memory?**
Claude Code's Auto Memory is great for storing facts. But it has a 200-line silent truncation limit, no learning from errors, no active forgetting, and no quality checks. Enso adds those missing layers on top.

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
