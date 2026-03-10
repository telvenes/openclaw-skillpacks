import os
import time
from functools import lru_cache
from typing import Any, Dict, List, Optional, Tuple

from mcp.server.fastmcp import FastMCP
from proxmoxer import ProxmoxAPI
from proxmoxer.core import ResourceException  # type: ignore

from .config import ensure_skill_env, get_effective_env

mcp = FastMCP("proxmox-mcp")


REQUIRED_ENV = [
    "PROXMOX_HOST",
    "PROXMOX_USER",
    "PROXMOX_TOKEN_NAME",
    "PROXMOX_TOKEN_VALUE",
]


def _env_bool(name: str, default: bool = False) -> bool:
    v = os.environ.get(name)
    if v is None:
        return default
    return v.strip().lower() in ("1", "true", "yes", "y", "on")


def _validate_env() -> None:
    missing = [k for k in REQUIRED_ENV if not os.environ.get(k)]
    if missing:
        effective = get_effective_env(REQUIRED_ENV + ["PROXMOX_VERIFY_SSL", "PROXMOX_ALLOW_WRITE"])
        # redact token value in error message
        if effective.get("PROXMOX_TOKEN_VALUE"):
            effective["PROXMOX_TOKEN_VALUE"] = "<redacted>"
        raise RuntimeError(
            "Missing required Proxmox config env: "
            + ", ".join(missing)
            + ". Effective (redacted): "
            + str(effective)
            + ". NOTE: env may come from OpenClaw config at /home/openclaw/.openclaw/openclaw.json "
            + "(skills.entries.proxmox-mcp.env)."
        )


@lru_cache(maxsize=1)
def _client() -> ProxmoxAPI:
    # Make sure env exists even if OpenClaw didn't inject it into this process
    ensure_skill_env("proxmox-mcp")

    # If PROXMOX_TOKEN_VALUE is still something like ${PROXMOX_TOKEN_SECRET}, expand once more
    # (in case server is launched outside OpenClaw injection context)
    tv = os.environ.get("PROXMOX_TOKEN_VALUE", "")
    if tv.startswith("${") and tv.endswith("}"):
        key = tv[2:-1]
        if os.environ.get(key):
            os.environ["PROXMOX_TOKEN_VALUE"] = os.environ[key]

    _validate_env()

    host = os.environ["PROXMOX_HOST"].strip()
    user = os.environ["PROXMOX_USER"].strip()
    token_name = os.environ["PROXMOX_TOKEN_NAME"].strip()
    token_value = os.environ["PROXMOX_TOKEN_VALUE"].strip()

    verify_ssl = _env_bool("PROXMOX_VERIFY_SSL", default=True)

    # proxmoxer expects host WITHOUT scheme; "10.10.10.24" or "10.10.10.24:8006"
    return ProxmoxAPI(
        host,
        user=user,
        token_name=token_name,
        token_value=token_value,
        verify_ssl=verify_ssl,
    )


def _allow_write() -> bool:
    return _env_bool("PROXMOX_ALLOW_WRITE", default=False)


def _require_write() -> None:
    if not _allow_write():
        raise RuntimeError(
            "Write operations are disabled. Set PROXMOX_ALLOW_WRITE=true in proxmox-mcp env to enable."
        )


def _find_vm(vmid: int) -> Tuple[str, str]:
    """
    Returns (node, kind) where kind is 'qemu' or 'lxc'
    """
    p = _client()
    resources = p.cluster.resources.get(type="vm")
    for r in resources:
        if int(r.get("vmid", -1)) == int(vmid):
            node = r.get("node")
            kind = r.get("type")  # "qemu" or "lxc"
            if not node or kind not in ("qemu", "lxc"):
                break
            return str(node), str(kind)
    raise RuntimeError(f"Unable to resolve vmid={vmid} to node/type via cluster resources.")


@mcp.tool()
def proxmox_version() -> Dict[str, Any]:
    """Return Proxmox API version info (connectivity test)."""
    p = _client()
    return p.version.get()


@mcp.tool()
def proxmox_nodes() -> List[Dict[str, Any]]:
    """List nodes in the Proxmox cluster."""
    p = _client()
    return p.nodes.get()


@mcp.tool()
def proxmox_node_status(node: str) -> Dict[str, Any]:
    """Get detailed status for a node."""
    p = _client()
    return p.nodes(node).status.get()


@mcp.tool()
def proxmox_cluster_status() -> List[Dict[str, Any]]:
    """Cluster status (membership/quorum/etc)."""
    p = _client()
    return p.cluster.status.get()


@mcp.tool()
def proxmox_vms(node: Optional[str] = None) -> List[Dict[str, Any]]:
    """List QEMU VMs. If node is provided, list only on that node."""
    p = _client()
    if node:
        return p.nodes(node).qemu.get()

    # Cluster-wide listing; filter for qemu only.
    resources = p.cluster.resources.get(type="vm")
    return [r for r in resources if r.get("type") == "qemu"]


@mcp.tool()
def proxmox_containers(node: Optional[str] = None) -> List[Dict[str, Any]]:
    """List LXC containers. If node is provided, list only on that node."""
    p = _client()
    if node:
        return p.nodes(node).lxc.get()

    resources = p.cluster.resources.get(type="vm")
    return [r for r in resources if r.get("type") == "lxc"]


@mcp.tool()
def proxmox_storage(node: Optional[str] = None) -> List[Dict[str, Any]]:
    """List storage definitions or per-node storage status if node is provided."""
    p = _client()
    if node:
        return p.nodes(node).storage.get()
    return p.storage.get()


# -------------------------
# Optional write operations
# -------------------------

@mcp.tool()
def proxmox_start(vmid: int, node: Optional[str] = None) -> Dict[str, Any]:
    """Start a VM/CT (requires PROXMOX_ALLOW_WRITE=true)."""
    _require_write()
    p = _client()
    if not node:
        node, kind = _find_vm(vmid)
    else:
        # If node explicitly provided, infer kind by trying qemu first then lxc.
        kind = "qemu"
        try:
            p.nodes(node).qemu(vmid).status.current.get()
        except Exception:
            kind = "lxc"

    if kind == "qemu":
        return p.nodes(node).qemu(vmid).status.start.post()
    return p.nodes(node).lxc(vmid).status.start.post()


@mcp.tool()
def proxmox_shutdown(vmid: int, node: Optional[str] = None) -> Dict[str, Any]:
    """Graceful shutdown VM/CT (requires PROXMOX_ALLOW_WRITE=true)."""
    _require_write()
    p = _client()
    if not node:
        node, kind = _find_vm(vmid)
    else:
        kind = "qemu"
        try:
            p.nodes(node).qemu(vmid).status.current.get()
        except Exception:
            kind = "lxc"

    if kind == "qemu":
        return p.nodes(node).qemu(vmid).status.shutdown.post()
    return p.nodes(node).lxc(vmid).status.shutdown.post()


@mcp.tool()
def proxmox_stop(vmid: int, node: Optional[str] = None) -> Dict[str, Any]:
    """Hard stop VM/CT (requires PROXMOX_ALLOW_WRITE=true)."""
    _require_write()
    p = _client()
    if not node:
        node, kind = _find_vm(vmid)
    else:
        kind = "qemu"
        try:
            p.nodes(node).qemu(vmid).status.current.get()
        except Exception:
            kind = "lxc"

    if kind == "qemu":
        return p.nodes(node).qemu(vmid).status.stop.post()
    return p.nodes(node).lxc(vmid).status.stop.post()


def _main() -> None:
    # Print a tiny startup banner to stderr (safe for prod)
    ensure_skill_env("proxmox-mcp")
    host = os.environ.get("PROXMOX_HOST", "")
    user = os.environ.get("PROXMOX_USER", "")
    allow_write = os.environ.get("PROXMOX_ALLOW_WRITE", "false")
    verify_ssl = os.environ.get("PROXMOX_VERIFY_SSL", "true")
    print(
        f"[proxmox-mcp] starting (host={host}, user={user}, verify_ssl={verify_ssl}, allow_write={allow_write})",
        file=os.sys.stderr,
    )
    mcp.run()


if __name__ == "__main__":
    _main()
