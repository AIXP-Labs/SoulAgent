# SoulAgent Architecture — multi-host blueprint

> How SoulAgent stays portable across hosts (Claude Code, Gemini CLI, Codex, …) without the engine drifting into N divergent copies.

## Two layers

| Layer | What | Portable? |
|---|---|---|
| **Engine (core)** | `start.aisop.json` + `start.py` + `soulbot_execute_engine_aiap/` + `aiap/*_aiap/` + `soulbot_intent_classifier_aiap/` | ✅ host-neutral — any agent that can read files, run Python, and dispatch sub-agents can drive it |
| **Adapter (shell)** | the per-host entry: a `SKILL.md`, a `plugin.json`, a command file, etc. | ❌ host-specific |

The engine is the value; the adapter is a thin per-host wrapper around it.

## The isolation principle (why each adapter bundles its own engine)

Once a skill/plugin is installed (junctioned into `~/.claude/skills/`, or unzipped, or marketplace-installed), it is **isolated to its own root**: it can only reach files *inside* its own tree via relative paths. A `..` that climbs above the plugin root escapes to the host's skills directory, **not** back to your repo.

**Consequence**: you cannot have one shared engine directory that several sibling adapters reference relatively. **Each adapter must contain (bundle) the engine it runs.** (Attempts to keep the engine in a sibling dir outside the adapter root break — see the failed `soulagent/` + `claude_code_plugin/skills/` sibling layout.)

## Path resolution per host

| Host | Skill-dir variable | Engine reference |
|---|---|---|
| **Claude Code** | `${CLAUDE_SKILL_DIR}` (= the skill folder; for a plugin skill in `skills/run/`, that subdir) | `${CLAUDE_SKILL_DIR}\soulagent\start.aisop.json` |
| **Generic / other** | none guaranteed | relative to the skill's own directory: `soulagent/start.aisop.json` |
| **Any (Form 2)** | — | the agent reads `…/soulagent/start.aisop.json` directly; no SKILL.md needed |

`start.py` self-locates the engine via `__file__`, so it works wherever it physically sits.

## Current adapters

```
SoulAgent/                       ← repo root (docs + metadata)
├── claude_code_plugin/          ← Claude Code adapter  →  /soulagent:run
│   └── skills/run/{ SKILL.md(Claude), soulagent/(engine) }
└── soulagent/                   ← host-neutral adapter  (Form 2 / non-Claude)
    └── { SKILL.md(generic), soulagent/(engine) }
```

Both **bundle a full engine copy** today. That is correct for distribution (each ships self-contained) but means the copies **drift** when maintained by hand.

## The drift problem → target maintenance pattern

Hand-maintaining N engine copies does not scale. The right shape once a 2nd adapter is real:

```
repo/
├── engine/                      ← SINGLE SOURCE OF TRUTH (not installed directly)
│   └── start.aisop.json  start.py  aiap/  soulbot_execute_engine_aiap/  …
├── adapters/
│   ├── claude-code/             ← Claude shell (.claude-plugin/ + skills/run/SKILL.md)
│   ├── gemini/                  ← Gemini shell
│   └── codex/                   ← Codex shell
├── build.ps1                    ← copies engine/ into each adapter at package time
└── docs…
```

- **Dev time**: edit the engine **once** in `engine/`.
- **Package time**: `build.ps1` copies `engine/` into each `adapters/<host>/` so every shipped artifact is self-contained and isolated.
- This resolves isolation with **build-time copy**, not run-time cross-directory relative paths (which break).

> SoulAgent has not migrated to this layout yet (only 2 adapters, manually kept in sync). Adopt it when a 2nd native host adapter (Gemini/Codex) actually ships.

## Adding a new host adapter

1. Create `adapters/<host>/` with that host's entry format (its skill/command/plugin manifest).
2. Reference the engine via the host's path mechanism (its skill-dir variable, or relative, or Form 2).
3. Map the four engine disciplines (DISPATCH / PYTHON_TOOLS / SOVEREIGNTY / SCOPE) onto the host's sub-agent + shell capabilities. If the host can't dispatch sub-agents, `node`-mode packages won't run; `normal`/`lite` still work inline.
4. Have `build.ps1` copy `engine/` into the new adapter.

## The universal interface: Form 2

The most portable entry needs **no adapter at all**: point any capable agent at `…/soulagent/start.aisop.json` and have it execute. Use this for hosts without a native skill format.

## Cross-cutting rules

- **Windows + UTF-8**: any `python` call handling non-ASCII / emoji JSON must use `python -X utf8` (else `UnicodeEncodeError: surrogates not allowed`).
- **`.gitignore`** at the repo root uses `**/` globs, so it excludes runtime/private artifacts (`.execution_cache/`, `conversation_context.json`, `yijing_history/`, …) wherever an engine copy lives.
- **Axiom 0** (Human Sovereignty and Wellbeing) and the sovereignty user-gate are immutable across every adapter.

---

# SoulAgent 架构 —— 多宿主蓝图

> SoulAgent 如何在多个宿主（Claude Code、Gemini CLI、Codex…）间保持可移植，而引擎不会裂成 N 份各自漂移的副本。

## 两层

| 层 | 是什么 | 可移植？ |
|---|---|---|
| **引擎（核心）** | `start.aisop.json` + `start.py` + `soulbot_execute_engine_aiap/` + `aiap/*_aiap/` + `soulbot_intent_classifier_aiap/` | ✅ 宿主中立 —— 任何能读文件、跑 Python、派 sub-agent 的 agent 都能驱动 |
| **适配壳（shell）** | 每个宿主的入口：`SKILL.md`、`plugin.json`、命令文件等 | ❌ 宿主专属 |

引擎是价值所在；适配壳只是包在它外面的一层薄宿主封装。

## 隔离原则（为什么每个适配器都要自带引擎）

skill/plugin 一旦安装（junction 进 `~/.claude/skills/`、解压、或市场安装），就被**隔离在自己的根里**：只能相对够到自己树内的文件。`..` 一旦爬出插件根，会跳到宿主的 skills 目录，**回不到**你的仓库。

**后果**：没法让多个兄弟适配器相对共享同一个引擎目录。**每个适配器必须自带（打包）它要跑的引擎。**（把引擎放到适配器根**之外**的兄弟目录会坏 —— 见失败的 `soulagent/` + `claude_code_plugin/skills/` 兄弟布局。）

## 各宿主的路径解析

| 宿主 | 技能目录变量 | 引擎引用 |
|---|---|---|
| **Claude Code** | `${CLAUDE_SKILL_DIR}`（= 技能文件夹；插件技能在 `skills/run/` 则指该子目录） | `${CLAUDE_SKILL_DIR}\soulagent\start.aisop.json` |
| **通用 / 其它** | 无保证 | 相对技能自身目录：`soulagent/start.aisop.json` |
| **任意（Form 2）** | — | agent 直接读 `…/soulagent/start.aisop.json`，无需 SKILL.md |

`start.py` 用 `__file__` 自定位引擎，所以放哪都能跑。

## 当前的适配器

```
SoulAgent/                       ← 仓库根（文档 + 元数据）
├── claude_code_plugin/          ← Claude Code 适配器  →  /soulagent:run
│   └── skills/run/{ SKILL.md(Claude), soulagent/(引擎) }
└── soulagent/                   ← 宿主中立适配器（Form 2 / 非 Claude）
    └── { SKILL.md(通用), soulagent/(引擎) }
```

两者现在都**各自打包了一份完整引擎**。对分发是对的（各自自包含），但手工维护时这些副本会**漂移**。

## 漂移问题 → 目标维护形态

手工维护 N 份引擎不可持续。等第二个适配器真正出现时，正确形态：

```
repo/
├── engine/                      ← 唯一事实源（不直接安装）
│   └── start.aisop.json  start.py  aiap/  soulbot_execute_engine_aiap/  …
├── adapters/
│   ├── claude-code/             ← Claude 壳（.claude-plugin/ + skills/run/SKILL.md）
│   ├── gemini/                  ← Gemini 壳
│   └── codex/                   ← Codex 壳
├── build.ps1                    ← 打包时把 engine/ 拷进每个适配器
└── docs…
```

- **开发期**：只在 `engine/` 改一次引擎。
- **打包期**：`build.ps1` 把 `engine/` 拷进每个 `adapters/<host>/`，每个发行件自包含、各自隔离。
- 用**构建期拷贝**解决隔离，而不是**运行期跨目录相对路径**（那会坏）。

> SoulAgent 还没迁到此布局（只有 2 个适配器，手工保持同步）。等第二个原生宿主适配器（Gemini/Codex）真要发布时再采用。

## 新增一个宿主适配器

1. 建 `adapters/<host>/`，用该宿主的入口格式（它的 skill/command/plugin 清单）。
2. 用该宿主的路径机制引用引擎（它的技能目录变量、相对路径、或 Form 2）。
3. 把引擎四纪律（DISPATCH / PYTHON_TOOLS / SOVEREIGNTY / SCOPE）映射到该宿主的 sub-agent + shell 能力。若该宿主不能派 sub-agent，`node` 模式包跑不动；`normal`/`lite` 仍能 inline 跑。
4. 让 `build.ps1` 把 `engine/` 拷进新适配器。

## 通用入口：Form 2

最可移植的入口**完全不需要适配器**：让任何能干的 agent 指向 `…/soulagent/start.aisop.json` 执行即可。没有原生 skill 格式的宿主用这个。

## 横切规则

- **Windows + UTF-8**：凡处理含非 ASCII / emoji JSON 的 `python` 调用都要 `python -X utf8`（否则 `UnicodeEncodeError: surrogates not allowed`）。
- **`.gitignore`** 在仓库根用 `**/` 通配，所以无论引擎副本在哪，都能排除运行期/私密产物（`.execution_cache/`、`conversation_context.json`、`yijing_history/`…）。
- **Axiom 0**（Human Sovereignty and Wellbeing）与主权用户门在每个适配器里都不可变。

---

Align Axiom 0: Human Sovereignty and Wellbeing. Version: SoulAgent V1.0.0. www.soulagent.dev
