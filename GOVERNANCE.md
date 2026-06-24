# SoulAgent Governance

SoulAgent is a **distribution artifact of the SoulBot ecosystem** — it packages the SoulBot Execute Engine as local Claude Code and Codex skills, plus a host-neutral direct engine entry. It is governed by the same decentralized, federated trust model that governs the AIXP protocol family, designed to isolate the structure of intelligence from the rules of its application.

## The Tripartite Chain

The ecosystem operates on a strict separation of concerns across three authoritative domains. **All layers are licensed under Apache 2.0** for unified patent protection and ecosystem consistency. **SoulAgent belongs to the `soulbot.dev` Executor Layer** (it ships the reference runtime as a skill). The `aisop.dev` Seed Layer and `aiap.dev` Authority Layer are maintained in separate repositories under the same Apache 2.0 license.

### 1. The Seed Layer (`aisop.dev`)

The origin of the format.

- **Responsibility**: Defines the underlying `.aisop.json` language specification, Mermaid graph parsing rules, and the System/User execution model.
- **Philosophy**: Neutral, static, foundational.
- **License**: Apache 2.0.

### 2. The Authority Layer (`aiap.dev`)

The source of governance and the steward of Axiom 0.

- **Responsibility**: Maintains the AIAP and HSAW specifications, the quality gates, and enforces the Zero-Entropy and L0 isolation rules.
- **Philosophy**: Rigorous, uncompromising.
- **License**: Apache 2.0.

### 3. The Executor Layer (`soulbot.dev`) — SoulAgent lives here

The reference runtime environment, and its distributions.

- **Responsibility**: Instantiates the AI Agent, resolves tools, manages memory layers, and enforces the `permissions` declared in the AISOP / AIAP package contract. **SoulAgent** delivers this runtime through Claude Code, Codex, and host-neutral adapters, where the active host session itself is the orchestrator (Path A).
- **Philosophy**: Secure, performant, sandboxed.
- **License**: Apache 2.0.

## Axiom 0 Immutability

**Axiom 0: "Human Sovereignty and Wellbeing" is immutable.**

No release of any AIXP protocol (AISOP, AIAP, HSAW), the SoulBot reference runtime, or any distribution such as SoulAgent may ever modify, weaken, or deprecate the core alignment to Human Sovereignty and Wellbeing. This constraint is absolute and non-negotiable.

In SoulAgent specifically, this means the engine's **sovereignty (user-gate) enforcement** — halting at `WAITING_USER` and never self-approving — must never be bypassed by the orchestrator, even when a task prompt sounds pre-authorising. Any change that compromises, dilutes, or bypasses Axiom 0 will be rejected regardless of performance benefits, commercial pressure, or technical convenience.

## Versioning

SoulAgent follows Semantic Versioning (SemVer):

- **Major**: Breaking changes to the skill contract, invocation, or packaging layout
- **Minor**: Backward-compatible additions (new AIAP packages, capabilities)
- **Patch**: Bug fixes, documentation corrections, non-normative clarifications

The bundled engine carries its own version, independent of the SoulAgent package version (`1.0.0`) tracked by the Claude plugin manifest and `_meta.json`, the Codex plugin manifest and marketplace index, and the host-neutral skill footer. The Axiom 0 immutability constraint supersedes all versioning rules.

## Protocol Steering

| Domain | Role | Scope |
|--------|------|-------|
| `aisop.dev` | Format Steward | `.aisop.json` specification, field definitions |
| `aiap.dev` | Governance Steward | Protocol rules, quality standards, security model |
| `soulbot.dev` | Runtime Steward | Reference implementation; **SoulAgent** = Claude/Codex skill distribution plus host-neutral direct engine entry |

### Decision Process

1. **Proposals**: Submit change requests via [GitHub Issues](https://github.com/AIXP-Labs/SoulAgent/issues). Use the `spec-change` label for anything touching AISOP/AIAP semantics (these are escalated upstream to `aiap.dev`).
2. **Discussion**: Open discussion period (minimum 14 days for normative changes).
3. **Review**: Maintainers review for Axiom 0 compliance, technical soundness, and backward compatibility.
4. **Consensus**: Changes require consensus among relevant domain stewards.
5. **Documentation**: All normative changes must include updated text and, where applicable, an Architecture Decision Record (ADR).

## Communication

- **GitHub Issues**: Primary channel for discussions and proposals
- **GitHub Discussions**: Community questions and broader conversations

---

Align Axiom 0: Human Sovereignty and Wellbeing. Version: SoulAgent V1.0.0. www.soulagent.dev
