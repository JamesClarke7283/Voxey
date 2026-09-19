extends RefCounted

# Focused regression for shields. The reference blocks an attack when the dot
# product of the attack direction against the player's look is at or below
# `-cos(180/2)`, which is the frontal hemisphere, and only for a listed set of
# attack types. Wear costs the ceiling of the damage, but only for hits of three
# or more. The shield is held up rather than raised for a fixed window.

static func face(game: Node3D, direction: Vector3) -> void:
	# Point the player, and therefore the look direction, along `direction`.
	game.player.camera.look_at(game.player.camera.global_position+direction)

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	game.player.camera.set_process(false)
	game.gamemode = "survival"
	var player = game.player
	var survival = game.survival

	# --- constants ---------------------------------------------------------
	t.check(is_equal_approx(Shields.BLOCK_ARC,180.0),"the source's 180 degree arc is used")
	t.check(is_equal_approx(Shields.BLOCK_COSINE,0.0),"the source's -cos(180/2) threshold evaluates to zero")
	t.check(is_equal_approx(Shields.WEAR_THRESHOLD,3.0),"wear is only added for hits of three or more")
	t.check(Shields.USES == 336,"the source's 336 uses are used")
	t.check(Shields.is_shield(VillageContent.SHIELD) and not Shields.is_shield(Nodes.IRON),"the shield item is recognised and other items are not")
	for kind in ["mob","player","arrow","generic","explosion","dragon_breath","trident"]:
		t.check(Shields.BLOCKABLE.has(kind),"the source's blockable type %s is listed"%kind)
	for kind in ["fire","void","starve","drowning","fall"]:
		t.check(not Shields.BLOCKABLE.has(kind),"%s is not blockable, as the source's table says"%kind)

	# --- the frontal arc ---------------------------------------------------
	player.armor_slots[0] = {"id":0,"count":0,"wear":0}
	game.inventory.restore([]); game.inventory.add_item(VillageContent.SHIELD,1); game.inventory.selected = 0
	survival.shield_raised = true; survival.shield_disabled = 0.0
	player.position = Vector3(8,1800,8)
	# Face north, then attack from straight ahead: that is dead centre.
	face(game,Vector3(0,0,-1))
	var ahead: Vector3 = player.position+Vector3(0,0,-4)
	t.check(Shields.angle(player,ahead) <= Shields.BLOCK_COSINE,"an attack from straight ahead is inside the blocking arc")
	t.check(Shields.can_block(player,ahead,"mob"),"a mob attack from the front is blocked")
	# From directly behind it is refused.
	var behind: Vector3 = player.position+Vector3(0,0,4)
	t.check(Shields.angle(player,behind) > Shields.BLOCK_COSINE,"an attack from behind is outside the blocking arc")
	t.check(not Shields.can_block(player,behind,"mob"),"a mob attack from behind is not blocked")
	# Exactly at the frontal 90 degree edge the source's comparison allows it.
	var side: Vector3 = player.position+Vector3(4,0,0)
	var side_angle: float = Shields.angle(player,side)
	t.check(side_angle <= Shields.BLOCK_COSINE,"an attack exactly at the arc's edge is still blocked, since the source tests <= 0")
	t.check(Shields.can_block(player,side,"mob"),"a side attack at the boundary is blocked")

	# --- blockable types ---------------------------------------------------
	t.check(not Shields.can_block(player,ahead,"fire"),"a fire hit passes through a shield")
	t.check(not Shields.can_block(player,ahead,"void"),"void damage passes through a shield")
	t.check(Shields.can_block(player,ahead,"arrow"),"an arrow from the front is blocked")
	t.check(Shields.can_block(player,ahead,"explosion"),"an explosion from the front is blocked")

	# --- raised state ------------------------------------------------------
	# A shield that is not raised blocks nothing, whatever the angle.
	survival.shield_raised = false
	t.check(not Shields.can_block(player,ahead,"mob"),"a lowered shield blocks nothing")
	survival.shield_raised = true
	# A disabled shield blocks nothing until it recovers.
	survival.shield_disabled = 5.0
	t.check(not Shields.can_block(player,ahead,"mob"),"a disabled shield blocks nothing")
	survival.shield_disabled = 0.0
	t.check(Shields.can_block(player,ahead,"mob"),"the shield blocks again once it recovers")
	# Without the shield in hand it does not block.
	game.inventory.restore([]); game.inventory.add_item(Nodes.IRON,1); game.inventory.selected = 0
	survival.shield_raised = true
	t.check(not Shields.can_block(player,ahead,"mob"),"holding something other than a shield blocks nothing")
	game.inventory.restore([]); game.inventory.add_item(VillageContent.SHIELD,1); game.inventory.selected = 0

	# --- wear --------------------------------------------------------------
	# Below three damage costs nothing; at or above it costs the ceiling.
	player.armor_slots[0] = {"id":0,"count":0,"wear":0}
	game.inventory.held().wear = 0
	Shields.add_wear(player,2.0)
	t.check(int(game.inventory.held().wear) == 0,"a hit below the three-damage threshold costs no durability")
	Shields.add_wear(player,4.5)
	t.check(int(game.inventory.held().wear) == 5,"a hit costs durability equal to the damage's ceiling")
	Shields.add_wear(player,3.0)
	t.check(int(game.inventory.held().wear) == 8,"further hits accumulate wear")
	# A shield worn out breaks and is removed.
	game.inventory.held().wear = Shields.USES-1
	Shields.add_wear(player,3.0)
	t.check(int(game.inventory.held().id) == 0,"a shield that reaches its use count breaks")

	# --- the live damage path ----------------------------------------------
	# A front attack against a raised shield leaves health untouched.
	game.inventory.restore([]); game.inventory.add_item(VillageContent.SHIELD,1); game.inventory.selected = 0
	game.inventory.held().wear = 0
	survival.shield_raised = true; survival.shield_disabled = 0.0
	player.health = 20; player.damage_cooldown = 0
	face(game,Vector3(0,0,-1))
	player.hurt(6.0,false,player.position+Vector3(0,0,-4),"mob")
	t.check(is_equal_approx(player.health,20.0),"a blocked frontal mob attack leaves health untouched")
	t.check(int(game.inventory.held().wear) > 0,"blocking a strong hit costs shield durability")
	# The same attack from behind lands.
	player.health = 20; player.damage_cooldown = 0
	game.inventory.held().wear = 0
	player.hurt(6.0,false,player.position+Vector3(0,0,4),"mob")
	t.check(player.health < 20.0,"an attack from behind is not blocked and deals damage")
	# So does an unblockable type from the front.
	player.health = 20; player.damage_cooldown = 0
	player.hurt(6.0,false,player.position+Vector3(0,0,-4),"fire")
	t.check(player.health < 20.0,"an unblockable damage type passes through a raised shield")
	# A lowered shield does not block the frontal hit either.
	player.health = 20; player.damage_cooldown = 0
	survival.shield_raised = false
	player.hurt(6.0,false,player.position+Vector3(0,0,-4),"mob")
	t.check(player.health < 20.0,"a lowered shield does not block")
	player.health = 20; player.damage_cooldown = 0
	survival.shield_raised = true
	game.inventory.held().wear = 0
