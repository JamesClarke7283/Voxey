class_name LeadManager
extends RefCounted

var game: Node3D
var leads: Array = []

func _init(owner_game: Node3D) -> void:
	game = owner_game

func attached(mob: Creature) -> bool:
	return leads.any(func(link: Dictionary): return is_instance_valid(link.mob) and link.mob == mob)

func attach(mob: Creature, consume: bool = true) -> bool:
	if mob == null or mob.kind == "end_crystal" or attached(mob): return false
	if consume and game.gamemode != "creative" and not game.inventory.remove_item(VillageContent.LEAD,1): return false
	var rope := Node3D.new(); game.entities.add_child(rope)
	var material := StandardMaterial3D.new(); material.albedo_color = Color("ad8858"); material.roughness = 1.0
	for i in 12:
		var piece := MeshInstance3D.new(); var mesh := BoxMesh.new(); mesh.size = Vector3(0.035,0.035,1)
		piece.mesh = mesh; piece.material_override = material; rope.add_child(piece)
	leads.append({"mob":mob,"rope":rope})
	game.toast("Lead attached. Walk to pull; use an empty hand or lead on this creature to release.")
	return true

func detach(mob: Creature, drop: bool = true) -> void:
	for link in leads.duplicate():
		if not is_instance_valid(link.mob) or link.mob == mob:
			if drop:
				var pos: Vector3 = mob.center() if is_instance_valid(mob) else game.player.position+Vector3.UP
				game.spawn_drop(pos,VillageContent.LEAD,1)
			if is_instance_valid(link.rope): link.rope.queue_free()
			if is_instance_valid(mob) and mob is VillageMob and not mob.is_queued_for_deletion(): game.villages.relocate(mob)
			leads.erase(link)

func clear() -> void:
	for link in leads:
		if is_instance_valid(link.rope): link.rope.queue_free()
	leads.clear()

func update(delta: float) -> void:
	for link in leads.duplicate():
		var mob: Creature = link.mob if is_instance_valid(link.mob) else null
		if mob == null or mob.is_queued_for_deletion(): detach(mob); continue
		var anchor: Vector3 = game.player.position+Vector3.UP*1.1+game.player.global_basis.x*0.2
		var end: Vector3 = mob.position+Vector3.UP*mob.height*0.7
		var distance: float = anchor.distance_to(end)
		if distance > 16: detach(mob); game.toast("The lead snapped."); continue
		if distance > 3.0:
			var toward: Vector3 = (anchor-end).normalized()
			var step: Vector3 = toward*minf(8.0,(distance-3.0)*3.0)*delta
			step.y = clampf(step.y,-0.05,0.08)
			var steps: int = maxi(1,ceili(step.length()/0.15))
			for i in steps:
				for axis in [0,2,1]:
					var next: Vector3 = mob.position; next[axis] += step[axis]/steps
					if not game.world.intersects(next,mob.width,mob.height): mob.position = next
					elif axis != 1 and not game.world.intersects(mob.position+Vector3.UP*1.05,mob.width,mob.height): mob.velocity.y = 6.4
			mob.direction = ((game.player.position-mob.position)*Vector3(1,0,1)).normalized()
		end = mob.position+Vector3.UP*mob.height*0.7
		for i in 12:
			var a: float = i/12.0; var b: float = (i+1)/12.0
			var sag: float = clampf(0.7-distance*0.04,0.02,0.6)
			var start: Vector3 = anchor.lerp(end,a)-Vector3.UP*sin(a*PI)*sag
			var finish: Vector3 = anchor.lerp(end,b)-Vector3.UP*sin(b*PI)*sag
			var piece: MeshInstance3D = link.rope.get_child(i)
			piece.position = (start+finish)*0.5; piece.scale.z = maxf(0.01,start.distance_to(finish))
			if start.distance_to(finish) > 0.001: piece.look_at(finish,Vector3.RIGHT if absf((finish-start).normalized().y) > 0.99 else Vector3.UP)

func snapshot() -> Array:
	var saved: Array = []
	for link in leads:
		if not is_instance_valid(link.mob) or link.mob.is_queued_for_deletion(): continue
		var mob: Creature = link.mob
		saved.append({"kind":mob.kind,"position":[mob.position.x,mob.position.y,mob.position.z],"health":mob.health,"effects":PotionEffects.snapshot(mob),"slime_size":mob.slime_size if mob is ExpeditionCreature and mob.kind == "slime" else 0,"wool_timer":mob.wool_timer,"raid":mob.get_meta("raid",false),"person":mob.person_key if mob is VillageMob else "","sheared":mob.sheared,"trust":mob.trust if mob is RuralAnimal else 0,"saddled":mob.saddled if mob is RuralAnimal else false,"horse_armor":mob.horse_armor if mob is RuralAnimal else false})
	return saved

func restore(saved: Array) -> void:
	clear()
	for entry in saved:
		if not entry is Dictionary or not Creature.KINDS.has(entry.get("kind","")) or not entry.get("position") is Array or entry.position.size() != 3: continue
		var mob: Creature
		var key: String = entry.get("person","")
		if not key.is_empty():
			var person: Dictionary = game.villages.record(key)
			if person.is_empty() or person.dead: continue
			mob = VillageMob.new(); mob.game = game; mob.kind = entry.kind; mob.person_key = key; mob.position = VillageLife.vec(entry.position)
			game.creatures.add_child(mob); mob.bind(person)
		else: mob = game.spawn_creature(entry.kind,VillageLife.vec(entry.position))
		if mob is ExpeditionCreature and mob.kind == "slime": mob.set_slime_size(int(entry.get("slime_size",2)))
		mob.health = entry.get("health",mob.health); mob.sheared = entry.get("sheared",false); mob.wool_timer = entry.get("wool_timer",100)
		for part in mob.wool_parts: part.visible = not mob.sheared
		if entry.get("raid",false): mob.set_meta("raid",true)
		for name in entry.get("effects",{}):
			var effect: Dictionary = entry.effects[name]
			PotionEffects.apply(mob,name,float(effect.get("duration",0)),int(effect.get("level",1)))
		if mob is RuralAnimal:
			mob.trust = int(entry.get("trust",0))
			if entry.get("saddled",false): mob.equip_saddle()
			if entry.get("horse_armor",false): mob.equip_horse_armor()
		attach(mob,false)
