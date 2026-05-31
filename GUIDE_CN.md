# SoulAgent 指南

[English](GUIDE_EN.md) | 中文

> **状态：骨架（编写中）。** 本指南比 [README](README_CN.md) 更深入逐包用法与引擎内部。标 _TODO_ 的小节会随行为稳定逐步补全（在此之前，安装与调用以 README 为准）。

---

## 1. 范围

本指南在 [README](README_CN.md) 之外补充：各任务类型的实操走查、AIAP 包参考、引擎编排内部机制。安装、调用、Skill-vs-Plugin 选择见 README。

## 2. Skill 模式 vs Plugin 模式（回顾）

见 README 的「Skill 模式 vs Plugin 模式」节。一句话：本包以**插件布局**（`claude_code_plugin/skills/run/` + `plugin.json`）发布 → `/soulagent:run`；**standalone 布局**（根级 `SKILL.md`、无 `plugin.json`）给出简短的 `/soulagent`。两者是不同的布局，不是运行时开关。

_TODO：两种安装的并排走查。_

## 3. 任务类型 —— 闲聊（`direct_reply`）

- **何时**：会话型/一般消息，无专用包匹配。
- **路径**：Router `match` → `no_match` → 直接回复（无引擎、无 sub-agent，最轻）。
- **示例**：`/soulagent:run 你好`

_TODO：示例、引擎会读哪些上下文、输出格式。_

## 4. 任务类型 —— 易经占卜（`normal` 模式）

- **调用**：`/soulagent:run 帮我算一卦：<你的问题>`
- **流程**：`Start → NLU → CastHexagram → InterpretHexagram → GiveAdvice → SaveRecord → endNode`
- **机制**：三枚铜钱法（6 次起卦）、六十四卦识别、变爻、变卦。
- **持久化**：记录存于 `claude_code_plugin/skills/run/soulagent/aiap/soulbot_yijing_divination_aiap/yijing_history/`（已被 git 忽略）。

_TODO：爻辞解读规则（变爻规则）、重复占卜防护、免责与合规定位、历史/清空流程。_

## 5. 任务类型 —— Creator 演化（`node` 模式）

- **调用**：`/soulagent:run 使用 creator 进化 <包名>`
- **重量**：最重的路径 —— 完整流水线、经 Task 工具派多个 sub-agent、可能数分钟。
- **授权**：默认引擎**不**改生产文件；真正的演化须显式授权，并一路跑完 ReviewFinalize。

_TODO：如何措辞一个演化请求、ReviewFinalize 验什么、governance_hash TRI-SYNC、读 dispatch audit、解读 ThreeDimTest 分数。_

## 6. AIAP 包参考

| 包 | 模式 | 用途 |
|---|---|---|
| `soulbot_creator_evolution` | node | 创建 / 演化 AIAP 包 |
| `soulbot_yijing_divination` | normal | 易经占卜（传统文化学习） |
| `soulbot_intent_classifier` | — | 意图分类（`match` 不确定时用） |

_TODO：逐包节点图、输入/输出、trust level。_

## 7. 编排内部机制

见 README「内部是怎么跑的」执行链。四条终端编排纪律 —— DISPATCH / PYTHON_TOOLS / SOVEREIGNTY / SCOPE —— 定义在 `start.aisop.json` 的 `RunEngine.step2`。

_TODO：节点循环、cache（`_index.json`）生命周期、用户门 RESUME、sub-agent dispatch records。_

## 8. 主权与用户门

引擎遇到需要你拍板的地方会停在 `WAITING_USER` 并询问。回答方式：再次调用并把回答作为参数（`/soulagent:run <回答>`）；`start.py` 会复用 in-progress turn 续跑同一节点。

_TODO：门的类型、`user_gate_audit.py --enforce`、编排器绝不可自动批准的动作。_

## 9. 编写你自己的 AIAP 包

_TODO：包布局（`*_aiap/` 含 `main.aisop.json` + `AIAP.md`）、loading 模式、注册（从 `claude_code_plugin/skills/run/soulagent/aiap/` 自动发现）、治理元数据。_

## 10. 故障排查（深入）

常见情况见 README 故障排查表。

_TODO：引擎级诊断、读 cache 状态、dispatch-audit 严重度、长会话内存说明。_

---

Align Axiom 0: Human Sovereignty and Wellbeing. Version: SoulAgent V1.0.0. www.soulagent.dev
