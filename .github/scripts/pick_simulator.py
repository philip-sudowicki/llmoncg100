"""Reads `xcrun simctl list devices available -j` on stdin and prints the UDID of an iPhone
on the newest iOS runtime, preferring a standard (non-Pro, non-SE) model."""
import json
import re
import sys

devices = json.load(sys.stdin)["devices"]


def version(runtime):
    match = re.search(r"iOS-(\d+)-(\d+)", runtime)
    return tuple(int(part) for part in match.groups()) if match else (0, 0)


def rank(name):
    if re.fullmatch(r"iPhone \d+", name):
        return 0
    if re.fullmatch(r"iPhone \d+ Pro", name):
        return 1
    return 2 if "SE" not in name else 3


for runtime in sorted((r for r in devices if "iOS" in r), key=version, reverse=True):
    phones = [d for d in devices[runtime] if d.get("isAvailable") and d["name"].startswith("iPhone")]
    if phones:
        best = min(phones, key=lambda d: rank(d["name"]))
        print(best["udid"])
        print(f"Using {best['name']} on {runtime}", file=sys.stderr)
        sys.exit(0)
sys.exit("No available iPhone simulator found")
