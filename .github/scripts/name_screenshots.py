"""Renames screenshots exported by `xcresulttool export attachments` to their attachment names."""
import json
import os
import re
import sys

folder = sys.argv[1]
manifest_path = os.path.join(folder, "manifest.json")
if not os.path.exists(manifest_path):
    sys.exit(0)


def attachments(node):
    if isinstance(node, dict):
        if "exportedFileName" in node:
            yield node
        for value in node.values():
            yield from attachments(value)
    elif isinstance(node, list):
        for value in node:
            yield from attachments(value)


with open(manifest_path) as manifest:
    for item in attachments(json.load(manifest)):
        source = os.path.join(folder, item["exportedFileName"])
        human = item.get("suggestedHumanReadableName") or item["exportedFileName"]
        # "03 map_0_6F1C....png" -> "03 map.png"
        stem, extension = os.path.splitext(human)
        stem = re.sub(r"_\d+_[0-9A-Fa-f-]{8,}$", "", stem)
        target = os.path.join(folder, stem + extension)
        if os.path.exists(source) and not os.path.exists(target):
            os.rename(source, target)
