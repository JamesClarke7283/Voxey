#!/usr/bin/env bash
set -euo pipefail
voxey_source_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
voxey_check_dir="$(mktemp -d "${TMPDIR:-/tmp}/voxey-check.XXXXXX")"
trap 'rm -rf -- "$voxey_check_dir"' EXIT
# A separate minimal project prevents the editor's MCP addon from interfering
# with a currently running playtest. The game scripts are the actual sources.
for voxey_folder in scripts scenes shaders assets tests; do
  ln -s "$voxey_source_dir/$voxey_folder" "$voxey_check_dir/$voxey_folder"
done
cat > "$voxey_check_dir/project.godot" <<'PROJECT'
config_version=5
[application]
config/name="Voxey Tests"
run/main_scene="res://scenes/main.tscn"
[display]
window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"
[rendering]
renderer/rendering_method="gl_compatibility"
PROJECT
godot --headless --path "$voxey_check_dir" --editor --import --quit > "$voxey_check_dir/import.log" 2>&1
# Godot can return zero after a script error, so check diagnostics as well.
if rg -q 'SCRIPT ERROR:|^ERROR:' "$voxey_check_dir/import.log"; then
  cat "$voxey_check_dir/import.log"
  exit 1
fi
for voxey_suite in test_survival village_runner alchemy_runner parity_runner polish_runner building_runner; do
  godot --headless --path "$voxey_check_dir" --script "res://tests/$voxey_suite.gd" 2>&1 | tee "$voxey_check_dir/$voxey_suite.log"
  if rg -q 'SCRIPT ERROR:|^ERROR:' "$voxey_check_dir/$voxey_suite.log"; then
    exit 1
  fi
done
