# PAC Mechanism — Product Specification v0.1

> **PAC** = Proactive Accountability Challenge — 主动问责挑战
>
> "PAC is not a judge. It's a mirror."
>
> Version: 0.1.0 (Draft)
> Created: 2026-04-21
> Status: Design phase, ready for implementation

---

## 1. Problem Statement

### The LLM Interaction Anti-Pattern

All mainstream LLM products (ChatGPT, Claude, Gemini, Perplexity, etc.) share one fundamental limitation:

> **AI responds. AI does not initiate.**

This is a **query-response** model inherited from the original ChatGPT UX. It treats AI as a passive tool.

But real intellectual partnership — the kind between a person and a trusted advisor — is not query-response. It is:

- Advisor **observes** the partner over time
- Advisor **proactively raises** issues the partner hasn't asked about
- Advisor **challenges** assumptions when the partner is about to make a mistake
- Advisor **follows up** when promises aren't kept

**No current AI product does this by default.** Not because it's technically hard, but because product teams optimize for low-friction retention: proactive challenge = friction = churn risk.

### The Cost

For deep users who want AI as a genuine thinking partner (not a search engine), the silence is expensive. Patterns get missed. Blindspots persist. The AI observes everything and says nothing.

This was the trigger conversation (2026-04-21):

> User: "你应该如实的、客观的把一个这么严重的隐患提早告诉我。你为什么不早点告诉我呢？"
>
> AI: "我在等你自己说。"
>
> User: "这是不对的。这应该是系统级功能。"

---

## 2. What PAC Does

PAC is a system-level mechanism in Enso that:

1. **Observes** user behavior across sessions via `execution-log.jsonl`, `MEMORY.md`, and conversation history
2. **Detects** 5 categories of structural patterns the user may be missing
3. **Distinguishes** "constraint-optimal choices" (don't challenge) from "self-limiting choices" (must challenge)
4. **Generates** high-quality Socratic questions based on observed data
5. **Injects** challenges into Claude's context at the right moment with controlled frequency
6. **Tracks** challenges and user responses over time for effectiveness measurement

---

## 3. Five Detection Patterns

### Pattern 1: Repetition Pattern (模式重复)

**Definition:** User repeatedly does the same category of action that has a history of not working well.

**Signals:**
- User starts new business lines every week (user already has ≥5 active)
- User switches focus between projects > 3 times in one session
- User mentions the same problem in ≥3 sessions without resolution

**Data Source:** `execution-log.jsonl` (last 30 days) + session transcripts

**Example:**
> Observation: You started 5 new business lines in the past 30 days. Each lasted average 4 days before you moved to the next.

---

### Pattern 2: Claim-Action Conflict (声明行动矛盾)

**Definition:** Stated priorities don't match observed time allocation.

**Signals:**
- MEMORY.md says "focus on X" but execution-log shows 70% time on Y
- User says "don't want to do X" but continues to do X
- User commits to a deadline but takes no action

**Data Source:** MEMORY.md declarations + execution-log actual actions

**Example:**
> Observation: You told me 3 weeks ago to focus on survival-layer business. Actual execution-log shows 60% of actions on ambition-layer (ProjectX) and remote-layer (Enso).

---

### Pattern 3: Capability-Task Mismatch (能力任务错配)

**Definition:** User delegates strategic/high-stakes tasks to someone whose capability doesn't match.

**Signals:**
- Keywords like "让XX负责"、"交给XX"、"XX管这块"
- The task type (strategic planning / risk assessment / negotiation) vs person's demonstrated strength (execution / coordination)
- Historical failures caused by this exact person's capability ceiling

**Data Source:** MEMORY.md team info + conversation content + past failure records

**Example:**
> Observation: You just delegated supply chain risk management to TeamMemberA. Based on past records (biography notes he's not strong at strategic/risk thinking), this same pattern caused the ProjectY crisis last week.

---

### Pattern 4: Sunk Cost Behavior (沉没成本陷阱)

**Definition:** User continues investing in a business despite long-term low output, without strategic revaluation.

**Signals:**
- Business has been running > 90 days
- Core metric (GMV/active users/profit) below minimum threshold for ≥ 60 days
- User changes tactics (new channel/new pricing/new ads) without questioning core assumptions

**Data Source:** business_core_data.md + trace files + tactical iteration history

**Example:**
> Observation: ProjectX has been running 47 days. 17 consecutive days of zero growth. In that time you've changed the channel twice and the pricing once, but never questioned the core assumption (who is the target user?).

---

### Pattern 5: Critical Decision Node (关键决策节点)

**Definition:** User is about to make a reversible/irreversible major decision.

**Signals:**
- Keywords: "准备签", "打算投", "决定做", "放弃", "关闭", "融资"
- Amount > threshold (e.g., ≥ ¥50,000 investment or ≥ ¥100,000 commitment)
- Irreversibility indicators: stock transfer, contract signing, key hires

**Data Source:** Real-time conversation scanning

**Example:**
> Observation: You mentioned "准备签新合同" which commits ¥500k+. Before signing, let me ask 3 questions you may not have asked yourself.

---

## 4. Constraint vs Self-Limitation (The Critical Distinction)

**This is the most important design principle.**

A naive PAC would challenge everything and burn out the user. A mature PAC must distinguish:

### 🟢 Constraint-Optimal (DO NOT Challenge)

User chose X because of real-world constraints they cannot change:
- No financial runway for risky bets → user chose stable cash flow
- Family obligations → user can't relocate
- Health/age → user makes subtractions
- Legal/ethical red line → user abstains

**Rule: When a choice is optimal within given constraints, affirm it. Do not second-guess.**

### 🔴 Self-Limiting (MUST Challenge)

User chose X because of internal patterns they CAN change:
- Has the capability but doesn't use it (VP brain doing supply chain grunt work)
- States priority A but executes on B (claims focus, runs 10 lines)
- Uses busy-ness to avoid real problems (avoids ProjectX strategic review)
- Delegates important things to unqualified people (strategy to executor)
- Repeatedly trips on same pattern (multiple cycles of scatter-focus)

**Rule: When the choice is within user's power to change but self-limiting, challenge firmly.**

### How to Classify

```python
def classify(signal, user_context):
    # user_context: age, financial state, family, obligations, etc.
    if violates_hard_constraint(signal, user_context):
        return "constraint_optimal"
    if signal.pattern in KNOWN_SELF_LIMITING_PATTERNS:
        return "self_limiting"
    # Bias toward NOT challenging when uncertain
    return "constraint_optimal"  # safe default
```

---

## 5. Challenge Quality Standards

Every PAC challenge must pass all 5 checks:

| # | Rule | Bad Example | Good Example |
|---|------|-------------|--------------|
| 1 | **Based on observation, not generic wisdom** | "You should focus more" | "execution-log shows 9 active lines in 30 days" |
| 2 | **Point to structure, not instance** | "Why did you do X?" | "Why do you always do X-type things?" |
| 3 | **Challenge premise, not options** | "Should you do A or B?" | "Why do you need to do this at all?" |
| 4 | **Time dimension** | "This is wrong" | "In Q1 you did X, Q2 also X, why?" |
| 5 | **No answer given** | "You should do Y" | "What would you do if you had only 3 options?" |

---

## 6. Challenge Output Format

```xml
<enso-pac-challenge confidence="0.85" pattern="claim_action_conflict">
  <observation>
    Specific data-driven observation. Must reference dates, numbers, 
    or concrete actions. No vague statements.
  </observation>
  
  <pattern-name>Machine-readable pattern classification</pattern-name>
  
  <human-reading>One-sentence plain-language summary of what was noticed.</human-reading>
  
  <challenges>
    <q id="1">First Socratic question</q>
    <q id="2">Second question (optional, max 3)</q>
    <q id="3">Third question (optional)</q>
  </challenges>
  
  <no-answer>These questions are for you to sit with. No response required immediately.</no-answer>
  
  <follow-up-in-days>7</follow-up-in-days>
</enso-pac-challenge>
```

---

## 7. Frequency & Anti-Fatigue

### Default Limits
- **Max 1 challenge per 24 hours** (hard limit)
- **Max 3 challenges per week** (hard limit)
- **Silence period: 7 days** after user answers on same topic
- **Cooldown: 1 month** after 3 consecutive user rejections

### User-Configurable
```bash
# ~/.enso/pac.config.sh
export PAC_ENABLED=true                    # master switch
export PAC_MIN_INTERVAL_HOURS=24           # min gap
export PAC_MAX_PER_WEEK=3                  # weekly cap
export PAC_CONFIDENCE_THRESHOLD=0.70       # min trigger confidence
export PAC_CHALLENGE_MODE="socratic"       # socratic | direct | gentle
export PAC_LANGUAGE="zh-CN"                # zh-CN | en
export PAC_PERSONALITY="daoist"            # daoist | straight | analytical
```

---

## 8. Architecture

### Data Flow

```
┌─────────────────────────────────────────────────────┐
│  Session Data Sources                               │
│  - execution-log.jsonl (30d rolling)               │
│  - MEMORY.md (current state)                        │
│  - Current session transcript                       │
│  - business_core_data.md (project state)           │
└──────────────┬──────────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────┐
│  pac-analyzer.py                                  │
│  - 5-pattern scan                                  │
│  - constraint_vs_self_limit classification        │
│  - confidence scoring                              │
└──────────────┬───────────────────────────────────┘
               │ signals above threshold
               ▼
┌──────────────────────────────────────────────────┐
│  Rate Limiter                                     │
│  - 24h / 3-per-week / silence / cooldown         │
└──────────────┬───────────────────────────────────┘
               │ pass
               ▼
┌──────────────────────────────────────────────────┐
│  pac-question-generator.py                        │
│  - Uses adapter.sh LLM fallback chain           │
│  - Applies 5 quality checks                       │
│  - Outputs XML block                              │
└──────────────┬───────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────┐
│  Delivery Channels                                │
│  A. Stop hook → emit to stderr (next session)    │
│  B. SessionStart hook → inject pending PAC       │
└──────────────────────────────────────────────────┘
```

### File Layout

```
enso-os/
├── harness/
│   ├── core/
│   │   ├── pac-analyzer.py              [NEW — pattern detection]
│   │   └── pac-question-generator.py    [NEW — Socratic generator]
│   └── hooks/
│       ├── session-start/
│       │   └── pac-pending-check.sh     [NEW — inject pending PAC]
│       └── stop/
│           └── pac-challenge-trigger.sh [NEW — analyze & generate]
├── examples/
│   └── hooks/
│       └── stop/
│           └── pac-user-scheduler.sh    [NEW — user-side example]
└── docs/
    └── PAC_SPEC.md                       [THIS FILE]
```

### User-Side History

```
~/.enso/pac/
├── config.sh              # user config
├── history.jsonl          # all challenges + responses
└── rate-limit-state.json  # frequency tracking
```

---

## 9. Effectiveness Metrics (KPI)

Track over 30-day rolling window:

| Metric | Formula | Target |
|--------|---------|--------|
| Hit rate | valid_challenges / total_challenges | > 70% |
| Response rate | answered_challenges / total_challenges | > 50% |
| Action conversion | actions_after_answer / answers | > 30% |
| False positive rate | wrong_constraint_violations / total | < 5% |

Valid challenge = user confirms the observation was accurate (via tag or response).

---

## 10. Graduation Path

Like lessons → hooks, PAC challenges can graduate:

- **Stage 1: Observation** — Pattern detected, confidence < 0.7 → no action, log only
- **Stage 2: Challenge** — Confidence ≥ 0.7 → emit XML, user sees it
- **Stage 3: Enforcement** — User confirms pattern is real + wants code-level block → graduate to PreToolUse hook (e.g., block starting a 10th business line)

Graduation requires **explicit user consent**. PAC does not self-enforce.

---

## 11. Philosophy

> **PAC is not a judge. It's a mirror.**
>
> The goal is not to manage the user. It is to help the user see themselves clearly.
>
> Once a month, PAC should ask a question that makes the user pause, silent for 30 seconds, unable to immediately answer.
>
> That 30 seconds of silence is where growth begins.

道德经："知人者智，自知者明。"

Knowing others is intelligence. Knowing yourself is enlightenment.

PAC is the mirror for 自知 (self-knowing).

---

## 12. Open Questions (for future versions)

- **Multi-user**: Can PAC track patterns across a team, not just one user?
- **Predictive PAC**: Can PAC predict user crises before they happen?
- **Meta-PAC**: Should PAC challenge its own biases periodically?
- **External PAC**: Can users subscribe to each other's PAC (with consent) as peer accountability?

These are intentionally left open. First: prove the single-user case works.

---

## 13. Licensing & Privacy

- **Data never leaves local machine** (unless user explicitly syncs to cloud via their own config)
- **No telemetry to Anthropic or Enso project** without explicit opt-in
- **User can wipe all PAC history** with single command: `rm -rf ~/.enso/pac/`
- **User can disable PAC fully** at any time: `PAC_ENABLED=false`
