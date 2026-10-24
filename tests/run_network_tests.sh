#!/usr/bin/env bash
set -euo pipefail
voxey_source_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
voxey_check_dir="$(mktemp -d "${TMPDIR:-/tmp}/voxey-network-check.XXXXXX")"
voxey_server_pid=""
voxey_guest_pid=""
voxey_observer_pid=""
voxey_proxy_pid=""
trap 'for voxey_pid in "$voxey_server_pid" "$voxey_guest_pid" "$voxey_observer_pid" "$voxey_proxy_pid"; do if [[ -n "$voxey_pid" ]]; then kill "$voxey_pid" 2>/dev/null || true; fi; done; rm -rf -- "$voxey_check_dir"' EXIT
voxey_connect_args=()
start_proxy() {
  voxey_connect_args=()
  if [[ "${VOXEY_TEST_PROXY:-0}" != "1" ]]; then return; fi
  if [[ -n "$voxey_proxy_pid" ]]; then kill "$voxey_proxy_pid"; wait "$voxey_proxy_pid" 2>/dev/null || true; fi
  local voxey_proxy_port=$((voxey_port + 20000))
  python3 "$voxey_source_dir/tests/network_proxy.py" --listen-port "$voxey_proxy_port" --server-port "$voxey_port" > "$voxey_check_dir/proxy.log" 2>&1 &
  voxey_proxy_pid=$!
  for _ in {1..30}; do
    if rg -q 'NETWORK PROXY READY' "$voxey_check_dir/proxy.log"; then
      cat "$voxey_check_dir/proxy.log"
      voxey_connect_args=("--connect-port=$voxey_proxy_port")
      return
    fi
    if ! kill -0 "$voxey_proxy_pid" 2>/dev/null; then cat "$voxey_check_dir/proxy.log"; exit 1; fi
    sleep 0.1
  done
  cat "$voxey_check_dir/proxy.log"; exit 1
}
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
limits/opengl/max_lights_per_object=24
PROJECT
godot --headless --path "$voxey_check_dir" --editor --import --quit > "$voxey_check_dir/import.log" 2>&1
if rg -q 'SCRIPT ERROR:|^ERROR:' "$voxey_check_dir/import.log"; then cat "$voxey_check_dir/import.log"; exit 1; fi
godot --headless --path "$voxey_check_dir" --script res://tests/network_protocol_checks.gd > "$voxey_check_dir/protocol.log" 2>&1 || { cat "$voxey_check_dir/protocol.log"; exit 1; }
cat "$voxey_check_dir/protocol.log"
if rg -q 'SCRIPT ERROR:|^ERROR:' "$voxey_check_dir/protocol.log"; then exit 1; fi
voxey_port=$((25000 + $$ % 15000))
if [[ "${1:-}" != "--world-sync" ]]; then
  start_proxy
  godot --headless --path "$voxey_check_dir" --script res://tests/network_runner.gd -- "--port=$voxey_port" > "$voxey_check_dir/host.log" 2>&1 &
  voxey_server_pid=$!
  for _ in {1..150}; do
    if rg -q 'NETWORK HOST READY' "$voxey_check_dir/host.log"; then break; fi
    if ! kill -0 "$voxey_server_pid" 2>/dev/null; then cat "$voxey_check_dir/host.log"; exit 1; fi
    sleep 1
  done
  if ! rg -q 'NETWORK HOST READY' "$voxey_check_dir/host.log"; then cat "$voxey_check_dir/host.log"; exit 1; fi
  godot --headless --path "$voxey_check_dir" --script res://tests/network_runner.gd -- --client "--port=$voxey_port" "${voxey_connect_args[@]}" > "$voxey_check_dir/client.log" 2>&1 &
  voxey_guest_pid=$!
  wait "$voxey_guest_pid" || { cat "$voxey_check_dir/host.log" "$voxey_check_dir/client.log"; exit 1; }
  voxey_guest_pid=""
  wait "$voxey_server_pid" || { cat "$voxey_check_dir/host.log" "$voxey_check_dir/client.log"; exit 1; }
  voxey_server_pid=""
  cat "$voxey_check_dir/host.log" "$voxey_check_dir/client.log"
  if rg -q 'SCRIPT ERROR:|^ERROR:' "$voxey_check_dir/host.log" "$voxey_check_dir/client.log"; then exit 1; fi
fi
if [[ "${1:-}" == "--inventory" ]]; then exit 0; fi
voxey_port=$((voxey_port + 1))
start_proxy
godot --headless --path "$voxey_check_dir" --script res://tests/world_sync_runner.gd -- --role=host "--port=$voxey_port" > "$voxey_check_dir/world-host.log" 2>&1 &
voxey_server_pid=$!
for _ in {1..150}; do
  if rg -q 'WORLD SYNC HOST READY' "$voxey_check_dir/world-host.log"; then break; fi
  if ! kill -0 "$voxey_server_pid" 2>/dev/null; then cat "$voxey_check_dir/world-host.log"; exit 1; fi
  sleep 1
done
if ! rg -q 'WORLD SYNC HOST READY' "$voxey_check_dir/world-host.log"; then cat "$voxey_check_dir/world-host.log"; exit 1; fi
godot --headless --path "$voxey_check_dir" --script res://tests/world_sync_runner.gd -- --role=guest "--port=$voxey_port" "${voxey_connect_args[@]}" > "$voxey_check_dir/world-guest.log" 2>&1 &
voxey_guest_pid=$!
godot --headless --path "$voxey_check_dir" --script res://tests/world_sync_runner.gd -- --role=observer "--port=$voxey_port" "${voxey_connect_args[@]}" > "$voxey_check_dir/world-observer.log" 2>&1 &
voxey_observer_pid=$!
voxey_result=0
wait "$voxey_server_pid" || voxey_result=1
wait "$voxey_guest_pid" || voxey_result=1
wait "$voxey_observer_pid" || voxey_result=1
voxey_server_pid=""; voxey_guest_pid=""; voxey_observer_pid=""
cat "$voxey_check_dir/world-host.log" "$voxey_check_dir/world-guest.log" "$voxey_check_dir/world-observer.log"
if rg -q 'SCRIPT ERROR:|^ERROR:' "$voxey_check_dir/world-host.log" "$voxey_check_dir/world-guest.log" "$voxey_check_dir/world-observer.log"; then exit 1; fi
exit "$voxey_result"
