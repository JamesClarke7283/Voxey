# Mooshroom stew: source and integration

## Source behavior

Reference: `mobs_mc/cow+mooshroom.lua` in the Mineclonia checkout.

- `mooshroom` inherits the cow's wheat `follow` list and interaction starts with `feed_tame`; babies then return before every item branch (`:124-126`). Thus wheat has priority over all item behavior in `MooshroomStew.use`, and babies cannot be fed flowers, milked, bowled, or sheared.
- A brown mooshroom has one `_sus_ingredient_held` (`:119-122`). An item in the source `sus_stew_ingredient` group fills it only when empty; a second valid flower returns without consumption or replacement (`:186-193`). Red mooshrooms do not accept flowers. Generic plants, mushrooms, ferns, and other items are not ingredients.
- A bowl always spends one input. Brown plus a stored flower calls `mcl_sus_stew.get_sus_stew` and clears the ingredient; every other mooshroom bowl gives ordinary mushroom stew (`:168-185`). Output enters the inventory or drops at mob Y+0.5. The source removes the bowl before testing output room.
- Empty buckets on adult cows and adult mooshrooms become milk, with the same inventory-or-Y+0.5-drop rule (`:75-93`, `:156-167`).
- These callbacks call `inv:remove_item` unconditionally. Bowls, buckets, and accepted flowers are consumed in creative mode too. Only shear wear has a creative check. This is the checked-out source behavior, not a modern-Minecraft exemption and not a creative-only stew route.
- Shears drop exactly five red or brown mushrooms at mob Y+1.4, replace the mooshroom with a fresh cow, and apply `shearsy` wear outside creative (`:135-155`). `mcl_mobs/api.lua:20-87` shows replacement retaining only child, nametag, persistence, and yaw. The child case is unreachable through this interaction because of the earlier child return. The stored flower is not transferred.
- Lightning toggles the two texture sets without touching `_sus_ingredient_held`, and returns true to suppress ordinary strike damage (`:197-205`). Consequently a red mooshroom can retain a hidden flower: bowls remain ordinary while red, and the flower becomes available again if lightning makes it brown.
- Generic mob staticdata serializes non-function fields, including the ingredient (`mcl_mobs/api.lua:125-139`, `:362-367`). Voxey therefore snapshots both colour and ingredient in `Farming` rather than treating either as model-only state.
- Neither the cow nor mooshroom AI list contains sheep grazing (`cow+mooshroom.lua:99-105`). They do not consume grass. Existing `Farming.begin_graze`/`Farming.graze` sheep guards already implement this distinction; no mooshroom grazing timer, wool regrowth, or grass-to-dirt behavior belongs here.
- The source also has a `MushroomIslands` spawner (`:243-259`). This module intentionally adds no biome or substitute natural-spawn rule.

## Module API

`MooshroomStew` uses creature metadata `mooshroom_brown` and `mooshroom_stew_flower`.

- `initialize(mob, brown = null)` chooses a fresh red/brown variant without rerolling restored state.
- `set_brown`, `is_brown`, `ingredient`, `snapshot`, and `restore` expose the persistent state. `restore` rejects unsupported saved flower ids but retains a valid hidden ingredient on red. `set_brown` also calls `refresh(mob)`, so restoration and lightning immediately update the live model.
- `refresh(mob)` swaps the original procedural body, cap, and stem textures on existing mesh materials. It creates no model nodes, replaces no meshes or materials, and leaves animation joints, pose, baby scaling, and collision untouched. It is safe before `_build_model`; initialization metadata then determines the first build's appearance.
- `use(game, mob) -> bool` is the adult cow/mooshroom item callback. Call it **after** `Farming.use` to preserve wheat priority.
- `shear(game, mob) -> Creature` returns the replacement cow, or null when not applicable.
- `lightning(mob) -> bool` toggles colour, preserves the flower, saves state, and tells the weather dispatcher to skip damage.

Suspicious stew is delegated to the shared `FoodFeatures.stew_ingredient(id)`, `stew_item(id)`, `stew_effect(id)`, and `stew_duration(id)` API. There is no second recipe/effect table. Ordinary bowls use `Nodes.MUSHROOM_STEW`; suspicious bowls use `VillageContent.SUSPICIOUS_STEW` with the shared item's `data.effect`.

## Original-art presentation mapping

The reference selects `mobs_mc_mooshroom.png` plus `mobs_mc_mushroom_red.png`, or their brown counterparts (`cow+mooshroom.lua:113-122`). Voxey maps those two texture sets to newly generated 16x16 pixel textures: a red or brown coat with pale cow-like patches, and matching spotted mushroom caps with pale stems. No reference texture, model, or other source art is imported.

`Creature` retains the ordinary cow body, head, horns, legs, tail, joints, walk animation, baby scaling, and registered collision dimensions. Four small original cuboid mushrooms use stepped caps and slender stems: three sit on the back and one is parented to the head joint so it follows head animation. Variant-sensitive parts carry `mooshroom_part` metadata (`body`, `cap`, or `stem`), which also keeps them out of `Creature.merge_parts`; this is what allows later red/brown changes to modify those exact mesh objects in place. Repeated refreshes do not add mushrooms or other nodes. Shearing still spawns the ordinary, unmarked cow model.

## Integrated parent hooks

### Creature registration and initialization

Add a `mooshroom` row beside `cow` in `Creature.KINDS`, copying the cow definition (same health, speed, dimensions, drops, voice, pitch, and XP), and include `"mooshroom"` wherever the cow body model is selected. Do not add it to `Creature.PASSIVE`: that is the generic farm-animal spawn pool, not the source's mycelium/MushroomIslands spawner.

In `Creature._ready`, before `_build_model()` and `Farming.register(self)`:

```gdscript
if kind == MooshroomStew.KIND: MooshroomStew.initialize(self)
```

In `Farming.FOODS`, add the inherited wheat entry:

```gdscript
"mooshroom":[Nodes.GRAIN],
```

That also makes `Farming.supports`, `managed`, `saved_kind`, growth, breeding, following, and hibernation use their existing real paths. `Creature.die` already includes mooshroom in Cow Tipper.

### Player interaction

In `VillageSurvival.use`, immediately after the existing `if Farming.use(game,mob): return true`:

```gdscript
if MooshroomStew.use(game,mob): return true
```

No change is needed in `Player.use`: its early shears branch is restricted to sheep, so mooshroom shears reach this dispatcher. `MooshroomStew.use` itself enforces adult status and shears/bucket/bowl/flower order. The focused suite invokes this real dispatcher rather than calling the flower helper directly.

### Snapshots

At the end of `Farming.state`, before `return value`:

```gdscript
if mob.kind == MooshroomStew.KIND:
	value.mooshroom = MooshroomStew.snapshot(mob)
```

At the beginning of `Farming.restore_state`:

```gdscript
if mob.kind == MooshroomStew.KIND:
	MooshroomStew.restore(mob,entry.get("mooshroom",{}))
```

The existing `Farming.remember`, `snapshot`, `resolve`, lead/boat `Farming.state` calls, and world save then carry the state through all normal persistence routes. Flower feeding, suspicious-stew extraction, and lightning call `Farming.remember` immediately.

### Lightning

In `Weather.strike`, before the generic `mob.hit(...,"lightning")` and alongside the other conversion callbacks:

```gdscript
if MooshroomStew.lightning(mob): continue
```

### Food dispatch

No new food dispatcher is required or wanted. The existing chain is:

1. `Eating.start` captures the selected stew id and `data` in `player.eating`.
2. `Eating.update` checks that the held stack and metadata still match, then calls `Hunger.eat`, `Eating.food_effects`, and `FoodFeatures.on_eat(player,id,data)` (`eating.gd:27-32`).
3. `FoodFeatures.on_eat` applies the shared suspicious-stew effect and source duration.
4. Survival `Eating.update` consumes one stew and returns `Nodes.BOWL`, dropping overflow (`eating.gd:33-40`). Creative eating preserves the item and creates no bowl. `Hunger.can_eat` already permits suspicious stew at full hunger.

The checks exercise this chain with a mooshroom-produced effect, verifying effect level, duration, consumption, and the returned bowl.

## Tests

`tests/mooshroom_stew_checks.gd` is a `RefCounted` suite fragment with `run(suite, game)`, matching the farming/food suites. Add to the parent runner:

```gdscript
await load("res://tests/mooshroom_stew_checks.gd").run(self,game)
```

Coverage includes distinct forced red/brown initial models, four mushrooms per model, in-place `set_brown`/restoration/lightning refreshes with stable mesh and material identities, no duplicate nodes on repeated assignment, live player dispatch, one-flower capacity, unsupported/red rejection, ordinary and suspicious bowl counts, full-inventory drops, source creative consumption, baby rejection, no grass consumption, cow milking, JSON snapshots plus actual save/reload, shared eating/effect/bowl dispatch, lightning's hidden-ingredient rule, and both shearing conversions. Tests use real spawned creatures and real inventory/world paths; variant choices are set explicitly so they do not depend on random spawn order.
