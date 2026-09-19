"""Convert the six classic mcl_core tree sets to portable sparse JSON.

Usage: python3 tools/convert_mineclonia_trees.py /path/to/mineclonia
No images or textures are copied. Source filenames and SHA-256 hashes remain
alongside the original voxel probabilities, rotation and layer probabilities.
See assets/trees/NOTICE.md for attribution and licensing.
"""
import hashlib
import json
from pathlib import Path
import re
import struct
import sys
import zlib

source = Path(sys.argv[1]) / "mods/ITEMS/mcl_core"
registration = (source / "nodes_trees.lua").read_text()
files = re.findall(r'/schematics/(.*?\.mts)', registration)
result = {}
for filename in files:
    original = (source / "schematics" / filename).read_bytes()
    assert original[:4] == b"MTSM"
    version, width, height, depth = struct.unpack(">4H", original[4:12])
    assert version == 4, (filename, version)
    layers = list(original[12:12 + height])
    offset = 12 + height
    count = struct.unpack_from(">H", original, offset)[0]
    offset += 2
    names = []
    for _ in range(count):
        length = struct.unpack_from(">H", original, offset)[0]
        offset += 2
        names.append(original[offset:offset + length].decode())
        offset += length
    raw = zlib.decompress(original[offset:])
    volume = width * height * depth
    assert len(raw) == volume * 4
    content = struct.unpack(f">{volume}H", raw[:volume * 2])
    nodes = []
    for i, name_index in enumerate(content):
        if names[name_index] == "air":
            continue
        nodes.append([i % width, (i // width) % height, i // (width * height),
                      name_index, raw[volume * 2 + i], raw[volume * 3 + i]])
    result[filename.removeprefix("mcl_core_").removesuffix(".mts")] = {
        "source": filename, "sha256": hashlib.sha256(original).hexdigest(),
        "size": [width, height, depth], "layers": layers,
        "names": names, "nodes": nodes,
    }
destination = Path(__file__).resolve().parents[1] / "assets/trees/mineclonia_trees.json"
destination.parent.mkdir(parents=True, exist_ok=True)
destination.write_text(json.dumps(result, separators=(",", ":")) + "\n")
print(f"Converted {len(result)} schematics to {destination} ({destination.stat().st_size} bytes)")
