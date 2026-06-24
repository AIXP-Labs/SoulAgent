# 为 SoulAgent 贡献

[English](CONTRIBUTING.md) | 中文

感谢你有意为 SoulAgent 做贡献！

> ⚠️ **贡献状态（当前阶段）**
>
> 现阶段我们欢迎**通过 GitHub Issues 讨论**。
>
> **暂不接受外部 Pull Request。** 若你有提议 —— bug 报告、功能想法、新的 AIAP 包、或改进 —— 请开一个 issue 说明。如果我们认同其价值，由维护者实现并署名致谢。
>
> 此政策未来可能调整。

> **阶段状态（v1.0.0）**
>
> SoulAgent 处于早期开发阶段。下述流程描述的是*目标*开发模型。初期决策由 AIXP Labs 核心维护者做出；社区讨论期随贡献者规模增长而扩大。

## SoulAgent 是什么

SoulAgent 把 **SoulBot Execute Engine** 封装为 Claude Code 与 Codex 技能，并提供宿主中立的直接引擎入口（Path A：使用官方宿主 CLI + 订阅/账号能力，不经 soulacp/ACP）。它属于 `soulbot.dev` Executor 层 —— 见 [GOVERNANCE.md](GOVERNANCE.md)。因此贡献会落在四个区域之一：

1. **封装 / 技能层** —— `claude_code_plugin/`、`codex_plugin/`、`.agents/plugins/`、`.claude-plugin/`、`SKILL.md`、`plugin.json`、安装/分发
2. **引擎 / AIAP 层** —— 源引擎在 `soulagent/soulagent/`，打包副本在 `claude_code_plugin/skills/run/soulagent/` 与 `codex_plugin/skills/run/soulagent/`（深层协议改动经 `aiap.dev`）
3. **发布工具** —— `scripts/sync_plugin_engines.ps1`、`scripts/sync_codex_plugin.ps1`、`scripts/release_check.ps1`、gitignore/发布卫生
4. **文档** —— README、指南、架构、隐私、安全、本文件等

## 如何贡献

### 报告问题

- 用 [GitHub Issues](https://github.com/AIXP-Labs/SoulAgent/issues) 报告 bug、提议功能或新包
- 附上 Claude Code 或 Codex CLI 版本、Python 版本、操作系统、以及确切的调用方式
- 提供最小复现步骤
- AISOP / AIAP 相关问题，请链接到对应的 `.aisop.json` 文件
- **切勿粘贴私密内容** —— 从日志中清除真实路径、用户名、密钥、以及 `.execution_cache/` 内容（见 [.gitignore](.gitignore)）

### 讨论驱动开发

1. 通过 issue 提出讨论
2. 维护者评估价值、可行性与 Axiom 0 对齐
3. 达成共识后由维护者实现
4. 贡献者在 commit / release notes 中署名致谢

## 准则

### 质量标准

- `python_tools/` 遵循引擎既有风格；尽量用 Python 3.10+ 类型注解
- 凡读写含非 ASCII / emoji 的 JSON 的工具，至少用 `python -X utf8` 调用；release/smoke 检查统一用 `python -B -X utf8`（Windows surrogate 与 pycache 防护）
- 不用通配符导入；函数保持有文档
- 发布前先运行 `python -m pip install -r requirements-dev.txt`，再运行 `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\release_check.ps1`；GitHub Actions 会在 push、pull request 和手动触发时用批准的匿名发布元数据复跑同一套发布门。
- 若本机已安装 Claude 与 Codex CLI，正式发布前运行 `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\release_check.ps1 -RequireHostCli`，强制跑真实宿主 CLI 检查。

### AISOP / AIAP 贡献

对 AISOP 蓝图（`.aisop.json`）或 AIAP 包（`*_aiap/`）的改动应：

- 遵循 [AIAP 协议](https://github.com/AIXP-Labs/AIAP) 规范
- 保持 mermaid 图中执行路径的确定性
- 维护引擎的四条终端编排纪律（DISPATCH / PYTHON_TOOLS / SOVEREIGNTY / SCOPE）
- 保持治理元数据（`AIAP.md`、`quality_baseline.json`、TRI-SYNC `governance_hash`）一致
- 切勿把绝对路径（例如真实的 `$HOME`）写死进模板 —— 保持相对 / 占位符
- 保持打包引擎副本同步；`scripts/release_check.ps1` 会拒绝 Claude/Codex bundle 漂移以及运行期/私密产物。

### 双语说明

Issue 与讨论可用中文或英文。

## 行为准则

参与即表示你同意遵守[行为准则](CODE_OF_CONDUCT.md)。

## 贡献的许可

提交（通过 issue 或将来的 PR）即表示你的贡献以 [Apache License 2.0](LICENSE) 授权。

Copyright 2026 AIXP Labs AIXP.dev | SoulAgent.dev

---

Align Axiom 0: Human Sovereignty and Wellbeing. Version: SoulAgent V1.0.0. www.soulagent.dev
