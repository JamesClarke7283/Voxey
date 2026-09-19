# Classic wood families

Voxey now implements the six classic Mineclonia wood families: oak, spruce,
birch, jungle, acacia and dark oak. Each has its own logs, leaves, saplings,
planks, stripped logs, bark wood and stripped bark wood. Logs retain their axis
when placed, stripped or saved. Hidden axis states drop the ordinary log item.
The original oak IDs remain unchanged, including items in existing saves.

| Species | Log | Leaves | Sapling | Planks | Natural acquisition in Voxey |
| --- | ---: | ---: | ---: | ---: | --- |
| Oak | 6 | 7 | 23 | 8 | Oakwood meadow, cool swamp and willow shores |
| Spruce | 6032 | 6033 | 6034 | 6035 | Frostpine highlands |
| Birch | 6064 | 6065 | 6066 | 6067 | Birch patches in Oakwood meadow |
| Jungle | 6096 | 6097 | 6098 | 6099 | Warm swamp and willow shores |
| Acacia | 6128 | 6129 | 6130 | 6131 | Warm, dry meadow |
| Dark oak | 6160 | 6161 | 6162 | 6163 | Dark oak patches in Oakwood meadow |

The existing six-biome terrain generator is retained. This distribution adapts
source taiga/birch forest/jungle/savanna/dark forest identities to available
Voxey biomes; it is not a claim of Mineclonia biome or map-generation parity.
All six species are obtainable without commands and renewable from leaf drops.
Tree placement uses world-coordinate randomness and includes neighboring roots
in chunk halos. Saved block edits still override regenerated terrain.

## Source and attribution

The implementation was checked against the local source tree at
`/home/impulse/.minetest/games/mineclonia`:

- `mods/ITEMS/mcl_core/nodes_trees.lua`: six family registrations, all 38
  sapling-growth schematics, giant spruce/jungle, mandatory 2×2 dark oak,
  90% small/10% large oak selection, jungle sapling rarity, apple eligibility.
- `mods/ITEMS/mcl_trees/api.lua`: normal/bark/stripped variants, four logs →
  three bark blocks, each log/bark → four planks, fuels, leaves, ordered drops,
  placed-leaf metadata and 45% bone meal success.
- `mods/ITEMS/mcl_trees/functions.lua`: connected leaf distance six, stripping,
  schematic rotations, matching 2×2 detection and growth clearance.
- `mods/ITEMS/mcl_trees/abms.lua`: growth every 35 seconds with chance 1/5;
  dark sapling removal; orphan decay every five seconds with chance 1/10.
- `mods/ITEMS/mcl_trees/lg_register.lua`: natural family and swamp/jungle tree
  features. Source jungle schematics contain vines and cocoa.
- `mods/ITEMS/mcl_tools/init.lua`: successful axe placement callbacks wear the
  tool once, including stripping.

[Converted layout attribution](../assets/trees/NOTICE.md) includes the source
license notice and reproduction command. The immutable JSON contains the
original filename and SHA-256 checksum for every MTS file. The converter
preserves voxel IDs, facedir information, individual-node probabilities and
vertical-slice probabilities. The binary format is decoded at conversion time;
Voxey does not need Luanti installed at runtime. Original Voxey procedural
textures remain in use; no source textures, sounds or models were copied.

## Mechanics and persistence

A normal or stripped log/bark block produces four matching planks. Four logs in
a 2×2 grid produce three matching bark blocks. Axes strip logs and bark on use,
retain axis, and lose one durability in survival. All logs/bark smelt to
charcoal. Logs/planks fuel furnaces for 15 seconds and saplings for five.
Leaves/saplings have a 30% composter chance. All six species participate in wood
building families and generic plank recipes through their shared integrations.
Source tree groups also let mixed logs/stems make smokers and campfires; mixed
wooden slabs make daylight detectors and composters in both manual and guide
crafting. Named wood products require their own species.

Saplings grow on the existing dirt, grass, snow-covered soil and swamp grass.
Single spruce/jungle saplings grow ordinary trees; matching 2×2 squares grow
giant source layouts. Dark oak requires a matching 2×2 square. The timer and
bone meal probabilities follow the source. Bone meal is consumed even when
clearance or a missing companion prevents growth. This source version creates
saplings with stage zero but does not advance a separate visible growth stage.

Before consuming any sapling, growth validates the complete loaded shape and
the source center-column or 6×6 giant clearance volume. Existing player blocks,
containers and placed leaves cannot be overwritten. Snow layers remain
replaceable, matching source `nodes_base.lua` buildable snow; full snow blocks
remain protected. This is deliberately
stricter than the source's growth whitelist and forced schematic trunk nodes,
which can replace some wood or dirt. Trees do not partially appear across
unloaded columns. Natural layouts that would exceed Voxey's 64-high generated
surface buffer select a compact spruce/single jungle alternative or skip that
root; their tops are never clipped. Sapling-grown trees can use the full build
height.

Leaf drops follow source `max_items=1`, in order: one stick attempt, two-stick
attempt, sapling, then eligible apple. Ordinary sapling rarity is 1/20; jungle
is 1/40 before earlier attempts are accounted for. Only oak and dark oak drop
apples. Fortune uses the source tables, including the source's unusual stick
rarity 35 at Fortune III. Shears or Silk Touch recover the exact leaf block.
An empty drop result produces nothing and cannot fall through to a default
block reward. Natural leaf decay uses the same ordinary drops.

Natural leaves follow connected leaf paths to any log species or persistent
leaf within six edges. Player-placed leaves do not decay. Unknown neighboring
columns postpone decisions. Leaf simulation uses a runtime index, at most 16
queue entries and a 1.5 ms soft time budget per frame; stale entries count toward
the same bound. Orphan/persistent flags use saved block metadata, sapling timers
use the existing growth records, and unload/reload rebuilds only loaded indexes.
Old saves did not distinguish placed leaves from grown leaf edits: every legacy
edited oak leaf is preserved once as persistent, including distant unloaded
edits. A saved `wood_schema` marker prevents this migration affecting new trees.

## Deliberate limits and remaining dependencies

- The other Mineclonia wood types, additional natural oak variants and exact
  source biome distributions remain separate parity work.
- Giant spruce's podzol conversion requires the missing podzol soil family.
- Oak/birch's nearby-flower bee-nest chance requires bee nests and bees.
- Cocoa beans plant only on the horizontal sides of normal jungle logs,
  including axis variants. This source explicitly excludes stripped logs and
  bark wood (`mcl_cocoas/init.lua`). Existing cocoa has two maturity states; source stages one/two map to the
  immature pod and source stage three maps to the ripe pod. Vine orientation
  continues using Voxey's existing vine rendering.
- Voxey's light scale reaches 14 rather than source light 15. Sapling darkness
  uses actual nearby light and the existing sky visibility helper.
- Cut-leaf particles, potted saplings and source biome leaf palettes are not
  included. The tree resource and growth loop does not depend on them.

## Verification

`godot --headless --path . --script res://tests/lifecycle_runner.gd -- wood`
checks each species' registration, atlas indices, natural generation, source
shape placement, acquisition drops, manual/guide recipes, real stripping and
wear, giant growth, obstruction transactions, dark/light timing, bone meal,
leaf paths, unload behavior and real save/reload. The general content suite
also samples a deterministic warm-swamp jungle column to verify that vines
remain obtainable after replacing the old vines-on-every-oak generator.
