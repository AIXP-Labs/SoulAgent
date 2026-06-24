# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability, please report it privately through GitHub Security Advisory:

**[Report a vulnerability](https://github.com/AIXP-Labs/SoulAgent/security/advisories/new)**

Please do not disclose the issue publicly until a fix is available.

## Scope

SoulAgent packages the SoulBot Execute Engine as local Claude Code and Codex skills, plus a host-neutral direct engine entry. It runs with the **tool authority of the active host session** (file system, shell, and sub-agent dispatch when the host provides it). Treat any prompt you pass to `/soulagent:run`, `$soulagent-run`, or `start.aisop.json` as you would a shell command. This software is **experimental** and provided **as-is** for research and educational purposes. There is no guaranteed response time, no SLA, and no bug bounty. The maintainers will review reports on a best-effort basis.

For full terms, see [LICENSE](LICENSE) (Apache 2.0).

---

# 安全政策

## 报告漏洞

如发现安全漏洞，请通过 GitHub Security Advisory 私下报告：

**[报告漏洞](https://github.com/AIXP-Labs/SoulAgent/security/advisories/new)**

在修复发布之前请勿公开披露问题。

## 范围

SoulAgent 将 SoulBot Execute Engine 封装为本地 Claude Code 与 Codex 技能，并提供宿主中立的直接引擎入口。运行时它**拥有当前宿主会话授予的工具权限**（文件系统、shell，以及宿主可用时的 sub-agent 派发）。对待传给 `/soulagent:run`、`$soulagent-run` 或 `start.aisop.json` 的任务，应如同对待 shell 命令一样谨慎。本软件为**实验性**软件，按"现状"提供，仅供研究和教育用途。无响应时限承诺、无 SLA、无 Bug Bounty。维护者将尽力审阅报告。

完整条款见 [LICENSE](LICENSE)（Apache 2.0）。

---

Align Axiom 0: Human Sovereignty and Wellbeing. Version: SoulAgent V1.0.0. www.soulagent.dev
