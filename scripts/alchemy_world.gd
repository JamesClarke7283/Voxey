class_name AlchemyWorld
extends RefCounted

static func snapshot(game: Node3D) -> void:
	var saved: Array = []
	for mob in game.creatures.get_children():
		if not mob is AlchemyCreature or mob.is_queued_for_deletion() or game.leads.attached(mob): continue
		var effects: Dictionary = {}
		for name in PotionEffects.NAMES:
			if mob.has_meta("effect_"+name): effects[name] = {"duration":mob.get_meta("effect_"+name),"level":PotionEffects.level(mob,name)}
		saved.append({"kind":mob.kind,"position":[mob.position.x,mob.position.y,mob.position.z],"health":mob.health,"effects":effects,"raid":mob.get_meta("raid",false)})
	game.world.adventure_state["alchemy_creatures"] = saved

static func restore(game: Node3D) -> void:
	if game.world.has_meta("alchemy_restored"): return
	game.world.set_meta("alchemy_restored",true)
	for record in game.world.adventure_state.get("alchemy_creatures",[]):
		if not record is Dictionary or record.get("kind","") not in ["silverfish","turtle","phantom","breeze","pillager"]: continue
		var mob: Creature = game.spawn_creature(record.kind,VillageLife.vec(record.position))
		mob.health = clampf(record.get("health",mob.health),0,mob.info().health)
		if record.get("raid",false): mob.set_meta("raid",true)
		for effect in record.get("effects",{}):
			var data: Dictionary = record.effects[effect]
			PotionEffects.apply(mob,effect,float(data.get("duration",0)),int(data.get("level",1)))

static func update(game: Node3D, delta: float) -> void:
	if game.dimension != "overworld": return
	var raid: Dictionary = game.world.adventure_state.get("raid",{})
	if raid.is_empty() and PotionEffects.level(game.player,"bad_omen") > 0:
		var village: Dictionary = VillageGenerator.nearest(game.world.generator,game.player.position)
		if Vector3(village.center).distance_to(game.player.position) < 55:
			raid = {"center":[village.center.x,village.center.y,village.center.z],"wave":0,"timer":5.0,"level":PotionEffects.level(game.player,"bad_omen")}
			game.survival.effects.erase("bad_omen")
			game.toast("Bad Omen triggered a raid! Defend the village through three waves.")
	if raid.is_empty(): return
	var alive: int = 0
	for mob in game.creatures.get_children():
		if not mob.is_queued_for_deletion() and mob.get_meta("raid",false): alive += 1
	raid["alive"] = alive
	if alive == 0:
		raid.timer -= delta
		if raid.timer <= 0:
			if raid.wave >= 3:
				PotionEffects.apply(game.player,"hero_of_village",600)
				game.survival.give(VillageContent.EMERALD,10); game.experience += 30
				game.toast("Village defended! Hero of the Village grants trade discounts for ten minutes.")
				game.world.adventure_state.erase("raid"); return
			var center: Vector3 = VillageLife.vec(raid.center)
			if not game.world.loaded_at(center): return
			raid.wave += 1; raid.timer = 8
			var count: int = 3+int(raid.wave)+mini(4,int(raid.level)-1)
			for i in count:
				var angle: float = i*TAU/count
				var pos: Vector3 = game._safe_spawn(center+Vector3(cos(angle),0,sin(angle))*26)
				var mob: Creature = game.spawn_creature("pillager",pos); mob.set_meta("raid",true)
			game.toast("Raid wave %d / 3"%int(raid.wave))
	game.world.adventure_state["raid"] = raid
