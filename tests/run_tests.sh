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
godot --headless --path "$voxey_check_dir" --script res://tests/test_survival.gd
