extends SceneTree
var failures: int = 0
func _init() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		if failures <= 15: push_error(message)
func run() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/farmer_fields_reference.json"))
	for row in data.farm:
		var target := Vector3i.ZERO; var actions: Dictionary = {"count":0}
		var state: Dictionary = {"farm":row.active,"target":target if row.current else null,"targets":[target] if row.queued else [],"elapsed":row.elapsed,"cooldown":row.cooldown}
		var result: bool = FarmerFields.farm_step(state,0.1,true,func(): return [target] if row.sensor else [],func(_p,_c): return {"active":row.moving,"distance":row.distance},func(_p): actions.count += 1)
		check(result == row.result and state.farm == row.after_active and (state.target != null) == row.after_target,"Farm activity state differs: "+str(row))
		check(is_equal_approx(state.elapsed,row.after_elapsed) and is_equal_approx(state.cooldown,row.after_cooldown) and (state.targets.size() if state.farm else 0) == row.after_queue and actions.count == int(row.actions),"Farm timers/actions differ: "+str(row))
	for row in data.fertilize:
		var target := Vector3i.ZERO; var actions: Dictionary = {"count":0,"meal":3}
		var state: Dictionary = {"fertilize":row.active,"fert_target":target if row.current else null,"fert_elapsed":row.elapsed,"fert_cooldown":row.cooldown}
		var result: bool = FarmerFields.fertilize_step(state,0.1,true,func(): return target if row.sensor else null,func(_p,_c): return {"active":row.moving,"distance":row.distance},func(_p): actions.count += 1; actions.meal -= int(row.success))
		check(result == row.result and state.fertilize == row.after_active and (state.fert_target != null) == row.after_target,"Fertilizer activity state differs: "+str(row))
		check(is_equal_approx(state.fert_elapsed,row.after_elapsed) and is_equal_approx(state.fert_cooldown,row.after_cooldown) and actions.count == int(row.actions) and actions.meal == int(row.meal),"Fertilizer timers/actions differ: "+str(row))
	var ids: Array = FarmerFields.SEEDS+[Nodes.BREAD,Nodes.STONE]
	var names: Array = ["mcl_farming:wheat_seeds","mcl_farming:potato_item","mcl_farming:carrot_item","mcl_farming:beetroot_seeds","mcl_farming:bread","mcl_core:stone"]
	for row in data.seeds:
		var items: Array = [{"id":ids[int(row.first)-1],"count":int(row.count),"wear":0},{"id":ids[int(row.second)-1],"count":int(row.count),"wear":0}]
		var seed: Dictionary = FarmerFields.take_seed(items); var id: int = int(seed.get("id",0))
		check(("" if id == 0 else names[ids.find(id)]) == row.result and items[0].count == row.left[0] and items[1].count == row.left[1],"Seed inventory choice differs")
	for row in data.dispatch:
		var rng := EnchantRolls.new(int(row.seed))
		check(FarmerFields.dispatch(rng) == row.order and rng.state == int(row.state),"Weighted work ordering differs")
	print("FARMER FIELD SOURCE: %d farm steps, %d fertilizer steps, %d seed choices, %d dispatches; %d failures"%[data.farm.size(),data.fertilize.size(),data.seeds.size(),data.dispatch.size(),failures])
	quit(1 if failures else 0)
