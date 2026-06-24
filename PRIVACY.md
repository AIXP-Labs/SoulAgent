# Privacy Policy — SoulAgent

_Last updated: 2026-06-03_

**Short version: SoulAgent collects nothing. It runs on your machine and has no SoulAgent server or backend.**

## What SoulAgent is

SoulAgent packages the SoulBot Execute Engine as local Claude Code and Codex skills, plus a host-neutral direct engine entry. Your current host session is the orchestrator — there is **no SoulAgent server, backend, or hosted service**.

## Data we collect

**None.** SoulAgent does not collect, transmit, sell, or share any personal data, usage data, analytics, or telemetry — neither with the authors nor with any third party. There is no "phone home".

## Local storage (stays on your device)

SoulAgent writes only to local files inside your own workspace, which never leave your machine:

- `**/.execution_cache/` — per-run execution cache (includes the prompts of the current run). Git-ignored.
- `**/yijing_history/` — optional Yijing divination history (your questions + results), only if you use divination. Git-ignored.
- `**/.nihil_backup/`, `*_backup.*`, and `*.bak` — temporary local rollback or backup artifacts created by evolution workflows. Git-ignored and rejected by release checks.
- OpenTelemetry spans, if you enable observability, are written **locally**; no external exporter is configured by default.

You can delete these directories at any time. The bundled Yijing package follows a data-minimization policy: no personal identifiers, no biometric data, no third-party sharing, with a lazy local purge of old records.

## Network

The engine's own tools are file-system based. SoulAgent sends nothing to us. If a task you run explicitly requires web research, the active host may use its own built-in web search / fetch capability. Those requests are made by the host tool you are using, subject to that host's terms, not by any SoulAgent service.

## Children

SoulAgent is not directed at children under 13. The bundled Yijing package declines interactions from users who self-identify as under 13.

## AI-generated content

All engine output is AI-generated and labeled as such (EU AI Act Art.50).

## Changes

Any updates to this policy will be published in this file in the repository.

## Contact

noreply@SoulAgent.dev · <https://github.com/AIXP-Labs/SoulAgent>
