#!/usr/bin/env python3
"""Use WatchYourLAN API to get devices on your network."""

import json
import sys
import urllib.request

# WatchYourLAN API.
WYL_URL = "http://127.0.0.1:8840/api/all"

# ANSI green dot.
GREEN_DOT = "\033[32m●\033[0m"

# Get name and IP of all devices.
try:
    req = urllib.request.Request(WYL_URL, headers={"User-Agent": "wtfutil-dashboard"})
    with urllib.request.urlopen(req, timeout=3) as response:
        devices = json.loads(response.read().decode())
except Exception as e:
    print("WatchYourLAN Offline")
    print(f"Error: {e}")
    sys.exit(0)

# Filter online devices.
online_devices = [d for d in devices if d.get("Now") in (1, True, "1")]

online_count = len(online_devices)
total_count = len(devices)


def get_clean_name(dev: dict) -> str:
    """Remove the emoji from the names on devices.

    Args:
        dev (dict): Dictionary containing the device, including it's name.

    Returns:
        str: Name of the device without the emojis at the beginning.
    """
    REMOVE = 2
    raw = dev.get("Name") or dev.get("Hw") or "Unknown"
    return raw[REMOVE:].lstrip() if len(raw) > REMOVE else raw


# Sort devices.
sorted_online = sorted(online_devices, key=lambda d: get_clean_name(d).lower())

# Print Summary Header
print(f"{'LAN Devices:':<16} {online_count} / {total_count} online\n")

# Print Online Device Rows with expanded 26-character column width
LENGTH = 26
for dev in sorted_online:
    clean_name = get_clean_name(dev)
    ip = dev.get("IP") or ""

    # Allow up to 26 characters for the device name before truncating
    display_name = (clean_name[:LENGTH] + "..") if len(clean_name) > LENGTH else clean_name
    print(f" {GREEN_DOT}  {display_name:<26} {ip}")
