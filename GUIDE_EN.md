# SoulAgent Guide

[中文](GUIDE_CN.md) | English

> **Status: skeleton (work in progress).** This guide goes deeper than the [README](README.md) on per-package usage and the engine internals. Sections marked _TODO_ will be filled in as behavior stabilizes (the README remains the source of truth for install & invocation until then).

---

## 1. Scope

What this guide adds beyond the [README](README.md): hands-on walkthroughs for each task type, an AIAP package reference, and the engine's orchestration internals. For install, invocation, and the Skill-vs-Plugin decision, see the README.

## 2. Skill mode vs Plugin mode (recap)

See the README's "Skill mode vs Plugin mode" section. In one line: this package ships in **plugin layout** (`claude_code_plugin/skills/run/` + `plugin.json`) → `/soulagent:run`; a **standalone layout** (root `SKILL.md`, no `plugin.json`) gives the short `/soulagent`. The two are alternative layouts, not a runtime toggle.

_TODO: side-by-side install walkthrough for each._

## 3. Task type — Chat (`direct_reply`)

- **When**: conversational / general messages with no specialized package match.
- **Path**: Router `match` → `no_match` → direct reply (no engine, no sub-agent — the lightest path).
- **Example**: `/soulagent:run 你好`

_TODO: examples, what context the engine reads, output format._

## 4. Task type — Yijing divination (`normal` mode)

- **Invocation**: `/soulagent:run 帮我算一卦：<your question>`
- **Flow**: `Start → NLU → CastHexagram → InterpretHexagram → GiveAdvice → SaveRecord → endNode`
- **Mechanics**: three-coin method (6 casts), 64-hexagram identification, changing lines, derived hexagram.
- **Persistence**: records saved under `claude_code_plugin/skills/run/soulagent/aiap/soulbot_yijing_divination_aiap/yijing_history/` (git-ignored).

_TODO: hexagram reading rules (Master Yin's rules), repeat-divination guard, disclaimers & compliance framing, history/clear flow._

## 5. Task type — Creator evolution (`node` mode)

- **Invocation**: `/soulagent:run 使用 creator 进化 <package>`
- **Weight**: heaviest path — full pipeline, multiple sub-agents dispatched via the Task tool, can take minutes.
- **Authorization**: by default the engine will NOT modify production files; a real evolution must be explicitly authorized and runs all the way through ReviewFinalize.

_TODO: how to phrase an evolution request, what ReviewFinalize verifies, governance_hash TRI-SYNC, reading the dispatch audit, interpreting ThreeDimTest scores._

## 6. AIAP package reference

| Package | Mode | Purpose |
|---|---|---|
| `soulbot_creator_evolution` | node | create / evolve AIAP packages |
| `soulbot_yijing_divination` | normal | Yijing divination (cultural learning) |
| `soulbot_intent_classifier` | — | intent classification (used when `match` is uncertain) |

_TODO: per-package node maps, inputs/outputs, trust levels._

## 7. Orchestration internals

See the README "How it runs internally" chain. The four terminal-orchestrator disciplines — DISPATCH / PYTHON_TOOLS / SOVEREIGNTY / SCOPE — are defined in `start.aisop.json`'s `RunEngine.step2`.

_TODO: node loop, cache (`_index.json`) lifecycle, RESUME on user gates, sub-agent dispatch records._

## 8. Sovereignty & user gates

When the engine reaches a decision that is yours, it halts at `WAITING_USER` and asks. Answer by invoking again with your reply (`/soulagent:run <answer>`); `start.py` reuses the in-progress turn and resumes the same node.

_TODO: gate types, `user_gate_audit.py --enforce`, what the orchestrator must never auto-approve._

## 9. Writing your own AIAP package

_TODO: package layout (`*_aiap/` with `main.aisop.json` + `AIAP.md`), loading modes, registering it (it is auto-discovered from `claude_code_plugin/skills/run/soulagent/aiap/`), governance metadata._

## 10. Troubleshooting (deep)

See the README troubleshooting table for common cases.

_TODO: engine-level diagnostics, reading cache state, dispatch-audit severities, long-session memory notes._

---

Align Axiom 0: Human Sovereignty and Wellbeing. Version: SoulAgent V1.0.0. www.soulagent.dev
