#!/usr/bin/env python3
"""Regenerate the corner-shape oracle from the user's Mineclonia checkout."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

repository = Path(__file__).resolve().parents[1]
reference = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.home() / ".minetest/games/mineclonia"
relative = "mods/ITEMS/mcl_stairs/cornerstair.lua"
source = reference / relative
masks = json.loads(subprocess.check_output(["lua", str(repository / "tools/export_stair_cases.lua"), str(source)], text=True))
assert len(masks) == 5000 and all(isinstance(mask, int) and 0 <= mask <= 255 for mask in masks)
result = {
    "source": relative,
    "sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
    "order": "upright then inverted; facing 0..3; 625 neighbor combinations, base-5 digits in +Z,+X,-Z,-X order; 0=air,1..4=facing 0..3",
    "masks": masks,
}
(repository / "tests/stair-reference.json").write_text(json.dumps(result, separators=(",", ":")) + "\n")
print(f"Exported {len(masks):,} source stair configurations.")
