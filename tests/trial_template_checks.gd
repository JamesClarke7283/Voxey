extends SceneTree

var failed: int = 0
func check(ok: bool, message: String) -> void:
	if ok: print("PASS  "+message)
	else: failed += 1; push_error("FAIL  "+message)

func _init() -> void: call_deferred("run")

func run() -> void:
	Copper.register_families(); WoodTypes.register_families()
	var gen := TerrainGenerator.new(8675309)
	for id in Trials.DATA:
		check(not Signs.is_hanging(id) and not Signs.is_sign(id) and not Barriers.is_barrier(id) and not BuildingShapes.is_shape(id) and not WoodTypes.is_wood(id),"trial registry allocation does not overlap another family: "+str(id))
		check(Nodes.color(id) == Color(Trials.DATA[id].color),"trial id retains its own color: "+str(id))
	var templates: Dictionary = TrialChambers.prepare(gen)
	check(templates.size() == 44,"all44 source chamber templates are decoded")
	var mapped: bool = true
	for name in templates:
		var t: Dictionary = templates[name]
		check(t.nodes.size() == int(t.width)*int(t.height)*int(t.length),name+" retains every source voxel")
		for item in t.names.values():
			if item.begins_with("mcl_levelgen:"): continue
			var id: int = TrialChambers.node_id(item,0,0)
			if id < 0 or not Nodes.exists(id): print("UNMAPPED ",item," -> ",id); mapped = false
	check(mapped,"every source palette entry maps to an existing block")
	var plan: Dictionary = TrialChambers.plan(gen,Vector2i.ZERO)
	print("CHAMBER ",plan.origin," pieces=",plan.pieces.size())
	check(plan.origin.y >= -40 and plan.origin.y <= -20 and plan.pieces.size() > 5,"source depth and connected room expansion")
	check(plan.pieces.any(func(p):return "spawner" in p.name),"source pools create configured spawners")
	var copy := TerrainGenerator.new(8675309)
	check(TrialChambers.plan(copy,Vector2i.ZERO) == plan,"chamber plan is deterministic across generator instances")
	var coord := Vector2i(floori(plan.origin.x/16.0),floori(plan.origin.z/16.0))
	var a := PackedInt32Array(); a.resize(18*18*64); a.fill(Nodes.STONE)
	var d := PackedInt32Array(); d.resize(18*18*128); d.fill(Nodes.STONE)
	var data: Dictionary = TrialChambers.overlay(gen,coord,a,d)
	check(d.count(Nodes.AIR) > 0 and d.count(Nodes.STONE) < d.size(),"chamber actually carves source rooms into deep terrain")
	check(not data.states.is_empty(),"source waxed copper metadata is exported with the generated column")
	var next := PackedInt32Array(); next.resize(d.size()); next.fill(Nodes.STONE)
	var upper := PackedInt32Array(); upper.resize(a.size()); upper.fill(Nodes.STONE)
	TrialChambers.overlay(gen,coord+Vector2i.RIGHT,upper,next)
	var seam: bool = true
	for y in range(-128,0):
		for z in 18:
			for x in 2:
				if d[16+x+z*18+(y+128)*324] != next[x+z*18+(y+128)*324]: seam = false
	check(seam,"neighboring columns agree throughout their two shared halo slices")
	for i in 10: TrialChambers.plan(gen,Vector2i(i,1))
	check(gen.trial_cache.size() <= 8,"chamber plan cache is bounded during exploration")
	print("TRIAL TEMPLATE TESTS: ",failed," failed")
	quit(1 if failed else 0)
