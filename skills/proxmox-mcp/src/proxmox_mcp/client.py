from proxmoxer import ProxmoxAPI
from .config import get_config

def get_client() -> ProxmoxAPI:
    cfg = get_config()
    return ProxmoxAPI(
        cfg["host"],
        user=cfg["user"],
        token_name=cfg["token_name"],
        token_value=cfg["token_value"],
        verify_ssl=cfg["verify_ssl"],
    )
