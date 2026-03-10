from proxmoxer import ProxmoxAPI
from .config import proxmox_settings

def get_client() -> ProxmoxAPI:
    s = proxmox_settings()
    return ProxmoxAPI(
        s["host"],
        user=s["user"],
        token_name=s["token_name"],
        token_value=s["token_value"],
        verify_ssl=s["verify_ssl"],
    )
