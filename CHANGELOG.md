# Changelog

All notable changes to SoulAgent are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-05-30

Initial release. Packages the **SoulBot Execute Engine** as Claude Code and Codex skill plugins, with a host-neutral direct engine entry.

### Added

- **Claude `/soulagent:run` skill** (`claude_code_plugin/skills/run/SKILL.md`) — the current interactive Claude Code session acts as terminal orchestrator (Path A: official CLI + subscription, **no soulacp/ACP**).
- **Codex `$soulagent-run` skill** (`codex_plugin/skills/run/SKILL.md`) — local Codex plugin adapter with repo-local marketplace metadata under `.agents/plugins/marketplace.json`.
- **Host-neutral Form 2 entry** — agents can directly execute a bundled `start.aisop.json` when no native plugin is installed.
- **Bootstrap chain** — `start.aisop.json` (AIAP orchestrator-bootstrap) + `start.py` (cache + AIAP registry loader, self-locating via `__file__`).
- **Bundled engine** — SoulBot Execute Engine Router (`soulagent/soulagent/`, mirrored into Claude and Codex adapters) with node/normal engines and `python_tools/`.
- **Bundled AIAP packages** — `soulbot_creator_evolution` (node), `soulbot_yijing_divination` (normal); plus `soulbot_intent_classifier` for match disambiguation.
- **Self-contained, relative addressing** — Claude resolves via `${CLAUDE_SKILL_DIR}`, Codex resolves via its skill root, and `start.py` self-locates through `__file__`; zero absolute paths in the skill contract.
- **Plugin packaging (Route A)** — `.claude-plugin/plugin.json` + skill at `claude_code_plugin/skills/run/` → loads as `soulagent@skills-dir`; invocation `/soulagent:run`.
- **Codex packaging** — `.codex-plugin/plugin.json` + `codex_plugin/skills/run/` + `.agents/plugins/marketplace.json`; invocation `Use $soulagent-run ...`.
- **Release validation** — `scripts/sync_plugin_engines.ps1`, `scripts/sync_codex_plugin.ps1`, `scripts/release_check.ps1`, and `requirements-dev.txt` validate bundle sync, serialized release-check execution, the Codex sync wrapper, optional `-RequireHostCli` host CLI enforcement, sync-script exclusion coverage, Claude/Codex plugin manifests, Codex marketplace registration, skill shape and Codex SKILL frontmatter, anonymized Git metadata, repository policy files, GitHub Actions release-gate wiring with explicit Python setup and declared PyYAML dependency, manual dispatch, and read-only diff check, documented package exclusion examples, Claude staged-package and zip/archive smoke, JSON/YAML parseability, Python and PowerShell syntax, all Markdown local links, README heading alignment, distribution `LICENSE` / `NOTICE` copies, Claude/Codex adapter text boundaries, Codex interface capabilities, version consistency, privacy/secret hygiene, LF line endings, UTF-8 and relative-path bootstrap round-trips, empty-input `start.py` rejection, split-argv fallback, and runtime/private artifact hygiene.
- **Distribution metadata** — Claude `_meta.json` registry manifest, Codex `.codex-plugin/plugin.json` + `.agents/plugins/marketplace.json`, and shared `LICENSE` / `NOTICE` copies.
- **`.gitignore`** — excludes runtime/private artifacts (`.execution_cache/`, `conversation_context.json`, `yijing_history/`, `.evolution_snapshot/`, `.nihil_backup/`, backups, keys) from version control.
- **Documentation** — `README.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`, `CONTRIBUTING.md`, `GOVERNANCE.md`, this `CHANGELOG.md`.

### Engine disciplines enforced

- **DISPATCH** — agent-mode nodes dispatched through the active host's real sub-agent mechanism; no injected auto-approve/skip-confirmation directives; stop if the host cannot dispatch required sub-agents.
- **PYTHON_TOOLS** — JSON passed via STDIN/file-input flags/args-list (never inline in PowerShell); `python -X utf8` minimum and `python -B -X utf8` for release/smoke checks to avoid Windows non-BMP/emoji surrogate and pycache issues.
- **SOVEREIGNTY** — `user_gate_audit.py --enforce` after terminal-status nodes; halt at `WAITING_USER`, never self-approve.
- **SCOPE** — writes confined to the run's `cache_dir`; engine production files untouched without explicit evolution authorization.

[1.0.0]: https://github.com/AIXP-Labs/SoulAgent/releases/tag/v1.0.0

---

Align Axiom 0: Human Sovereignty and Wellbeing. Version: SoulAgent V1.0.0. www.soulagent.dev
