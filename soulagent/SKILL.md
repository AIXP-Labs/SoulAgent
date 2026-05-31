---
name: soulagent
description: "Run the SoulBot Execute Engine (AIAP) — chat, Yijing divination, and create / evolve AIAP packages. Host-neutral skill: the orchestrating agent reads and strictly executes the engine's bootstrap program; the task text passed in is the engine user_message."
---

# SoulAgent — host-neutral skill

You are the **orchestrator** for the SoulBot Execute Engine. This is the **host-neutral** variant — usable by any agent that can read files, run Python, and dispatch sub-agents. (The Claude Code-specific adapter lives in `claude_code_plugin/`; the most portable entry is "Form 2" in Notes.)

The engine and its bootstrap live in the **`soulagent/` subfolder beside this file** (paths below are relative to this skill's own directory).

## Input

The task text passed when this skill is invoked (your host's argument mechanism, e.g. `$ARGUMENTS`) is the engine's `user_message`. If empty → ask what to run and **STOP**; never invent a task (Axiom 0).

## Run

1. **[READ]** the AIAP bootstrap program at `soulagent/start.aisop.json`.
2. **Execute it exactly, 100%** as written: `Bootstrap → RunEngine → endNode`. The file's own steps are the single source of truth — do not reinvent, summarize, or skip.
3. Bootstrap runs `python -X utf8 soulagent/start.py "<user_message>"` from this skill's directory; `start.py` self-locates `engine_dir` / `aiap_dir` via `__file__`. Parse its single JSON stdout object (`cache_dir`, `engine_dir`, `router_entry`, `registry`, ...).
4. **[READ]** the Router (`engine_dir/main.aisop.json`) and run its flow `match → execute → engineExec → endNode`.

## Discipline (engine design philosophy — host-neutral)

- **DISPATCH**: each agent-mode node → ONE sub-agent via **your host's sub-agent mechanism**, using the engine's exact bootstrap prompt; never inject auto-approve / skip-confirmation directives (Axiom 0).
- **PYTHON_TOOLS**: pass JSON to python_tools via **STDIN or an args-list** (never inline JSON in a shell); always invoke `python -X utf8` (non-ASCII / emoji JSON fails with a surrogate error otherwise on Windows).
- **SOVEREIGNTY**: after every terminal-status node, run `user_gate_audit.py --enforce`; on `WAITING_USER`, forward the gate question **verbatim** and **STOP** — never decide for the user.
- **SCOPE**: write only under the run's `cache_dir`; do not modify engine production files (`.aisop.json` / `python_tools` / `AIAP.md` / `quality_baseline.json`) unless the task explicitly authorizes a full evolution through ReviewFinalize.

## Output

At the Router's `endNode`, output the engine's final reply (begin with 🤖, in the user's language, with EU AI Act Art.50 disclosure). On `WAITING_USER`, present the pending gate question and wait; the user's reply re-invokes the same node (`start.py` reuses the in-progress turn).

## Notes

- **Form 2 (most portable)**: any agent can skip skill registration and just execute `soulagent/start.aisop.json` directly — no SKILL.md needed.
- **Host-specific frontmatter**: only `name` / `description` are kept here for portability. Claude Code's `disable-model-invocation`, `allowed-tools`, `argument-hint`, and the `${CLAUDE_SKILL_DIR}` variable are host-specific — the Claude adapter in `claude_code_plugin/` uses them and resolves paths via `${CLAUDE_SKILL_DIR}\soulagent\`.

Align Axiom 0: Human Sovereignty and Wellbeing.

---
*SoulAgent v1.0.0 (host-neutral) · Apache-2.0 · © 2026 AIXP Labs · soulagent.dev*
