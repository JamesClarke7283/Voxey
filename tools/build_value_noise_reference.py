#!/usr/bin/env python3
"""Compile the actual Luanti noise functions to make independent test vectors.

Usage: python3 tools/build_value_noise_reference.py /path/to/luanti/src/noise.cpp
The reference source is read, never modified or copied into the game.
"""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile

source = Path(sys.argv[1])
code = source.read_text()

def function(name):
    start = code.index("float " + name + "(")
    opening = code.index("{", start)
    depth = 1
    end = opening + 1
    while depth:
        depth += (code[end] == "{") - (code[end] == "}")
        end += 1
    return code[start:end]

defines = "\n".join(line for line in code.splitlines() if line.startswith("#define NOISE_MAGIC_") or line.startswith("#define myfloor"))
header = """
#include <cmath>
#include <cstdint>
#include <iostream>
#include <iomanip>
using s32 = int32_t;
const unsigned NOISE_FLAG_EASED = 2, NOISE_FLAG_ABSVALUE = 4;
float easeCurve(float t) { return t*t*t*(t*(6*t-15)+10); }
struct Vector { float X=250, Y=250, Z=250; };
struct NoiseParams { Vector spread; int seed=12345; unsigned octaves=3, flags=1; float persist=.6, lacunarity=2, offset=0, scale=1; };
"""
functions = "\n".join(function(name) for name in ["noise3d", "linearInterpolation", "biLinearInterpolation", "triLinearInterpolation", "noise3d_value", "NoiseFractal3D"])
main = """
int main() {
 NoiseParams params;
 std::cout << std::setprecision(10);
 const int points[][3]={{0,0,0},{8,-80,8},{16,-46,-16},{-31,-128,47},{30920,-62,-30900},{250,500,-750},{-250,-500,750}};
 for(int seed : {0,1,8675309,2147483500}) for(auto &p : points) {
  std::cout << seed << ' ' << p[0] << ' ' << p[1] << ' ' << p[2] << ' ' << noise3d(p[0],p[1],p[2],seed) << ' ' << NoiseFractal3D(&params,p[0],p[1],p[2],seed) << '\\n';
 }
}
"""
with tempfile.TemporaryDirectory(prefix="voxey-noise-reference-") as directory:
    path = Path(directory)
    (path / "reference.cpp").write_text(header + defines + "\n" + functions + main)
    subprocess.run(["c++", "-std=c++17", "-fwrapv", "-o", str(path / "reference"), str(path / "reference.cpp")], check=True)
    lines = subprocess.check_output([str(path / "reference")], text=True).splitlines()
samples = [[int(v) if i < 4 else float(v) for i,v in enumerate(line.split())] for line in lines]
result = {"source":"https://github.com/luanti-org/luanti/blob/master/src/noise.cpp", "sha256":hashlib.sha256(source.read_bytes()).hexdigest(), "samples":samples}
destination = Path(__file__).resolve().parents[1] / "tests/value-noise-reference.json"
destination.write_text(json.dumps(result, indent=2) + "\n")
print(f"Exported {len(samples)} native Luanti noise samples.")
