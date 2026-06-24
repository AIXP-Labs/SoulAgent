# SoulAgent Guide

[中文](GUIDE_CN.md) | English

> This guide goes deeper than the [README](README.md) on per-package usage and the engine internals. The README remains the source of truth for install commands and release packaging.

---

## 1. Scope

What this guide adds beyond the [README](README.md): hands-on walkthroughs for each task type, an AIAP package reference, and the engine's orchestration internals. For install, invocation, and host-specific plugin details, see the README.

## 2. Host modes (recap)

SoulAgent currently ships three adapters:

- **Claude Code plugin**: `claude_code_plugin/` -> `/soulagent:run <task>`
- **Codex plugin**: `codex_plugin/` -> `Use $soulagent-run ...`
- **Host-neutral Form 2**: point a capable agent directly at `start.aisop.json`

The adapters are alternative host entry points around the same bundled engine, not runtime toggles.

## 3. Task type — Chat (`direct_reply`)

- **When**: conversational / general messages with no specialized package match.
- **Path**: Router `match` → `no_match` → direct reply (no engine, no sub-agent — the lightest path).
- **Example**: `/soulagent:run 你好` or `Use $soulagent-run to run SoulAgent for hello.`

- **Context read**: the router reads the current `user_message`, the package registry, and the intent classifier package when the match is uncertain. It does not need production-file writes or sub-agent dispatch for this path.
- **Output shape**: final user-facing replies should be returned directly in the user's language. No `Router:` / `Engine:` debug prefix should be exposed unless the user asks for diagnostics.
- **Good first smoke**: `hello`, `what can you do`, or a short bilingual greeting. These verify plugin loading and bootstrap routing without touching heavier AIAP packages.

## 4. Task type — Yijing divination (`normal` mode)

- **Invocation**: `/soulagent:run 帮我算一卦：<your question>` or `Use $soulagent-run to cast a Yijing hexagram: <your question>`
- **Flow**: `Start → NLU → CastHexagram → InterpretHexagram → GiveAdvice → SaveRecord → endNode`
- **Mechanics**: three-coin method (6 casts), 64-hexagram identification, changing lines, derived hexagram.
- **Persistence**: records are saved under the active adapter's bundled `soulagent/aiap/soulbot_yijing_divination_aiap/yijing_history/` directory (git-ignored and rejected by release checks).

- **Reading frame**: the package is for cultural learning and reflective interpretation. Treat the result as symbolic guidance, not financial, legal, medical, or safety-critical advice.
- **Repeat-divination guard**: if the user repeatedly asks the same decision question, prefer summarizing the prior reading and ask whether they want a fresh cast before continuing.
- **History**: `yijing_history/` is runtime data only. It is git-ignored, rejected by release checks, and should be cleared before packaging or publishing.
- **Privacy**: do not place private user questions into source-controlled examples, test fixtures, screenshots, or docs.

## 5. Task type — Creator evolution (`node` mode)

- **Invocation**: `/soulagent:run 使用 creator 进化 <package>` or `Use $soulagent-run to create or evolve an AIAP package.`
- **Weight**: heaviest path — full pipeline, multiple sub-agents dispatched through the active host's real sub-agent mechanism, can take minutes. If the host cannot dispatch sub-agents, the orchestrator must stop and report the missing capability.
- **Authorization**: by default the engine will NOT modify production files; a real evolution must be explicitly authorized and runs all the way through ReviewFinalize.

- **Request shape**: name the target package and desired change explicitly, for example `use creator to evolve <package>: add typed error routing and update docs`.
- **ReviewFinalize**: a production evolution should reach the final review gate, recompute governance hashes, keep TRI-SYNC metadata aligned, and preserve user sovereignty gates.
- **Dispatch audit**: read dispatch records as evidence that agent-mode nodes were actually dispatched through the host mechanism. Do not treat a claimed dispatch as proof unless the audit supports it.
- **ThreeDimTest scores**: use them as review signals, not automatic truth. A low score should trigger investigation; a high score still needs source and behavior checks.

## 6. AIAP package reference

| Package | Mode | Entry file | Typical path | Trust note |
|---|---|---|---|---|
| `soulbot_creator_evolution` | node | `aiap/soulbot_creator_evolution_aiap/main.aisop.json` | research -> generate/modify -> validate -> review -> finalize | Highest impact; requires explicit user authorization before production edits |
| `soulbot_yijing_divination` | normal | `aiap/soulbot_yijing_divination_aiap/main.aisop.json` | NLU -> cast -> interpret -> advise -> save | Cultural/reflective only; no high-stakes decisions |
| `soulbot_intent_classifier` | support | `soulbot_intent_classifier_aiap/main.aisop.json` | classify -> route | Router support package; should stay lightweight and deterministic where possible |

## 7. Orchestration internals

See the README "How it runs internally" chain. The four terminal-orchestrator disciplines — DISPATCH / PYTHON_TOOLS / SOVEREIGNTY / SCOPE — are defined in `start.aisop.json`'s `RunEngine.step2`.

- **Node loop**: the router selects a package and mode, then the engine advances node by node until a terminal status, user gate, or error path.
- **Cache lifecycle**: each run uses an execution cache turn directory with `_index.json`, node payloads, audit files, and status records. Mutate it through bundled tools such as `agent_update_index.py` and `agent_write_node_cache.py`.
- **RESUME**: when `_index.json` contains an in-progress turn waiting on the user, the next invocation resumes that turn instead of creating a new one.
- **Dispatch records**: agent-mode nodes must leave enough audit evidence to show what was dispatched, which host mechanism was used, and how the result re-entered the engine.

## 8. Sovereignty & user gates

When the engine reaches a decision that is yours, it halts at `WAITING_USER` and asks. Answer by invoking again with your reply (`/soulagent:run <answer>`); `start.py` reuses the in-progress turn and resumes the same node.

- **Gate types**: confirmation, rejection, timeout, and review/finalize gates can all pause execution.
- **Required check**: after every terminal-status node, run `user_gate_audit.py --enforce` before continuing or reporting completion.
- **Never auto-approve**: do not convert the original task text into permission to modify files, skip review, publish, push, or answer a sovereignty prompt on the user's behalf.
- **Reply discipline**: on `WAITING_USER`, relay only the pending gate question and wait for the next user message.

## 9. Writing your own AIAP package

- **Layout**: place each package under `soulagent/aiap/<name>_aiap/` with at least `main.aisop.json`, `AIAP.md`, `agent_card.json`, and any package-local `tool_dirs/` resources it declares.
- **Registration**: packages are discovered from the active bundled `soulagent/aiap/` directory. After adding a package, resync plugin engine copies with `scripts/sync_plugin_engines.ps1`.
- **Modes**: use `normal` for inline deterministic flows, `lite` for lightweight assisted paths, and `node` when host sub-agent dispatch is required.
- **Governance**: keep quality baseline, governance hash, and documentation aligned. Do not publish runtime caches or user data as package source.

## 10. Troubleshooting (deep)

See the README troubleshooting table for common cases.

- **Release gate**: run `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\release_check.ps1` from the repository root before publishing.
- **Cache diagnostics**: inspect the current turn directory and `_index.json`, then use bundled audit tools rather than editing cache JSON manually.
- **Dispatch severity**: treat non-OK dispatch audit severities as release blockers for node-mode packages until explained.
- **Long sessions**: if a run appears stuck, check whether it is waiting on a user gate before restarting; restarting may abandon the in-progress turn.

---

Align Axiom 0: Human Sovereignty and Wellbeing. Version: SoulAgent V1.0.0. www.soulagent.dev
