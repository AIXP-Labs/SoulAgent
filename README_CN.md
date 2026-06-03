# SoulAgent — SoulBot Execute Engine 的 Claude Code Skill / 插件封装

[![License](https://img.shields.io/badge/license-Apache%202.0-green.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](CHANGELOG.md)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-skill%20%2F%20plugin-orange.svg)](https://code.claude.com/docs/en/skills)

[English](README.md) | 中文文档

把 **SoulBot Execute Engine** 包装成一个 Claude Code 技能：在终端里调用，当前 Claude Code 会话就作为**编排器（orchestrator）**，引导并严格执行整套 AIAP 引擎 —— 可对话、占卜、创建 / 演化 AIAP 程序包。

- **路径方案（Path A）**：官方 Claude Code CLI + 订阅，**不经** soulacp / ACP 层。当前会话本身就是编排器。
- **自包含插件**：Claude Code 适配壳全部在 **`claude_code_plugin/`** 内。其中 `SKILL.md`（薄适配入口）在技能根，可移植引擎归到 **`skills/run/soulagent/`**。仓库根只放文档与仓库级元数据。
- **相对寻址**：`SKILL.md` 经 `${CLAUDE_SKILL_DIR}\soulagent\…` 够到引擎，零绝对路径。
- **当前两个适配器**：`claude_code_plugin/`（Claude Code）和 `soulagent/`（宿主中立，给非 Claude 宿主 / Form 2）并列，各自自包含。将来的宿主壳（`gemini_plugin/`、`codex_plugin/` 等）照同样模式 —— 见 [ARCHITECTURE.md](ARCHITECTURE.md)。
- **调用**：以 `soulagent@skills-dir` 插件加载 → **`/soulagent:run`**。

**项目信息**：仓库 <https://github.com/AIXP-Labs/SoulAgent> ｜ 主页 <https://soulagent.dev> ｜ 许可 Apache-2.0 ｜ 版本 1.0.0 ｜ © 2026 AIXP Labs

---

## 安装（Claude Code CLI）

```
/plugin marketplace add AIXP-Labs/SoulAgent
/plugin install soulagent@aixp
```

然后在终端里调用：**`/soulagent:run <任务>`** —— 例如 `/soulagent:run 帮我算一卦：今天适合发布吗`。逐任务走查见 [GUIDE_CN.md](GUIDE_CN.md)。

**更新** —— 发布新版本后，刷新市场缓存并重装以拉取新版本（在你的终端 shell 里运行；在 Claude Code 内用 `/plugin …` 等效）：

```
claude plugin marketplace update aixp
claude plugin uninstall soulagent@aixp
claude plugin install soulagent@aixp
```

---

## 目录结构（仓库根 = 文档 · 两个自包含适配器：`claude_code_plugin/` + `soulagent/`）

```
<path-to>\SoulAgent\               ← 仓库根（文档 + 仓库级元数据）
├── claude_code_plugin\                   ← 自包含 Claude Code 插件（junction 指这里）
│   ├── .claude-plugin\plugin.json        ← 插件清单（name=soulagent, version/license/...）
│   ├── _meta.json  LICENSE  NOTICE       ← 随插件走（zip / marketplace 分发需要）
│   └── skills\run\                        ← 技能（= ${CLAUDE_SKILL_DIR}）
│       ├── SKILL.md                       ← 入口 + 编排纪律 → /soulagent:run
│       ├── LICENSE  NOTICE                ← Apache-2.0（技能级也带一份）
│       └── soulagent\                      ← 引擎（经 ${CLAUDE_SKILL_DIR}\soulagent\ 寻址）
│           ├── start.aisop.json          ← AIAP 引导程序（Bootstrap→RunEngine→endNode）
│           ├── start.py                  ← 终端引导 CLI（__file__ 自定位）
│           ├── aiap\                     ← 可执行 AIAP 包（registry 来源）
│           │   ├── soulbot_creator_evolution_aiap\        （node）
│           │   └── soulbot_yijing_divination_aiap\        （normal：易经占卜）
│           ├── soulbot_execute_engine_aiap\  ← 执行引擎 Router + engines + python_tools
│           └── soulbot_intent_classifier_aiap\
├── soulagent\                            ← 宿主中立适配器（Form 2 / 非 Claude 宿主）
│   ├── SKILL.md                          ← 通用（宿主中立）skill，无 plugin.json
│   ├── LICENSE  NOTICE
│   └── soulagent\                        ← 引擎（源与 Claude 适配器内的一致）
├── README.md  README_CN.md  CHANGELOG.md
├── GUIDE_EN.md  GUIDE_CN.md  ARCHITECTURE.md
├── CONTRIBUTING.md  CONTRIBUTING_CN.md  CODE_OF_CONDUCT.md  GOVERNANCE.md  SECURITY.md
├── LICENSE  NOTICE                       ← 仓库级
└── .gitignore

安装链接：
C:\Users\<你>\.claude\skills\soulagent  ──junction──▶  <path-to>\SoulAgent\claude_code_plugin
```

> 在插件技能里，`${CLAUDE_SKILL_DIR}` 指向 `claude_code_plugin/skills/run/`（`SKILL.md` 所在）。引擎在其 `soulagent/` 子目录，经 `${CLAUDE_SKILL_DIR}\soulagent\start.aisop.json`、`${CLAUDE_SKILL_DIR}\soulagent\start.py` 等寻址。

> `.gitignore`（在仓库根，`**/` 通配）会排除运行期/私密产物（`.execution_cache/`、`conversation_context.json`、`yijing_history/`、`.evolution_snapshot/`、`*.bak`、密钥等），无论它们在哪一层 —— **留在本地、不进 GitHub**。

---

## 环境要求

| 项 | 要求 |
|---|---|
| Claude Code CLI | 2.1.x（交互模式，`claude`） |
| Python | 3.10+（本机 3.12，路径上能直接 `python`） |
| 系统 | Windows（路径与 junction 以 Windows 为准） |
| 控制台编码 | 建议 UTF-8（中文 / emoji），见末尾「Windows 注意」 |

---

## 安装（让 Claude Code 发现它）

用 **junction** 把 `~/.claude/skills` 指向**插件** `claude_code_plugin/`（单一事实源、零副本）：

```powershell
New-Item -ItemType Junction `
  -Path   "$env:USERPROFILE\.claude\skills\soulagent" `
  -Target "<path-to>\SoulAgent\claude_code_plugin"
```

然后**重启 Claude Code**。因为目标含 `.claude-plugin/plugin.json`，它会以**插件** `soulagent@skills-dir` 形态加载，技能调用为 `/soulagent:run`。

> 验证安装：
> ```powershell
> Test-Path "$env:USERPROFILE\.claude\skills\soulagent\.claude-plugin\plugin.json"   # 应为 True
> ```

---

## Skill 模式 vs Plugin 模式

SoulAgent 以**插件**发布（`/soulagent:run`）。同一套引擎也能包成普通 standalone 技能（`/soulagent`）。

| | Plugin 模式（已发布） | Standalone 技能模式 |
|---|---|---|
| 调用 | **`/soulagent:run`**（带命名空间） | `/soulagent`（简短） |
| 布局 | `claude_code_plugin/`（`.claude-plugin/` + `skills/run/`：`SKILL.md`，引擎在 `soulagent/`） | 一个技能文件夹放 `SKILL.md` + `soulagent/` 引擎，**无** `plugin.json` |
| 原生版本/作者 | ✅ 经 `plugin.json` | ❌（仅 `_meta.json`） |
| marketplace 安装（`/plugin install`） | ✅ | ❌ |
| 多个命名入口（`:run`、`:divine`…） | ✅ | ❌ |
| 适合 | 分享、版本化发布、市场 | 个人使用、最短名 |

两种布局里 `SKILL.md` 都经 `${CLAUDE_SKILL_DIR}\soulagent\…` 够引擎。要 standalone：把 `claude_code_plugin/skills/run/`（SKILL.md + soulagent/）整体复制到 `~/.claude/skills/soulagent/` 下作为技能文件夹、并去掉 `plugin.json`。（下文「Form 2」两种都可用 —— 也是**非 Claude 宿主**该走的路：它们直接读引擎，不读任何 SKILL.md。）

> 生态说明：组织聚合属于 **marketplace 层**（如 `soulagent@aixp-labs`），不是 plugin 命名空间 —— 所以 plugin 名保持 `soulagent`、技能名保持 `run`。

---

## 调用

### 形态 1：插件技能（交互模式，推荐）

```
/soulagent:run <你的任务>
```

重启后在 `/` 菜单确认确切写法。`<你的任务>` 就是引擎的 `user_message`。例如：

```
/soulagent:run 你好
/soulagent:run 帮我算一卦：今天适合发布吗
/soulagent:run 使用 creator 进化 <你的-aiap-名称>
```

### 形态 2：直接念引导程序（不依赖技能注册 · 宿主无关）

不想装技能、或在**非 Claude 宿主**（Gemini CLI、Codex 等）上，直接让 agent 指向引擎：

```
执行 start.aisop.json 指令：<你的任务>
```

冒号后的文本即 `user_message`，前提是上下文能定位到 `claude_code_plugin/skills/run/soulagent/start.aisop.json`。这是可移植入口：任何能「读文件 + 跑 Python + 派 sub-agent」的 agent 都能这样驱动引擎。

### ⚠️ 不能在 `claude -p`（headless）里用

`SKILL.md` 设了 `disable-model-invocation: true`，是**用户手动技能**，只在交互模式可用，`claude -p` 里调不到。要在 `-p` 里跑引擎，请用形态 2 的措辞，让 Claude 自己读执行 `start.aisop.json`。

---

## 三种任务怎么写

引擎的 Router 会把你的话**匹配到一个 AIAP 包**，匹配不到就直接对话回复。

| 你想做什么 | 怎么说 | 走哪条路 |
|---|---|---|
| **闲聊 / 提问** | `…你好` / `…你能做什么` | 无专用包匹配 → **direct_reply**（最轻，无引擎、无 sub-agent） |
| **易经占卜** | `…帮我算一卦：今天适合发布吗` | 匹配 `soulbot_yijing_divination`（**normal** 模式，节点循环、多为 inline） |
| **创建 / 演化 AIAP** | `…使用 creator 进化 <你的-aiap-名称>` | 匹配 `soulbot_creator_evolution`（**node** 模式，**派 sub-agent**，最重、最慢） |

> 第一次体验建议从**闲聊**或**占卜**开始（轻量）；`creator` 演化是完整流水线（十几到二十几个节点、派多个 sub-agent、可能几分钟）。逐任务走查见 [GUIDE_CN.md](GUIDE_CN.md)。

---

## 内部是怎么跑的（执行链）

```
调用 (/soulagent:run <任务> 或「执行 start.aisop.json 指令：<任务>」)
  │  SKILL.md：把任务当 user_message，物理读取 ${CLAUDE_SKILL_DIR}\soulagent\start.aisop.json 并严格执行
  ▼
start.aisop.json  (AIAP 引导程序，3 个编排节点)
  ├─ [1] Bootstrap  → 从 claude_code_plugin/skills/run/soulagent/ 跑 python -X utf8 start.py "<user_message>"
  │                   start.py 建 cache(turn) + 载 registry，__file__ 自定位引擎
  ├─ [2] RunEngine  → 物理读取 Router main.aisop.json，执行 match→execute→engineExec→endNode
  │                   · match：把 user_message 匹配到某个 AIAP 包（匹配不到→直接回复）
  │                   · execute：把 target/loading_mode 记进 _index.json
  │                   · engineExec：按 loading_mode 选 node/normal engine，跑节点循环
  │                       - node 模式：agent 节点用 Task 工具派 sub-agent
  │                       - normal 模式：节点循环，多为 inline
  └─ [3] endNode    → 输出引擎最终回复（🤖 开头，用户语言，含 EU AI Act Art.50 披露）
```

**全程相对寻址**：SKILL.md 用 `${CLAUDE_SKILL_DIR}\soulagent\` → start.aisop.json 自引用「本文件所在目录」→ start.py 用 `__file__` 自解析。junction 真实目标解析后落到 `<path-to>\SoulAgent\claude_code_plugin\skills\run\soulagent\`。

---

## 编排纪律（SKILL.md / start.aisop.json 强制，体现引擎设计哲学）

作为编排器，当前会话必须遵守（细节见 `start.aisop.json` 的 `RunEngine.step2`）：

- **DISPATCH**：每个 agent 模式节点用 **Task 工具**派一个 sub-agent，prompt 用引擎给出的精确 bootstrap；**绝不**注入「自动批准 / 跳过确认」等行为指令（Axiom 0，B1 完整性）。
- **PYTHON_TOOLS**：调 `agent_update_index.py` / `dispatch_audit.py` / `user_gate_audit.py` 等，JSON 经 **STDIN 或 args-list** 传入；**绝不**在 PowerShell 内联 JSON 字面量；并**始终用 `python -X utf8`**（含非 ASCII / emoji 的 JSON 在 Windows 上不加会 surrogate 报错）。
- **SOVEREIGNTY（主权）**：每个 terminal-status 节点后跑 `user_gate_audit.py --enforce`；遇 `WAITING_USER` **原文转达**门问题并**停止**，绝不替用户决定。
- **SCOPE**：只在本次 `cache_dir` 下写文件；**不修改**引擎生产文件（`.aisop.json` / `python_tools` / `AIAP.md` / `quality_baseline.json`），除非任务明确授权一次跑完 ReviewFinalize 的真实进化。

### 遇到 WAITING_USER（用户门）怎么办

引擎遇到需要你拍板的地方会**停下来问你**（主权门）。回答方式：再次调用并把回答作为参数（如 `/soulagent:run <你的回答>`）。`start.py` 会**自动复用 in_progress 的那个 turn**，续跑同一个节点（RESUME 模式），不会从头再来。

---

## Windows 注意事项

| 现象 | 原因 | 解决 |
|---|---|---|
| 终端中文 / emoji 乱码 | 控制台默认 GBK | `chcp 65001` 切 UTF-8，或设 `$env:PYTHONUTF8="1"` |
| `UnicodeEncodeError: surrogates not allowed` | python 读含 emoji 的 JSON 没用 UTF-8 | python_tools 调用统一 `python -X utf8 …`（已写进 start.aisop.json 纪律） |
| 菜单里找不到技能 | junction 没建好 / 没重启 | 重新建 junction + 重启 Claude Code |

---

## 故障排查

- **调用没反应 / 找不到**：确认 junction 存在（`Test-Path "$env:USERPROFILE\.claude\skills\soulagent\.claude-plugin\plugin.json"`），并已重启 Claude Code；在 `/` 菜单核对确切的命名空间写法。
- **start.py 报错 / cache 没建**：手动跑一次验证：
  ```powershell
  python -X utf8 "<path-to>\SoulAgent\claude_code_plugin\skills\run\soulagent\start.py" "测试"
  ```
  应输出一个 JSON（含 `status:"ok"`、`engine_dir`、`registry`）。
- **跑 creator 演化卡住很久**：正常 —— node 模式会派多个 sub-agent、跑完整流水线，耐心等或先用轻量任务测试。
- **插件没加载**：`claude plugin validate "<path-to>\SoulAgent\claude_code_plugin"` 应通过；改动后 `/reload-plugins` 或重启。

---

## 分发

### 路线 A（你当前用的）：`@skills-dir` 插件
junction `~/.claude/skills/soulagent` → `claude_code_plugin/`，即自动以 `soulagent@skills-dir` 加载，无需市场。

### 路线 B：`.zip` 包
打包**插件目录** `claude_code_plugin/`，剔除运行期/私密产物：

```powershell
$stage = "<path-to>\_pkg\soulagent"
robocopy "<path-to>\SoulAgent\claude_code_plugin" $stage /E `
  /XD ".execution_cache" ".version_history" ".evolution_snapshot" ".pipeline_cache" "__pycache__" ".pytest_cache" ".mypy_cache" ".ruff_cache" "yijing_history" "htmlcov" "node_modules" "dist" "build" ".git" `
  /XF "*.bak" "*.tmp" "coverage.xml" ".coverage" "*.log"
Compress-Archive -Path "$stage\*" -DestinationPath "<path-to>\soulagent-1.0.0.zip" -Force
```
对方：`claude --plugin-dir .\soulagent-1.0.0.zip`（或托管后 `--plugin-url`）。

### 路线 C：marketplace（正式发布）
市场仓根部 `.claude-plugin/marketplace.json` 列出本插件（source = `claude_code_plugin/` 目录），对方 `/plugin marketplace add AIXP-Labs/<市场仓>` 后 `/plugin install soulagent@<市场>`。AIXP 生态聚合落在这一层（如 `soulagent@aixp-labs`）。

> 发布前：`git init` 后靠仓库根 `.gitignore` 自动排除私密产物；推送公开仓前先设**本地匿名 git 身份**，避免真实姓名随 commit 泄露。

---

## 关键事实速记

- 引擎：**SoulBot Execute Engine Router**
- AIAP 包：`soulbot_creator_evolution`(node) · `soulbot_yijing_divination`(normal)
- registry 无 `soulbot_chat` → 闲聊走 **direct_reply** 直接回复
- 调用：`/soulagent:run <任务>`（插件命名空间）或「执行 start.aisop.json 指令：<任务>」
- 仓库根 = `<path-to>\SoulAgent`（文档）；插件根 = `…\claude_code_plugin`；`SKILL.md` 在 `skills/run/`，**引擎在 `skills/run/soulagent/`**；junction 指向插件根
- 对齐 **Axiom 0：Human Sovereignty and Wellbeing**
- 仓库 <https://github.com/AIXP-Labs/SoulAgent> · 主页 soulagent.dev · Apache-2.0 · v1.0.0 · © 2026 AIXP Labs

---

## AIXP Labs [aixp.dev](https://aixp.dev)

AIXP Labs 开发并维护以下核心项目：

| 项目 | 说明 | 网站 |
|---|---|---|
| [HSAW](https://hsaw.dev) | 人类主权与福祉 —— Axiom 0 白皮书（基石） | hsaw.dev |
| [AIZP](https://aizp.dev) | AI Zenith-Zero Protocol —— 运行时行为对齐 | aizp.dev |
| [AILP](https://ailp.dev) | AI List Protocol —— agent 发现与能力广告 | ailp.dev |
| [AIVP](https://aivp.dev) | AI Value Protocol —— 国际商务、加密资产结算 | aivp.dev |
| [AIRP](https://airp.dev) | AI RMB Protocol —— 中国大陆商务、人民币持牌结算 | airp.dev |
| [AIBP](https://aibp.dev) | AI Bot Protocol —— 社交通信与信任 | aibp.dev |
| [AIAP](https://aiap.dev) | AI Application Protocol —— 治理与合规 | aiap.dev |
| [AISOP](https://aisop.dev) | AI Standard Operating Protocol —— 流程程序定义 | aisop.dev |
| [SoulAgent](https://soulagent.dev) | 任何 CLI / SDK / IDE 直接调用的 drop-in AI agent **（本项目）** | soulagent.dev |
| [SoulBot](https://soulbot.dev) | AI agent 运行时 & 自编排框架（定时、建 agent、agent 间通信） | soulbot.dev |
| [SoulACP](https://soulacp.dev) | 适配库 —— 桥接 CLI 工具与 LLM 提供方 | soulacp.dev |

---

## ⚠️ 免责声明

本软件为**实验性**软件，仅供**研究和教育用途**。不适用于生产环境。使用风险由用户自行承担。作者对因使用本软件造成的任何损害不承担责任。完整条款见 [LICENSE](LICENSE)（Apache 2.0）。

---

## 许可证

[Apache License 2.0](LICENSE) - Copyright 2026 AIXP Labs AIXP.dev | SoulAgent.dev

---

Align Axiom 0: Human Sovereignty and Wellbeing. Version: SoulAgent V1.0.0. www.soulagent.dev
