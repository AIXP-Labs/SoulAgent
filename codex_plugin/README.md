# SoulAgent Codex Plugin

This is the repo-local Codex plugin for SoulAgent. It exposes one Codex skill:
`soulagent-run` from `skills/run/`.

The skill is self-contained. Its `SKILL.md` is the Codex adapter, and the full
SoulAgent engine lives below the same skill folder at `skills/run/soulagent/`.
The adapter does not depend on absolute paths or on the repository root after
installation.

## Local Marketplace Smoke

From the SoulAgent repository root, register or refresh the local marketplace:

```powershell
codex plugin marketplace add .
```

Then invoke the skill from Codex:

```text
Use $soulagent-run to run SoulAgent for hello.
Use $soulagent-run to cast a Yijing hexagram: is today good for a release?
Use $soulagent-run to create or evolve an AIAP package.
```

Current Codex CLI releases expose marketplace management commands, but not
separate `codex plugin add`, `codex plugin list`, or `codex plugin validate`
subcommands. For release validation, use:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\release_check.ps1
```

## Runtime Boundary

SoulAgent is an execution engine package, not a hosted service. The Codex skill
must read `soulagent/start.aisop.json`, run `python -B -X utf8
soulagent/start.py "<task>"` locally, and then follow the engine bootstrap
exactly.

Agent-mode nodes require a host with a real sub-agent mechanism. If a Codex
environment cannot dispatch sub-agents for an agent-mode node, the orchestrator
must stop and report that missing capability rather than pretending the node was
executed.

## Sync

Refresh all bundled engine copies and distribution `LICENSE` / `NOTICE` files
from the repository root with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\sync_plugin_engines.ps1
```

Use `scripts\sync_plugin_engines.ps1 -Check` before release. It compares the
root `soulagent/soulagent/` engine with both bundled plugin engine copies,
checks distribution metadata copies, and rejects private runtime caches.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\sync_plugin_engines.ps1 -Check
```

For backward compatibility, `scripts\sync_codex_plugin.ps1` remains as a
Codex-only wrapper around `sync_plugin_engines.ps1 -Target codex`.
