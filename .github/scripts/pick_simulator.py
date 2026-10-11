"""Prints the UDID of an available iPhone simulator on the newest iOS runtime."""
import json
import subprocess
import sys

listing = subprocess.run(
    ["xcrun", "simctl", "list", "devices", "available", "--json"],
    check=True, capture_output=True, text=True,
).stdout
devices = json.loads(listing)["devices"]
runtimes = sorted(
    (runtime for runtime in devices if "iOS" in runtime),
    key=lambda runtime: [int(part) for part in runtime.split("iOS-")[-1].split("-")],
    reverse=True,
)
for runtime in runtimes:
    for device in devices[runtime]:
        if device["name"].startswith("iPhone") and device["isAvailable"]:
            print(device["udid"])
            sys.exit(0)
sys.exit("No available iPhone simulator")
