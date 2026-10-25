# Trial chambers, spawners and vaults

Reference: the local Mineclonia checkout at
`/home/impulse/.minetest/games/mineclonia`, inspected on 2026-10-24. Work remains
active; this is a completed implementation batch, not a claim of whole-game parity.

## Source and implementation

- `mods/ITEMS/mcl_trial_spawners/{init,item_spawner}.lua` →
  `scripts/trials.gd`: 14-block activation with line of sight; six base enemies,
  two additional enemies per extra participant, two simultaneous plus one per
  extra participant; two-second spawn interval; 30-minute cooldown; source
  ordinary/ominous key chances (50% / 30%). The outcome is one group roll with
  one reward per participating player, spaced two seconds apart.
- Ominous trials convert Bad Omen to Trial Omen for 15 minutes per level, reset
  outstanding ordinary enemies, add a simultaneous slot, double the total for
  species without armor, and schedule the source's twelve falling-item hazards
  at eight-second intervals with three-to-six-second preparation. Skeletons,
  strays, zombies and husks can receive the source's iron/diamond/chain armor
  distribution. Weapon prototypes lose enchantments when the source converts
  them back to names; this behavior is retained. Combat uses Voxey's existing
  damage model. The source has no loaded breeze spawner pool, so none is invented.
- `mods/ITEMS/mcl_vaults/{init,api}.lua` → `scripts/trials.gd` and
  `scripts/trial_loot.gd`: normal and ominous keys, three weighted loot pools,
  per-player entitlement, the source's bounded 128-name claim history,
  three-block activation/five-block deactivation hysteresis, two-second previews
  and half-second loot ejection. Wrong keys and repeated claims consume nothing.
  Creative preserves keys. The host validates remote claims and updates that
  player's inventory; callers cannot choose another player's identity.
- `mods/MAPGEN/mcl_levelgen/trial_chambers.lua` and its 44 `.dat` templates →
  `scripts/trial_chambers.gd`: named connector expansion from the source's room
  pools, original room voxels, configured spawner species, ordinary and ominous
  vaults, supplies, decorated pots and waxed copper. Placement uses the source's
  34-chunk spacing, 12-chunk separation and Y −40…−20 start range with Voxey's
  seeded random generator. `/locate trial_chambers` finds the nearest anchor.
- `mods/ITEMS/mcl_core/craftitems.lua` → enchanted golden apple: four food,
  9.6 saturation, edible when full, five minutes of fire resistance/resistance,
  two minutes of Absorption IV and twenty seconds of Regeneration II.

The exporters `tools/export_trial_loot.py` and `tools/export_trial_templates.py`
write reproducible JSON in `assets/data/`, retaining source paths/hashes and
GPL-3.0-or-later attribution. The license is in
[`docs/licenses/Mineclonia-GPL-3.0.txt`](licenses/Mineclonia-GPL-3.0.txt).
Templates are decoded in an empty Lua environment; the game reads only JSON.
Artwork remains Voxey's original procedural geometry and textures.

## Saves and streaming

Each active trial stores the participant list, total-spawn count, unique enemy
identities, health, equipment, effects, pending hazards, cooldown and reward queue
in its station record. Enemies removed for column unloading retain their records;
defeated enemies are removed from the records. Reloading recreates outstanding
enemies once. Trial silverfish are excluded from the separate generic alchemy
snapshot to prevent duplicate restoration. Named trial enemies likewise keep one
owner instead of joining the farming snapshot.

Breaking a cage moves surviving enemies to independent saved records. A
world-level serial prevents a replacement cage from reusing their identities.
Externally removed enemies are pruned instead of being recreated.

Vault claims and the remaining reward queue are saved before key consumption and
ejection begins. Queue entries are removed as they are ejected. Repeated opening,
column registration or loading does not reroll an existing reward queue.
Generated station and copper state are installed before ordinary load hooks and
never overwrite saved player edits or previously initialized containers.

## Remaining differences

- Room geometry and connector names come from source templates. Piece selection
  uses Voxey's RNG and a bounded native connector assembler (20 levels, at most
  160 pieces), not Luanti's complete jigsaw collision/terrain machinery. Worlds
  therefore do not reproduce Mineclonia seeds. Old builds still win through saved
  edits; newly generated rooms can appear in previously unedited terrain.
- Template bed colors/facing and some directional decorations use existing
  Voxey representations. Podzol/mycelium decorations currently use dirt. Bamboo
  planks and hanging signs now resolve to their implemented material family,
  retaining the original loot weights.
- Equipment loot now uses the shared [source-verified enchanting engine](enchanting-source.md), with treasure eligibility, reliable retries and the source's unrestricted continuation flag.
- Cooldown and pending-effect timers advance during loaded play, matching Voxey's
  existing simulation convention. They pause in menus, inactive dimensions and
  unloaded areas. The reference's absolute game-time cooldown can elapse while a
  spawner is unloaded.
- Cage state and key use work over hosted multiplayer. Rotating item previews
  currently render on the host; remote preview entities and source-specific
  particle/audio presentation remain open. Omen conversion currently reads the
  host player's effects; remote-player effect replication remains a separate
  multiplayer gap. Mob AI continues to use Voxey's existing creature behavior.

## Verification

`tests/trial_checks.gd` runs through `tests/lifecycle_runner.gd -- trial` and covers
activation, obstruction, quotas, unloading/restoration, completion, cooldown,
omen conversion, key consumption, concurrent/repeated claims, saved ejection,
source loot entries, food effects and real generated-column installation.
`tests/trial_template_checks.gd` checks every template's voxel count, palette
coverage, deterministic assembly, source spawners, deep carving, metadata,
neighboring-column agreement and bounded caches. `tests/trial_tour.gd` renders
the four main cage/vault forms for visual review.

Validation for this batch: 245 focused gameplay regressions passed; the final
expanded trial suite passed 40 checks. Template/registry/column-seam checks and
network protocol checks passed. A Linux resource pack loaded both JSON datasets
and passed the template checks from inside the pack. Both exporters reproduced
byte-identical output on a second run. The rendered cage/vault preview was
inspected after resolving an ID collision with hanging signs; the final range is
12200–12212.
