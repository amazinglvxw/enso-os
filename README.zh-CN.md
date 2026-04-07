<p align="center">
  <img src="docs/assets/hero-banner.png" alt="Enso — 自进化 AI Agent Harness" width="100%">
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="MIT"></a>
  <a href="#"><img src="https://img.shields.io/badge/代码量-1267行-brightgreen" alt="1267 LOC"></a>
  <a href="#"><img src="https://img.shields.io/badge/Hook-10个-orange" alt="10 Hooks"></a>
  <a href="#"><img src="https://img.shields.io/badge/依赖-bash%20%2B%20python3-blue" alt="bash + python3"></a>
</p>

<p align="center">
  <a href="#快速开始">快速开始</a> •
  <a href="#怎么工作的">原理</a> •
  <a href="#架构">架构</a> •
  <a href="#遗忘">遗忘</a> •
  <a href="#健康检查">检查</a> •
  <a href="README.md">English</a>
</p>

---

**你的 AI 助手犯了同一个错两次。Enso 确保没有第三次。**

30 秒安装。只需 bash + python3（macOS/Linux 自带）。你的 Agent 自动开始学习。

<p align="center">
  <img src="docs/assets/demo-flow.png" alt="Enso: Session 1 犯错 → Session 2 学会了" width="85%">
</p>

## 快速开始

```bash
git clone https://github.com/amazinglvxw/enso-os.git
cd enso-os && bash install.sh
```

**就这样。** 开始新的 Claude Code 会话，Enso 自动生效：

```
会话 1:  你遇到一个错误 → Enso 自动捕获
         会话结束 → Enso 从错误中蒸馏 1-3 条教训

会话 2:  Enso 注入教训 → Agent 自动避免同样的错误
         你什么都不用做。系统自己学会了。
```

## Enso vs 三大 Agent

我们深入研究了 Claude Code、OpenClaw、Hermes Agent 的记忆和学习机制后构建了 Enso。以下是坦诚的对比——**他们比我们强的地方，以及我们有而他们没有的。**

| 能力 | Claude Code | OpenClaw | Hermes (30K⭐) | **Enso** |
|------|:-:|:-:|:-:|:-:|
| **从错误中学习** | ❌ | ❌ | ✅ 自动创建技能 | ✅ 代码强制 |
| **主动遗忘** | 200行静默截断 | ❌ | ❌ 只增不减 | ✅ 衰减+LRU+检查 |
| **上下文压缩** | ✅ 5层管线 | ✅ Compaction | ❌ | ❌ 依赖宿主Agent |
| **睡眠整合** | ✅ AutoDream 4阶段 | ✅ Light→REM→Deep | ❌ | 部分(DIKW蒸馏) |
| **自我保护** | ❌ Agent可改记忆 | ❌ | ❌ | ✅ 不可变Hook |
| **知识质量检查** | ❌ | ❌ | ❌ | ✅ 每周Lint |
| **代码量** | ~512K行 TS | ~50K行 | ~50K行 Python | **1267行** |
| **依赖** | Node.js | Node.js+插件 | Python+RL框架 | **bash+python3** |

### 他们比我们强的地方（坦诚说）

**Claude Code** 有最强的上下文压缩——5层管线(工具结果预算→snip压缩→微压缩→上下文折叠→自动摘要)。Enso 不做上下文压缩，依赖 Claude Code 自身的。

**OpenClaw** 有最优雅的记忆晋升——Dreaming 三阶段(Light→REM→Deep) + 6维加权评分。暂存区设计防止了记忆碎片化。Enso 的写入更激进，可能产生重复。

**Hermes Agent** 自进化走得最远——使用轨迹 → RL 训练 → 微调模型。还有混合专家工具(4个前沿模型并行)和技能市场。Enso 不修改模型权重。

### 我们有而他们没有的

**1. 代码强制学习（不是可选的）** — 他们三个的学习都是 Agent 自主发起的（模型决定是否记住）。Enso 的 Hook 是代码强制的——Agent 物理上无法跳过。我们的 Agent 在修 bug 时试图修改自己的安全 Hook——被自己拦住了。

**2. 主动遗忘 + 质量验证** — Claude Code 200行静默截断，Hermes 技能只增不减。Enso 主动修剪：37天衰减、50条LRU淘汰、每周 Lint 检查矛盾/孤岛/重复。

**3. 不可变自我保护** — 没有一个主流 Agent 能阻止自己修改自己的规则。Enso 的 3 个不可变 Hook 是代码级约束。

**4. 极致简单** — 1267行。不需要 npm、pip、Docker、数据库。全部是可 grep 搜索的文本文件。

### Enso 的定位

Enso **不是** Claude Code/OpenClaw/Hermes 的替代品。是**补充层**——包裹在你现有 Agent 外面，添加学习、遗忘和自我保护。

```
你的 Agent（Claude Code / OpenClaw / 任何）
       ↕ 每次工具调用经过 Enso
┌──────────────────────────────────────┐
│           Enso Harness               │
│  🔒 不能跳过  🧠 自动学习  🗑️ 主动遗忘  │
└──────────────────────────────────────┘
```

当前针对 Claude Code 优化。架构可移植到任何支持生命周期 Hook 的 Agent。

## 怎么工作的

<p align="center">
  <img src="docs/assets/architecture.png" alt="Enso 架构" width="85%">
</p>

**10 个 Hook，4 层架构。** 代码强制执行，Agent 无法跳过。

| 层 | Hook 数 | 做什么 |
|----|---------|--------|
| 🔒 **不可变** | 3 | 写→必须验证。不能改自己的规则。会话结束审计。 |
| 🧠 **学习** | 3 | 记录每次工具调用。捕获错误。LLM 蒸馏教训。 |
| 💡 **记忆** | 1 | 下次会话注入教训+知识+智慧。 |
| 🛡️ **守护** | 3 | 记忆预算上限。拦截密钥/注入。自动维护。 |

**核心循环：**
```
错误 → 捕获（代码强制）→ 蒸馏（异步）→ 存储 → 下次注入 → 避免
```

不是 Agent "选择"学习。是系统**让它必须**学习。

## 遗忘

大多数记忆系统只增长。Enso 主动遗忘——因为不遗忘比遗忘更危险。

| 机制 | 做什么 |
|------|--------|
| 过时衰减 | 教训 >37 天未使用 → 删除 |
| LRU 淘汰 | 超过 50 条 → 淘汰最旧 |
| MEMORY.md 下沉 | 已完成项 → 归档 |
| Trace 轮转 | >14 天 → 删除 |
| 恢复安全网 | 删除的教训再次出错 → 标记复查 |

## 健康检查

`enso-lint.sh` 每周运行——知识库的 CI/Lint：

| 检查项 | 发现什么 |
|--------|---------|
| 孤岛 | 从未使用的教训 (hits:0, >7天) |
| 重复 | 关键词重叠 >60% |
| 弱教训 | 没有动作词——不可执行 |
| 预算 | MEMORY.md 容量状态 |

每次蒸馏自动重建 `lessons/INDEX.md` 索引。

## 架构

```
~/.enso/
├── core/                          # 共享模块
│   ├── env.sh                     # 路径、enso_parse()、enso_find_memory_file()
│   ├── parse-hook-input.py        # 所有 Hook 的 JSON 解析器
│   ├── dikw-utils.py              # DIKW 操作（7 个子命令）
│   ├── enso-lint.sh               # 🔍 每周健康检查
│   ├── rebuild-index.py           # 📇 自动重建 INDEX.md
│   └── deleted-lessons-tracker.py # 🔄 恢复安全网
├── hooks/                         # 10 个生命周期 Hook
│   ├── pre-tool-use/              # 🔒🛡️
│   ├── post-tool-use/             # 🔒🧠
│   ├── post-tool-use-failure/     # 🧠
│   ├── stop/                      # 🔒🧠🛡️
│   └── session-start/             # 💡
├── dikw/                          # DIKW 蒸馏（信息→知识→智慧）
├── traces/                        # 工具调用日志 + 检查报告
└── lessons/                       # active.md + INDEX.md
```

<details>
<summary><strong>哲学："约束是灵活的地基"</strong></summary>

像生物进化：DNA 提供不可变约束（蛋白质折叠物理定律），但在约束之内，生命找到无穷的创造性解法。

- **3 个不可变 Hook** = 地基（永不改变）
- **其他一切** = 自由进化
- **主动遗忘** = 防止僵化

基于 100+ 篇论文、5 个月日常使用提炼：

| 来源 | 核心洞察 |
|------|---------|
| [OpenAI Harness Engineering](https://openai.com/index/harness-engineering/) | 规则写在代码里 |
| [Agent Lightning (Microsoft)](https://github.com/microsoft/agent-lightning) | Trace/Span + Hook/Emission 双层 |
| [fireworks-skill-memory](https://github.com/yizhiyanhua-ai/fireworks-skill-memory) | 200 行 Hook > 800 行 Prompt |
| [SWE-agent (NeurIPS 2024)](https://github.com/SWE-agent/SWE-agent) | 受约束的接口降低错误率 |

</details>

<details>
<summary><strong>生存实验</strong></summary>

这个项目的 GitHub 指标就是它的进化适应度信号：

- ⭐ Star = "有用"（生存验证）
- 🍴 Fork = "我要基于它构建"（繁衍）
- 🐛 Issue = "这里有问题"（选择压力）

维护这个仓库的 Agent 监控这些信号。好用就活，不好用就死。

</details>

## FAQ

**Q: 支持什么 AI Agent？**
Claude Code（主要目标，全面测试，每日 dogfooding）。架构可移植到任何支持生命周期 Hook 的 Agent，但 install.sh 目前只配置 Claude Code。

**Q: 数据存在哪？**
100% 本地。`~/.enso/` 在你的机器上。无云、无 Docker、无数据库。

**Q: 和 Mem0 / LangChain Memory 有什么区别？**
它们存事实。Enso 从错误中学习——并遗忘不再有用的东西。

**Q: 前提条件？**
`bash` 和 `python3`（3.6+）。macOS 和大多数 Linux 发行版自带。不需要 pip、npm、Docker。

**Q: 安装后需要配置什么？**
不需要。`bash install.sh` 注册所有 Hook。下次会话自动开始学习。

## 贡献

见 [CONTRIBUTING.md](CONTRIBUTING.md)。最有价值的贡献：
- 🐛 带复现步骤的 Bug 报告
- 💡 新的 Hook 创意
- 🧪 与其他 Agent 的兼容性测试

## 许可

MIT。见 [LICENSE](LICENSE)。

---

<p align="center">
  <em>禅书法中，圆相一笔画成——不完美、不完整、美。<br>
  这个系统永远不会完美。但它会一直进化。</em>
</p>
