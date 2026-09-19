# Heads and skulls

Voxey follows the supplied Mineclonia `mods/ITEMS/mcl_heads`. The implementation is original GDScript using the source as a behaviour reference; no source code or mesh is copied.

## Seven heads, three placements each

The reference registers each head three times — on the floor, on a wall, and under a ceiling — but they are **one item**. `on_place` appends `_wall` or `_ceiling` to the node name depending on the face clicked, and every placement drops the plain floor head. Voxey reproduces this: the placement is chosen from the clicked face, and the wall and ceiling variants return the floor item.

| Head | Wearable effect in the source |
|---|---|
| Zombie Head | halves zombie detection range |
| Creeper Head | halves creeper detection range |
| Human Head | none |
| Skeleton Skull | halves skeleton detection range |
| Wither Skeleton Skull | none |
| Piglin Head | halves piglin detection range |
| Dragon Head | none |

Each is a half-block decoration with the source hardness of 1.0. The boxes differ per placement: a floor head sits in the lower half, a ceiling head hangs in the upper half, and a wall head hugs one face.

## Acquisition: the charged creeper chain

This is the part that matters, because the reference has no random head drop at all. `mcl_mobs/physics.lua` forces a `mob_head` drop **only** when the killing reason was an explosion from `mobs_mc:creeper_charged`:

```lua
if (dropdef.mob_head and mcl_reason
    and mcl_reason.type == "explosion"
    and mcl_reason.mob_name == "mobs_mc:creeper_charged") then
    num = 1
end
```

So acquiring a head requires the whole chain, and Voxey implements it:

1. **Lightning charges a creeper.** A creeper struck by lightning becomes charged rather than damaged — the source's `_on_lightning_strike` replaces the mob with `mobs_mc:creeper_charged`.
2. **A charged creeper explodes harder.** The source gives it strength 6 over radius 8, against the ordinary creeper's 3 and 3.5.
3. **Its blast drops heads.** Only an explosion whose source was charged marks its victims, and a marked victim that dies drops its head. An ordinary death drops nothing.

Zombies, creepers and skeletons yield their own heads; mobs with no source head entry yield nothing.

## The other lightning conversions

The source's `_on_lightning_strike` is not only about creepers. Each mob it defines returns `true`, which means the strike **converts rather than damages** the mob it hits:

| Struck mob | Becomes | Note |
|---|---|---|
| Creeper | Charged creeper | The head chain above |
| Pig | Zombified piglin | Neutral to players, immune to sunlight |
| Villager | Witch | Its record is marked dead so the village does not respawn it |
| Skeleton horse | — | Immune; takes no damage |
| Mooshroom | Other colour | Voxey has no mooshroom |

A **zombified piglin** is why the pig conversion is worth having: it is a piglin rotted green, and the source makes it `_neutral_to_players`, so it ignores you until you strike it. It is also `ignited_by_sunlight = false`, so unlike a zombie it survives daylight. Those two facts are what make it a distinct mob rather than another zombie, and the checks assert both.

Converting a **villager** has to mark its record dead. The source relinquishes the villager's points of interest after replacing it; Voxey's village keeps its people in a record table, so leaving the record alive would respawn the villager and duplicate it. The check asserts the record is dead, not just that a witch appeared.

## Recorded source gaps

- **The worn effect is not applied.** Heads carry the source's `armor_head` group and reduce the detection range of the matching mob by half. Voxey's creature aggro computes a single shared range with no per-mob factor, so applying this would mean adding an aggro-range parameter to every creature. It is recorded rather than approximated with a different number.
- **Only three mob heads are obtainable.** Zombie, creeper and skeleton heads drop from the charged-creeper chain. The human, wither skeleton, piglin and dragon heads exist as items and blocks matching the source's registration, but the source acquires those from structure loot, the Wither and piglins, none of which Voxey has; they remain decorative-only.
- **Charged creepers do not otherwise differ.** The source gives the charged variant its own charge texture; Voxey's creeper model is shared, so the charge is shown by a flash rather than a texture swap.
- The source's `screwdriver` rotation modes and its legacy-head conversion LBMs have no equivalent here, because Voxey has neither a screwdriver nor legacy head nodes.
