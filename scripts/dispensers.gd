class_name Dispensers
extends RefCounted

# Mineclonia ITEMS/REDSTONE/mcl_dispensers/init.lua, GPL-3.0-or-later. Original
# GDScript using the source as a behaviour reference.
#
# The source's `activate_dispenser` has an item-specific branch per dispensed
# item, reached through each item's own `_on_dispense`. Voxey already handled
# arrows, TNT, boats, eggs, snowballs, shears on a snow golem and bottles on a hive
# (that last one in `Beehives.dispense`); this module adds the rest of the item
# actions the checkout actually defines:
#
# - **Bone meal** grows whatever it is aimed at, using the pointed-thing rule the
#   source builds: when the target cell is air the bone meal is applied to the
#   block *below* it, otherwise to the target cell itself.
# - **Empty bucket** collects a liquid source in front of the dispenser, and a
#   **filled bucket** pours into a replaceable cell.
# - **Flint and steel** lights a fire in the empty cell in front.
# - **Fire charge** is the source's `mcl_charges` projectile, which flies and lights
#   what it lands on.
# - **Splash and lingering potions** are thrown as projectiles, which is the
#   source's `mcl_potions/splash.lua` `_on_dispense`.
# - **XP bottle** throws an experience bottle.
#
# The outcome is `{applied, replacement, consume}`: `replacement` is the item the
# dispenser should end up holding (a bucket, or a spent flint and steel), and
# `consume` says whether the caller should take one from the stack.

static func handles(id: int) -> bool:
	return id in [Nodes.BONE_MEAL,Nodes.BUCKET,Nodes.WATER_BUCKET,Nodes.LAVA_BUCKET,
		Nodes.FLINT_AND_STEEL,PiglinBarter.FIRE_CHARGE,VillageContent.XP_BOTTLE] or is_potion(id)

static func is_potion(id: int) -> bool:
	# The throwable forms live in `PotionCatalog.ITEMS[id].form`; `VillageContent.DATA`
	# carries no splash/lingering keys, so reading them would make this branch dead.
	return str(PotionCatalog.ITEMS.get(id,{}).get("form","")) in ["splash","lingering"]

# The source's pointed thing: aimed at air means the block underneath, otherwise
# the target cell itself.
static func pointed(world: VoxelWorld, at: Vector3i) -> Vector3i:
	return at+Vector3i.DOWN if world.node_at(at) == Nodes.AIR else at

# `dispense` is called with the dispenser's own cell, the direction its face
# points, and the slot being dispensed. It performs the action and reports what
# the caller must do to the stack.
static func dispense(game: Node3D, p: Vector3i, d: Vector3i, slot: Dictionary) -> Dictionary:
	var world: VoxelWorld = game.world
	var at: Vector3i = p+d
	var id: int = slot.id
	var origin: Vector3 = Vector3(p)+Vector3.ONE*0.5+Vector3(d)*0.51
	# Bone meal grows whatever it is aimed at. The pointed block's own growth rules
	# are the ones the player path already owns.
	if id == Nodes.BONE_MEAL:
		var target: Vector3i = pointed(world,at)
		var here: int = world.node_at(target)
		var grew: bool = false
		if here == Nodes.GRASS and world.node_at(target+Vector3i.UP) == Nodes.AIR:
			grew = FoodFeatures.bone_meal_grass(game,target)
		elif CropFarming.is_crop(here):
			grew = bool(CropFarming.bone_meal(world,target).get("grew",false))
		elif FoodFeatures.flower(here):
			grew = FoodFeatures.bone_meal(game,target)
		elif here in [Nodes.RED_MUSHROOM,Nodes.BROWN_MUSHROOM]:
			grew = HugeMushrooms.grow(world,target,here,RandomNumberGenerator.new())
		elif Bamboo.is_bamboo(here):
			var rng := RandomNumberGenerator.new()
			rng.seed = world.generator.hash_at(target.x,target.y,target.z)
			grew = Bamboo.grow(world,world.generator,target,func(q: Vector3i) -> int: return Pasture.light(world,q,14),rng)
		elif here == Nodes.SUGAR_CANE:
			var top: Vector3i = target
			while world.node_at(top+Vector3i.UP) == Nodes.SUGAR_CANE: top += Vector3i.UP
			if world.node_at(top+Vector3i.UP) == Nodes.AIR and world.can_plant_cane(target): grew = world.set_node(top+Vector3i.UP,Nodes.SUGAR_CANE)
		if grew: game.puff(Vector3(target)+Vector3i.UP*0.5+Vector3.ONE*0.5,Color("b8e07a"),8)
		return {"applied":grew,"replacement":0,"consume":grew}
	# Buckets: an empty one collects a source, a filled one pours.
	if id == Nodes.BUCKET:
		var liquid: int = world.node_at(at)
		if liquid in [Nodes.WATER,Nodes.LAVA] and world.set_node(at,Nodes.AIR):
			game.sound("dig")
			return {"applied":true,"replacement":Nodes.LAVA_BUCKET if liquid == Nodes.LAVA else Nodes.WATER_BUCKET,"consume":true}
		return {"applied":false,"replacement":0,"consume":false}
	if id in [Nodes.WATER_BUCKET,Nodes.LAVA_BUCKET]:
		if id == Nodes.WATER_BUCKET and game.dimension == "nether": return {"applied":false,"replacement":0,"consume":false}
		if not SnowCover.replaceable(world.node_at(at)): return {"applied":false,"replacement":0,"consume":false}
		if world.set_node(at,Nodes.WATER if id == Nodes.WATER_BUCKET else Nodes.LAVA):
			game.sound("place")
			return {"applied":true,"replacement":Nodes.BUCKET,"consume":true}
		return {"applied":false,"replacement":0,"consume":false}
	# Flint and steel lights a fire in the empty cell in front.
	if id == Nodes.FLINT_AND_STEEL:
		if world.node_at(at) != Nodes.AIR: return {"applied":false,"replacement":0,"consume":false}
		if Fire.ignite(world,at):
			game.sound("place")
			# The source consumes the charge but keeps the tool, so the replacement is
			# the same item; the caller must not subtract a count for a tool.
			return {"applied":true,"replacement":id,"consume":false}
		return {"applied":false,"replacement":0,"consume":false}
	# A fire charge flies and lights what it lands on.
	if id == PiglinBarter.FIRE_CHARGE:
		var shot := MagicProjectile.new()
		shot.game = game; shot.kind = "fire_charge"; shot.position = origin; shot.velocity = Vector3(d)*18.0
		game.entities.add_child(shot)
		game.sound_at("arrow",origin)
		return {"applied":true,"replacement":0,"consume":true}
	# A splash or lingering potion flies at the dispenser's facing.
	if is_potion(id):
		var potion := PotionProjectile.new()
		potion.game = game; potion.position = origin; potion.velocity = Vector3(d)*22.0
		potion.item_id = id
		game.entities.add_child(potion)
		game.sound_at("arrow",origin)
		return {"applied":true,"replacement":0,"consume":true}
	# An experience bottle flies and grants its experience where it lands.
	if id == VillageContent.XP_BOTTLE:
		var bottle := ThrownItem.new()
		bottle.game = game; bottle.item_id = id; bottle.position = origin
		bottle.velocity = Vector3(d)*14.0+Vector3.UP*2.0
		game.entities.add_child(bottle)
		return {"applied":true,"replacement":0,"consume":true}
	# A splash or lingering potion flies at the dispenser's facing.
	return {"applied":false,"replacement":0,"consume":false}
