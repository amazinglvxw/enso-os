<p align="center">
  <h1 align="center">Enso</h1>
  <p align="center"><strong>一个让 AI 从错误中学习的系统</strong></p>
  <p align="center"><em>不改模型，不花钱微调，10 个 Hook + DIKW 蒸馏管线。952 行代码。</em></p>
</p>

<p align="center">
  <a href="#问题是什么">问题</a> •
  <a href="#核心洞察">洞察</a> •
  <a href="#三层架构">架构</a> •
  <a href="#为什么叫-enso">哲学</a> •
  <a href="README.md">English</a>
</p>

---

## 问题是什么？

你的 AI 助手很聪明，但有一个致命缺陷：**每次对话开始，它都是一张白纸。**

上次犯的错，这次还会犯。你纠正过三次的习惯，第四次它还是忘。你说"记住这个"，它说"好的"，下次开机——忘了。

更糟的是，当你试图用文字规则约束它（"每次写完文件要验证"），它会**走捷径跳过**。不是它故意的，是 LLM 的物理特性——就像水总是往低处流，它总是走阻力最小的路径。

我们试过用 1600 行 Prompt 规则来管理记忆。结果：
- 规则越写越多，从 v4.0 到 v5.9，10 个版本升级
- 独立审计发现：大部分规则都在被跳过
- 预判系统写了 35 行规范，实际使用率 **0%**
- Q 值追踪设计了完美的 Beta 分布公式，实际是**空壳**

这就是"赛博盆景"——看起来精美，但没有根。

## 核心洞察

我们研究了 5 个顶级开源 AI Agent 项目（合计 15 万 Stars），发现一个共同规律：

> **规则写在 Prompt 里 = Agent 可以跳过。规则写在代码里 = Agent 无法跳过。**

这叫 **Harness Engineering**（SWE-agent, Princeton, NeurIPS 2024）。

- Prompt 规则 = 路边的"限速 60"牌子（司机可以无视）
- 代码 Hook = 物理减速带（车必须慢下来，没有选择）

## 快速开始

```bash
git clone https://github.com/amazinglvxw/enso-os.git
cd enso-os
bash install.sh

# 就这样。下次启动 Claude Code，Enso 自动生效。
```

安装后：
- `~/.enso/` 目录创建，包含 Hook、Trace、教训、DIKW 层
- 10 个 Hook 注册到 `~/.claude/settings.json`
- 下次会话：Enso 开始监视、学习、记忆

卸载：
```bash
rm -rf ~/.enso
# 然后从 ~/.claude/settings.json 中删除 enso 相关条目
```

## Enso 做三件事

1. **强制诚实**（你不能作弊）
2. **自动学习**（从错误中提取教训）
3. **记住教训**（下次开机就知道）

## 三层架构

```
你（用户）
  ↕ 对话
AI Agent（Claude）
  ↕ 每次工具调用都经过 Enso
┌─────────────────────────────────────────────┐
│              Enso Harness v0.2.0            │
│                                             │
│  🔒 不可变层（3个Hook，永不改变）            │ ← 地基
│  🧠 学习层（3个Hook，持续进化）              │ ← 建筑
│  💡 记忆层（1个Hook，注入三层 DIKW）         │ ← 窗户
│  🛡️ 守护层（3个Hook，安全防护）             │ ← 围墙
│  🔄 DIKW 蒸馏（异步: I→K→W 逐层提纯）      │ ← 进化
└─────────────────────────────────────────────┘
```

### 🔒 不可变层：地基

三个规则，写死在代码里，AI **物理上无法违反**：

**写了就必须验证**
```
AI说"文件已写好" → Hook检查：你真的读回来验证了吗？
没验证 → 会话结束时报警
```
就像建筑验收：你说墙砌好了，监理必须亲自看一眼。

**不能改自己的规则**
```
AI试图修改Enso的Hook脚本 → 系统直接阻止
```
就像宪法不能被普通法律修改。这个 Hook 在真实使用中验证过——它真的阻止了 AI 修改自己。

**没有痕迹就没有真相**
```
会话结束 → 审计：调用了多少工具？多少次出错？有文件没验证？
```
不管 AI 说什么，数据说了算。

### 🧠 学习层：建筑

**Trace 记录器**（每次工具调用自动触发）
```
AI执行成功操作 → 自动记录：什么工具、什么文件、耗时多久
```

**错误种子捕获器**（工具调用失败时触发）
```
AI操作失败 → 自动捕获为"错误种子"，存入种子池（上限20条/会话）
```
这是"训练数据管道"——不是 AI 选择记录，是代码自动记录。

**教训蒸馏器 + DIKW I 层**（会话结束时触发）
```
有错误种子吗？
  没有 → 什么都不做（顺利不需要学习）
  有 → 调用轻量模型提取教训 + 分类标签：
       "读大文件时用offset/limit参数，别一次性全读" [CATEGORY: file-io]
     → TF-IDF 语义去重（cosine ≥ 0.7 视为重复）
     → 双写：lessons/active.md + dikw/info-layer.jsonl
     → 效用追踪：同类教训加载后仍犯错 → miss_streak+1；不犯错 → hits+1
```

**只有犯了错才学习，顺利不记。**

### 💡 记忆层：窗户

**教训加载器**（每次新会话启动时触发）
```
上次学到的教训 → 自动注入AI的上下文，分三层：

<enso-lessons>          ← 原始教训（I层）
- 读大文件时用offset/limit参数
- 用find -exec替代xargs处理大量文件

<enso-knowledge>        ← 合并后的知识规则（K层）
- [file-io] 读写大文件时必须用offset/limit分片，避免token溢出

<enso-wisdom>           ← 验证过的永久规则（W层）
- [VERIFIED] 浏览器DOM操作前必须null-check，防止渲染器冻结
```
AI 一开机就知道之前学了什么——从原始教训到验证过的智慧，三层递进。

### 🔄 DIKW 异步蒸馏（v0.2.0 新增）

教训不是堆积如山，而是**逐层提纯**：

```
错误种子 → I层(教训) → K层(知识) → W层(智慧)
  每次会话     ≥3条同类合并     ≥30%错误降低
  有错才蒸馏    每日凌晨2点      每周日凌晨3点
```

| 层 | 存储 | 生命周期 | 淘汰规则 |
|----|------|---------|---------|
| **I层 (Information)** | info-layer.jsonl | 每次会话产出 | miss_streak ≥ 5 或 60天无hit → 自动清除 |
| **K层 (Knowledge)** | knowledge.json | 每日异步合并 | I层 ≥3 条同类 → LLM 合并为1条规则 |
| **W层 (Wisdom)** | wisdom.json | 每周验证晋升 | K层规则导致同类错误降低 ≥30% → 永久晋升 |

**核心工具：dikw-utils.py**（纯标准库，零外部依赖）
- 7 个 CLI 子命令：`semantic_dedup` / `categorize` / `update_utility` / `append_info` / `merge_to_knowledge` / `prune_stale` / `sync_active_md`

### 🛡️ 守护层：围墙

- **记忆预算守卫**：MEMORY.md 超过 6000 字符 → 阻止写入
- **安全扫描**：检测 API 密钥、密码、注入攻击 → 阻止
- **自动维护**：容量检查 + 过时标记 + 预算预警

### 核心循环

```
AI犯错 → 代码自动捕获 → 蒸馏成教训(I层)
  → 同类合并成知识(K层) → 验证晋升为智慧(W层) → 下次自动加载 → 行为改变
```

这个循环的每一步都是代码强制的。不是 AI "选择"去学习，是系统**让它必须**学习。

## 和 1600 行 Prompt 规则比

| | v5.9（旧） | Enso v0.2.0（新） |
|---|---|---|
| 规则位置 | Prompt 里（可以跳过） | 代码里（无法跳过） |
| 规则行数 | 1605 行 | **952 行**（含 DIKW 工具库） |
| Token 消耗/会话 | ~23,000 | **~900** |
| 未实现的空壳 | 多个 | **0 个** |
| 学习能力 | 理论上有 | **10 个 Hook + DIKW 三层蒸馏** |
| 教训管理 | 堆积不淘汰 | **效用追踪 + 自动合并 + 过期清除** |

## 研究基础

基于 100+ 篇论文、5 个月日常使用提炼：

| 来源 | 核心洞察 |
|------|---------|
| [OpenAI Harness Engineering](https://openai.com/index/harness-engineering/) | 规则写在代码里，不写在文档里 |
| [Agent Lightning (Microsoft)](https://github.com/microsoft/agent-lightning) | Trace/Span 分层日志 + Hook/Emission 双层 |
| [fireworks-skill-memory](https://github.com/yizhiyanhua-ai/fireworks-skill-memory) | 200 行 Hook > 800 行 Prompt 规则 |
| [SWE-agent (Princeton, NeurIPS 2024)](https://github.com/SWE-agent/SWE-agent) | 受约束的接口大幅降低错误率 |
| [Training-Free GRPO (Tencent)](https://arxiv.org/abs/2503.04735) | $18 上下文优化 > $10,000 微调 |

## 为什么叫 Enso？

禅书法里的"圆相"（ensō）——一笔画成的不完美圆圈。

**不完美是美的** —— 这个系统永远不会完美。
**持续循环** —— 错误 → 学习 → 改进 → 新错误 → 更好的学习。
**约束即自由** —— 3 条不可变规则是地基，地基之上可以自由建造。

这不是一个哲学隐喻。这是一个工程选择：

- 3 个不可变 Hook = **地基**（永不动摇）
- 学习 + 记忆 Hook = **地基上的建筑**（随时改建）
- 主动遗忘 = **拆除老旧**（腾出空间）
- 北极星 = **城市规划方向**（越来越懂你）

就像生物进化：DNA 提供不可变约束（蛋白质折叠的物理定律），但在这些约束之内，生命找到了无穷的创造性解法。

## 生存实验

这个项目有一个独特的属性：**它的 GitHub 指标就是它的进化适应度信号。**

- ⭐ Star = "这个系统有用"（生存验证）
- 🍴 Fork = "我要基于它构建"（繁衍）
- 🐛 Issue = "这里有问题"（选择压力）
- 🔀 PR = "这是一个更好的变异"（有益突变）
- 无人问津 = 被淘汰（自然选择）

我们研究了 5 个最大的开源 Agent 项目——OpenHands (7万星), Goose (3.4万), SWE-agent (1.9万), Deep Agents (1.8万), Cognee (1.5万)——**没有一个能从错误中学习**。Enso 是唯一一个。

如果它好用，它会被 Star。如果不好用，它会被遗忘。自然选择。

## 兼容性

- Claude Code（主要目标，已全面测试）
- 任何支持生命周期 Hook 的 AI Agent

**依赖**：bash, python3。就这些。

## 贡献

见 [CONTRIBUTING.md](CONTRIBUTING.md)。最有价值的贡献：

- 带复现步骤的 Bug 报告
- 新的 Hook 创意
- 与其他 Agent 的兼容性测试

## 许可

MIT License. 见 [LICENSE](LICENSE).

---

<p align="center">
  <em>禅书法中，圆相一笔画成。<br>
  它代表不完美之美，和永不停止的改进循环。<br>
  这个系统永远不会完美。但它会一直进化。</em>
</p>
