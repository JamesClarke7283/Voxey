# Pillager outposts and parrots

Voxey follows the supplied Mineclonia `mods/MAPGEN/mcl_structures/pillager_outpost.lua` and `mods/ENTITIES/mobs_mc/parrot.lua`. The implementation is original GDScript using the source as a behaviour reference; all art is original procedural code.

## Why it mattered

The outpost is a watchtower that is a **place**, not a loot box. The source's `after_place` spawns a raiding party:

| Party | Count |
|---|---|
| Pillagers | 5 |
| **Parrots** | 3 |
| Iron golem | 1 |

The parrots are the part Voxey lacked **entirely** — there was no parrot creature at all, so the tower could not be the outpost without them. This batch adds the bird as well as the building.

The source also carries a **damaged anvil** (`construct_nodes = {"mcl_anvils:anvil_damage_2"}`), which is its way of placing an anvil whose damage state is already set.

## The parrot

The source's own bird:

- **Six health**, dropping **1–2 feathers**.
- **Passive**, and a **glider** — the same `glides` behaviour Voxey already gives chickens, so a parrot does not plummet.
- Built as a red body with blue wing tips, a hooked grey beak and a fanned tail. The hooked beak is what tells it apart from the chicken at a glance, and the source's parrots are red with blue markings.

The parrot is registered as a passive animal, so it interacts with the existing passive-mob systems (fleeing when struck, persisting when named).

## The loot

The source's four groups, each with its own roll count:

| Group | Rolls | Contents |
|---|---|---|
| Crops | 2–3 | Wheat, carrots, potatoes |
| Supplies | 1–2 | Experience bottles, arrows, string, iron, a book, the sentry trim |
| Saplings | 1–3 | Dark oak saplings |
| **Guaranteed** | 1 | A **crossbow** |

The crossbow group is the notable one: it is the source's guaranteed drop, so **every** outpost chest holds one. The test asserts that specifically, because a version that rolled it by weight instead would look right while sometimes producing none.

## Recorded source gaps

- **The tower is generated, not loaded from a schematic.** The source ships two `.mts` files. Voxey has no schematic loader, so the tower is a stone-based wooden shell with a ladder, a raised platform and a railing. The party counts, the anvil and the loot table are the source's exact behaviour; the block-by-block layout is not.
- **No party respawn timer.** The source registers a structure spawn (`chance 10, interval 60, limit 9`) that keeps pillagers coming back around an outpost. Voxey spawns the initial party once; a returning-player repopulation is not implemented.
- **No sentry armour trim.** The source's supply group includes `mcl_armor:sentry`, which Voxey has no item for, so the entry keeps its weight with a zero id.
- **No wall-reconnection step.** The source re-runs `mcl_walls.update_wall` over the outpost's bounds after placing it. Voxey's barriers already settle on placement, so the step has no equivalent here.
- **No biome or `place_on` restriction beyond ground.** The source lists Desert, Plains, Savanna, IcePlains and Taiga. Voxey has no such biome map, so an outpost is placed where the ground is grass, dirt or sand, which is what the source's `place_on` requires.
- **Parrots are not tameable yet.** The source tames a parrot with seeds and lets it perch on the player's shoulder. Voxey's parrot is a wild bird that can be named and killed; the shoulder-perch behaviour is not implemented.
