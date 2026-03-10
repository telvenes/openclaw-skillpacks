from typing import Any, Dict, List, Optional, Literal
from mcp.server.fastmcp import FastMCP
from .client import get_client

mcp = FastMCP("proxmox-mcp")

@mcp.tool()
def list_nodes() -> List[Dict[str, Any]]:
    """List Proxmox cluster nodes."""
    p = get_client()
    return p.nodes.get()

@mcp.tool()
def list_vms(type: Literal["vm","container","all"] = "all") -> List[Dict[str, Any]]:
    """
    List cluster resources (VMs/CTs) via /cluster/resources.

    type:
      - vm -> QEMU VMs
      - container -> LXC
      - all -> both
    """
    p = get_client()

    if type == "vm":
        return p.cluster.resources.get(type="vm")
    if type == "container":
        return p.cluster.resources.get(type="lxc")

    # all
    out: List[Dict[str, Any]] = []
    out.extend(p.cluster.resources.get(type="vm"))
    out.extend(p.cluster.resources.get(type="lxc"))
    return out

@mcp.tool()
def get_vm_status(node: str, vmid: int, type: Literal["vm","container"] = "vm") -> Dict[str, Any]:
    """
    Get current status for a VM/CT.
    """
    p = get_client()
    if type == "container":
        return p.nodes(node).lxc(vmid).status.current.get()
    return p.nodes(node).qemu(vmid).status.current.get()

if __name__ == "__main__":
    mcp.run()
