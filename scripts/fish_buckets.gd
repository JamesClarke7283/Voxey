class_name FishBuckets
extends RefCounted

# Mineclonia `mods/ITEMS/mcl_buckets/fishbuckets.lua` plus the bucket half of
# `mods/ENTITIES/mobs_mc/{cod,salmon,pufferfish,tropical_fish}.lua`,
# GPL-3.0-or-later. Original GDScript using the source as a behaviour reference.
#
# Voxey had exactly one fish bucket, `VillageContent.COD_BUCKET` (788), and using
# it was wrong in two ways: the cod branch in `village_survival.gd` emptied the
# bucket into a water node and dropped a **raw cod item** — a dead fish from a
# live-fish container — and salmon, pufferfish and tropical fish had no bucket at
# all, so the only route to a live fish was the (uncontrollable) natural spawn in
# `game.gd`. `wandering_traders.gd:52` records the missing ids as the reason the
# trader sells the bare fish items instead.
#
# Source rules reproduced here:
# - A fish bucket is `stack_max = 1`, group `bucket`, group `fish_bucket`, and it
#   carries its fish in `_mcl_buckets_fish` (fishbuckets.lua:66-73). Voxey holds
#   the same table in `BUCKETS` below; the cod entry still points at the existing
#   `VillageContent.COD_BUCKET` rather than re-registering it.
# - Using one against a **non-solid, non-opaque** node spawns that fish at the
#   pointed cell's `above` (fishbuckets.lua:24-26). Solid or opaque nodes do
#   nothing, and the itemstack is returned unchanged, so the interaction is
#   consumed without effect.
# - The fish is spawned with `persistent = true` (fishbuckets.lua:29-32), so it
#   never despawns for distance. In Voxey that is the `persistent` meta the
#   parent's despawn gate honours (`scripts/creature.gd:715`, listed in PARENT
#   WIRING). Nothing else in Mineclonia removes it either.
# - A stored `name` becomes the creature's `nametag` (fishbuckets.lua:34-37).
#   Voxey's fish buckets carry it in the stack's `data.name`, and `release_name`
#   reads it back.
# - The cell is then filled with a water source and the bucket becomes an empty
#   `mcl_buckets:bucket_empty` (fishbuckets.lua:46-56). In creative the source
#   keeps the fish bucket, which is the same rule Voxey's own water bucket uses
#   (`player.gd:788-793`).
# - In the Nether the source sets `water = nil`, so **no water node is written**
#   and it plays `fire_extinguish_flame` at gain 0.25 inside sixteen blocks
#   instead (fishbuckets.lua:47-50). The bucket is still emptied.
# - `on_place` and `on_secondary_use` are the same function, so there is no
#   separate in-air use to port.
# - River water is not in Voxey: the source's two `mclx_core:river_water_*`
#   branches (fishbuckets.lua:41-45) collapse to the plain water source.
#
# Capture is the other half, and it lives on the fish rather than on the bucket:
# `cod.lua:77-84`, `salmon.lua:70-77`, `pufferfish.lua:96-103` and
# `tropical_fish.lua:145-158` all take a **water bucket** from the clicker,
# `safe_remove` the fish and hand back the matching fish bucket. The first three
# do not carry the fish's name across, while the tropical fish stores its
# `nametag` in the bucket (`tropical_fish.lua:150-158`); Voxey applies that
# nametag rule to every fish, since its nametag is a plain `custom_name` and
# losing a player-given name on a round trip through a bucket is a bug rather
# than a rule. The source's `awards.unlock("mcl:tacticalFishing")` has no Voxey
# achievement to award (Voxey's fish achievement, `fishy_business`, is the
# fishing-rod catch and is not this path).
#
# PARENT WIRING — the parent owns these central files. Exact lines:
#
# 1. `scripts/village_content.gd` `const DATA`, beside the cod bucket at line 855.
#    Point the three rows at this module's table so there is one source of truth,
#    the way `Magma.DATA`/`Rails.DATA`/`Farmland.DATA` already are:
#
#        11560:FishBuckets.DATA[11560],
#        11561:FishBuckets.DATA[11561],
#        11562:FishBuckets.DATA[11562],
#
# 2. `scripts/village_survival.gd` `use()` — two branches:
#
#    * the capture half, beside the other creature interactions, after
#      `if NameTags.use(game,mob): return true`:
#
#          if FishBuckets.capture(game,mob): return true
#
#    * the placement half, **replacing** the old cod branch at lines 126-129, so
#      the target cell is no longer filled with water plus a raw cod:
#
#          if FishBuckets.is_fish_bucket(held): return FishBuckets.place(game,target)
#
# 3. `scripts/creature.gd:715` — the never-despawn gate that honours the
#    `persistent` meta `place()` sets:
#
#        if distance > 90 and data.get("can_despawn",false) and not has_meta("persistent"): queue_free(); return
#
# 4. `scripts/inventory.gd:378` — `clean_slot`'s metadata allow-list has no `name`
#    key. Verified by probe: `Inventory.clean_slot({...data:{name:"Sunny"}})` and
#    `Inventory.restore(...)` both come back with `data == {}`, so a carried fish
#    name survives in the world but not a save/load. One line beside the
#    `custom_name` key keeps it:
#
#        if raw.get("name") is String and not raw.name.is_empty(): metadata["name"] = NameTags.bounded(str(raw.name),NAME_LIMIT)
#
# 5. `scripts/alchemy_world.gd` `snapshot`/`restore` — verified by probe: the
#    snapshot already saves every `AlchemyCreature`, the four fish are all in
#    `Creature.ALCHEMY_KINDS`, and a released fish's `custom_name` comes back
#    intact, so the fish and its name survive a reload with no change. The
#    `persistent` meta is **not** snapshotted, so a *reloaded* fish is
#    despawnable again. Carrying the flag in the record closes that:
#
#        snapshot: "persistent":mob.get_meta("persistent",false)
#        restore:  if record.get("persistent",false): mob.set_meta("persistent",true)

const SALMON_BUCKET = 11560
const PUFFERFISH_BUCKET = 11561
const TROPICAL_FISH_BUCKET = 11562

# The source's `fish_names` table, minus the axolotl (Voxey has no axolotl), with
# the cod pointing at the id Voxey already had. The order is the source's own.
const BUCKETS = {
	"cod":VillageContent.COD_BUCKET,
	"salmon":SALMON_BUCKET,
	"tropical_fish":TROPICAL_FISH_BUCKET,
	"pufferfish":PUFFERFISH_BUCKET,
}

# Registered by the parent into `VillageContent.DATA`; `stack_max = 1` and the
# `fish_bucket` group are the source's own (fishbuckets.lua:71-72). The colour is
# the species' own body colour from `AquaticMobs.colour`, so a bucket reads as its
# fish.
const DATA = {
	11560:{"name":"Bucket of salmon","color":"c98a72","stack":1,"family":"fish_bucket"},
	11561:{"name":"Bucket of pufferfish","color":"d9b04a","stack":1,"family":"fish_bucket"},
	11562:{"name":"Bucket of tropical fish","color":"d97a3a","stack":1,"family":"fish_bucket"},
}

# The source caps a creature tag at thirty bytes; a bucket name is the same tag.
const NAME_LIMIT = 30

# `_mcl_buckets_fish` for a bucket id, and its inverse. Empty when the item is not
# a fish bucket, so the parent can use it as a plain predicate.
static func fish_for(bucket: int) -> String:
	for kind in BUCKETS:
		if int(BUCKETS[kind]) == bucket: return kind
	return ""

# The bucket a fish kind is carried in, or 0 for a kind Voxey has no bucket for
# (a squid, a glow squid, or anything else).
static func bucket_for(kind: String) -> int:
	return int(BUCKETS.get(kind,0))

static func is_fish_bucket(id: int) -> bool:
	return not fish_for(id).is_empty()

# The name a released fish should carry: the source's `get_meta():get_string("name")`
# (fishbuckets.lua:35), which Voxey stores in the stack's `data.name`.
static func release_name(stack: Dictionary) -> String:
	var data: Dictionary = stack.get("data",{})
	if not data.get("name") is String: return ""
	return NameTags.bounded(str(data.name),NAME_LIMIT)

# The whole placement transaction: consume the held fish bucket, release the fish
# into the pointed cell and fill that cell with water, honouring the Nether rule.
# Returns false — the parent's "not mine" answer — when the held item is not a fish
# bucket; true once the item is recognised, even when the destination refuses it,
# because the source returns the itemstack unchanged rather than falling through
# to another handler.
static func place(game: Node3D, target: Dictionary) -> bool:
	var held: Dictionary = game.inventory.held()
	var kind: String = fish_for(int(held.id))
	if kind.is_empty() or held.count <= 0: return false
	if target.is_empty(): return true
	var world: VoxelWorld = game.world
	# `pointed_thing.above`, through snow's replacement rule so a fish bucket over a
	# snow layer does not bury itself in the layer.
	var at: Vector3i = SnowCover.placement(world,target).pos
	var id: int = world.node_at(at)
	# `not defs or group solid or group opaque` (fishbuckets.lua:26). Voxey's
	# `Nodes.transparent` is the "not opaque" test, and it admits air, water and
	# every plant, exactly the set the source allows.
	if not Nodes.exists(id) or Nodes.solid(id) or not Nodes.transparent(id): return true
	var mob: Creature = game.spawn_creature(kind,Vector3(at)+Vector3(0.5,0.01,0.5))
	if mob == null: return true
	# The source's `props.persistent = true`: a released fish is not distance
	# culled, which the parent's gate reads off this meta.
	mob.set_meta("persistent",true)
	var label: String = release_name(held)
	if not label.is_empty():
		mob.custom_name = label
		NameTags.refresh(mob)
	if world.dimension == "nether":
		# `water = nil` in the Nether, plus `fire_extinguish_flame` at gain 0.25
		# within sixteen blocks. Voxey synthesises no extinguish sample and
		# `sound_at` has no gain parameter, so the closest short hiss it does have
		# stands in for it.
		game.sound_at("splash",Vector3(at),1.0)
	else:
		world.set_node(at,Nodes.WATER)
	# `if not placer or not creative` — a creative player keeps the filled bucket,
	# as Voxey's own water bucket does.
	if game.gamemode != "creative":
		game.inventory.consume_selected()
		game.survival.give(Nodes.BUCKET,1)
	return true

# The fish's own `on_rightclick`: a water bucket picks the fish up and becomes the
# matching fish bucket carrying the fish's name (`cod.lua:77-84`,
# `tropical_fish.lua:145-158`). Voxey's water bucket is `Nodes.BUCKET`'s filled
# neighbour, `Nodes.WATER_BUCKET`; its river-water variant does not exist here.
static func capture(game: Node3D, mob: Creature) -> bool:
	if mob == null or not is_instance_valid(mob) or mob.is_queued_for_deletion() or mob.health <= 0: return false
	var bucket: int = bucket_for(mob.kind)
	if bucket == 0: return false
	var held: Dictionary = game.inventory.held()
	if int(held.id) != Nodes.WATER_BUCKET or held.count <= 0: return false
	if game.gamemode != "creative": game.inventory.consume_selected()
	var label: String = NameTags.bounded(mob.custom_name,NAME_LIMIT)
	game.survival.give(bucket,1,{"name":label} if not label.is_empty() else {})
	Farming.forget(mob)
	mob.queue_free()
	return true
