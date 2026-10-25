extends RefCounted

static func advance(shot: Arrow, steps: int = 100) -> void:
	for i in steps:
		if shot.is_queued_for_deletion() or shot.deflected or shot.stuck: return
		shot._physics_process(0.01)

static func run(t: SceneTree, game: Node3D) -> void:
	var old_slots: Array = game.inventory.slots.duplicate(true); var old_selected: int = game.inventory.selected
	var old_offhand: Dictionary = game.player.offhand_slot.duplicate(true); var old_armor: Array = game.player.armor_slots.duplicate(true)
	var old_position: Vector3 = game.player.position; var old_look: Vector3 = game.player.camera.rotation
	var old_mode: String = game.gamemode; var old_health: float = game.player.health; var old_effects: Dictionary = game.survival.effect_snapshot()
	game.pause(); game.set_process(false); game.world.set_process(false); game.player.set_process(false); game.player.set_physics_process(false)
	game.gamemode = "survival"; game.inventory.selected = 0
	for child in game.creatures.get_children(): child.free()
	var at := Vector3(8.5,900,8.5)
	for x in range(-4,5):
		for z in range(-5,5):
			for y in range(-1,4): game.world.set_node(Vector3i(at)+Vector3i(x,y,z),Nodes.STONE if y == -1 else Nodes.AIR)
	game.player.position = at; game.player.camera.rotation = Vector3.ZERO
	game.player.health = 20; game.player.damage_cooldown = 0; PotionEffects.clear(game.player)
	for i in 4: game.player.armor_slots[i] = Bookshelves.empty()
	game.inventory.restore([]); game.player.offhand_slot = {"id":VillageContent.SHIELD,"count":1,"wear":0,"data":{"shield_color":6,"layers":[{"pattern":"border","color":0}],"enchantments":{"Unbreaking":2}}}
	game.survival.shield_raised = true; game.survival.shield_disabled = 0
	t.check(Shields.accepts_dot(0.3,"mob") and not Shields.accepts_dot(0.5,"mob"),"the native shield matches both sides of the source's measured radians threshold")
	var skeleton: Creature = game.spawn_creature("skeleton",at+Vector3(0,0,-1.7)); skeleton.set_physics_process(false); skeleton.health = 1
	var arrow: Arrow = game.spawn_arrow(at+Vector3(0,1.08,-1.7),Vector3(0,0,40)); arrow.set_physics_process(false)
	arrow.shooter_id = skeleton.get_instance_id(); arrow.shooter_kind = "skeleton"; arrow.item_id = VillageContent.POISON_ARROW; arrow.flame = true
	game.state = "playing"; advance(arrow)
	t.check(arrow.deflected and not arrow.is_queued_for_deletion() and arrow.velocity.z < 0 and arrow.blocked_by == game.player_id,"an incoming arrow physically reverses and stays alive when blocked")
	t.check(game.player.health == 20 and PotionEffects.level(game.player,"poison") == 0 and PotionEffects.level(game.player,"burning") == 0,"a deflected tipped flaming arrow applies neither damage nor its effects")
	var once: int = Durability.normalized(game.player.offhand_slot)
	for i in 70:
		if arrow.is_queued_for_deletion(): break
		arrow._physics_process(0.01)
	t.check(Durability.normalized(game.player.offhand_slot) == once,"leaving the shield cannot repeatedly charge wear for the same contact")
	t.check(skeleton.health <= 0 and arrow.shooter_kind == "skeleton","the deflected arrow can hit its original shooter while preserving provenance")
	arrow.free(); skeleton.free()
	game.player.damage_cooldown = 0; game.player.health = 20
	arrow = game.spawn_arrow(at+Vector3(0,1.08,-2),Vector3(0,0,35)); arrow.set_physics_process(false); arrow.piercing = 1; arrow.item_id = VillageContent.POISON_ARROW
	advance(arrow)
	t.check(not arrow.deflected and arrow.is_queued_for_deletion() and PotionEffects.level(game.player,"poison") > 0,"Piercing skips physical deflection and runs the source's tipped-effect path")
	arrow.free(); PotionEffects.clear(game.player)
	game.player.health = 20; game.player.damage_cooldown = 0; game.survival.shield_raised = false
	arrow = game.spawn_arrow(at+Vector3(0,1.08,-2),Vector3(0,0,35)); arrow.set_physics_process(false)
	advance(arrow)
	t.check(game.player.health < 20 and arrow.attached,"a lowered shield lets the arrow damage the player and remain attached")
	arrow.free(); game.survival.shield_raised = true; game.player.health = 20; game.player.damage_cooldown = 0
	arrow = game.spawn_arrow(at+Vector3(0,1.08,-2),Vector3(0,0,35),VillageContent.TRIDENT); arrow.set_physics_process(false)
	advance(arrow)
	t.check(arrow.deflected and not arrow.is_queued_for_deletion() and arrow.velocity.z < 0 and game.player.health == 20,"an incoming trident bounces instead of disappearing against a shield")
	arrow.free()
	var cow: Creature = game.spawn_creature("cow",at+Vector3(0,0,-2)); cow.set_physics_process(false); cow.health = 20
	var spear := TridentProjectile.new(); spear.game = game; spear.stack = {"id":VillageContent.TRIDENT,"count":1,"wear":0}; spear.consumed = false
	spear.position = at+Vector3(0,0.65,-0.7); spear.velocity = Vector3(0,0,-25); game.entities.add_child(spear); spear.set_physics_process(false)
	for i in 25:
		if spear.velocity.z > 0 or spear.is_queued_for_deletion(): break
		spear._physics_process(0.01)
	t.check(spear.velocity.z > 0 and not spear.returning and not spear.is_queued_for_deletion() and cow.health == 12,"a thrown trident bounces off a mob before later returning or landing")
	spear._physics_process(0.01)
	t.check(cow.health == 12,"the same trident contact cannot damage its target twice")
	spear.free(); cow.free()
	game.player.offhand_slot = Bookshelves.empty(); game.survival.shield_raised = false; game.player.target = {}
	for power in [0,1,5]:
		game.inventory.restore([]); game.inventory.selected = 0
		game.inventory.slots[0] = {"id":Nodes.BOW,"count":1,"wear":0,"data":{"enchantments":{"Power":power}}}
		game.inventory.add_item(Nodes.ARROW_ITEM,1)
		game.player.use()
		BowUse.release(game.player,int(game.player.bow_draw.start)+BowUse.FULL_US)
		var shot: Arrow = game.entities.get_children().back()
		shot.set_physics_process(false)
		t.check(is_equal_approx(shot.damage,2.0+(power/2.0+0.5 if power > 0 else 0.0)),"the actual bow uses the source Power bonus at level %d" % power)
		shot.free()
	game.pause(); game.inventory.slots = old_slots; game.inventory.selected = old_selected; game.player.offhand_slot = old_offhand; game.player.armor_slots = old_armor
	game.player.position = old_position; game.player.camera.rotation = old_look; game.player.health = old_health; game.gamemode = old_mode; game.survival.restore_effects(old_effects)
