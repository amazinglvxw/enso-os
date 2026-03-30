# Dynamic Strength Formula (from v5.0)

> 记忆衰减公式。v6.0 中概念保留，详细实现归档于此。

```
strength(t) = decay × retrievalBoost × emotionalMultiplier × usageFeedback

decay = 0.5 ^ (daysSinceLastAccess / half_life_days)
retrievalBoost = 1 + 0.1 × log2(retrieval_count + 1)
emotionalMultiplier: neutral=1.0 | positive=1.3 | negative=1.5 | critical=2.0
usageFeedback = (helpful + 1) / (helpful + harmful + 2)  # Laplace smoothing
```

## Half-Life Rules

| Type | Default | Notes |
|------|---------|-------|
| Business state | 14 days | Active business needs frequent updates |
| Financial numbers | 7 days | Prices change fast |
| Decisions | 30 days | Major decisions persist |
| Relationships | 60 days | Relationships change slowly |
| Errors/lessons | base × 2 | Painful lessons last longer |
| Pinned/CORE | ∞ | Never decay |

## Thresholds

- `strength < 0.1` → auto-archive to mem0 + delete from MEMORY.md
- `strength < 0.3` → mark ⏰ for review
- `strength > 0.7` → stable, no intervention needed
