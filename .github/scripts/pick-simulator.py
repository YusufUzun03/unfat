#!/usr/bin/env python3
"""Pick an available iPhone simulator and print SIM_UDID / SIM_NAME lines for $GITHUB_ENV.

Preference: "iPhone 17 Pro Max" on the newest iOS runtime; otherwise any iPhone on the newest
runtime. Only runtimes >= the deployment target (iOS 26.0) are considered.
"""
import json
import re
import subprocess
import sys

PREFERRED = "iPhone 17 Pro Max"
MIN_RUNTIME = (26, 0, 0)

out = subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "-j"])
devices = json.loads(out)["devices"]

candidates = []
for runtime, entries in devices.items():
    match = re.search(r"SimRuntime\.iOS-(\d+)-(\d+)(?:-(\d+))?$", runtime)
    if not match:
        continue
    version = tuple(int(part or 0) for part in match.groups())
    if version < MIN_RUNTIME:
        continue
    for device in entries:
        if device.get("isAvailable", True) and device["name"].startswith("iPhone"):
            candidates.append((device["name"] == PREFERRED, version, device["name"], device["udid"]))

if not candidates:
    sys.exit("No available iPhone simulator with iOS >= 26.0")

_, version, name, udid = max(candidates)
print(f"Picked {name} (iOS {'.'.join(map(str, version))}) {udid}", file=sys.stderr)
print(f"SIM_UDID={udid}")
print(f"SIM_NAME={name}")
