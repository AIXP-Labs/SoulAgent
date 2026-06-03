# Privacy Policy — SoulAgent

_Last updated: 2026-06-03_

**Short version: SoulAgent collects nothing. It runs on your machine and has no server or backend.**

## What SoulAgent is

SoulAgent is a Claude Code skill / plugin that runs the SoulBot Execute Engine locally. Your current Claude Code session is the orchestrator — there is **no SoulAgent server, backend, or hosted service**.

## Data we collect

**None.** SoulAgent does not collect, transmit, sell, or share any personal data, usage data, analytics, or telemetry — neither with the authors nor with any third party. There is no "phone home".

## Local storage (stays on your device)

SoulAgent writes only to local files inside your own workspace, which never leave your machine:

- `**/.execution_cache/` — per-run execution cache (includes the prompts of the current run). Git-ignored.
- `**/yijing_history/` — optional Yijing divination history (your questions + results), only if you use divination. Git-ignored.
- OpenTelemetry spans, if you enable observability, are written **locally**; no external exporter is configured by default.

You can delete these directories at any time. The bundled Yijing package follows a data-minimization policy: no personal identifiers, no biometric data, no third-party sharing, with a lazy local purge of old records.

## Network

The engine's own tools are file-system based. SoulAgent sends nothing to us. If a task you run explicitly requires web research, the engine may use **Claude Code's own built-in web search / fetch** — those requests are made by Claude Code itself (subject to Anthropic's terms), not by any SoulAgent service.

## Children

SoulAgent is not directed at children under 13. The bundled Yijing package declines interactions from users who self-identify as under 13.

## AI-generated content

All engine output is AI-generated and labeled as such (EU AI Act Art.50).

## Changes

Any updates to this policy will be published in this file in the repository.

## Contact

noreply@soulagent.dev · <https://github.com/AIXP-Labs/SoulAgent>
