# Contributing to SoulAgent

[中文](CONTRIBUTING_CN.md) | English

Thank you for your interest in contributing to SoulAgent!

> ⚠️ **Contribution Status (Current Stage)**
>
> We welcome **discussion through GitHub Issues** at this stage of development.
>
> **External Pull Requests are not currently accepted.** If you have a proposal — bug report, feature idea, new AIAP package, or improvement — please open an issue describing it. If we agree it adds value, maintainers will implement it and credit you.
>
> This policy may be revisited in the future.

> **Stage Status (v1.0.0)**
>
> SoulAgent is at an early development stage. The processes below describe the *target* development model. Initial decisions are made by AIXP Labs core maintainers; the community discussion period scales as the contributor base grows.

## What SoulAgent Is

SoulAgent packages the **SoulBot Execute Engine** as Claude Code and Codex skills, plus a host-neutral direct engine entry (Path A: official host CLI + subscription where applicable, no soulacp/ACP). It is part of the `soulbot.dev` Executor Layer — see [GOVERNANCE.md](GOVERNANCE.md). Contributions therefore touch one of four areas:

1. **Packaging / skill layer** — `claude_code_plugin/`, `codex_plugin/`, `.agents/plugins/`, `.claude-plugin/`, `SKILL.md`, `plugin.json`, install/distribution
2. **Engine / AIAP layer** — source engine at `soulagent/soulagent/`, plus bundled copies under `claude_code_plugin/skills/run/soulagent/` and `codex_plugin/skills/run/soulagent/` (deep protocol changes flow through `aiap.dev`)
3. **Release tooling** — `scripts/sync_plugin_engines.ps1`, `scripts/sync_codex_plugin.ps1`, `scripts/release_check.ps1`, gitignore/release hygiene
4. **Docs** — README, guides, architecture, privacy, security, this file, etc.

## How to Contribute

### Reporting Issues

- Use [GitHub Issues](https://github.com/AIXP-Labs/SoulAgent/issues) to report bugs, suggest features, or propose new packages
- Include Claude Code or Codex CLI version, Python version, OS, and exact invocation
- Provide minimal reproduction steps
- For AISOP / AIAP-related issues, link to the relevant `.aisop.json` file
- **Never paste private content** — scrub real paths, usernames, secrets, and `.execution_cache/` contents from logs (see [.gitignore](.gitignore))

### Discussion-Driven Development

1. Propose discussion via issue
2. Maintainers evaluate value, feasibility, and Axiom 0 alignment
3. After consensus, maintainers implement the change
4. Contributors are credited in commit / release notes

## Guidelines

### Quality Standards

- `python_tools/` follow the engine's existing style; Python 3.10+ type hints where practical
- Always invoke `python` with at least `-X utf8` for any tool that reads/writes JSON containing non-ASCII / emoji; release/smoke checks use `python -B -X utf8` (Windows surrogate and pycache guard)
- No wildcard imports; keep functions documented
- Before release, run `python -m pip install -r requirements-dev.txt`, then `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\release_check.ps1`; GitHub Actions runs the same gate on push, pull request, and manual dispatch with the approved anonymous release metadata.
- For final local release verification with both host CLIs installed, run `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\release_check.ps1 -RequireHostCli`.

### AISOP / AIAP Contributions

Changes to AISOP blueprints (`.aisop.json`) or AIAP packages (`*_aiap/`) should:

- Follow the [AIAP Protocol](https://github.com/AIXP-Labs/AIAP) specification
- Maintain deterministic execution paths in mermaid graphs
- Preserve the engine's four terminal-orchestrator disciplines (DISPATCH / PYTHON_TOOLS / SOVEREIGNTY / SCOPE)
- Keep governance metadata (`AIAP.md`, `quality_baseline.json`, TRI-SYNC `governance_hash`) consistent
- Never bake absolute paths (e.g. a real `$HOME`) into templates — keep them relative / placeholder
- Keep bundled engine copies synchronized. `scripts/release_check.ps1` rejects Claude/Codex bundle drift and runtime/private artifacts.

### Bilingual Note

Issues and discussion may be in English or Chinese.

## Code of Conduct

By participating, you agree to abide by the [Code of Conduct](CODE_OF_CONDUCT.md).

## License of Contributions

By submitting (via issue or any future PR), your contribution is licensed under [Apache License 2.0](LICENSE).

Copyright 2026 AIXP Labs AIXP.dev | SoulAgent.dev

---

Align Axiom 0: Human Sovereignty and Wellbeing. Version: SoulAgent V1.0.0. www.soulagent.dev
