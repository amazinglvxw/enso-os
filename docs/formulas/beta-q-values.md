# Beta Distribution Q-Values (from v5.9)

> 概率化效用追踪。v6.0 中 scoreboard.json 仍用简单 Q_scalar，Beta 分布为升级路径。

```
Q_beta = Beta(α, β)
  α = successes + 1 (prior)
  β = failures + 1 (prior)
  Q_mean = α / (α + β)
  Q_var = αβ / ((α+β)²(α+β+1))

Initial: α=1, β=1 → Q_mean=0.5 (uniform, maximum uncertainty)

Updates:
  Success: α += 1
  Failure: β += 1
  Partial: α += 0.5, β += 0.5
  Cross-scenario reuse: α += 1.5 (generalization bonus)

Deprecation: Q_mean < 0.3 AND α+β ≥ 7
Needs review: Q_var > 0.05 AND α+β ≥ 5
```

## UCB Skill Selection

```
Score(s) = Q_mean(s) + c × √(Q_var(s) + ln(T) / n(s))
c = 2.0, T = total interactions, n(s) = skill s usage count
```
