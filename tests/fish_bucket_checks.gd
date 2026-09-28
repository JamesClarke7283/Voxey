extends RefCounted

# Fish buckets (Mineclonia `mcl_buckets/fishbuckets.lua` and the four fish mobs'
# own `on_rightclick`). Voxey's single cod bucket used to place water and drop a
# **raw cod item**; this suite pins the live-fish behaviour, the salmon /
# pufferfish / tropical-fish ids that did not exist, the Nether rule and the
# capture round trip.

static func held(game: Node3D, id: int, count: int = 1, data: Dictionary = {}) -> void:
	game.inventory.selected = 0
	game.inventory.slots[0] = {"id":id,"count":count,"wear":0}
	if not data.is_empty(): game.inventory.slots[0].data = data.duplicate(true)

# The creature of a kind sitting in the cell the bucket was used against. A
# creature already queued for deletion is ignored, so a later phase never reads a
# previous phase's fish.
static func fish_at(game: Node3D, kind: String, at: Vector3i) -> Creature:
	for mob in game.creatures.get_children():
		if mob.is_queued_for_deletion() or mob.kind != kind: continue
		if mob.position.distance_to(Vector3(at)+Vector3(0.5,0.01,0.5)) < 1.5: return mob
	return null

# Free every fish around the test cell and let the queue drain, so the next phase
# starts from an empty cell.
static func clear_fish(suite: SceneTree, game: Node3D, at: Vector3i) -> void:
	for mob in game.creatures.get_children():
		if mob.kind in AquaticMobs.FISH and mob.position.distance_to(Vector3(at)) < 3.0: mob.queue_free()
	await suite.process_frame

static func clear_cell(world: VoxelWorld, p: Vector3i) -> void:
	world.set_node(p,Nodes.AIR)
	world.set_node(p+Vector3i.DOWN,Nodes.STONE)

static func count_of(game: Node3D, id: int) -> int:
	return game.inventory.count_item(id)

static func run(suite: SceneTree, game: Node3D) -> void:
	var world: VoxelWorld = game.world
	var old_slots: Array = game.inventory.slots.duplicate(true)
	var old_pouches: Array = game.inventory.pouch_slots.duplicate(true)
	var old_selected: int = game.inventory.selected
	var old_mode: String = game.gamemode
	var old_dimension: String = world.dimension
	var old_state: String = game.state
	var old_position: Vector3 = game.player.position
	var old_world_active: bool = world.active
	var touched: Array = []

	# --- the three new ids, and the four-way round trip ----------------------
	suite.check(FishBuckets.SALMON_BUCKET == 11560 and FishBuckets.PUFFERFISH_BUCKET == 11561 and FishBuckets.TROPICAL_FISH_BUCKET == 11562,"the three new fish buckets keep their ids")
	var ids_ok: bool = true
	for entry in [["salmon",FishBuckets.SALMON_BUCKET],["pufferfish",FishBuckets.PUFFERFISH_BUCKET],["tropical_fish",FishBuckets.TROPICAL_FISH_BUCKET],["cod",VillageContent.COD_BUCKET]]:
		var kind: String = entry[0]
		var id: int = entry[1]
		if not Nodes.exists(id) or Nodes.max_stack(id) != 1: ids_ok = false
		if FishBuckets.bucket_for(kind) != id or FishBuckets.fish_for(id) != kind: ids_ok = false
		if not FishBuckets.is_fish_bucket(id): ids_ok = false
	suite.check(ids_ok,"every fish bucket exists, holds one and round-trips through bucket_for/fish_for, cod included")
	# Only the three ids this module registers carry the family; the cod bucket
	# predates it and is reused as-is rather than re-registered.
	var family_ok: bool = true
	for id in [FishBuckets.SALMON_BUCKET,FishBuckets.PUFFERFISH_BUCKET,FishBuckets.TROPICAL_FISH_BUCKET]:
		if VillageContent.DATA.get(id,{}).get("family","") != "fish_bucket": family_ok = false
	suite.check(family_ok,"the three new fish buckets are registered in the fish_bucket family")
	suite.check(FishBuckets.bucket_for("squid") == 0 and FishBuckets.fish_for(Nodes.BUCKET).is_empty() and FishBuckets.fish_for(0).is_empty(),"a kind with no bucket and an unrelated item resolve to no bucket and no fish")
	suite.check(VillageContent.DATA.get(FishBuckets.SALMON_BUCKET,{}).get("name","") == "Bucket of salmon" and Nodes.title(FishBuckets.SALMON_BUCKET) == "Bucket of salmon","a fish bucket is titled for its fish")
	# `is_fish_bucket` must not accept the plain bucket or an unrelated item.
	suite.check(not FishBuckets.is_fish_bucket(Nodes.BUCKET) and not FishBuckets.is_fish_bucket(Nodes.APPLE) and not FishBuckets.is_fish_bucket(VillageContent.RAW_COD),"a plain bucket, an apple and a raw cod are not fish buckets")

	# --- placement -----------------------------------------------------------
	# The source's own `pointed_thing.above`, reached through snow's replacement
	# rule: the target is the stone under an air cell, so the bucket fills that
	# cell.
	var p: Vector3i = Vector3i(8,170,8)
	game.gamemode = "survival"
	game.player.position = Vector3(6,175,6)
	clear_cell(world,p)
	var target: Dictionary = {"pos":p+Vector3i.DOWN,"id":Nodes.STONE,"normal":Vector3i.UP,"distance":2.0,"point":Vector3(p)}

	# A non-fish bucket is refused outright, so the parent can fall through.
	held(game,Nodes.BUCKET,1)
	suite.check(not FishBuckets.place(game,target) and world.node_at(p) == Nodes.AIR and count_of(game,Nodes.BUCKET) == 1,"place refuses a non-fish bucket without touching the world")
	held(game,Nodes.APPLE,1)
	suite.check(not FishBuckets.place(game,target),"place refuses an apple")
	held(game,VillageContent.RAW_COD,1)
	suite.check(not FishBuckets.place(game,target),"place refuses a raw fish item")

	for entry in [["cod",VillageContent.COD_BUCKET],["salmon",FishBuckets.SALMON_BUCKET],["pufferfish",FishBuckets.PUFFERFISH_BUCKET],["tropical_fish",FishBuckets.TROPICAL_FISH_BUCKET]]:
		var kind: String = entry[0]
		var bucket: int = entry[1]
		var label: String = "Bucket fish "+kind
		await clear_fish(suite,game,p)
		clear_cell(world,p)
		held(game,bucket,1,{"name":label})
		suite.check(FishBuckets.place(game,target),"place handles a "+kind+" bucket")
		var mob: Creature = fish_at(game,kind,p)
		if mob != null: touched.append(mob)
		suite.check(mob != null,"using a "+kind+" bucket releases a live "+kind+" into the world")
		suite.check(world.node_at(p) == Nodes.WATER,"using a "+kind+" bucket fills the cell with water")
		suite.check(game.inventory.held().id == Nodes.BUCKET and game.inventory.held().count == 1,"using a "+kind+" bucket returns an empty bucket")
		suite.check(mob != null and mob.custom_name == label and mob.get_node_or_null("NameTag") != null,"a "+kind+" bucket's stored name becomes the fish's visible nametag")
		suite.check(mob != null and bool(mob.get_meta("persistent",false)),"a released "+kind+" carries the source's persistent flag")
		suite.check(count_of(game,VillageContent.RAW_COD) == 0 and count_of(game,VillageContent.RAW_SALMON) == 0 and count_of(game,VillageContent.PUFFERFISH) == 0 and count_of(game,VillageContent.TROPICAL_FISH) == 0,"a "+kind+" bucket no longer produces a dead raw fish")

	# An unnamed bucket releases an unnamed fish, which is the source's own
	# `bucket_name ~= ""` test.
	await clear_fish(suite,game,p)
	clear_cell(world,p)
	held(game,VillageContent.COD_BUCKET,1)
	FishBuckets.place(game,target)
	var plain: Creature = fish_at(game,"cod",p)
	if plain != null: touched.append(plain)
	suite.check(plain != null and plain.custom_name.is_empty() and plain.get_node_or_null("NameTag") == null,"a bucket with no stored name releases an unnamed fish")

	# A solid or opaque destination is refused, and no water is written.
	clear_cell(world,p)
	world.set_node(p,Nodes.STONE)
	held(game,FishBuckets.SALMON_BUCKET,1)
	suite.check(FishBuckets.place(game,target) and world.node_at(p) == Nodes.STONE and game.inventory.held().id == FishBuckets.SALMON_BUCKET,"a solid destination spawns nothing and keeps the bucket")
	clear_cell(world,p)

	# A snow layer is replaceable, so the bucket fills the layer's own cell rather
	# than the one above it, which is snow's own placement rule and the behaviour
	# `snow_cover_checks.gd` already pins for the cod bucket.
	await clear_fish(suite,game,p)
	world.set_node(p,SnowCover.BASE)
	held(game,FishBuckets.PUFFERFISH_BUCKET,1)
	suite.check(FishBuckets.place(game,target) and world.node_at(p) == Nodes.WATER and fish_at(game,"pufferfish",p) != null,"a fish bucket used on a snow layer replaces the layer with water and releases the fish there")
	var snowy: Creature = fish_at(game,"pufferfish",p)
	if snowy != null: touched.append(snowy)
	clear_cell(world,p)

	# --- the Nether rule ----------------------------------------------------
	# `water = nil` in the Nether: the fish is still released and the bucket still
	# emptied, but no water node is written.
	world.dimension = "nether"
	for entry in [["cod",VillageContent.COD_BUCKET],["salmon",FishBuckets.SALMON_BUCKET],["pufferfish",FishBuckets.PUFFERFISH_BUCKET],["tropical_fish",FishBuckets.TROPICAL_FISH_BUCKET]]:
		var kind: String = entry[0]
		await clear_fish(suite,game,p)
		clear_cell(world,p)
		held(game,entry[1],1)
		suite.check(FishBuckets.place(game,target) and world.node_at(p) == Nodes.AIR and fish_at(game,kind,p) != null,"in the Nether a "+kind+" bucket places no water but still releases the fish")
		var nether_mob: Creature = fish_at(game,kind,p)
		if nether_mob != null: touched.append(nether_mob)
	world.dimension = old_dimension
	suite.check(world.dimension == old_dimension,"the dimension is restored after the Nether rule is checked")

	# --- the despawn gate the persistent flag relies on ---------------------
	# The released fish must never be distance-culled. Voxey's gate keeps a mob
	# only when `can_despawn` is false or the `persistent` meta is set.
	game.state = "playing"
	var far: Vector3 = game.player.position+Vector3(200,0,0)
	var kept: Creature = game.spawn_creature("cod",far)
	var dropped: Creature = game.spawn_creature("cod",far)
	if kept != null: kept.set_meta("persistent",true); touched.append(kept)
	if dropped != null: touched.append(dropped)
	for mob in [kept,dropped]:
		if mob != null: mob._physics_process(0.1)
	suite.check(kept != null and not kept.is_queued_for_deletion(),"a released fish is kept when it is far from the player, as the source's persistent flag requires")
	suite.check(dropped != null and dropped.is_queued_for_deletion(),"an ordinary cod of the same kind is still culled when far away, so the kept fish proves the flag")
	game.state = old_state

	# --- capture -------------------------------------------------------------
	# A water bucket picks a fish up and becomes the matching fish bucket
	# carrying the fish's name, as the fish's own `on_rightclick` does.
	await clear_fish(suite,game,p)
	clear_cell(world,p)
	var catch_name: String = "Catch of the day"
	held(game,VillageContent.COD_BUCKET,1,{"name":catch_name})
	FishBuckets.place(game,target)
	var prey: Creature = fish_at(game,"cod",p)
	suite.check(prey != null,"a cod is released ready to be caught again")
	held(game,Nodes.WATER_BUCKET,1)
	suite.check(FishBuckets.capture(game,prey),"a water bucket captures a released fish")
	suite.check(game.inventory.held().id == VillageContent.COD_BUCKET and game.inventory.held().count == 1,"capturing a cod hands back the cod bucket")
	suite.check(FishBuckets.release_name(game.inventory.held()) == catch_name,"the captured fish's name travels in the bucket")
	suite.check(prey != null and prey.is_queued_for_deletion(),"the captured fish is removed from the world")

	# A plain bucket, a missing creature and an unnamed fish all behave.
	await clear_fish(suite,game,p)
	clear_cell(world,p)
	var refused: Creature = game.spawn_creature("cod",Vector3(p)+Vector3(0.5,0.01,0.5))
	if refused != null: touched.append(refused)
	held(game,Nodes.BUCKET,1)
	suite.check(not FishBuckets.capture(game,refused) and game.inventory.held().id == Nodes.BUCKET,"an empty bucket does not capture a fish")
	held(game,Nodes.WATER_BUCKET,1)
	suite.check(not FishBuckets.capture(game,null),"capture refuses a missing creature")
	# An unnamed fish yields a bucket with no stored name, which is the source's
	# `bucket_name ~= ""` test read in the other direction.
	suite.check(FishBuckets.capture(game,refused),"the water bucket captures the unnamed cod")
	suite.check(game.inventory.held().id == VillageContent.COD_BUCKET and FishBuckets.release_name(game.inventory.held()).is_empty(),"an unnamed fish comes back in an unnamed bucket")
	# The whole round trip: bucket to fish to bucket keeps the name.
	clear_cell(world,p)
	held(game,FishBuckets.TROPICAL_FISH_BUCKET,1,{"name":"Sunny"})
	FishBuckets.place(game,{"pos":p+Vector3i.DOWN,"id":Nodes.STONE,"normal":Vector3i.UP,"distance":2.0,"point":Vector3(p)})
	var tropical: Creature = fish_at(game,"tropical_fish",p)
	suite.check(tropical != null and tropical.custom_name == "Sunny","a named tropical fish is released from its bucket")
	held(game,Nodes.WATER_BUCKET,1)
	suite.check(FishBuckets.capture(game,tropical),"the released tropical fish is caught again")
	suite.check(game.inventory.held().id == FishBuckets.TROPICAL_FISH_BUCKET and FishBuckets.release_name(game.inventory.held()) == "Sunny","the tropical fish bucket comes back with the same name")

	# --- cleanup -------------------------------------------------------------
	for mob in touched:
		if is_instance_valid(mob) and not mob.is_queued_for_deletion(): mob.queue_free()
	# The queue drains on the next frame, so the leftover check must wait for it.
	await suite.process_frame
	clear_cell(world,p)
	world.set_node(p,Nodes.AIR)
	world.set_node(p+Vector3i.DOWN,Nodes.AIR)
	var leftovers: bool = false
	for mob in game.creatures.get_children():
		if mob.kind in AquaticMobs.FISH and mob.position.distance_to(Vector3(p)) < 3.0: leftovers = true
	suite.check(not leftovers,"every released fish is cleaned up")
	game.inventory.selected = old_selected
	game.inventory.restore(old_slots,old_pouches)
	game.gamemode = old_mode
	game.player.position = old_position
	world.dimension = old_dimension
	world.active = old_world_active
	game.state = old_state
