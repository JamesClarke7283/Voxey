# Digging capabilities and tool-speed effects

Reference: `/home/impulse/.minetest/games/mineclonia`, inspected 2026-10-24.
The source-derived rules retain GPL-3.0-or-later attribution. The exported
capabilities, node groups and source hashes are in `assets/data/digging.json`;
the independent engine results are in `assets/data/digging_reference.json`.

## Effects and cached capabilities

Haste is now a registered live effect. Beacons grant it, its remaining duration
and level appear in the HUD, and it survives a save/reload. Haste, Fatigue and
Conduit Power use the source's factor conversions and capability transformations.
Conduit Power contributes to speed only while the player is in water.

Haste adds 0.2 per level. Active Haste and Conduit Power multiply their speed
factors. Fatigue uses the checkout's rational progression, not an exponential
approximation: level III gives a 0.02 factor. Level IV and higher produce a zero
total factor, for which the source sets affected digging times to at least 300
seconds. The ordinary slowdown path caps a time crossing that boundary at 300;
times already at or above the boundary retain the source's separate behavior.

Attack intervals use the source's rounded effective levels and ten-percent
adjustment per level, capped at ten seconds. Only items with the source's
`tool=1` group receive an item override. Swords and tridents do not have that
group. The hand has its own capability cache and supplies fallback digging when
the held item has no matching digging group.

The cache updates on relevant effect changes and tool punches. A newly selected
tool's first melee punch uses the capabilities passed to the callback before
the refresh; its next punch uses the new cache. Expiry, clearing effects and
gamemode changes clear carried overrides. Item metadata validation preserves
valid cached factors during ordinary inventory transfers.

## Digging and wear

Mapped blocks now use the source's actual registered groupcaps, including its
hardness/eligibility scaling, Efficiency's additive speed bonus, twentieth-second
rounding, instant-dig thresholds and the fastest matching group. An unsuitable
tool falls back to hand capabilities. The port does not impose the old synthetic
fivefold underwater penalty; this checkout has no active Aqua Affinity or that
penalty in its digging path.

The registered Unbreaking update has a notable edge: even at Efficiency zero,
regenerating groupcaps passes zero as a present Lua argument. This adds one to
the digging speed. The export preserves that behavior for Unbreaking-only tools.

Digging wear comes from the engine's selected group and current normalized wear,
including the remainder distribution over 65536 units. Unbreaking increases
group uses; it no longer rolls a chance to skip a whole dig. Hand-fallback digging
does not wear an unsuitable weapon. Failed block removals spend no digging wear.
Successful guest mining applies the same rule after the host acknowledges it.

The dataset contains 67 tool/hand profiles and 2,891 source node profiles, plus
the source's registered aliases. `MiningNodes` resolves **1,026 of 1,068 unique
placeable catalog entries** and **3,398 registered native IDs** to 1,313 actual
source nodes. The catalog audit initializes the later wood families and removes
duplicate IDs before counting. Brushes and pottery sherds are now correctly
non-placeable inventory items.

Mappings include doors and trapdoors, fences and walls, stairs and slabs,
standing/hanging signs, buttons and plates, colored materials, copper oxidation
variants, crops, coral, pickles, dripstone, amethyst, rails and decorations. Placed
variants use the registered placed nodes, not inventory placeholders such as the
dummy chest or door nodes. Ordinary copper now uses `mcl_copper:block`, and
stripped logs and bark use their own registrations. Cherry uses the source's
`cherry_blossom` key. Metadata-only variants select the corresponding base node;
their mining groups do not depend on the metadata. The pickle registration is
the rooted form on dead brain coral, which is the parent this port supports.

The **42 remaining catalog entries** are explicitly classified:

- Three original generic plants/recovery-chest entries and seven steam blocks.
- Four legacy crimson/warped leaf and sapling entries; the source uses fungi and
  wart blocks instead.
- Ten stairs/slabs for materials without source shapes, twelve stripped-bark
  stairs/slabs, and six walls without source registrations.

These extensions retain native timing and wear. They are not silently mapped to
a similar source material. The source registers unstripped bark shapes only;
the native stripped-bark shapes are an extension. Harvest drops, hardness
metadata used by other systems and non-digging tool interactions still have
separate implementations. This mapping work does not establish full block or
game parity. The shared harvest/drop path now has its own
[source implementation and validation](harvesting-source.md).

## Amplified beacons

Use a beacon normally to cycle its available primary effects. On a complete
four-layer pyramid, **sneak-use (Ctrl + right-click)** switches the selected
effect between level II and level I plus regeneration. This selection persists.
If the pyramid loses its fourth layer, level II stops being renewed until the
layer is repaired; effects already granted can expire normally.

The existing native beacon interface remains an adaptation. Its payment slot,
full beam generation and other documented beacon gaps are not closed by this
batch. The Haste II HUD and selection toast were inspected in a rendered scene.

## Verification

`tools/export_digging_reference.py` runs the installed game in an isolated
temporary world. It uses real ItemStacks, source groupcap generation and potion
functions, then Luanti's actual `get_dig_params`, including current wear. It also
executes the source's effect-factor aggregation functions. It does not change
the reference game or an existing world.

`tests/digging_reference_checks.gd` compares 720 effect cases and 23,232 engine
dig cases. `tools/export_mining_reference.py` also starts an isolated reference
world and evaluates all mapped node names using the **unfiltered live registry**,
eight hand/tool choices, and normal/enhanced capabilities at different wear
values. `tests/mining_reference_checks.gd` checks 3,398 ID mappings and **21,008
additional engine results**, and rejects unclassified catalog gaps. The stored
results in `assets/data/mining_reference.json` make this reproducible without
requiring the reference installation to run normal tests.

`tests/mining_node_checks.gd` checks semantic identities, paired door states,
dripstone and crop stages, and actual interrupted/completed mining and wear.
`tests/tool_effect_checks.gd` covers live effects, melee refresh
ordering, actual digging, Unbreaking, beacon acquisition/amplification, water
conditions, gamemode changes, disk persistence and expiry.

The mapping batch passed 1,183 focused lifecycle checks, 534 survival checks and
239 alchemy/pouch checks. A Linux PCK export also passed all 21,008 mapping-oracle
comparisons when run from the packaged resources. Brush/sherd inventory art was
checked in a rendered Godot view after their placement flags were corrected.

```sh
PYTHONDONTWRITEBYTECODE=1 python3 tools/export_digging_reference.py
PYTHONDONTWRITEBYTECODE=1 python3 tools/export_mining_reference.py
godot --headless --path . --script res://tests/digging_reference_checks.gd
godot --headless --path . --script res://tests/mining_reference_checks.gd
godot --headless --path . --script res://tests/lifecycle_runner.gd -- mining_node tool_effect
godot --headless --path . --script tools/audit_digging.gd -- /tmp/voxey-digging-audit.json
```

Verification on 2026-10-24: all 720 effect cases and 23,232 dig cases pass in
the project and exported Linux pack. The exported live-effect suite passes 26
checks, the tool/melee combination passes 49, and the beacon/conduit/guardian/
melee/defensive combination passes 137. The full survival suite passes 534
checks and the alchemy suite passes 239. The Haste II HUD and selection message
were inspected in a rendered scene.

The loopback host/client regression also passes, including Haste expiring before
a dig acknowledgement and reconnect persistence. Cached speed changes are
excluded from the pending tool's identity check; enchantments and wear still
have to match. Godot import and Linux pack export report no script errors.
