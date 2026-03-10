from mcp.server.fastmcp import FastMCP
from .client import get_client

mcp = FastMCP("proxmox-mcp")

@mcp.tool()
def list_nodes() -> list[dict]:
    """List Proxmox cluster nodes."""
    p = get_client()
    return p.nodes.get()

@mcp.tool()
def list_vms(node: str | None = None) -> list[dict]:
    """List VMs (qemu) across cluster, optionally filtered by node."""
    p = get_client()
    out: list[dict] = []

    nodes = [node] if node else [n.get("node") for n in p.nodes.get()]
    for n in nodes:
        if not n:
            continue
        for vm in p.nodes(n).qemu.get():
            vm["node"] = n
            out.append(vm)
    return out

@mcp.tool()
def get_vm_status(node: str, vmid: int) -> dict:
    """Get runtime status for a VM (qemu) on a given node."""
    p = get_client()
    return p.nodes(node).qemu(vmid).status.current.get()

def main() -> None:
    mcp.run()

if __name__ == "__main__":
    main()
