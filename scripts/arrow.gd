class_name Arrow
extends Node3D

var game: Node3D
var velocity := Vector3.ZERO
var life: float = 0.0
var item_id: int = Nodes.ARROW_ITEM
var damage: float = 6.0
var recoverable: bool = true
var flame: bool = false
var punch: int = 0
var piercing: int = 0
var hit_mobs: Array = []
var stuck: bool = false
var from_player: bool = false
# Where the arrow was loosed, so `sniper_duel` can measure the shot's own range.
var launch_point: Vector3 = Vector3.INF
var hits_player: bool = false
var shooter_kind: String = ""
var shooter_id: int = 0

func _ready() -> void:
	var shaft := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.05,0.05,0.55)
	shaft.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("8a6a45")
	shaft.material_override = mat
	add_child(shaft)
	var tip := MeshInstance3D.new()
	var tip_mesh := BoxMesh.new()
	tip_mesh.size = Vector3(0.08,0.08,0.12)
	tip.mesh = tip_mesh
	tip.position = Vector3(0,0,-0.3)
	var tip_mat := StandardMaterial3D.new()
	tip_mat.albedo_color = Color("c9ccc4")
	tip.material_override = tip_mat
	add_child(tip)
	for axis in 2:
		var feather := MeshInstance3D.new()
		var feather_mesh := BoxMesh.new()
		feather_mesh.size = Vector3(0.16,0.018,0.16) if axis == 0 else Vector3(0.018,0.16,0.16)
		feather.mesh = feather_mesh; feather.position.z = 0.21
		feather.material_override = tip_mat
		add_child(feather)
	_orient()

func _orient() -> void:
	if velocity.length() > 0.01: look_at(position+velocity,Vector3.UP if absf(velocity.normalized().y) < 0.99 else Vector3.RIGHT)

func _physics_process(delta: float) -> void:
	if not game.playing(): return
	life += delta
	if stuck:
		if life >= 600.0: queue_free(); return
		if recoverable and position.distance_to(game.player.position+Vector3.UP*0.8) < 1.6 and game.inventory.capacity(item_id) >= 1:
			game.inventory.add_item(item_id)
			game.sound("pickup")
			queue_free()
		return
	if life > 30: queue_free(); return
	velocity.y -= 12*delta
	var motion: Vector3 = velocity*delta
	var steps: int = maxi(1,ceili(motion.length()/0.08))
	for step in steps:
		var next: Vector3 = position+motion/steps
		if game.world.intersects(next,0.03,0.06):
			RedstoneSensors.projectile_hit(game.world,position,motion,true,game.player if from_player and not hits_player else null)
			RedstoneInputs.projectile_hit(game.world,position,motion)
			if flame:
				var hit: Dictionary = game.world.raycast(position,motion.normalized(),motion.length()+0.1)
				if not hit.is_empty(): Campfires.ignite(game.world,hit.pos)
			stuck = true
			life = 0.0
			game.sound_at("thud",position,1.4)
			return
		position = next
		if from_player:
			for entity in game.entities.get_children():
				if entity is MagicProjectile and position.distance_to(entity.position) < 0.5:
					if entity.kind == "ghast": entity.deflect(velocity); queue_free(); return
					if entity.kind == "shulker": entity.queue_free(); queue_free(); return
		if from_player or not shooter_kind.is_empty():
			for mob in game.creatures.get_children():
				if mob.get_instance_id() != shooter_id and not hit_mobs.has(mob.get_instance_id()) and not mob.is_queued_for_deletion() and position.distance_to(mob.center()) < maxf(0.55,mob.width+0.2):
					hit_mobs.append(mob.get_instance_id())
					PotionEffects.apply_item(mob,item_id)
					if flame: PotionEffects.apply(mob,"burning",5)
					var was_alive: bool = mob.health > 0
					if from_player and not hits_player: Golems.attacked(mob,game.player)
					elif shooter_id != 0 and is_instance_id_valid(shooter_id): Golems.attacked(mob,instance_from_id(shooter_id))
					mob.hit(damage,position-velocity)
					Jukeboxes.arrow_killed(mob,shooter_kind,was_alive)
					# `sniper_duel`: a player's arrow killing a skeleton from at least
					# fifty blocks away.
					if from_player and mob.kind == "skeleton" and was_alive and not is_inf(launch_point.x) and launch_point.distance_to(position) >= 50.0:
						game.achievements.award("sniper_duel")
					mob.knock *= 1+punch*0.6
					if hit_mobs.size() > piercing: queue_free(); return
		if (not from_player or hits_player) and position.distance_to(game.player.position+Vector3.UP*0.9) < 0.65:
			game.player.hurt(3,false,position-velocity,"projectile")
			PotionEffects.apply_item(game.player,item_id)
			queue_free()
			return
	_orient()
