import os

def env_bool(name: str, default: bool) -> bool:
    v = os.getenv(name)
    if v is None:
        return default
    return v.strip().lower() not in ("0", "false", "no", "off", "")

def get_config() -> dict:
    # NOTE: wrapper script populates env from openclaw.json
    return {
        "host": os.environ["PROXMOX_HOST"],
        "user": os.environ["PROXMOX_USER"],
        "token_name": os.environ["PROXMOX_TOKEN_NAME"],
        "token_value": os.environ["PROXMOX_TOKEN_VALUE"],
        "verify_ssl": env_bool("PROXMOX_VERIFY_SSL", False),
    }
