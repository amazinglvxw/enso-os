# PAV (Predict-Act-Verify) Specification

> **Status: ARCHIVED — v6.0 搁置**
> 原因: 50 条 execution-log 采样中 0 条含 `prediction_hit` 字段。0% 实现率。
> 来源: Hyperspace Prometheus (v5.9) — 理论正确但未落地执行
> 决策: 与其保留空壳规范污染 context window，不如诚实归档。
> 恢复条件: 当 Enso trace 系统成熟后，可在 Hook 层重新实现预判追踪。

## 原始设计（来自 v5.9 memory-management.md）

### 三步闭环

1. **Predict**: 技能执行前预测结果 (predicted_outcome, predicted_status, confidence)
2. **Act**: 正常执行
3. **Verify**: 对比预测与实际 (prediction_hit: true/false)

### 校准效应
- 连续 3 次准确 → 置信度基线上调
- 连续 3 次偏差 → 技能需 review

### execution-log 字段
- `predicted_status`: success/partial/fail
- `predicted_outcome`: ≤50 字描述
- `prediction_hit`: boolean

## 为什么搁置

1. **赛博盆景**: 规范写了但从未执行 = "飞球调速器没有连接到蒸汽机"
2. **Prompt 层不可靠**: 要求 Agent 在每次技能执行前"在心理暂存区预测" — Agent 走捷径跳过
3. **正确的实现路径**: 应该在 Enso Hook 层实现 (PostToolUse 自动记录预测 vs 实际)，而非 Prompt 层
