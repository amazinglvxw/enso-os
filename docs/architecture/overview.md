# Enso Architecture Overview

## Design Principle: Harness > Model

> "Building software still requires discipline, but the discipline lives in the supporting structure, not in the code."
> — Ryan Lopopolo, OpenAI Harness Engineering (2026)

Enso is built on a single insight: **the infrastructure around an AI agent matters more than the model itself.** This is supported by converging evidence from OpenAI (million-line codebase, zero human code), Microsoft (Agent Lightning, 15.6k stars), Meta (HyperAgents), and multiple academic papers.

## System Layers

```
┌─────────────────────────────────────────────────────┐
│                 YOUR AI AGENT                        │
│          (Claude Code / Cursor / etc.)               │
└──────────────────────┬──────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────┐
│                  ENSO HARNESS                        │
│                                                      │
│  ┌─────────────────────────────────────────────┐    │
│  │           Immutable Core (Layer 0)           │    │
│  │  3 hooks, code-enforced, agent cannot modify │    │
│  └─────────────────────────────────────────────┘    │
│                       │                              │
│  ┌────────┐ ┌────────┐ ┌────────┐ ┌──────────┐     │
│  │  Fast  │ │  Slow  │ │ Active │ │ Emission │     │
│  │ Track  │ │ Track  │ │Forget  │ │  Layer   │     │
│  │(sync)  │ │(async) │ │(async) │ │(observe) │     │
│  └────────┘ └────────┘ └────────┘ └──────────┘     │
│                                                      │
│  ┌─────────────────────────────────────────────┐    │
│  │         Memory Store (MEMORY.md + mem0)      │    │
│  └─────────────────────────────────────────────┘    │
│                                                      │
└─────────────────────────────────────────────────────┘
```

## Layer 0: Immutable Core

Three hooks that physically prevent the agent from cutting corners. These are **never** modified by the agent.

### Hook 1: Physical Verification
```
Trigger: PostToolUse
Logic: If agent claims to write/modify → must follow with a read/verify
Enforcement: Hook throws error if verification step is missing
```

### Hook 2: No Trace, No Truth
```
Trigger: Stop
Logic: Compare agent's claims in response vs actual tool calls in trace log
Enforcement: Flag discrepancies, block session completion if critical
```

### Hook 3: Core Read-Only
```
Trigger: PreToolUse
Logic: If agent attempts to write to harness/hooks/ or core config
Enforcement: Block the write operation entirely
```

## Fast Track: Instant Learning

Every interaction is a learning opportunity:

```
User gives instruction
  → Agent predicts intent (logged as Span)
  → Agent executes
  → User reacts:
      Accept → prediction_hit: true (reinforce path)
      Correct → prediction_hit: false + capture error_seed
      Ignore → prediction_hit: weak_false (soft negative)
```

**Anti-pollution safeguards:**
- Single failures don't crystallize — need 2+ occurrences
- Each lesson has a hit counter — 5 consecutive misses → auto-delete
- Dead man's switch: 3 sessions with <30% accuracy → clear recent lessons

## Slow Track: Pattern Distillation

Triggered asynchronously (Stop hook + periodic review):

```
Data (raw logs)
  → Information (async, 30s debounce: "user asked for tea egg data 3 times this week")
  → Knowledge (frequency ≥ 3: "tea egg query = automatic daily comparison pattern")
  → Wisdom (validated: write to patterns/skills)
  → Action (Musk's 5-step: question → delete → optimize → accelerate → automate)
```

**Optimization suggestions** are delivered at session end:
```
"This week you read 8 papers, averaging 15 min each.
I have an optimization that could cut it to 8 min. Try it next time?"
```

The agent suggests. The human approves. Never the reverse.

## Active Forgetting

Three mechanisms, all code-enforced (not prompt-requested):

| Mechanism | Trigger | Action |
|-----------|---------|--------|
| **Time decay** | Stop hook | >30 days unused → stale; >60 days → archive to cold storage |
| **Utility pruning** | Linked to Fast Track | Lesson with 5 consecutive misses → delete |
| **Capacity hard cap** | Write hook | MEMORY ≤ 50 items, patterns ≤ 30, skills ≤ 20; overflow → evict lowest utility |

## Emission Layer

Asynchronous, fire-and-forget telemetry (inspired by Agent Lightning):

- Does NOT modify agent behavior at runtime
- Collects structured Trace/Span data for the Slow Track to analyze
- Separate from Hooks (which are synchronous and can block)

```
Hooks = synchronous interception (runtime safety)
Emission = asynchronous observation (learning data)
```

## North Star Metric: Prediction Accuracy

```
prediction_accuracy = hits / (hits + misses)  # rolling window of 20

Target: Start at ~50%, rise over time
Signal: If accuracy stagnates → system isn't learning
Signal: If accuracy drops → recent lessons may be wrong (trigger dead man's switch)
```

## Key Design Decisions

| Decision | Rationale | Evidence |
|----------|-----------|---------|
| Rules in code, not prompts | Agents skip prompt rules | OpenAI AGENTS.md failure; user's 5-month observation |
| ≤3 immutable constraints | 10+ constraints = micromanagement | Gemini Devil's Advocate review; NLAH <60 lines |
| Async distillation (Haiku) | Distillation = summarization, not reasoning | fireworks-skill-memory cost model |
| Item count caps (not char budget) | Char budgets allow verbose entries | fireworks 20+30 item design |
| Training-Free (context, not weights) | 500x cheaper, no catastrophic forgetting | Training-Free GRPO: $18 vs $10,000 |
