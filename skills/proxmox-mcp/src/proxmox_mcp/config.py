import os

def env_bool(name: str, default: bool = False) -> bool:
    v = os.getenv(name)
    if v is None:
        return default
    return v.strip().lower() not in ("0", "false", "no", "off", "")

def require(name: str) -> str:
    v = os.getenv(name)
    if not v:
        raise RuntimeError(f"Missing required env var: {name}")
    return v

def proxmox_settings() -> dict:
    return {
        "host": require("PROXMOX_HOST"),
        "user": require("PROXMOX_USER"),
        "token_name": require("PROXMOX_TOKEN_NAME"),
        "token_value": require("PROXMOX_TOKEN_VALUE"),
        "verify_ssl": env_bool("PROXMOX_VERIFY_SSL", default=False),
    }
