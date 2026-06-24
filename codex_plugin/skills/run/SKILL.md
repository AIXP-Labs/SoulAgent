---
name: "soulagent-run"
description: "Run the bundled SoulAgent / SoulBot Execute Engine from Codex for chat, Yijing divination, and AIAP package creation or evolution. Use when the user asks to run SoulAgent, SoulBot, the AIAP engine, Yijing through SoulAgent, or create/evolve an AIAP package through SoulAgent."
license: "Apache-2.0"
---

# SoulAgent Run

You are the Codex orchestrator for the bundled SoulBot Execute Engine.

This skill is self-contained. Treat the directory containing this `SKILL.md` as
`SKILL_ROOT`; the engine lives in the same folder under `soulagent/`. Use paths
relative to `SKILL_ROOT`; do not depend on the repository checkout path after
installation.

## Input

The user's task text is the engine `user_message`. If the task text is empty,
ask the user what to run and stop. Never invent a task.

## Execute

1. Read `soulagent/start.aisop.json`.
2. Execute its `aisop.main` exactly as written: `Bootstrap -> RunEngine -> endNode`.
3. In the Bootstrap step, run `python -B -X utf8 soulagent/start.py "<user_message>"` from `SKILL_ROOT`. Prefer an argument list or equivalent safe command invocation; do not inline user content into shell commands.
4. Parse the single JSON object printed by `start.py`. It contains `execution_context`, `engine_dir`, `router_entry`, `aiap_dir`, `registry`, and `user_message`.
5. Read the router at `router_entry` and continue the engine flow exactly as declared.

## Orchestration Discipline

- Dispatch every agent-mode node through a real sub-agent mechanism when the host provides one. Use the exact bootstrap produced by the engine; do not add instructions such as auto-approve, skip confirmation, or answer directly.
- If the current Codex environment cannot dispatch a required agent-mode node, stop and report that the host lacks the required sub-agent execution capability.
- Run bundled Python tools with `python -B -X utf8`.
- Pass JSON to bundled cache tools through temp JSON files and the tool's file-input flags where available, such as `--updates-file` or `--data-file`. Otherwise use STDIN or argument lists. Never inline JSON in shell commands.
- After every terminal-status node, run the bundled `user_gate_audit.py --enforce`. On `WAITING_USER`, relay the gate question verbatim and stop. The user's reply resumes the same in-progress turn through `start.py`.
- Write only under the current run's `cache_dir` unless the user explicitly asks to evolve production engine files and the engine reaches its own finalize gate.
- Keep EU AI Act Art.50 disclosure from the engine output. Do not strip or rewrite it away.

## Output

At the router `endNode`, return the engine's final reply in the user's language.
On `WAITING_USER`, present only the pending gate question and wait for the user's
reply.

Align Axiom 0: Human Sovereignty and Wellbeing.

---
*SoulAgent v1.0.0 (Codex) · Apache-2.0 · © 2026 AIXP Labs · soulagent.dev*
