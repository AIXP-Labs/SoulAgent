# Changelog

All notable changes to SoulAgent are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-05-30

Initial release. Packages the **SoulBot Execute Engine** as a Claude Code skill/plugin.

### Added

- **`/soulagent` skill** (`SKILL.md`) — the current interactive Claude Code session acts as terminal orchestrator (Path A: official CLI + subscription, **no soulacp/ACP**).
- **Bootstrap chain** — `start.aisop.json` (AIAP orchestrator-bootstrap) + `start.py` (cache + AIAP registry loader, self-locating via `__file__`).
- **Bundled engine** — SoulBot Execute Engine Router (`claude_code_plugin/skills/run/soulagent/soulbot_execute_engine_aiap/`) with node/normal engines and `python_tools/`.
- **Bundled AIAP packages** — `soulbot_creator_evolution` (node), `soulbot_yijing_divination` (normal); plus `soulbot_intent_classifier` for match disambiguation.
- **Self-contained, relative addressing** — all paths resolve via `${CLAUDE_SKILL_DIR}` and `__file__`; zero absolute paths in the skill contract.
- **Plugin packaging (Route A)** — `.claude-plugin/plugin.json` + skill at `claude_code_plugin/skills/run/` → loads as `soulagent@skills-dir`; invocation `/soulagent:run`.
- **Distribution metadata** — `_meta.json` (registry manifest), `LICENSE` (Apache-2.0), `NOTICE`.
- **`.gitignore`** — excludes runtime/private artifacts (`.execution_cache/`, `conversation_context.json`, `yijing_history/`, `.evolution_snapshot/`, `*.bak`, keys) from version control.
- **Documentation** — `README.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`, `CONTRIBUTING.md`, `GOVERNANCE.md`, this `CHANGELOG.md`.

### Engine disciplines enforced

- **DISPATCH** — agent-mode nodes dispatched as sub-agents via the Task tool; no injected auto-approve/skip-confirmation directives.
- **PYTHON_TOOLS** — JSON passed via STDIN/args-list (never inline in PowerShell); `python -X utf8` mandated to avoid the Windows non-BMP/emoji surrogate write failure.
- **SOVEREIGNTY** — `user_gate_audit.py --enforce` after terminal-status nodes; halt at `WAITING_USER`, never self-approve.
- **SCOPE** — writes confined to the run's `cache_dir`; engine production files untouched without explicit evolution authorization.

[1.0.0]: https://github.com/AIXP-Labs/SoulAgent/releases/tag/v1.0.0

---

Align Axiom 0: Human Sovereignty and Wellbeing. Version: SoulAgent V1.0.0. www.soulagent.dev
