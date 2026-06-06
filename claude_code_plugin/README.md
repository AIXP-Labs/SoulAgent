# SoulAgent

**SoulBot Execute Engine as a Claude Code skill / plugin.** Your current session orchestrates the full AIAP engine — chat, Yijing divination, and creating / evolving any AIAP agent program. Glass-box, sovereignty-first (Axiom 0), **no API key required**.

> This directory (`claude_code_plugin/`) is the installable plugin. Source & full docs: [github.com/AIXP-Labs/SoulAgent](https://github.com/AIXP-Labs/SoulAgent) · [soulagent.dev](https://soulagent.dev/)

---

## Install

**From the AIXP marketplace** (available now):
```
/plugin marketplace add AIXP-Labs/SoulAgent
/plugin install soulagent@aixp
```

**From the Claude community marketplace** (once listed):
```
/plugin marketplace add anthropics/claude-plugins-community
/plugin install soulagent@claude-community
```

Restart Claude Code after installing so the `/soulagent:run` command registers.

---

## Usage

Invoke the engine with `/soulagent:run <task>` — `<task>` is the engine's user message:

```
/soulagent:run hello                                          # chat
/soulagent:run cast a Yijing hexagram — is today good for a release?
/soulagent:run create an AIAP program: a daily to-do list     # create / evolve
```

The session itself becomes the engine's terminal orchestrator: it physically reads the package-root `start.aisop.json` and runs it through to completion — classify intent → route → execute → reply.

## What it does

- **Chat** — direct, sovereignty-aligned replies.
- **Yijing divination** — cast & interpret a hexagram for a question.
- **Create / evolve AIAP programs** — scaffold a new AIAP agent package, or evolve an existing one through the full research → generate → review → finalize pipeline.

## Design

- **Glass-box** — every step is an inspectable AISOP/AIAP node; nothing is hidden behind an opaque API.
- **Sovereignty-first (Axiom 0)** — never invents tasks; user gates are surfaced verbatim and never auto-approved.
- **No API key** — runs on your existing Claude Code session (official CLI + subscription), no separate key or service.
- **Scoped tools** — `Read Write Task Bash(python *)`; the engine runs only its own bundled `python_tools`, with **no network / web tools** and no arbitrary shell. Invoked only on explicit `/soulagent:run` (`disable-model-invocation: true`).

## License

[Apache-2.0](./LICENSE) · © 2026 AIXP Labs · [soulagent.dev](https://soulagent.dev/)
