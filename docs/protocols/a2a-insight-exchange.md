# A2A Compressed Insight Exchange Protocol (v0.1)

> **Status: RESERVED — 未实现**
> 来源: Hyperspace Prometheus (v5.9) — Agent 间交换洞察而非原始数据
> 当前: 仅本地产出洞察格式 (insights-exportable.jsonl)，无传输层
> 启动条件: 积累 50+ 条可导出洞察后评估

## Insight Types

| Type | Content | Source Layer |
|------|---------|-------------|
| skill_insight | Reusable procedures (sanitized) | L2 fixation |
| pattern_insight | Behavioral patterns | patterns.json |
| prediction_model | PAV calibration data | execution-log |
| tool_insight | Tool best practices/pitfalls | evolution-log |

## Schema (v0.1)

```json
{
  "schema_version": "0.1",
  "type": "skill_insight | pattern_insight | tool_insight",
  "domain": "supply_chain | scraping | dev_ops | memory_system",
  "summary": "≤100 chars",
  "confidence": {"alpha": 5, "beta": 2, "q_mean": 0.714},
  "privacy": {"contains_pii": false, "sanitized": true}
}
```

## Privacy Rules

Before exchange: remove names → roles, remove amounts → magnitudes, remove dates → relative time.
