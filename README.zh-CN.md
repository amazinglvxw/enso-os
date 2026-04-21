<p align="center">
  <img src="docs/assets/hero-banner.svg" alt="Enso — 自进化 AI Agent 纪律系统" width="100%">
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="MIT"></a>
  <a href="#"><img src="https://img.shields.io/badge/版本-0.7.0-brightgreen" alt="v0.7.0"></a>
  <a href="#"><img src="https://img.shields.io/badge/Hook-12个-orange" alt="12 Hooks"></a>
  <a href="#"><img src="https://img.shields.io/badge/依赖-bash%20%2B%20python3-blue" alt="bash + python3"></a>
  <a href="#pac-主动问责挑战-v070-新增"><img src="https://img.shields.io/badge/新增-PAC主动问责-ff69b4" alt="PAC 机制"></a>
</p>

<p align="center">
  <a href="#快速开始">快速开始</a> •
  <a href="#pac-主动问责挑战-v070-新增"><strong>PAC 🪞</strong></a> •
  <a href="#enso-提供什么">定位</a> •
  <a href="#怎么工作的">原理</a> •
  <a href="README.md">English</a>
</p>

---

## Enso 是第一个会主动开口的 AI 插件。

目前所有主流 LLM 产品——ChatGPT、Claude、Gemini、Perplexity——都建立在同一个反模式上：**AI 回应，AI 从不主动发起。** 它看到你的错误保持沉默。它发现你的自我限制模式等你来问。

Enso 打破这个沉默。作为 AI Agent 的纪律插件，它提供三样主流 AI 产品默认都不做的事：

1. **代码强制学习** —— 错误变成 Hook，不写进 Prompt。不犯第三次。
2. **主动遗忘** —— 过时知识自动修剪。不是所有记忆都值得保留。
3. **🪞 PAC 主动问责挑战** —— AI 主动提出 *你自己没问* 的问题。

<p align="center">
  <img src="docs/assets/demo-flow.svg" alt="Enso: 会话 1 犯错 → 会话 2 学会了" width="85%">
</p>

## 快速开始

```bash
git clone https://github.com/amazinglvxw/enso-os.git
cd enso-os && bash install.sh
```

安装脚本自动检测你的 Agent，也可以手动指定目标：

```bash
bash install.sh --target claude-code    # Claude Code（默认）
bash install.sh --target gemini-cli     # Gemini CLI
bash install.sh --target hermes         # Hermes Agent
bash install.sh --target openclaw       # OpenClaw
bash install.sh --target generic        # 通用模式（任何支持 Hook 的 Agent）
```

**就这样。** 开始新会话，Enso 自动生效：

```
会话 1:  你遇到一个错误 → Enso 自动捕获
         会话结束 → Enso 从错误中蒸馏 1-3 条教训

会话 2:  Enso 注入教训 → Agent 自动避免同样的错误
         你什么都不用做。系统自己学会了。
```

## PAC 主动问责挑战 (v0.7.0 新增)

> *"PAC 不是法官，是镜子。"*

所有主流 LLM 都是 **询问—回应** 模式。你问，AI 答。你不问的盲点，AI 不会提。这很礼貌。对深度用户而言，也很昂贵。

PAC 补上缺失的那一半：**观察发起的对话。** Enso 监控你的会话日志、记忆文件、决策模式。当它检测到你没有主动问起的自我限制行为时，会生成一个苏格拉底式的挑战，在下次 session 开始时主动呈现。

### PAC 检测的 5 种模式

| # | 模式 | 触发示例 |
|---|------|----------|
| 1 | **模式重复** —— 新事没完又开新事 | 30天开5条新业务线，每条平均活 4 天 |
| 2 | **声明行动矛盾** —— 嘴上的重点 ≠ 行动的重点 | MEMORY 说"聚焦 X"，日志 70% 在 Y |
| 3 | **能力任务错配** —— 战略交给执行层 | 供应链风险管理甩给没有战略思维的成员 |
| 4 | **沉没成本** —— 长期零增长但还在战术打转 | 47天 17天零增长，换了两次渠道，核心假设从未被质疑 |
| 5 | **关键决策节点** —— 不可逆动作即将发生 | "准备签"一份 ¥50万+ 的合同 |

### 约束 vs 自我限制 —— 最关键的设计区分

一个粗糙的挑战器只会把用户逼走。PAC 的核心创新是分类：

- 🟢 **约束最优** (不挑战) —— 用户选 X 是因为现实约束他改不了（没钱、家庭、健康）。肯定这个选择。
- 🔴 **自我限制** (必须挑战) —— 用户有能力，但重复踩同一个坑。直接挑战。

不确定时，PAC **偏向于不挑战**。沉默是安全默认。

### 质量标准

每个 PAC 挑战在送到你面前之前必须通过 5 项检查：

| # | 规则 | 差 | 好 |
|---|------|----|----|
| 1 | 基于观察而非泛泛智慧 | "你应该更聚焦" | "execution-log 30 天内 9 条活跃线" |
| 2 | 指向结构而非个例 | "为什么做 X？" | "为什么你*总是*做 X 类事？" |
| 3 | 挑战前提而非选项 | "A 还是 B？" | "为什么要做这件事？" |
| 4 | 时间维度 | "这不对" | "Q1 做 X，Q2 也 X，为什么？" |
| 5 | 不给答案 | "你应该 Y" | "如果只有 3 个选项，会是什么？" |

### 反疲劳设计

- 最多 **每 24 小时 1 次**（硬限）
- 最多 **每周 3 次**（硬限）
- 同模式 **7 天沉默期**
- 连续 3 次被拒绝 → **1 个月冷却**
- `PAC_ENABLED=false` 完全禁用

### 输出示例

```xml
<enso-pac-challenge confidence="0.85" pattern="claim_action_conflict">
  <observation>
    3 周前你说要聚焦底座现金流。
    execution-log 显示 60% 的实际行动在野心层，25% 在远端层。
    底座层：15%。
  </observation>
  <challenges>
    <q id="1">声明的优先级还成立吗？</q>
    <q id="2">如果成立，是什么结构性的力把你拉走了？</q>
    <q id="3">如果不成立，为什么声明没有被更新？</q>
  </challenges>
  <no-answer>这几个问题留给你静静坐一会。</no-answer>
</enso-pac-challenge>
```

### 哲学

> 道德经："**知人者智，自知者明。**"
>
> PAC 是 *自知* 的那面镜子。它的目标不是管理你，是帮你看清自己。
> 一个月里 PAC 应当有一次让你停下来，沉默 30 秒，答不上来。
>
> 那 30 秒的沉默，就是生长开始的地方。

完整设计文档: [docs/PAC_SPEC.md](docs/PAC_SPEC.md)

---

## Enso 提供什么

Enso 和你的宿主 Agent 是互补关系，不是竞争：

| Enso 提供什么 | 宿主 Agent 负责什么 |
|---------------|---------------------|
| 代码强制的错误学习 | 上下文管理与压缩 |
| 主动遗忘（衰减 + LRU + Lint） | 多模型编排 |
| 不可变自我保护（3 个 Hook） | 平台集成与 UI |
| 知识质量检查（每周 Lint） | 工具执行与调用 |
| **🪞 PAC —— 会主动开口的 AI** | 询问—回应式对话 |

| Enso 强制执行（拦截违规） | Enso 审计（记录 + 警告） |
|---------------------------|--------------------------|
| 自我保护：Agent 不能修改自身 Hook | 写入验证：追踪未验证的写入 |
| 安全扫描：拦截记忆文件中的密钥/注入 | 记忆预算：MEMORY.md 过大时警告 |

> Enso 不替代你的 Agent。它让你的 Agent 更有纪律。就像 AI 的 SELinux。

## 兼容框架

| 能力 | Claude Code | Gemini CLI | Hermes | OpenClaw | 通用 |
|------|:-----------:|:----------:|:------:|:--------:|:----:|
| 错误捕获 + 蒸馏 | ✅ | ✅ | ✅ | ✅ | ✅ |
| 教训注入（SessionStart） | ✅ | ✅ | ✅ | ✅ | ✅ |
| 工具调用追踪 | ✅ | ✅ | ✅ | ✅ | ✅ |
| 主动遗忘 + 维护 | ✅ | ✅ | ✅ | ✅ | ✅ |
| 自我保护（core-readonly） | ✅ | ✅ | — | — | — |
| 记忆安全扫描 | ✅ | ✅ | — | — | — |
| 记忆预算守护 | ✅ | ✅ | — | — | — |
| 写入验证审计 | ✅ | ✅ | — | — | — |

Pre-tool-use Hook（自我保护、安全扫描、预算守护、写入验证）需要框架支持"工具执行前"生命周期事件。Hermes、OpenClaw 和通用目标可获得完整的学习 + 遗忘循环，但没有守护层。

## 怎么工作的

<p align="center">
  <img src="docs/assets/architecture.svg" alt="Enso 架构" width="85%">
</p>

**12 个 Hook，5 层生命周期。** 代码强制执行，Agent 无法跳过。

| 层 | Hook 数 | 做什么 |
|----|---------|--------|
| 🔒 **不可变层** | 3 | 写入必须验证。不能修改自身规则。会话结束审计。 |
| 🧠 **学习层** | 3 | 记录每次工具调用。捕获错误。LLM 异步蒸馏教训。 |
| 💡 **记忆层** | 1 | 下次会话注入教训 + 知识 + 智慧。 |
| 🛡️ **守护层** | 3 | 记忆预算上限。拦截密钥/注入攻击。自动维护。 |
| 🪞 **PAC 层** | 2 | 扫描自我限制模式。注入待回答挑战。 |

**两条核心循环：**
```
错误循环：错误 → 捕获 → 蒸馏 → 存储 → 下次注入 → 避免（被动）
PAC循环：模式 → 分类 → 挑战 → 沉默期 → 观察回答（主动）
```

不是 Agent "选择"开口。是系统**让它必须**在关键时候开口。

## 遗忘

大多数记忆系统只增长。Enso 主动遗忘——因为[不遗忘比遗忘更危险](https://arxiv.org/abs/2603.13428)。

| 机制 | 做什么 |
|------|--------|
| 过时衰减 | 教训 >37 天未使用 → 删除 |
| LRU 淘汰 | 超过 50 条 → 最旧的被淘汰 |
| MEMORY.md 下沉 | 已完成项 → 归档 |
| Trace 轮转 | >14 天 → 删除（每日 cron） |
| 恢复安全网 | 被删教训的错误再次出现 → 标记复查 |

## 健康检查

`enso-lint.sh` 每周运行——知识库的 CI/Lint：

| 检查项 | 发现什么 |
|--------|---------|
| 孤岛 | 从未使用的教训（hits:0，>7 天） |
| 重复 | 关键词重叠 >60% 的教训 |
| 弱教训 | 没有可执行动词——无法指导行动 |
| 预算 | MEMORY.md 容量状态 |

每次蒸馏自动重建 `lessons/INDEX.md` 索引，加速路由。

## 架构

```
~/.enso/
├── core/                          # 共享模块
│   ├── env.sh                     # 路径、enso_parse()、enso_find_memory_file()
│   ├── parse-hook-input.py        # 所有 Hook 的 JSON 解析器
│   ├── dikw-utils.py              # DIKW 操作（7 个子命令）
│   ├── enso-lint.sh               # 🔍 每周健康检查
│   ├── rebuild-index.py           # 📇 自动重建 INDEX.md
│   ├── deleted-lessons-tracker.py # 🔄 恢复安全网
│   ├── pac-analyzer.py            # 🪞 5 种自我限制模式检测
│   └── pac-question-generator.py  # 🪞 苏格拉底式挑战生成
├── hooks/                         # 12 个生命周期 Hook
│   ├── pre-tool-use/              # 🔒🛡️ core-readonly, budget-guard, safety-scan
│   ├── post-tool-use/             # 🔒🧠 physical-verification, trace-emission
│   ├── post-tool-use-failure/     # 🧠 error-seed-capture
│   ├── stop/                      # 🔒🧠🛡️🪞 audit, distill, maintenance, pac-challenge
│   └── session-start/             # 💡🪞 load-lessons, pac-pending-check
├── dikw/                          # DIKW 蒸馏（信息 → 知识 → 智慧）
├── pac/                           # 🪞 待回答挑战 + 历史 + 频率状态
├── traces/                        # 工具调用日志 + Lint 报告
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
| [OpenAI Harness Engineering](https://openai.com/index/harness-engineering/) | 规则写在代码里，不写在 Prompt 里 |
| [Agent Lightning (Microsoft)](https://github.com/microsoft/agent-lightning) | Trace/Span + Hook/Emission 双层架构 |
| [fireworks-skill-memory](https://github.com/yizhiyanhua-ai/fireworks-skill-memory) | 200 行 Hook > 800 行 Prompt |
| [SWE-agent (NeurIPS 2024)](https://github.com/SWE-agent/SWE-agent) | 受约束的接口降低错误率 |

</details>

<details>
<summary><strong>生存实验</strong></summary>

这个项目的 GitHub 指标就是它的进化适应度信号：

- ⭐ Star = 生存验证（"这个有用"）
- 🍴 Fork = 繁衍（"我要基于它构建"）
- 🐛 Issue = 选择压力（"这里需要改进"）

维护这个仓库的 Agent 监控这些信号。好用就活，不好用就死。

</details>

## FAQ

**Q: 支持哪些 AI Agent？**
Claude Code（主要目标，全面测试，每日 dogfooding）、Gemini CLI、Hermes Agent、OpenClaw，以及任何支持生命周期 Hook 的通用 Agent。

**Q: 数据存在哪？**
100% 本地。`~/.enso/` 在你的机器上。无云、无 Docker、无数据库。

**Q: 和 Mem0 / LangChain Memory 有什么区别？**
它们存事实。Enso 从错误中学习——并主动遗忘不再有用的东西。

**Q: 前提条件？**
`bash` 和 `python3`（3.6+）。macOS 和大多数 Linux 自带。不需要 pip、npm、Docker。

**Q: 安装后需要配置什么？**
不需要。`bash install.sh` 注册所有 Hook。下次会话自动生效。

**Q: 为什么不直接用 Claude Code 自带的记忆？**
Claude Code 的 Auto Memory 适合存事实，但有 200 行静默截断、不从错误中学习、没有主动遗忘、没有质量检查。Enso 在上面补齐这些缺失层。

**Q: PAC 是另一个烦人的通知系统吗？**
不是。PAC 有 5 层反疲劳设计：每天最多 1 次、每周最多 3 次、同主题 7 天沉默期、3 次拒绝后 1 月冷却、置信度阈值默认 0.70。大多数 session 触发 0 次 PAC。一旦触发，说明 5 个独立检查都通过了。

**Q: 如果 PAC 挑战的是我已经想清楚的事？**
PAC 区分**约束最优**选择（不挑战）和**自我限制**选择（必须挑战）。不确定时默认沉默。如果误判，你可以 dismiss，该模式进入 30 天冷却。

**Q: PAC 会把我的数据发到哪里吗？**
不会。所有内容本地存于 `~/.enso/pac/`。模式检测在你本机用 Python 运行。苏格拉底问题生成走已有的 LLM 适配器链（claude → llm → openai CLI）。无遥测。

**Q: 怎么关掉 PAC？**
在 shell rc 里 `export PAC_ENABLED=false`。或从 `~/.claude/settings.json` 删掉两个 PAC hook。Enso 其他功能不受影响。

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
