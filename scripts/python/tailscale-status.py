#!/usr/bin/env python3
"""Return Tailscale IP, services and currently onlien devices with a clean green/grey dot."""

import json
import subprocess


def get_cmd_output(cmd: list) -> str:
    """Run commandline arguments in Python.

    Args:
        cmd (list): Command to run as separate items in list.

    Returns:
        str: Output of the command run or "N/A".
    """
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, check=True)
        return res.stdout.strip()
    except Exception:
        return ""


# Tailscale IP.
ts_ip = get_cmd_output(["tailscale", "ip", "-4"]) or "N/A"

# Run tailscale status.
status_raw = get_cmd_output(["tailscale", "status", "--json"])

total_devices = 0
online_devices = 0
exit_node_status = "Disabled"
device_list = []
if status_raw:
    # Pull the JSON out of the response JSON.
    try:
        data = json.loads(status_raw)

        # Get exit node status.
        if data.get("ExitNodeStatus"):
            exit_node_status = "Active"

        # Extract details for the server.
        self_node = data.get("Self", {})
        if self_node:
            # Get DNS name of the server.
            self_name = self_node.get("DNSName", "").split(".")[0] or self_node.get("HostName") or "this-server"
            device_list.append((self_name, True))

        # Extract details of the other devices on the network.
        peers = data.get("Peer", {})
        for p in peers.values():
            # Get DNS name.
            p_name = p.get("DNSName", "").split(".")[0] or p.get("HostName") or "Unknown"
            # Get online/offline status.
            p_online = p.get("Online", False)
            device_list.append((p_name, p_online))

        # Sort the list.
        device_list.sort(key=lambda x: x[0].lower())

        total_devices = len(device_list)
        online_devices = sum(1 for _, online in device_list if online)

    except Exception:
        pass

# Find how many services are on tailscale.
serve_raw = get_cmd_output(["tailscale", "serve", "status"])
if not serve_raw or "No serve config" in serve_raw:
    serve_count = "0"
else:
    serve_count = str(
        sum(1 for line in serve_raw.splitlines() if any(proto in line for proto in ["http://", "https://", "tcp://"]))
    )

# ANSI Colors.
GREEN_DOT = "\033[32m●\033[0m"
GREY_DOT = "\033[90m●\033[0m"

# Output all details.
print(f"{'Tailscale IP:':<18} {ts_ip}")
print(f"{'Served Services:':<18} {serve_count}")
print(f"{'Exit Node:':<18} {exit_node_status}")
print(f"{'Devices Online:':<18} {online_devices} / {total_devices}")
print("")

# Output all devices.
SPACING = 18
for name, online in device_list:
    dot = GREEN_DOT if online else GREY_DOT
    display_name = (name[:16] + "..") if len(name) > SPACING else name
    print(f" {dot}  {display_name}")
