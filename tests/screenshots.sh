#!/usr/bin/env bash
# Windowed visual smoke test. Needs a display; writes PNGs to /tmp/voxey-shots.
set -euo pipefail
voxey_source_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
voxey_check_dir="$(mktemp -d "${TMPDIR:-/tmp}/voxey-shots.XXXXXX")"
trap 'rm -rf -- "$voxey_check_dir"' EXIT
for voxey_folder in scripts scenes shaders tests; do
  ln -s "$voxey_source_dir/$voxey_folder" "$voxey_check_dir/$voxey_folder"
done
cat > "$voxey_check_dir/project.godot" <<'PROJECT'
config_version=5
[application]
config/name="Voxey Screenshots"
run/main_scene="res://scenes/main.tscn"
[display]
window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"
[rendering]
renderer/rendering_method="gl_compatibility"
PROJECT
godot --headless --path "$voxey_check_dir" --editor --import --quit > "$voxey_check_dir/import.log" 2>&1
godot --path "$voxey_check_dir" --resolution 1280x720 --script res://tests/screenshot_tour.gd

godot --path "$voxey_check_dir" --resolution 1280x920 --script res://tests/asset_gallery.gd
