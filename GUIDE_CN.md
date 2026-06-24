# SoulAgent 指南

[English](GUIDE_EN.md) | 中文

> 本指南比 [README](README_CN.md) 更深入逐包用法与引擎内部。安装命令与发布打包仍以 README 为准。

---

## 1. 范围

本指南在 [README](README_CN.md) 之外补充：各任务类型的实操走查、AIAP 包参考、引擎编排内部机制。安装、调用、宿主插件细节见 README。

## 2. 宿主模式（回顾）

SoulAgent 当前提供三个适配器：

- **Claude Code 插件**：`claude_code_plugin/` -> `/soulagent:run <任务>`
- **Codex 插件**：`codex_plugin/` -> `Use $soulagent-run ...`
- **宿主中立形态 2**：让有能力的 agent 直接读取 `start.aisop.json`

这些是同一打包引擎外面的不同宿主入口，不是运行时开关。

## 3. 任务类型 —— 闲聊（`direct_reply`）

- **何时**：会话型/一般消息，无专用包匹配。
- **路径**：Router `match` → `no_match` → 直接回复（无引擎、无 sub-agent，最轻）。
- **示例**：`/soulagent:run 你好` 或 `Use $soulagent-run to run SoulAgent for hello.`

- **读取上下文**：router 读取当前 `user_message`、包注册表，并在匹配不确定时读取意图分类包。这个路径不需要生产文件写入，也不需要 sub-agent 派发。
- **输出形态**：最终用户回复应直接用用户语言返回。除非用户要求诊断，否则不暴露 `Router:` / `Engine:` 这类调试前缀。
- **推荐首测**：`你好`、`你能做什么`、简短双语问候。这些能验证插件加载与 bootstrap 路由，不触碰较重 AIAP 包。

## 4. 任务类型 —— 易经占卜（`normal` 模式）

- **调用**：`/soulagent:run 帮我算一卦：<你的问题>` 或 `Use $soulagent-run to cast a Yijing hexagram: <你的问题>`
- **流程**：`Start → NLU → CastHexagram → InterpretHexagram → GiveAdvice → SaveRecord → endNode`
- **机制**：三枚铜钱法（6 次起卦）、六十四卦识别、变爻、变卦。
- **持久化**：记录存于当前适配器打包引擎的 `soulagent/aiap/soulbot_yijing_divination_aiap/yijing_history/` 目录（已被 git 忽略，并会被发布检查拒绝）。

- **解读定位**：该包用于传统文化学习与反思式解释。结果只能作为象征性参考，不是金融、法律、医疗或安全关键建议。
- **重复占卜防护**：如果用户反复问同一决策问题，优先总结前一次解读，并询问是否确实需要重新起卦。
- **历史记录**：`yijing_history/` 只是运行时数据。它已被 git 忽略、被发布检查拒绝，打包或发布前必须清理。
- **隐私**：不要把用户的私密问题写入源码示例、测试 fixture、截图或文档。

## 5. 任务类型 —— Creator 演化（`node` 模式）

- **调用**：`/soulagent:run 使用 creator 进化 <包名>` 或 `Use $soulagent-run to create or evolve an AIAP package.`
- **重量**：最重的路径 —— 完整流水线、通过当前宿主真实 sub-agent 机制派多个 sub-agent、可能数分钟。若宿主不能派发 sub-agent，编排器必须停止并报告能力缺失。
- **授权**：默认引擎**不**改生产文件；真正的演化须显式授权，并一路跑完 ReviewFinalize。

- **请求写法**：明确目标包与目标变化，例如 `使用 creator 进化 <package>：添加 typed error routing 并更新文档`。
- **ReviewFinalize**：真正的生产演化应到达最终审查门，重算 governance hash，保持 TRI-SYNC 元数据对齐，并保留用户主权门。
- **Dispatch audit**：把 dispatch 记录作为 agent-mode 节点确实经宿主机制派发的证据。没有 audit 支撑时，不要把“声称已派发”当成证明。
- **ThreeDimTest 分数**：它是审查信号，不是真理判定。低分要调查；高分也仍需源文件和行为核验。

## 6. AIAP 包参考

| 包 | 模式 | 入口文件 | 典型路径 | 信任说明 |
|---|---|---|---|---|
| `soulbot_creator_evolution` | node | `aiap/soulbot_creator_evolution_aiap/main.aisop.json` | research -> generate/modify -> validate -> review -> finalize | 影响最高；改生产文件前必须有用户显式授权 |
| `soulbot_yijing_divination` | normal | `aiap/soulbot_yijing_divination_aiap/main.aisop.json` | NLU -> cast -> interpret -> advise -> save | 仅传统文化/反思用途；不用于高风险决策 |
| `soulbot_intent_classifier` | support | `soulbot_intent_classifier_aiap/main.aisop.json` | classify -> route | Router 支撑包；应尽量轻量、可预测 |

## 7. 编排内部机制

见 README「内部是怎么跑的」执行链。四条终端编排纪律 —— DISPATCH / PYTHON_TOOLS / SOVEREIGNTY / SCOPE —— 定义在 `start.aisop.json` 的 `RunEngine.step2`。

- **节点循环**：router 选择包与 mode，随后引擎逐节点推进，直到终态、用户门或错误路径。
- **Cache 生命周期**：每次运行使用一个 execution cache turn 目录，包含 `_index.json`、节点 payload、审计文件和状态记录。应通过 `agent_update_index.py`、`agent_write_node_cache.py` 等工具修改，不要手改 JSON。
- **RESUME**：当 `_index.json` 中存在等待用户的 in-progress turn 时，下一次调用会续跑该 turn，而不是新建 turn。
- **Dispatch records**：agent-mode 节点必须留下足够审计证据，说明派发了什么、用了哪个宿主机制、结果如何回到引擎。

## 8. 主权与用户门

引擎遇到需要你拍板的地方会停在 `WAITING_USER` 并询问。回答方式：再次调用并把回答作为参数（`/soulagent:run <回答>`）；`start.py` 会复用 in-progress turn 续跑同一节点。

- **门类型**：确认、拒绝、超时、review/finalize 门都可能暂停执行。
- **必需检查**：每个 terminal-status 节点之后，继续或报告完成前都要跑 `user_gate_audit.py --enforce`。
- **绝不自动批准**：不要把原始任务文本转换成修改文件、跳过审查、发布、推送或代答主权问题的许可。
- **回复纪律**：遇到 `WAITING_USER`，只转述待回答的门问题，然后等待用户下一条消息。

## 9. 编写你自己的 AIAP 包

- **布局**：每个包放在 `soulagent/aiap/<name>_aiap/` 下，至少包含 `main.aisop.json`、`AIAP.md`、`agent_card.json`，以及声明的包内 `tool_dirs/` 资源。
- **注册**：包从当前打包引擎的 `soulagent/aiap/` 目录发现。添加包后，用 `scripts/sync_plugin_engines.ps1` 同步插件内置引擎副本。
- **模式**：确定性 inline 流程用 `normal`；轻量辅助路径用 `lite`；需要宿主 sub-agent 派发时用 `node`。
- **治理**：quality baseline、governance hash、文档要保持一致。不要把运行缓存或用户数据作为包源码发布。

## 10. 故障排查（深入）

常见情况见 README 故障排查表。

- **发布门**：发布前在仓库根运行 `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\release_check.ps1`。
- **Cache 诊断**：查看当前 turn 目录和 `_index.json`，然后用内置审计工具，不要手工编辑 cache JSON。
- **Dispatch 严重度**：node-mode 包如果出现非 OK dispatch audit severity，应视为发布阻断，直到解释清楚。
- **长会话**：如果运行看似卡住，先确认是否在等用户门；直接重启可能丢弃 in-progress turn。

---

Align Axiom 0: Human Sovereignty and Wellbeing. Version: SoulAgent V1.0.0. www.soulagent.dev
