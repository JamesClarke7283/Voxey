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
files = [(source / "schematics", f, f.removeprefix("mcl_core_").removesuffix(".mts")) for f in re.findall(r'/schematics/(.*?\.mts)', registration)]
# The later species each have their own mod and their own tree schematics (the same
# MTS format). The key is what `WoodTypes.schematics` looks up.
LATER = {
    "mcl_cherry_blossom": [("mcl_cherry_blossom_tree_1.mts","cherry_1"),
        ("mcl_cherry_blossom_tree_2.mts","cherry_2"),("mcl_cherry_blossom_tree_3.mts","cherry_3")],
    "mcl_mangrove": [("mcl_mangrove_tree_1.mts","mangrove_1"),("mcl_mangrove_tree_2.mts","mangrove_2"),
        ("mcl_mangrove_tree_3.mts","mangrove_3"),("mcl_mangrove_tree_4.mts","mangrove_4"),
        ("mcl_mangrove_tree_5.mts","mangrove_5")],
    "mcl_pale_oak": [("mcl_pale_oak_1.mts","pale_oak_1"),("mcl_pale_oak_2.mts","pale_oak_2"),
        ("mcl_pale_oak_3.mts","pale_oak_3")],
    "mcl_crimson": [("crimson_fungus_1.mts","crimson_fungus_1"),("crimson_fungus_2.mts","crimson_fungus_2"),
        ("crimson_fungus_3.mts","crimson_fungus_3"),("warped_fungus_1.mts","warped_fungus_1"),
        ("warped_fungus_2.mts","warped_fungus_2"),("warped_fungus_3.mts","warped_fungus_3")],
}
for mod, entries in LATER.items():
    directory = Path(sys.argv[1]) / "mods/ITEMS" / mod / "schematics"
    for name, key in entries: files.append((directory, name, key))
result = {}
for directory, filename, key in files:
    original = (directory / filename).read_bytes()
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
    result[key] = {
        "source": filename, "sha256": hashlib.sha256(original).hexdigest(),
        "size": [width, height, depth], "layers": layers,
        "names": names, "nodes": nodes,
    }
destination = Path(__file__).resolve().parents[1] / "assets/trees/mineclonia_trees.json"
destination.parent.mkdir(parents=True, exist_ok=True)
destination.write_text(json.dumps(result, separators=(",", ":")) + "\n")
print(f"Converted {len(result)} schematics to {destination} ({destination.stat().st_size} bytes)")
