class_name LeadManager
extends RefCounted

var game: Node3D
var leads: Array = []

func _init(owner_game: Node3D) -> void:
	game = owner_game

func attached(mob: Creature) -> bool:
	return leads.any(func(link: Dictionary): return is_instance_valid(link.mob) and link.mob == mob)

func player_attached(mob: Creature) -> bool:
	return leads.any(func(link: Dictionary): return not link.has("anchor") and is_instance_valid(link.mob) and link.mob == mob)

func anchored(mob: Creature) -> bool:
	return leads.any(func(link: Dictionary): return link.has("anchor") and is_instance_valid(link.mob) and link.mob == mob)

func _rope() -> Node3D:
	var rope := Node3D.new(); game.entities.add_child(rope)
	var material := StandardMaterial3D.new(); material.albedo_color = Color("ad8858"); material.roughness = 1.0
	for i in 12:
		var piece := MeshInstance3D.new(); var mesh := BoxMesh.new(); mesh.size = Vector3(0.035,0.035,1)
		piece.mesh = mesh; piece.material_override = material; rope.add_child(piece)
	return rope

func attach(mob: Creature, consume: bool = true) -> bool:
	if mob == null or mob.kind == "end_crystal" or attached(mob): return false
	if Boats.is_passenger(mob): game.toast("Release the creature from its boat before attaching a lead."); return false
	if consume and game.gamemode != "creative" and not game.inventory.remove_item(VillageContent.LEAD,1): return false
	leads.append({"mob":mob,"rope":_rope()})
	game.toast("Lead attached. Walk to pull; use an empty hand or lead on this creature to release.")
	return true

func detach(mob: Creature, drop: bool = true) -> void:
	for link in leads.duplicate():
		if not is_instance_valid(link.mob) and not link.has("sleeping") or mob != null and link.mob == mob:
			if drop:
				var pos: Vector3 = mob.center() if is_instance_valid(mob) else (VillageLife.vec(link.anchor)+Vector3.UP if link.has("anchor") else game.player.position+Vector3.UP)
				game.spawn_drop(pos,VillageContent.LEAD,1)
			if is_instance_valid(link.rope): link.rope.queue_free()
			if is_instance_valid(mob) and mob is VillageMob and not mob.is_queued_for_deletion(): game.villages.relocate(mob)
			leads.erase(link)

# Fence anchoring is a Voxey extension of its existing leads. Link state is
# saved with each dimension; a hibernating farm animal keeps its identity.
func anchor_at(p: Vector3i) -> bool:
	var used: bool = false
	for link in leads:
		if link.has("anchor") or not is_instance_valid(link.mob): continue
		if link.mob.position.distance_to(Vector3(p)+Vector3.ONE*0.5) > 16: continue
		link["anchor"] = [p.x,p.y,p.z]; used = true
	if used: game.toast("Leads tied to the fence."); return true
	for link in leads.duplicate():
		if link.get("anchor",[]) == [p.x,p.y,p.z]:
			_release_anchor(link,p)
			used = true
	if used: game.toast("Fence leads released.")
	return used

func _release_anchor(link: Dictionary, p: Vector3i) -> void:
	# A generic animal may have no independent world record. Recreate it before
	# deleting the sleeping lead record, so releasing a knot cannot erase it.
	var mob: Creature = link.mob if is_instance_valid(link.mob) else null
	if mob == null and link.has("sleeping"):
		mob = _restore_mob(link.sleeping)
		if mob != null: link.mob = mob; link.erase("sleeping")
	if mob != null: detach(mob)
	else:
		game.spawn_drop(Vector3(p)+Vector3.UP,VillageContent.LEAD,1)
		if is_instance_valid(link.rope): link.rope.queue_free()
		leads.erase(link)

func hibernate(mob: Creature) -> void:
	Farming.remember(mob)
	if mob is VillageMob or mob is SnowGolem: mob.store_record()
	if mob is NetherResident: mob.ensure_record(); mob.store_record()
	for link in leads:
		if link.mob != mob or not link.has("anchor"): continue
		link["sleeping"] = record(link)
		link.mob = null
		if is_instance_valid(link.rope): link.rope.visible = false

func sleep_if_unloaded(mob: Creature) -> bool:
	if not anchored(mob) or mob.is_queued_for_deletion() or mob.health <= 0: return false
	if game.world.loaded_at(mob.position) and mob.position.distance_to(game.player.position) <= 90: return false
	hibernate(mob)
	mob.queue_free()
	return true

func clear() -> void:
	for link in leads:
		if is_instance_valid(link.rope): link.rope.queue_free()
	leads.clear()

func update(delta: float) -> void:
	for link in leads.duplicate():
		var mob: Creature = link.mob if is_instance_valid(link.mob) else null
		if link.has("anchor"):
			if mob != null and sleep_if_unloaded(mob): mob = null
			var p := Vector3i(int(link.anchor[0]),int(link.anchor[1]),int(link.anchor[2]))
			if game.world.loaded_at(Vector3(p)) and not Barriers.is_fence(game.world.node_at(p)):
				_release_anchor(link,p)
				continue
			if mob == null and link.has("sleeping"):
				if not game.world.loaded_at(Vector3(p)) or game.player.position.distance_to(Vector3(p)) > 80: continue
				mob = _restore_mob(link.sleeping)
				if mob == null: continue
				link.mob = mob; link.erase("sleeping"); link.rope.visible = true
		if mob == null or mob.is_queued_for_deletion(): detach(mob); continue
		var anchor: Vector3 = game.player.position+Vector3.UP*1.1+game.player.global_basis.x*0.2
		if link.has("anchor"): anchor = VillageLife.vec(link.anchor)+Vector3(0.5,0.75,0.5)
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
			mob.direction = ((anchor-mob.position)*Vector3(1,0,1)).normalized()
		end = mob.position+Vector3.UP*mob.height*0.7
		for i in 12:
			var a: float = i/12.0; var b: float = (i+1)/12.0
			var sag: float = clampf(0.7-distance*0.04,0.02,0.6)
			var start: Vector3 = anchor.lerp(end,a)-Vector3.UP*sin(a*PI)*sag
			var finish: Vector3 = anchor.lerp(end,b)-Vector3.UP*sin(b*PI)*sag
			var piece: MeshInstance3D = link.rope.get_child(i)
			piece.position = (start+finish)*0.5; piece.scale.z = maxf(0.01,start.distance_to(finish))
			if start.distance_to(finish) > 0.001: piece.look_at(finish,Vector3.RIGHT if absf((finish-start).normalized().y) > 0.99 else Vector3.UP)

func record(link: Dictionary) -> Dictionary:
	if link.has("sleeping"): return link.sleeping.duplicate(true)
	if not is_instance_valid(link.mob) or link.mob.is_queued_for_deletion(): return {}
	var mob: Creature = link.mob
	if mob is NetherResident: mob.ensure_record(); mob.store_record()
	var saved: Dictionary = {"kind":mob.kind,"farm_id":mob.farm_id,"custom_name":mob.custom_name,"position":[mob.position.x,mob.position.y,mob.position.z],"health":mob.health,"effects":PotionEffects.snapshot(mob),"slime_size":mob.slime_size if mob is ExpeditionCreature and mob.kind == "slime" else 0,"wool_timer":mob.wool_timer,"raid":mob.get_meta("raid",false),"person":mob.person_key if mob is VillageMob else "","sheared":mob.sheared,"sheep_color":mob.sheep_color,"grazing":mob.grazing,"graze_consumed":mob.graze_consumed,"trust":mob.trust if mob is RuralAnimal else 0,"saddled":mob.saddled if mob is RuralAnimal else false,"horse_armor":mob.horse_armor if mob is RuralAnimal else false}
	if mob is SnowGolem: mob.store_record(); saved["golem"] = mob.golem_key
	if mob is NetherResident: saved["resident"] = mob.resident_key
	if mob is ExpeditionCreature: saved["crystal_key"] = mob.crystal_key
	if link.has("anchor"): saved["anchor"] = link.anchor.duplicate()
	return saved

func snapshot() -> Array:
	var saved: Array = []
	for link in leads:
		var entry: Dictionary = record(link)
		if not entry.is_empty(): saved.append(entry)
	return saved

func _restore_mob(entry: Dictionary) -> Creature:
	var mob: Creature
	var key: String = entry.get("person","")
	if not key.is_empty():
		var person: Dictionary = game.villages.record(key)
		if person.is_empty() or person.dead: return null
		for existing in game.creatures.get_children():
			if existing is VillageMob and not existing.is_queued_for_deletion() and existing.person_key == key: mob = existing; break
		if mob == null:
			mob = VillageMob.new(); mob.game = game; mob.kind = entry.kind; mob.person_key = key; mob.position = VillageLife.vec(entry.position)
			game.creatures.add_child(mob); mob.bind(person)
	elif not str(entry.get("golem","")).is_empty():
		mob = Golems.resolve(game,str(entry.golem))
		if mob == null: return null
	elif not str(entry.get("resident","")).is_empty():
		mob = NetherResident.resolve(game,str(entry.resident))
		if mob == null: return null
	else:
		mob = Farming.resolve(game,str(entry.get("farm_id","")))
		if mob == null: mob = game.spawn_creature(entry.kind,VillageLife.vec(entry.position))
	if mob == null: return null
	if mob is ExpeditionCreature:
		mob.crystal_key = str(entry.get("crystal_key",mob.crystal_key))
		if mob.kind == "slime": mob.set_slime_size(int(entry.get("slime_size",2)))
	mob.health = entry.get("health",mob.health); mob.sheared = entry.get("sheared",false); mob.wool_timer = entry.get("wool_timer",100)
	mob.custom_name = NameTags.bounded(str(entry.get("custom_name","")),30); NameTags.refresh(mob)
	Farming.restore_coat(mob,entry)
	if entry.get("raid",false): mob.set_meta("raid",true)
	for name in entry.get("effects",{}):
		var effect: Dictionary = entry.effects[name]
		PotionEffects.apply(mob,name,float(effect.get("duration",0)),int(effect.get("level",1)))
		if name == "absorption": PotionEffects.restore_absorption(mob,effect.get("remaining",0))
	if mob is RuralAnimal:
		mob.trust = int(entry.get("trust",0))
		if entry.get("saddled",false) and not mob.saddled: mob.equip_saddle()
		if entry.get("horse_armor",false) and not mob.horse_armor: mob.equip_horse_armor()
	Farming.remember(mob)
	return mob

func restore(saved: Array) -> void:
	clear()
	for entry in saved:
		if not entry is Dictionary or not Creature.KINDS.has(entry.get("kind","")) or not entry.get("position") is Array or entry.position.size() != 3: continue
		var mob: Creature = _restore_mob(entry)
		if mob == null: continue
		if attach(mob,false) and entry.get("anchor") is Array and entry.anchor.size() == 3:
			leads.back()["anchor"] = [int(entry.anchor[0]),int(entry.anchor[1]),int(entry.anchor[2])]
			sleep_if_unloaded(mob)
