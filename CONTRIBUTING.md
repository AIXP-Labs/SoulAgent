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

SoulAgent packages the **SoulBot Execute Engine** as a Claude Code skill/plugin (Path A: official CLI + subscription, no soulacp/ACP). It is part of the `soulbot.dev` Executor Layer — see [GOVERNANCE.md](GOVERNANCE.md). Contributions therefore touch one of three areas:

1. **Packaging / skill layer** — `SKILL.md`, `start.aisop.json`, `start.py`, `plugin.json`, install/distribution
2. **Engine / AIAP layer** — `claude_code_plugin/skills/run/soulagent/soulbot_execute_engine_aiap/`, `claude_code_plugin/skills/run/soulagent/aiap/*_aiap/` (these mirror upstream; deep protocol changes flow through `aiap.dev`)
3. **Docs** — README, this file, etc.

## How to Contribute

### Reporting Issues

- Use [GitHub Issues](https://github.com/AIXP-Labs/SoulAgent/issues) to report bugs, suggest features, or propose new packages
- Include Claude Code CLI version, Python version, OS, and exact invocation
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
- Always invoke `python` with `-X utf8` for any tool that reads/writes JSON containing non-ASCII / emoji (Windows surrogate guard)
- No wildcard imports; keep functions documented

### AISOP / AIAP Contributions

Changes to AISOP blueprints (`.aisop.json`) or AIAP packages (`*_aiap/`) should:

- Follow the [AIAP Protocol](https://github.com/AIXP-Labs/AIAP) specification
- Maintain deterministic execution paths in mermaid graphs
- Preserve the engine's four terminal-orchestrator disciplines (DISPATCH / PYTHON_TOOLS / SOVEREIGNTY / SCOPE)
- Keep governance metadata (`AIAP.md`, `quality_baseline.json`, TRI-SYNC `governance_hash`) consistent
- Never bake absolute paths (e.g. a real `$HOME`) into templates — keep them relative / placeholder

### Bilingual Note

Issues and discussion may be in English or Chinese.

## Code of Conduct

By participating, you agree to abide by the [Code of Conduct](CODE_OF_CONDUCT.md).

## License of Contributions

By submitting (via issue or any future PR), your contribution is licensed under [Apache License 2.0](LICENSE).

Copyright 2026 AIXP Labs AIXP.dev | SoulAgent.dev

---

Align Axiom 0: Human Sovereignty and Wellbeing. Version: SoulAgent V1.0.0. www.soulagent.dev
