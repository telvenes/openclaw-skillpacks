import json
import os
import re
from pathlib import Path
from typing import Any, Dict, Optional


_OPENCLAW_DEFAULT_CONFIG_PATHS = (
    os.environ.get("OPENCLAW_CONFIG_PATH"),
    "/home/openclaw/.openclaw/openclaw.json",
)


_TEMPLATE_RE = re.compile(r"\$\{([A-Z0-9_]+)\}")


def _read_json(path: str) -> Optional[Dict[str, Any]]:
    try:
        p = Path(path)
        if not p.exists():
            return None
        return json.loads(p.read_text(encoding="utf-8"))
    except Exception:
        # Fail silently here; caller will decide if it's fatal.
        return None


def _resolve_templates(value: str, env: Dict[str, str]) -> str:
    """
    Resolve ${VAR} using env. If VAR is missing, keep template as-is.
    (We validate required fields separately.)
    """
    def repl(match: re.Match) -> str:
        key = match.group(1)
        return env.get(key, match.group(0))

    return _TEMPLATE_RE.sub(repl, value)


def load_openclaw_skill_env(skill_key: str) -> Dict[str, str]:
    """
    Reads /home/openclaw/.openclaw/openclaw.json and returns skills.entries[skill_key].env
    with ${VAR} expanded using current process env.

    Returns {} if config isn't available.
    """
    cfg = None
    for p in _OPENCLAW_DEFAULT_CONFIG_PATHS:
        if not p:
            continue
        cfg = _read_json(p)
        if cfg:
            break

    if not cfg:
        return {}

    entries = (
        cfg.get("skills", {})
           .get("entries", {})
    )
    skill = entries.get(skill_key, {})
    raw_env = skill.get("env", {}) or {}

    out: Dict[str, str] = {}
    for k, v in raw_env.items():
        if v is None:
            continue
        s = str(v)
        s = _resolve_templates(s, dict(os.environ))
        out[k] = s
    return out


def ensure_skill_env(skill_key: str) -> Dict[str, str]:
    """
    Ensures process env has values for this skill.
    Priority:
      1) Existing process env wins
      2) Otherwise fill from openclaw.json (skills.entries.<skill_key>.env), with ${VAR} expansion
    """
    injected = load_openclaw_skill_env(skill_key)
    for k, v in injected.items():
        os.environ.setdefault(k, v)
    return injected


def get_effective_env(keys: list[str]) -> Dict[str, str]:
    return {k: os.environ.get(k, "") for k in keys}
