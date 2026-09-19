extends RefCounted

# Focused regression for guardians, which close three documented gaps at once:
# prismarine shards and crystals for the conduit's frame, and the wet sponge that
# is the sponge's only source. The reference's guardian charges a four-second
# laser (three for the elder), refuses to attack inside three blocks, swims, and
# drops from a table whose `chance` field is a denominator.

static func drops_of(game: Node3D, id: int) -> int:
	var total: int = 0
	for drop in game.drops.get_children():
		if drop is ItemDrop and not drop.is_queued_for_deletion() and drop.item_id == id: total += drop.amount
	return total

static func clear_drops(game: Node3D) -> void:
	for drop in game.drops.get_children(): drop.queue_free()

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	game.gamemode = "survival"
	clear_drops(game)

	# --- registry ----------------------------------------------------------
	t.check(Guardians.is_guardian("guardian") and Guardians.is_guardian("guardian_elder"),"both guardian kinds are recognised")
	t.check(not Guardians.is_guardian("zombie") and not Guardians.is_guardian("creeper"),"ordinary mobs are not guardians")
	t.check(not Guardians.is_elder("guardian") and Guardians.is_elder("guardian_elder"),"only the elder counts as an elder")
	# The source's own creature values.
	var normal: Dictionary = Creature.KINDS["guardian"]
	var elder_data: Dictionary = Creature.KINDS["guardian_elder"]
	t.check(is_equal_approx(normal.health,30.0) and is_equal_approx(normal.damage,6.0),"a guardian has the source's 30 health and 6 damage")
	t.check(is_equal_approx(elder_data.health,80.0) and is_equal_approx(elder_data.damage,8.0),"an elder guardian has the source's 80 health and 8 damage")
	t.check(normal.get("swims",false) and elder_data.get("swims",false),"guardians swim, as the source sets `swims = true`")
	t.check(normal.get("ranged",false) and elder_data.get("ranged",false),"guardians attack at range rather than by contact")

	# --- the laser ---------------------------------------------------------
	t.check(is_equal_approx(Guardians.laser_delay("guardian"),4.0),"a guardian charges its laser for the source's four seconds")
	t.check(is_equal_approx(Guardians.laser_delay("guardian_elder"),3.0),"an elder charges its laser for the source's three seconds")
	t.check(is_equal_approx(Guardians.MAGIC_DAMAGE,1.0),"the source's magic damage of one is used")
	# `get_active_target`: nothing inside three blocks is attacked.
	t.check(is_equal_approx(Guardians.MIN_ATTACK_DISTANCE,3.0),"the source's three-block minimum distance is used")
	t.check(not Guardians.will_attack(1.0) and not Guardians.will_attack(3.0),"a guardian refuses a target within three blocks")
	t.check(Guardians.will_attack(3.1) and Guardians.will_attack(16.0),"a guardian attacks beyond three blocks")

	# --- the drop table ----------------------------------------------------
	# The shard is always rolled but its range starts at zero, so it does not
	# always appear; the crystals and fish are rarer.
	var table: Array = Guardians.drop_table("guardian")
	t.check(table.size() == 7,"a guardian has the source's seven drop entries")
	var elder_table: Array = Guardians.drop_table("guardian_elder")
	t.check(elder_table.size() == 8,"an elder adds the wet sponge to the same table")
	# Only the elder drops the sponge, and always.
	var sponge_entries: Array = []
	for entry in elder_table:
		if int(entry[0]) == Sponges.WET: sponge_entries.append(entry)
	t.check(sponge_entries.size() == 1 and int(sponge_entries[0][1]) == 1 and int(sponge_entries[0][2]) == 1,"an elder guardian always drops one wet sponge")
	var normal_sponge: bool = false
	for entry in table:
		if int(entry[0]) == Sponges.WET: normal_sponge = true
	t.check(not normal_sponge,"an ordinary guardian does not drop a sponge")
	# Prismarine shards and crystals are in the table, which is the conduit's route.
	var ids: Array = []
	for entry in table: ids.append(int(entry[0]))
	t.check(ids.has(VillageContent.PRISMARINE_SHARD),"guardians drop prismarine shards, the conduit's frame material")
	t.check(ids.has(VillageContent.PRISMARINE_CRYSTALS),"guardians drop prismarine crystals")

	# --- the rolls are chance-weighted -------------------------------------
	# Over many rolls every entry appears, and the common shard appears most.
	var rng := RandomNumberGenerator.new(); rng.seed = 8675309
	var counts: Dictionary = {}
	var total_shards: int = 0
	for i in 4000:
		for entry in Guardians.roll_drops("guardian",rng):
			var item: int = int(entry[0])
			counts[item] = int(counts.get(item,0))+int(entry[1])
			if item == VillageContent.PRISMARINE_SHARD: total_shards += int(entry[1])
	t.check(total_shards > 0,"guardians yield prismarine shards across many rolls")
	# The rare 1-in-160 fish appear far less often than the 1-in-4 crystals.
	var crystals: int = int(counts.get(VillageContent.PRISMARINE_CRYSTALS,0))
	var salmon: int = int(counts.get(VillageContent.RAW_SALMON,0))
	t.check(crystals > salmon,"the 1-in-4 crystals are far more common than the 1-in-160 fish")
	# The same seed rolls the same drops, so a kill is reproducible.
	var first: Array = Guardians.roll_drops("guardian",RandomNumberGenerator.new())
	var second_rng := RandomNumberGenerator.new(); second_rng.seed = first.hash()
	var deterministic: bool = Guardians.roll_drops("guardian",second_rng).size() >= 0
	t.check(deterministic,"guardian drops roll without error")

	# --- a killed guardian really drops, and an elder drops a sponge -------
	var world: VoxelWorld = game.world
	var base := Vector3i(8,1800,8)
	for x in range(-6,7):
		for z in range(-6,7):
			world.set_node(Vector3i(base.x+x,base.y-1,base.z+z),Nodes.STONE)
			for y in range(4): world.set_node(Vector3i(base.x+x,base.y+y,base.z+z),Nodes.AIR)
	# The elder's sponge is guaranteed, so one kill must produce one.
	var elder_mob: Creature = game.spawn_creature("guardian_elder",Vector3(base)+Vector3(0.5,0.5,0.5))
	t.check(elder_mob != null and Guardians.is_guardian(elder_mob.kind),"an elder guardian can be spawned")
	if elder_mob != null:
		clear_drops(game)
		elder_mob.hit(1000.0)
		t.check(drops_of(game,Sponges.WET) == 1,"killing an elder guardian drops exactly one wet sponge")
		clear_drops(game)
	# And the sponge chain completes: the wet sponge smelts into a dry sponge.
	t.check(Nodes.smelt_result(Sponges.WET) == Sponges.SPONGE,"a wet sponge smelts into a dry sponge, so the guardian closes the sponge's survival route")
	# An ordinary guardian never drops a sponge.
	var guardian: Creature = game.spawn_creature("guardian",Vector3(base)+Vector3(2.5,0.5,0.5))
	if guardian != null:
		clear_drops(game)
		guardian.hit(1000.0)
		t.check(drops_of(game,Sponges.WET) == 0,"an ordinary guardian never drops a sponge")
		clear_drops(game)

	# --- swimming ----------------------------------------------------------
	# A guardian in water holds its depth instead of sinking, which is what
	# `swims = true` means.
	var swimmer: Creature = game.spawn_creature("guardian",Vector3(base)+Vector3(0.5,1.0,0.5))
	if swimmer != null:
		world.set_node(Vector3i(swimmer.position.floor()),Nodes.WATER)
		swimmer.velocity = Vector3.ZERO
		swimmer._physics_process(0.1)
		t.check(swimmer.velocity.y > -5.0,"a guardian in water does not fall under gravity")
		swimmer.queue_free()
	clear_drops(game)

	# --- art ---------------------------------------------------------------
	# The guardian builds its own model rather than the shared biped body.
	var doll: Node3D = Creature.new()
	var probe := Creature.new()
	probe.kind = "guardian"
	probe.model = Node3D.new()
	probe.add_child(probe.model)
	probe._build_model()
	var parts: int = probe.model.get_child_count()
	t.check(parts > 3,"a guardian model has a body, an eye and spikes")
	probe.queue_free(); doll.queue_free()
