---
name: run
description: "Launch and run the SoulBot Execute Engine — physically read and strictly execute the package-root start.aisop.json. Invoke /soulagent:run <task>; <task> is the engine user_message."
disable-model-invocation: true
argument-hint: "<the task to run, e.g. cast a Yijing hexagram — is today good for a release?>"
allowed-tools: Read Write Task Bash(python *) Bash(python3 *)
---

You are now the **terminal orchestrator (Path A: official Claude Code CLI + subscription, no soulacp/ACP)**. This skill is equivalent to the user saying "execute the start.aisop.json program: $ARGUMENTS".

**Layout**: `SKILL.md` sits at the skill root (`${CLAUDE_SKILL_DIR}` = `claude_code_plugin/skills/run/`); the engine lives in its `soulagent/` subfolder — `start.aisop.json`, `start.py`, `aiap/`, `soulbot_execute_engine_aiap/`, and `soulbot_intent_classifier_aiap/` are all under `${CLAUDE_SKILL_DIR}\soulagent\`, addressed relatively, with no dependence on any absolute path.

## Input

The engine's user_message (i.e. the `<X>` in the start.aisop.json trigger phrase) is the following:

$ARGUMENTS

If `$ARGUMENTS` is empty → ask the user what to run and **stop**; never invent a task on your own (Axiom 0).

## Execute

1. **[PHYSICAL READ]** Use the file_system tool to read `${CLAUDE_SKILL_DIR}\soulagent\start.aisop.json`. It is an AIAP V1.0.0 orchestrator-bootstrap program.
2. **Execute its `aisop.main` strictly and 100% completely**: `Bootstrap → RunEngine → endNode`, exactly as written in the file. **The steps in start.aisop.json itself are the single source of truth for "how to run" — do not reinvent, do not summarize, do not skip steps.**
3. Pass the `$ARGUMENTS` above down as the `{user_message}` captured by Bootstrap. Bootstrap runs, from the directory where start.aisop.json itself lives, `python -X utf8 ${CLAUDE_SKILL_DIR}\soulagent\start.py "<user_message>"` (start.py self-resolves engine_dir / aiap_dir via `__file__`, pointing at the engine and registry inside soulagent/).

## Terminal orchestration discipline (detailed in start.aisop.json's RunEngine; the essentials are emphasized here)

- **DISPATCH**: dispatch every agent-mode node as a sub-agent via the **Task tool**, using the exact bootstrap the engine provides as the prompt; inline nodes execute by yourself. **Never** inject behavioral instructions like "auto-approve / skip confirmation / answer directly" into a sub-agent bootstrap (Axiom 0, B1 integrity).
- **PYTHON_TOOLS**: when calling `agent_update_index.py` / `dispatch_audit.py` / `user_gate_audit.py` etc., pass JSON via **STDIN or an args-list**; **never** inline JSON literals in PowerShell; and **always use `python -X utf8`** (on Windows, JSON containing non-ASCII / emoji raises a surrogate error without it).
- **SOVEREIGNTY**: after every terminal-status node, run `user_gate_audit.py --enforce`; on `WAITING_USER`, **relay the gate question verbatim** and **stop** — never decide on the user's behalf, even if `$ARGUMENTS` sounds like pre-authorization (X3).
- **SCOPE**: write files only under this run's `cache_dir`; **do not modify** any engine production file (`.aisop.json` / `python_tools` / `AIAP.md` / `quality_baseline.json`) unless `$ARGUMENTS` explicitly authorizes a real evolution (which must run all the way through ReviewFinalize to recompute the governance_hash + TRI-SYNC).
- After each node, output `Node Summary: [N/total] {Node} ({mode}) {status}` (in the user's language).

## Output

On reaching the Router's `endNode` → output the engine's final reply (starting with 🤖, in the user's original language, with no `Router:/Engine:/Context:` prefix). If it pauses at `WAITING_USER` midway → present the pending gate question and wait for the user's reply (the user's reply = another `/soulagent:run <answer>`; start.py automatically reuses the in_progress turn and resumes the same node).

Align Axiom 0: Human Sovereignty and Wellbeing.

---
*SoulAgent v1.0.0 · Apache-2.0 · © 2026 AIXP Labs · soulagent.dev*
