# SoulAgent — SoulBot Execute Engine as a Claude Code / Codex Skill Plugin

[![License](https://img.shields.io/badge/license-Apache%202.0-green.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](CHANGELOG.md)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-skill%20%2F%20plugin-orange.svg)](https://code.claude.com/docs/en/skills)
[![Codex](https://img.shields.io/badge/Codex-plugin-blue.svg)](https://github.com/openai/codex)
[![Install](https://img.shields.io/badge/install-soulagent%40aixp-7c3aed.svg)](https://github.com/AIXP-Labs/SoulAgent)

[中文文档](README_CN.md) | English

Packages the **SoulBot Execute Engine** as Claude Code and Codex skills: invoke it in the host and the current session acts as the **orchestrator**, driving and strictly executing the full AIAP engine — chat, Yijing divination, and creating / evolving AIAP packages.

- **Path A**: official Claude Code CLI + subscription, **no** soulacp / ACP layer. The current session *is* the orchestrator.
- **Self-contained plugins**: `claude_code_plugin/` and `codex_plugin/` each bundle their own `skills/run/soulagent/` engine copy. The repo root holds docs, sync scripts, and repo-level metadata.
- **Relative addressing**: adapters reach the engine inside their own skill root — no absolute path dependency after installation.
- **Three adapters today**: `claude_code_plugin/` (Claude Code), `codex_plugin/` (Codex), and `soulagent/` (host-neutral / Form 2) sit side by side, each self-contained. See [ARCHITECTURE.md](ARCHITECTURE.md).
- **Invocation**: Claude loads as `soulagent@skills-dir` → **`/soulagent:run`**. Codex exposes the `soulagent-run` skill through the local marketplace.

**Project**: repo <https://github.com/AIXP-Labs/SoulAgent> ｜ homepage <https://soulagent.dev> ｜ license Apache-2.0 ｜ version 1.0.0 ｜ © 2026 AIXP Labs

---

## Install (Claude Code CLI)

```
/plugin marketplace add AIXP-Labs/SoulAgent
/plugin install soulagent@aixp
```

Then invoke it in your terminal: **`/soulagent:run <task>`** — e.g. `/soulagent:run cast a hexagram: is today good for a release?`. See [GUIDE_EN.md](GUIDE_EN.md) for per-task walkthroughs.

**Update** — after a new release, refresh the marketplace cache and reinstall to pick up the new version (run in your shell; `/plugin …` inside Claude Code is equivalent):

```
claude plugin marketplace update aixp
claude plugin uninstall soulagent@aixp
claude plugin install soulagent@aixp
```

---

## Install (Codex)

From the repository root, register or refresh the local Codex marketplace:

```powershell
codex plugin marketplace add .
```

Codex currently exposes marketplace management commands for plugins. The repo
therefore ships `.agents/plugins/marketplace.json`, which points Codex to the
self-contained `codex_plugin/` directory. After registration, invoke the
SoulAgent run skill when you want Codex to orchestrate the bundled engine.

---

## Layout (repo root · three self-contained adapters: `claude_code_plugin/` + `codex_plugin/` + `soulagent/`)

```
<path-to>\SoulAgent\               ← repo root (docs + repo-level metadata)
├── claude_code_plugin\                   ← self-contained Claude Code plugin (junction → here)
│   ├── .claude-plugin\plugin.json        ← plugin manifest (name=soulagent, version/license/...)
│   ├── _meta.json  LICENSE  NOTICE       ← Claude registry metadata + distribution files
│   └── skills\run\                        ← the skill (= ${CLAUDE_SKILL_DIR})
│       ├── SKILL.md                       ← entry + orchestration discipline → /soulagent:run
│       ├── LICENSE  NOTICE                ← Apache-2.0 (also carried at skill level)
│       └── soulagent\                      ← bundled engine (addressed as ${CLAUDE_SKILL_DIR}\soulagent\)
│           ├── start.aisop.json          ← AIAP bootstrap program (Bootstrap→RunEngine→endNode)
│           ├── start.py                  ← terminal bootstrap CLI (self-locating via __file__)
│           ├── aiap\                     ← executable AIAP packages (registry source)
│           │   ├── soulbot_creator_evolution_aiap\        (node)
│           │   └── soulbot_yijing_divination_aiap\        (normal: Yijing divination)
│           ├── soulbot_execute_engine_aiap\  ← Execute Engine Router + engines + python_tools
│           └── soulbot_intent_classifier_aiap\
├── codex_plugin\                         ← self-contained Codex plugin
│   ├── .codex-plugin\plugin.json         ← Codex plugin manifest
│   ├── README.md  LICENSE  NOTICE
│   └── skills\run\
│       ├── SKILL.md                      ← Codex adapter entry
│       ├── LICENSE  NOTICE
│       └── soulagent\                    ← bundled engine copy for Codex
├── soulagent\                            ← host-neutral adapter (Form 2 / direct engine invocation)
│   ├── SKILL.md                          ← generic (host-neutral) skill, no plugin.json
│   ├── LICENSE  NOTICE
│   └── soulagent\                        ← bundled engine (source identical to the Claude adapter's)
├── README.md  README_CN.md  CHANGELOG.md
├── GUIDE_EN.md  GUIDE_CN.md  ARCHITECTURE.md
├── CONTRIBUTING.md  CONTRIBUTING_CN.md  CODE_OF_CONDUCT.md  GOVERNANCE.md  SECURITY.md
├── scripts\sync_plugin_engines.ps1  scripts\sync_codex_plugin.ps1  scripts\release_check.ps1
├── .agents\plugins\marketplace.json       ← Codex local marketplace index
├── .github\workflows\release-check.yml    ← GitHub Actions release gate
├── LICENSE  NOTICE                       ← repo-level
└── .gitignore

Install link:
C:\Users\<you>\.claude\skills\soulagent  ──junction──▶  <path-to>\SoulAgent\claude_code_plugin
```

> Inside a plugin skill, `${CLAUDE_SKILL_DIR}` points at `claude_code_plugin/skills/run/` (where `SKILL.md` lives). The engine is in its `soulagent/` subdir, addressed as `${CLAUDE_SKILL_DIR}\soulagent\start.aisop.json`, `${CLAUDE_SKILL_DIR}\soulagent\start.py`, etc.

> Inside the Codex skill, `SKILL.md` lives at `codex_plugin/skills/run/` and the engine is addressed relatively as `soulagent/start.aisop.json` and `soulagent/start.py`.

> `.gitignore` (at the repo root, `**/`-globbed) excludes runtime/private artifacts (`.execution_cache/`, `conversation_context.json`, `yijing_history/`, `.evolution_snapshot/`, `*.bak`, keys, ...) wherever they sit — they **stay local and never reach GitHub**.

---

## Requirements

| Item | Requirement |
|---|---|
| Claude Code CLI | 2.1.x (interactive mode, `claude`) |
| Codex CLI | Plugin marketplace commands available (`codex plugin marketplace add`) |
| Python | 3.10+ (3.12 here; `python` must be on PATH) |
| Release checks | `python -m pip install -r requirements-dev.txt` |
| OS | Windows (paths and junction shown Windows-style) |
| Console encoding | UTF-8 recommended (CJK / emoji), see "Windows notes" |

---

## Install (let Claude Code discover it)

Point `~/.claude/skills` at the **plugin** (`claude_code_plugin/`) with a **junction** (single source of truth, no copy):

```powershell
New-Item -ItemType Junction `
  -Path   "$env:USERPROFILE\.claude\skills\soulagent" `
  -Target "<path-to>\SoulAgent\claude_code_plugin"
```

Then **restart Claude Code**. Because the target contains `.claude-plugin/plugin.json`, it loads as the **plugin** `soulagent@skills-dir` and the skill is invoked as `/soulagent:run`.

> Verify install:
> ```powershell
> Test-Path "$env:USERPROFILE\.claude\skills\soulagent\.claude-plugin\plugin.json"   # should be True
> ```

---

## Claude Code skill mode vs plugin mode

For Claude Code, SoulAgent ships as a **plugin** (`/soulagent:run`). The same engine can also be wrapped as a plain standalone Claude skill (`/soulagent`).

| | Plugin mode (shipped) | Standalone skill mode |
|---|---|---|
| Invocation | **`/soulagent:run`** (namespaced) | `/soulagent` (short) |
| Layout | `claude_code_plugin/` (`.claude-plugin/` + `skills/run/`: `SKILL.md`, engine in `soulagent/`) | a skill folder holding `SKILL.md` + `soulagent/` engine, **no** `plugin.json` |
| Native version / author | ✅ via `plugin.json` | ❌ (only `_meta.json`) |
| Marketplace install (`/plugin install`) | ✅ | ❌ |
| Multiple named entry points (`:run`, `:divine`, ...) | ✅ | ❌ |
| Best for | sharing, versioned releases, marketplace | personal use, shortest name |

In both Claude Code layouts, `SKILL.md` reaches the engine via `${CLAUDE_SKILL_DIR}\soulagent\...`. To run standalone, copy `claude_code_plugin/skills/run/` (SKILL.md + soulagent/) into a skill folder under `~/.claude/skills/soulagent/` and omit `plugin.json`. Form 2 below works regardless, and is the right path for hosts that read the engine directly rather than any Claude `SKILL.md`.

> Ecosystem note: organization grouping belongs at the **marketplace** layer (e.g. `soulagent@aixp-labs`), not the plugin namespace — so the plugin stays `soulagent` and the skill stays `run`.

---

## Codex plugin mode

Codex uses a separate host adapter under `codex_plugin/`. It is self-contained: its `SKILL.md` lives at `codex_plugin/skills/run/`, and its bundled engine lives at `codex_plugin/skills/run/soulagent/`.

Register or refresh the local Codex marketplace from the repository root:

```powershell
codex plugin marketplace add .
```

The Codex skill entry is `soulagent-run`. It should read `soulagent/start.aisop.json`, run the local bootstrap with:

```powershell
python -B -X utf8 soulagent/start.py "<task>"
```

Then it must follow the returned engine bootstrap exactly. Agent-mode nodes require a real sub-agent mechanism in the host. If the current Codex environment cannot dispatch a required sub-agent, the orchestrator must stop and report the missing capability instead of pretending the node was executed.

Before release, verify that all bundled adapters are still synced with the root engine and repo-level `LICENSE` / `NOTICE`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\sync_plugin_engines.ps1 -Check
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\release_check.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\release_check.ps1 -RequireHostCli
```

The release gate validates engine bundle sync, Claude and Codex plugin metadata,
local Git identity (`SoulAgent.dev` / `noreply@SoulAgent.dev`), GitHub Actions
release-gate wiring, JSON parseability, repository policy files (`.gitignore` /
`.gitattributes`), Python and PowerShell syntax, all Markdown local links,
README heading alignment, distribution `LICENSE` / `NOTICE` copies,
Claude/Codex adapter text boundaries, Codex interface capabilities, version
consistency, privacy/secret hygiene, LF line endings, UTF-8 bootstrap
round-trip, relative-path bootstrap smoke, Codex marketplace registration,
Claude plugin validation, empty-input `start.py` rejection, split-argv fallback,
and runtime/private artifact absence.
Use `-RequireHostCli` for final local release verification when both `claude` and
`codex` are installed; CI keeps host CLI checks optional and still validates the
static manifests, bundles, archives, and bootstrap paths.

---

## Invocation

### Form 1A: Claude Code plugin skill (interactive mode, recommended)

```
/soulagent:run <your task>
```

After restart, confirm the exact form in the `/` menu. `<your task>` is the engine's `user_message`. For example:

```
/soulagent:run hello
/soulagent:run cast a hexagram: is today good for a release?
/soulagent:run use creator to evolve <your-aiap-name>
```

### Form 1B: Codex plugin skill

Use the Codex skill by name:

```
Use $soulagent-run to run SoulAgent for hello.
Use $soulagent-run to cast a Yijing hexagram: is today good for a release?
Use $soulagent-run to create or evolve an AIAP package.
```

### Form 2: invoke the bootstrap directly (no skill registration · host-agnostic)

If you don't want to install either plugin, or you're on a host without the Claude/Codex plugin installed, or on another host such as Gemini CLI, just point the agent at the engine:

```
执行 start.aisop.json 指令：<your task>      (or: run start.aisop.json: <your task>)
```

The text after the colon is the `user_message` — provided the context can locate one of the bundled `start.aisop.json` files. This is the portable interface: any agent that can read files, run Python, and dispatch real sub-agents can drive the engine this way.

### ⚠️ Not available under `claude -p` (headless)

`SKILL.md` sets `disable-model-invocation: true`, making it a **user-only manual skill** — available in interactive mode only, not callable from `claude -p`. To run the engine under `-p`, use Form 2's phrasing and let Claude read & execute `start.aisop.json` itself.

---

## The three task shapes

The engine's Router **matches your message to an AIAP package**; if nothing matches, it replies directly.

| You want to | Say | Path taken |
|---|---|---|
| **Chat / ask** | `…hello` / `…what can you do` | no specialized package → **direct_reply** (lightest, no engine, no sub-agent) |
| **Yijing divination** | `…cast a hexagram: is today good for a release?` | matches `soulbot_yijing_divination` (**normal** mode, node loop, mostly inline) |
| **Create / evolve AIAP** | `…use creator to evolve <your-aiap-name>` | matches `soulbot_creator_evolution` (**node** mode, **dispatches sub-agents**, heaviest/slowest) |

> For a first try, start with **chat** or **divination** (lightweight). `creator` evolution is a full pipeline (a dozen-plus to ~two dozen nodes, multiple sub-agents, possibly minutes). See [GUIDE_EN.md](GUIDE_EN.md) for per-task walkthroughs.

---

## How it runs internally (execution chain)

```
invocation
  ├─ Claude Code: /soulagent:run <task>
  ├─ Codex:       Use $soulagent-run ...
  └─ Form 2:      run start.aisop.json: <task>
      Treat <task> as user_message, physically read the bundled start.aisop.json, and execute it strictly.
  ▼
start.aisop.json  (AIAP bootstrap program, 3 orchestration nodes)
  ├─ [1] Bootstrap  → run start.py "<user_message>" from the adapter's bundled engine directory
  │                   start.py rejects empty input, defensively joins split argv, then builds cache(turn) + loads registry via __file__
  ├─ [2] RunEngine  → physically read Router main.aisop.json; run match→execute→engineExec→endNode
  │                   · match: match user_message to an AIAP package (no match → direct reply)
  │                   · execute: record target/loading_mode into _index.json
  │                   · engineExec: pick node/normal engine by loading_mode, run the node loop
  │                       - node mode: agent nodes dispatched through the host's real sub-agent mechanism
  │                       - normal mode: node loop, mostly inline
  └─ [3] endNode    → output the engine's final reply (starts with 🤖, user's language, EU AI Act Art.50 disclosure)
```

**Host-relative addressing**: Claude Code uses `${CLAUDE_SKILL_DIR}\soulagent\`; Codex uses `SKILL_ROOT` / `codex_plugin/skills/run/soulagent/`; Form 2 uses whichever bundled engine directory the user points at. `start.aisop.json` self-references "the directory of this file", and `start.py` self-resolves via `__file__`. Bootstrap smoke and release checks invoke Python as `python -B -X utf8`. Hosts should pass the task as one argv value for exact fidelity; `start.py` joins split argv only as a defensive fallback for manual CLI use.

---

## Orchestration discipline (enforced by SKILL.md / start.aisop.json — the engine's design philosophy)

As the orchestrator, the current session must obey (details in `start.aisop.json`'s `RunEngine.step2`):

- **DISPATCH**: each agent-mode node is dispatched as ONE sub-agent through the host's real sub-agent mechanism (Claude Code Task tool; Codex equivalent if available), using the engine's exact bootstrap prompt; **never** inject behavioral directives (auto-approve / skip-confirmation). If the host cannot dispatch the required sub-agent, stop and report the missing capability (Axiom 0, B1 integrity).
- **PYTHON_TOOLS**: call `agent_update_index.py` / `dispatch_audit.py` / `user_gate_audit.py` etc. with JSON passed via **STDIN, `--updates-file`, `--data-file`, or an args-list**; **never** inline a JSON literal in PowerShell; use `python -B -X utf8` for bootstrap/release checks and at least `python -X utf8` in interactive runs (JSON containing non-ASCII / emoji fails with a surrogate error on Windows otherwise).
- **PACKAGE_TOOLS**: bundled AIAP packages may declare optional tools such as `web_search` / `web_fetch`; if the active host does not provide them, the orchestrator must use the package's documented degradation path or stop with a capability error, never fabricate external evidence.
- **SOVEREIGNTY**: run `user_gate_audit.py --enforce` after every terminal-status node; on `WAITING_USER`, forward the gate question **verbatim** and **STOP** — never decide for the user.
- **SCOPE**: write only under the run's `cache_dir`; **do not modify** engine production files (`.aisop.json` / `python_tools` / `AIAP.md` / `quality_baseline.json`) unless the task explicitly authorizes a real evolution that runs all the way through ReviewFinalize.

### What to do on WAITING_USER (a user gate)

When the engine hits a decision that's yours to make, it **stops and asks** (a sovereignty gate). To answer: invoke again with your answer as the argument (e.g. `/soulagent:run <your answer>`). `start.py` **automatically reuses the in_progress turn** and resumes the same node (RESUME mode), not from scratch.

---

## Windows notes

| Symptom | Cause | Fix |
|---|---|---|
| CJK / emoji garbled in terminal | console defaults to GBK | `chcp 65001` to switch to UTF-8, or set `$env:PYTHONUTF8="1"` |
| `UnicodeEncodeError: surrogates not allowed` | python read emoji JSON without UTF-8 | invoke smoke/release tools with `python -B -X utf8 ...`; use at least `python -X utf8 ...` interactively |
| Claude skill missing from the menu | junction not created / not restarted | recreate junction + restart Claude Code |
| Codex skill not available | local marketplace not registered or stale | run `codex plugin marketplace add .` from the repo root |

---

## Troubleshooting

- **Claude plugin invocation does nothing / not found**: confirm the junction exists (`Test-Path "$env:USERPROFILE\.claude\skills\soulagent\.claude-plugin\plugin.json"`) and Claude Code was restarted; check the exact namespaced form in the `/` menu.
- **Codex plugin not available**: register the local marketplace and run the release check:
  ```powershell
  codex plugin marketplace add .
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\release_check.ps1
  ```
  The release check also verifies anonymized Git metadata, repository policy files, all Markdown local links, README heading alignment, distribution `LICENSE` / `NOTICE` copies, Claude/Codex adapter text boundaries, Codex interface capabilities, version consistency, JSON files, Python and PowerShell syntax, LF line endings, privacy/secret hygiene, UTF-8 bootstrap behavior, relative-path bootstrap behavior, empty-input `start.py` rejection, and split-argv fallback.
- **Bundled engine or metadata drift**: verify the Claude and Codex engine copies still match the root engine, and that adapter `LICENSE` / `NOTICE` copies match the repo-level files:
  ```powershell
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\sync_plugin_engines.ps1 -Check
  ```
- **start.py errors / no cache**: run it once manually to verify:
  ```powershell
  python -B -X utf8 "<path-to>\SoulAgent\claude_code_plugin\skills\run\soulagent\start.py" "test"
  python -B -X utf8 "<path-to>\SoulAgent\codex_plugin\skills\run\soulagent\start.py" "test"
  ```
  It should print one JSON object (with `status:"ok"`, `engine_dir`, `registry`).
- **creator evolution hangs for a while**: normal — node mode dispatches multiple sub-agents and runs a full pipeline; be patient, or test with a lightweight task first.
- **plugin not loading**: `claude plugin validate "<path-to>\SoulAgent\claude_code_plugin"` should pass; after changes run `/reload-plugins` or restart.

---

## Distribution

### Claude Route A (what you use now): `@skills-dir` plugin
Junction `~/.claude/skills/soulagent` → `claude_code_plugin/`; it auto-loads as `soulagent@skills-dir`, no marketplace needed.

### Claude Route B: `.zip` archive
Zip the **plugin dir** (`claude_code_plugin/`), stripping runtime/private artifacts:

```powershell
$stage = "<path-to>\_pkg\soulagent"
$excludeDirs = @(
  ".execution_cache", ".version_history", ".evolution_snapshot", ".nihil_backup",
  ".pipeline_cache", "__pycache__", ".pytest_cache", ".mypy_cache", ".ruff_cache",
  ".release_tmp", "yijing_history", ".soulbot", "htmlcov", "node_modules",
  "dist", "build", ".tox", ".hypothesis", ".venv", "venv", "env", ".git"
)
$excludeFiles = @(
  "conversation_context.json", "pipeline_run_metadata.json", ".audit_log.json",
  "credentials.json", ".netrc", "_*payload*.json", "_spans*.jsonl*",
  "*_backup.*", "*.backup.*", "*.bak", "*.backup*", "*.pyc", "*.pyo",
  "*.tmp", "*.log", "*.pid", "*.pem", "*.key", "*.pkcs12", "id_rsa*",
  "id_ed25519*", "service-account*.json", "*.db", "*.db-wal", "*.db-shm",
  "*.db-journal", "*.sqlite", "coverage.xml", ".coverage"
)
robocopy "<path-to>\SoulAgent\claude_code_plugin" $stage /E `
  /XD $excludeDirs `
  /XF $excludeFiles
Compress-Archive -Path "$stage\*" -DestinationPath "<path-to>\soulagent-1.0.0.zip" -Force
```
Recipient: `claude --plugin-dir .\soulagent-1.0.0.zip` (or, once hosted, `--plugin-url`).

### Claude Route C: marketplace (formal release)
A marketplace repo with a root `.claude-plugin/marketplace.json` lists this plugin (source = the `claude_code_plugin/` dir); others run `/plugin marketplace add AIXP-Labs/<marketplace-repo>` then `/plugin install soulagent@<marketplace>`. The AIXP ecosystem grouping lives here (e.g. `soulagent@aixp-labs`).

### Codex route: local marketplace
The repository root contains `.agents/plugins/marketplace.json`, which points Codex to `codex_plugin/`. Register it locally:

```powershell
codex plugin marketplace add .
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\release_check.ps1
```

> Before release: `git init`, then the repo-root `.gitignore` auto-excludes private artifacts; before pushing to a public repo, set a **local anonymized git identity** so your real name does not leak via commits.

---

## Quick facts

- Engine: **SoulBot Execute Engine Router**
- AIAP packages: `soulbot_creator_evolution` (node) · `soulbot_yijing_divination` (normal)
- No `soulbot_chat` in the registry → chat goes through **direct_reply**
- Invocation: Claude `/soulagent:run <task>`; Codex `Use $soulagent-run ...`; Form 2 `执行 start.aisop.json 指令：<task>`
- Roots: repo root = `<path-to>\SoulAgent`; Claude plugin = `claude_code_plugin/`; Codex plugin = `codex_plugin/`; host-neutral adapter = `soulagent/`; each adapter keeps `SKILL.md` at `skills/run/` or equivalent and the engine at `soulagent/`
- Aligned with **Axiom 0: Human Sovereignty and Wellbeing**
- Repo <https://github.com/AIXP-Labs/SoulAgent> · homepage soulagent.dev · Apache-2.0 · v1.0.0 · © 2026 AIXP Labs

---

## AIXP Labs [aixp.dev](https://aixp.dev)

AIXP Labs develops and maintains the following core projects:

| Project | Description | Website |
|---------|-------------|---------|
| [HSAW](https://hsaw.dev) | Human Sovereignty and Wellbeing — Axiom 0 white paper (foundation) | hsaw.dev |
| [AIZP](https://aizp.dev) | AI Zenith-Zero Protocol — runtime behavioral alignment | aizp.dev |
| [AILP](https://ailp.dev) | AI List Protocol — agent discovery and capability advertising | ailp.dev |
| [AIVP](https://aivp.dev) | AI Value Protocol — international commerce, crypto asset settlement | aivp.dev |
| [AIRP](https://airp.dev) | AI RMB Protocol — Mainland China commerce, RMB licensed settlement | airp.dev |
| [AIBP](https://aibp.dev) | AI Bot Protocol — social communication and trust | aibp.dev |
| [AIAP](https://aiap.dev) | AI Application Protocol — governance and compliance | aiap.dev |
| [AISOP](https://aisop.dev) | AI Standard Operating Protocol — flow program definition | aisop.dev |
| [SoulAgent](https://soulagent.dev) | Drop-in AI agent invoked directly by any CLI / SDK / IDE **(this project)** | soulagent.dev |
| [SoulBot](https://soulbot.dev) | AI agent runtime & orchestration framework (scheduling, agent-spawn, inter-agent comms) | soulbot.dev |
| [SoulACP](https://soulacp.dev) | Adapter library — bridging CLI tools and LLM providers | soulacp.dev |

---

## ⚠️ Disclaimer

This software is **experimental** and provided for **research and educational purposes only**. Not intended for production use. Use at your own risk. The authors assume no liability for any damages arising from the use of this software. See [LICENSE](LICENSE) for full terms (Apache 2.0).

---

## License

[Apache License 2.0](LICENSE) - Copyright 2026 AIXP Labs AIXP.dev | SoulAgent.dev

---

Align Axiom 0: Human Sovereignty and Wellbeing. Version: SoulAgent V1.0.0. www.soulagent.dev
