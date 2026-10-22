#!/usr/bin/env bash
set -euo pipefail
voxey_source_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
voxey_check_dir="$(mktemp -d "${TMPDIR:-/tmp}/voxey-network-check.XXXXXX")"
voxey_server_pid=""
trap 'if [[ -n "$voxey_server_pid" ]]; then kill "$voxey_server_pid" 2>/dev/null || true; fi; rm -rf -- "$voxey_check_dir"' EXIT
for voxey_folder in scripts scenes shaders assets tests; do
  ln -s "$voxey_source_dir/$voxey_folder" "$voxey_check_dir/$voxey_folder"
done
cat > "$voxey_check_dir/project.godot" <<'PROJECT'
config_version=5
[application]
config/name="Voxey Network Tests"
run/main_scene="res://scenes/main.tscn"
[rendering]
renderer/rendering_method="gl_compatibility"
PROJECT
godot --headless --path "$voxey_check_dir" --editor --import --quit > "$voxey_check_dir/import.log" 2>&1
if rg -q 'SCRIPT ERROR:|^ERROR:' "$voxey_check_dir/import.log"; then cat "$voxey_check_dir/import.log"; exit 1; fi
voxey_port=$((25000 + $$ % 15000))
godot --headless --path "$voxey_check_dir" --script res://tests/network_runner.gd -- "--port=$voxey_port" > "$voxey_check_dir/host.log" 2>&1 &
voxey_server_pid=$!
for _ in {1..150}; do
  if rg -q 'NETWORK HOST READY' "$voxey_check_dir/host.log"; then break; fi
  if ! kill -0 "$voxey_server_pid" 2>/dev/null; then cat "$voxey_check_dir/host.log"; exit 1; fi
  sleep 1
done
if ! rg -q 'NETWORK HOST READY' "$voxey_check_dir/host.log"; then cat "$voxey_check_dir/host.log"; exit 1; fi
godot --headless --path "$voxey_check_dir" --script res://tests/network_runner.gd -- --client "--port=$voxey_port" > "$voxey_check_dir/client.log" 2>&1 || { cat "$voxey_check_dir/client.log"; exit 1; }
wait "$voxey_server_pid" || { cat "$voxey_check_dir/host.log"; exit 1; }
voxey_server_pid=""
cat "$voxey_check_dir/host.log" "$voxey_check_dir/client.log"
if rg -q 'SCRIPT ERROR:|^ERROR:' "$voxey_check_dir/host.log" "$voxey_check_dir/client.log"; then exit 1; fi
