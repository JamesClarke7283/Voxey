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
limits/opengl/max_lights_per_object=24
PROJECT
godot --headless --path "$voxey_check_dir" --editor --import --quit > "$voxey_check_dir/import.log" 2>&1
# Godot can return zero after a script error, so check diagnostics as well.
if grep -E -q 'SCRIPT ERROR:|^ERROR:' "$voxey_check_dir/import.log"; then
  cat "$voxey_check_dir/import.log"
  exit 1
fi
for voxey_suite in mineclonia_noise_checks mineclonia_biome_checks farming_reference_checks maps_reference_checks smithing_reference_checks grindstone_reference_checks stonecutting_reference_checks barrier_reference_checks shape_registry_reference_checks furnace_reference_checks copper_tools_reference_checks enchanting_registry_reference_checks villager_trading_reference_checks villager_gossip_reference_checks villager_social_reference_checks farmer_fields_reference_checks composter_reference_checks zombie_target_reference_checks zombie_behavior_reference_checks mob_baby_reference_checks mob_weapon_reference_checks mob_armor_reference_checks mob_bow_reference_checks mob_crossbow_reference_checks arrow_flight_reference_checks crossbow_reference_checks bow_reference_checks shield_combat_reference_checks shield_reference_checks written_books_reference_checks bookshelf_reference_checks banner_reference_checks digging_reference_checks melee_reference_checks durability_reference_checks anvil_reference_checks enchanting_reference_checks desert_well_reference_checks trail_template_checks trial_template_checks test_survival village_runner alchemy_runner parity_runner polish_runner building_runner environment_runner systems_runner lifecycle_runner steam_runner skin_checks hosting_runner torch_lighting_runner; do
  godot --headless --path "$voxey_check_dir" --script "res://tests/$voxey_suite.gd" 2>&1 | tee "$voxey_check_dir/$voxey_suite.log"
  if grep -E -q 'SCRIPT ERROR:|^ERROR:' "$voxey_check_dir/$voxey_suite.log"; then
    exit 1
  fi
done

godot --headless --path "$voxey_check_dir" --script "res://tests/special_crop_reference_checks.gd" 2>&1 | tee "$voxey_check_dir/special_crop_reference_checks.log"
if grep -E -q 'SCRIPT ERROR:|^ERROR:' "$voxey_check_dir/special_crop_reference_checks.log"; then
  exit 1
fi
