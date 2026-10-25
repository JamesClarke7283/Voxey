class_name Arrow
extends Node3D

var game: Node3D
var velocity := Vector3.ZERO
var life: float = 0.0
var item_id: int = Nodes.ARROW_ITEM
var potion_data: Dictionary = {}
var damage: float = 2.0 # Source base damage, scaled by current speed / 20.
var critical: bool = false
var recoverable: bool = true
var flame: bool = false
var punch: int = 0
var piercing: int = 0
var hit_mobs: Array = []
var stuck: bool = false
var from_player: bool = false
# Where the arrow was loosed, retained with its flight state.
var launch_point: Vector3 = Vector3.INF
var hits_player: bool = false
var shooter_kind: String = ""
var shooter_id: int = 0
var blocked_by: String = ""
var deflected: bool = false
var shield_contact: bool = false
var drag_clock: float = 0.0
var recheck_clock: float = 0.0
var visited_nodes: Dictionary = {}
var support: Vector3i = Vector3i.ZERO
var has_support: bool = false
var attached: bool = false
var attached_offset := Vector3.ZERO
var attached_basis := Basis.IDENTITY
var left_shooter: bool = false
var trail_clock: float = 0.0
# What a hit on the player deals. A mob's arrow is three; a drowned's thrown
# trident is the source's eight.
var player_damage: float = 3.0

func _ready() -> void:
	if item_id == AntiqueArms.SHOT:
		RedstoneArt.box(self,Vector3.ZERO,Vector3(0.07,0.07,0.12),Color("d3c6a4"))
		_orient()
		return
	# A drowned's thrown trident flies as its own three-pronged shape.
	if item_id == VillageContent.TRIDENT:
		RedstoneArt.box(self,Vector3.ZERO,Vector3(0.04,0.04,1.1),Color("7c9590"))
		for x in [-0.14,0,0.14]: RedstoneArt.box(self,Vector3(x,0,-0.7),Vector3(0.04,0.05,0.36),Color("79c0ba"))
		RedstoneArt.box(self,Vector3(0,0,-0.55),Vector3(0.3,0.05,0.05),Color("79c0ba"))
		_orient()
		return
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

static func source_damage(base: float, speed: float, bonus: int = 0) -> int:
	return ceili(maxf(0,base*speed/20.0)+bonus)

func impact_damage() -> float:
	if item_id == VillageContent.TRIDENT: return player_damage
	if item_id == AntiqueArms.SHOT: return damage
	var scaled: float = damage*velocity.length()/20.0
	return source_damage(damage,velocity.length(),randi_range(1,maxi(1,floori(scaled/2+2))) if critical else 0)

func hit_player(previous: Vector3, intersection: Vector3) -> String:
	var player: VoxeyPlayer = game.player
	var amount: float = impact_damage()
	if item_id not in [VillageContent.TRIDENT,AntiqueArms.SHOT] and piercing == 0 and Shields.can_block(player,previous,"arrow"):
		Shields.add_wear(player,amount)
		blocked_by = game.player_id; deflected = true; shield_contact = true
		# The ordinary knockback routine is suppressed by the shield, but the
		# source still applies Punch's additional impulse.
		if punch > 0:
			var horizontal: Vector3 = Vector3(velocity.x,0,velocity.z).normalized()
			player.velocity += horizontal*(punch*12.0*0.546)+Vector3.UP*(2.0*0.91)
		velocity *= -0.15; position = intersection; _orient()
		game.sound_at("thud",position)
		return "deflected"
	var attacker: Node3D = instance_from_id(shooter_id) as Node3D if shooter_id != 0 and is_instance_id_valid(shooter_id) else null
	var before_health: float = player.health
	player.hurt(amount,false,attacker.position if attacker != null else previous,"trident" if item_id == VillageContent.TRIDENT else "arrow",attacker)
	if attacker != null and player.health < before_health: Wolves.record_player_hurt(game,attacker)
	hit_mobs.append(player.get_instance_id())
	if item_id == VillageContent.TRIDENT:
		velocity *= -0.175; position = intersection; deflected = true; _orient()
		return "bounced"
	# Piercing skips physical deflection. The installed source still runs the
	# ordinary damage/effect callbacks, including shield damage mitigation.
	PotionEffects.apply_item(player,item_id,1.0,potion_data)
	if flame: PotionEffects.apply(player,"burning",5)
	if item_id != AntiqueArms.SHOT and piercing == 0:
		attached = true; attached_offset = player.basis.inverse()*(intersection-player.position)
		position = intersection; _orient()
		attached_basis = player.basis.inverse()*basis
		life = 0; flame = false; critical = false
		return "attached"
	if item_id == AntiqueArms.SHOT or hit_mobs.size() >= maxi(1,piercing): queue_free(); return "spent"
	return "pierced"

func _physics_process(delta: float) -> void:
	if item_id in [VillageContent.TRIDENT,AntiqueArms.SHOT]: _legacy_physics_process(delta); return
	if not game.playing(): return
	life += delta
	var limit: float = ArrowFlight.ATTACHED_LIFETIME if attached else ArrowFlight.STUCK_LIFETIME if stuck else ArrowFlight.FLIGHT_LIFETIME
	if life > limit: queue_free(); return
	if flame and Weather.exposed_to_rain(game.world,Vector3i(position.floor())): flame = false
	if attached:
		position = game.player.position+game.player.basis*attached_offset
		basis = game.player.basis*attached_basis
		return
	if stuck: step_stuck(delta); return
	if shield_contact and position.distance_to(game.player.position+Vector3.UP*0.9) > 0.8: shield_contact = false
	var previous: Vector3 = position
	# Luanti advances the physical object before its on_step callback applies
	# drag and raycasts that completed movement.
	velocity.y -= 9.81*delta
	var destination: Vector3 = position+velocity*delta
	var drag: Dictionary = ArrowFlight.drag(velocity,life,drag_clock)
	velocity = drag.velocity; drag_clock = drag.clock
	var outcome: String = trace_segment(previous,destination)
	if is_queued_for_deletion() or attached or stuck: return
	if outcome == "": position = destination
	if not left_shooter:
		var shooter: Node3D = instance_from_id(shooter_id) as Node3D if shooter_id != 0 and is_instance_id_valid(shooter_id) else game.player if from_player else null
		if shooter == null or ArrowFlight.box_hit(previous,destination-previous,actor_box(shooter)).is_empty(): left_shooter = true
	# Source prediction can hit an actor or cross liquid; solid nodes stop the
	# prediction and are embedded into only once the actual movement reaches it.
	if outcome != "break": trace_segment(position,position+velocity*0.05,true)
	if not stuck and not attached and not is_queued_for_deletion(): _orient()
	if critical or flame:
		trail_clock += delta
		if trail_clock >= 1.0/15:
			trail_clock = 0; game.puff(position,Color("ed9b3b") if flame else Color("bc7a57"),1,0.2)

func actor_box(actor: Node3D) -> AABB:
	var width: float = actor.width if actor is Creature else 0.3
	var height: float = actor.height if actor is Creature else 1.8
	return AABB(actor.position-Vector3(width,0,width),Vector3(width*2,height,width*2))

func visit_node(p: Vector3i, id: int) -> void:
	if visited_nodes.has(p): return
	visited_nodes[p] = true
	if Fluids.lava(id) or Fire.is_fire(id): flame = true
	elif Fluids.water(id): flame = false
	if Fluids.liquid(id): velocity *= ArrowFlight.LIQUID_RATE

func embed(point: Vector3, p: Vector3i, direction: Vector3) -> void:
	position = point+direction.normalized()*0.15
	_orient()
	stuck = true; has_support = true; support = p
	critical = false; life = 0; drag_clock = 0; recheck_clock = 0
	piercing = 0; visited_nodes.clear(); hit_mobs.clear(); velocity = Vector3.ZERO
	game.sound_at("thud",position,1.4)
	if flame:
		if game.world.node_at(p) == Nodes.TNT: game.ignite_tnt(p)
		elif Campfires.is_campfire(game.world.node_at(p)): Campfires.ignite(game.world,p)
		elif Candles.is_candle(game.world.node_at(p)): game.world.set_node(p,Candles.lit_of(game.world.node_at(p)))

func step_stuck(delta: float) -> void:
	for child in get_children():
		if child is Node3D: child.rotation.z = sin(life*70)*maxf(0,1-life/0.3)*0.08
	recheck_clock += delta
	if recheck_clock < ArrowFlight.RECHECK: return
	recheck_clock = 0
	if recoverable and position.distance_to(game.player.position) <= ArrowFlight.PICKUP_RANGE:
		if game.gamemode != "creative":
			var drop: ItemDrop = game.spawn_drop(position,item_id,1,0,potion_data)
			drop.velocity = Vector3.ZERO; drop.pickup_delay = 0; drop.insta_collect = true
		queue_free(); return
	if has_support and game.world.node_at(support) == Nodes.AIR:
		stuck = false; has_support = false; life = 0; drag_clock = 0
		critical = false; launch_point = position; visited_nodes.clear(); hit_mobs.clear()

func trace_segment(origin: Vector3, end: Vector3, prediction: bool = false) -> String:
	var motion: Vector3 = end-origin
	var events: Array = ArrowFlight.nodes(game.world,origin,end)
	for mob in game.creatures.get_children():
		if not mob is Creature or mob.health <= 0 or mob.kind == "enderman" or mob.is_queued_for_deletion() or hit_mobs.has(mob.get_instance_id()): continue
		if mob.get_instance_id() == shooter_id and not left_shooter: continue
		var event: Dictionary = ArrowFlight.box_hit(origin,motion,actor_box(mob))
		if not event.is_empty(): event.merge({"kind":"mob","actor":mob}); events.append(event)
	if game.player.health > 0 and not shield_contact and not hit_mobs.has(game.player.get_instance_id()) and (not from_player or left_shooter or hits_player):
		var event: Dictionary = ArrowFlight.box_hit(origin,motion,actor_box(game.player))
		if not event.is_empty(): event.merge({"kind":"player"}); events.append(event)
	if from_player:
		for projectile in game.entities.get_children():
			if not projectile is MagicProjectile or projectile.is_queued_for_deletion(): continue
			var event: Dictionary = ArrowFlight.box_hit(origin,motion,AABB(projectile.position-Vector3.ONE*0.25,Vector3.ONE*0.5))
			if not event.is_empty(): event.merge({"kind":"magic","actor":projectile}); events.append(event)
	events.sort_custom(func(a,b): return a.t < b.t)
	for event in events:
		if event.kind == "node":
			if event.solid:
				if prediction: return "barrier"
				RedstoneSensors.projectile_hit(game.world,origin,motion,true,game.player if from_player and not hits_player else null)
				RedstoneInputs.projectile_hit(game.world,origin,motion)
				embed(event.point,event.pos,velocity); return "stop"
			visit_node(event.pos,event.id)
		elif event.kind == "player":
			var result: String = hit_player(origin,event.point)
			if result == "deflected": return "break"
			if result != "pierced": return "stop"
		elif event.kind == "magic":
			if event.actor.kind == "ghast": event.actor.deflect(velocity)
			elif event.actor.kind == "shulker": event.actor.queue_free()
			else: continue
			queue_free(); return "stop"
		else:
			var mob: Creature = event.actor
			hit_mobs.append(mob.get_instance_id())
			var was_alive: bool = mob.health > 0
			if mob.kind == "pillager" and shooter_id != 0 and is_instance_id_valid(shooter_id): MobCrossbows.struck_by(mob,instance_from_id(shooter_id))
			if MobBows.handles(mob.kind) and shooter_id != 0 and is_instance_id_valid(shooter_id): MobBows.struck_by(mob,instance_from_id(shooter_id))
			if from_player and not hits_player: Golems.attacked(mob,game.player)
			mob.hit(impact_damage(),origin,"arrow",0,instance_from_id(shooter_id) if shooter_id != 0 and is_instance_id_valid(shooter_id) else null); PotionEffects.apply_item(mob,item_id,1.0,potion_data)
			MobBows.killed_by(mob,instance_from_id(shooter_id) if shooter_id != 0 and is_instance_id_valid(shooter_id) else null,"arrow",was_alive)
			if flame: PotionEffects.apply(mob,"burning",5)
			if from_player and not hits_player:
				Wolves.record_player_struck(game,mob); mob.set_meta("player_struck",true)
			Jukeboxes.arrow_killed(mob,shooter_kind,was_alive)
			mob.knock *= 1+punch*0.6
			if hit_mobs.size() >= maxi(1,piercing): queue_free(); return "stop"
	return ""

func _legacy_physics_process(delta: float) -> void:
	if not game.playing(): return
	life += delta
	if stuck:
		if life >= 600.0: queue_free(); return
		if recoverable and position.distance_to(game.player.position+Vector3.UP*0.8) < 1.6 and game.inventory.capacity(item_id,0,potion_data) >= 1:
			game.inventory.add_item(item_id,1,0,potion_data)
			game.sound("pickup")
			queue_free()
		return
	if life > 30: queue_free(); return
	if shield_contact and position.distance_to(game.player.position+Vector3.UP*0.9) > 0.8: shield_contact = false
	var previous: Vector3 = position
	velocity.y -= (2.0 if item_id == AntiqueArms.SHOT else 24.0 if item_id == VillageContent.TRIDENT else 9.81)*delta
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
			if item_id == AntiqueArms.SHOT: queue_free(); return
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
				if (mob.get_instance_id() != shooter_id or deflected) and not hit_mobs.has(mob.get_instance_id()) and not mob.is_queued_for_deletion() and position.distance_to(mob.center()) < maxf(0.55,mob.width+0.2):
					hit_mobs.append(mob.get_instance_id())
					var was_alive: bool = mob.health > 0
					if from_player and not hits_player: Golems.attacked(mob,game.player)
					elif shooter_id != 0 and is_instance_id_valid(shooter_id): Golems.attacked(mob,instance_from_id(shooter_id))
					if item_id == VillageContent.TRIDENT and shooter_id != 0 and is_instance_id_valid(shooter_id):
						if MobBows.handles(mob.kind): MobBows.struck_by(mob,instance_from_id(shooter_id))
						if mob.kind == "pillager": MobCrossbows.struck_by(mob,instance_from_id(shooter_id))
					mob.hit(impact_damage(),previous,"trident" if item_id == VillageContent.TRIDENT else "",0,instance_from_id(shooter_id) if shooter_id != 0 and is_instance_id_valid(shooter_id) else null)
					if item_id != AntiqueArms.SHOT:
						MobBows.killed_by(mob,instance_from_id(shooter_id) if shooter_id != 0 and is_instance_id_valid(shooter_id) else null,"trident",was_alive)
					PotionEffects.apply_item(mob,item_id,1.0,potion_data)
					if flame: PotionEffects.apply(mob,"burning",5)
					if from_player and not hits_player:
						Wolves.record_player_struck(game,mob)
						if is_instance_valid(mob): mob.set_meta("player_struck",true)
					Jukeboxes.arrow_killed(mob,shooter_kind,was_alive)
					mob.knock *= 1+punch*0.6
					if item_id == VillageContent.TRIDENT:
						velocity *= -0.175; deflected = true; _orient(); return
					if hit_mobs.size() >= maxi(1,piercing): queue_free(); return
		if (not from_player or hits_player) and not shield_contact and not hit_mobs.has(game.player.get_instance_id()) and position.distance_to(game.player.position+Vector3.UP*0.9) < 0.65:
			if hit_player(previous,position) != "pierced": return
	_orient()
