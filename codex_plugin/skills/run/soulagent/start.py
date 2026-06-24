#!/usr/bin/env python3
"""start.py — terminal bootstrap for running the SoulBot Execute Engine with
the current host session as the orchestrator (host-neutral / Claude Code /
Codex plugin paths, NO soulacp/ACP layer).

It mirrors the NON-INTERACTIVE parts of agent.py's _router_instruction:
  - prepare_execution_context()  -> create cache dir + conversation_context turn
                                     (cleanup runs inside; reuses an in_progress
                                      turn automatically for resume / gate reply)
  - the AIAP registry             -> the "[Available AIAP packages]" list the
                                     Router matches a user message against

Usage:
    python -B -X utf8 start.py "<non-empty user_message>"

If a shell accidentally splits the message into multiple argv tokens, start.py
joins sys.argv[1:] with spaces as a defensive fallback. Hosts should still pass
the task as one argv value for exact round-trip fidelity.

Prints exactly ONE JSON object to stdout (the bootstrap block) that
start.aisop.json instructs the current host session to consume:
    {
      "status": "ok",
      "execution_context": {turn_id, cache_dir, cache_name, trace_id},
      "engine_dir":   "...\\soulbot_execute_engine_aiap",
      "router_entry": "...\\soulbot_execute_engine_aiap\\main.aisop.json",
      "aiap_dir":     "...\\soulagent\\aiap",
      "registry":     [ {name, summary, entry, loading_mode, workspace_dir}, ... ],
      "user_message": "<user_message>"
    }

Why a separate bootstrap instead of letting the session call prepare_cache.py
directly: the session would otherwise have to know the cache-dir naming, the
trace_id wiring, and the registry path. start.py centralises that exactly as
agent.py does for the normal (soulacp) path, so the AISOP layer stays portable.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

_AGENT_DIR = Path(__file__).resolve().parent
_ENGINE_DIR = _AGENT_DIR / "soulbot_execute_engine_aiap"
_AIAP_DIR = (_AGENT_DIR / "aiap").resolve()
_AIAP_JSON = _AGENT_DIR / "aiap.json"

# prepare_cache is the SAME dual-use module agent.py imports (library + CLI).
sys.path.insert(0, str(_ENGINE_DIR / "python_tools"))
from prepare_cache import prepare_execution_context  # noqa: E402


def _load_registry() -> list:
    """Prefer the persisted aiap.json registry (written by agent.py's
    _get_aiap_registry); fall back to a minimal scan of aiap/ for *_aiap
    packages so start.py still works if aiap.json is absent/stale."""
    if _AIAP_JSON.is_file():
        try:
            with open(_AIAP_JSON, encoding="utf-8-sig") as f:
                data = json.load(f)
            if isinstance(data, list):
                return data
        except (OSError, json.JSONDecodeError):
            pass

    packages: list = []
    if _AIAP_DIR.is_dir():
        for d in sorted(_AIAP_DIR.iterdir()):
            entry = d / "main.aisop.json"
            if not (d.is_dir() and d.name.endswith("_aiap") and entry.is_file()):
                continue
            loading_mode = "normal"
            try:
                with open(entry, encoding="utf-8-sig") as f:
                    loading_mode = json.load(f)[0]["content"].get("loading_mode", "normal")
            except Exception:
                pass
            packages.append({
                "name": d.name.replace("_aiap", ""),
                "summary": "",
                "entry": str(entry),
                "loading_mode": loading_mode if loading_mode in ("normal", "node", "lite") else "normal",
                "workspace_dir": str(_AIAP_DIR),
            })
    return packages


def main() -> int:
    user_message = " ".join(sys.argv[1:]).strip()
    if not user_message:
        print(json.dumps({
            "status": "error",
            "error": "missing_user_message",
            "message": "Pass one non-empty user_message argument.",
        }, ensure_ascii=False))
        return 2

    # 1. Create cache dir + conversation_context turn (cleanup runs inside).
    #    If the latest turn is still in_progress (e.g. resuming a WAITING_USER
    #    gate), prepare_execution_context REUSES it instead of making a phantom.
    ctx = prepare_execution_context(user_message, engine_aiap_dir=_ENGINE_DIR)
    if ctx is None:
        print(json.dumps({
            "status": "error",
            "error": "prepare_execution_context failed (see logs)",
        }, ensure_ascii=False))
        return 1

    # 2. Load the AIAP registry the Router's match step selects from.
    registry = _load_registry()

    # 3. Emit the single bootstrap block.
    print(json.dumps({
        "status": "ok",
        "execution_context": ctx,                       # turn_id, cache_dir, cache_name, trace_id
        "engine_dir": str(_ENGINE_DIR),
        "router_entry": str(_ENGINE_DIR / "main.aisop.json"),
        "aiap_dir": str(_AIAP_DIR),
        "registry": registry,
        "user_message": user_message,
    }, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
