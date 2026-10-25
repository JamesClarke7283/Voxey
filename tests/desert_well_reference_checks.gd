extends SceneTree

var failed: int = 0
func check(ok: bool, message: String) -> void:
	if ok: print("PASS  "+message)
	else: failed += 1; push_error("FAIL  "+message)

func _init() -> void: call_deferred("run")

func run() -> void:
	Copper.register_families(); WoodTypes.register_families(); Archaeology.configure_loot()
	var gen := TerrainGenerator.new(8675309)
	var flat: Callable = func(p): return Nodes.SAND if p.y <= 0 else Nodes.AIR
	var reference: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/desert_well_reference.json"))
	var ids: Dictionary = {"mcl_core:sandstone":Nodes.SANDSTONE,"mcl_core:sand":Nodes.SAND,"mcl_core:water_source":Nodes.WATER,"mcl_stairs:slab_sandstone":BuildingShapes.slab_for(Nodes.SANDSTONE),"mcl_sus_nodes:sand":Archaeology.SUSPICIOUS_SAND}
	check(reference.cases.size() == 16,"source oracle covers all sixteen independent sand-position pairs")
	for fixture in reference.cases:
		var native: Dictionary = DesertWells.plan(gen,Vector3i(0,1,0),73,flat,Vector2i(fixture.directions[0],fixture.directions[1]))
		var matches: bool = native.voxels.size() == fixture.nodes.size()
		for node in fixture.nodes:
			var p := Vector3i(node[0],node[1],node[2])
			matches = matches and native.voxels.get(p,-1) == ids[node[3]]
		for location in fixture.suspicious:
			var p := Vector3i(location[0],location[1],location[2])
			matches = matches and native.states.has(p) and native.states[p].structure == "desert_well"
		check(matches,"well voxels and buried sand match the actual Lua builder for pair "+str(fixture.directions))
	var well: Dictionary = DesertWells.plan(gen,Vector3i(0,6,0),73,flat)
	check(well.origin == Vector3i.ZERO and well.voxels.size() == 112,"builder descends to ground and places all 112 source cells")
	check(well.voxels.values().count(Nodes.WATER) == 5 and well.states.size() == 2,"well has the source five-cell pool and two seeded archaeology cells")
	var holes: Callable = func(p): return Nodes.AIR if p == Vector3i(2,-1,2) else flat.call(p)
	check(DesertWells.plan(gen,Vector3i(0,1,0),73,holes).is_empty(),"a single hole in either foundation layer rejects placement")
	var previous: Callable = func(p): return BuildingShapes.slab_for(Nodes.SANDSTONE) if p == Vector3i(2,0,2) else flat.call(p)
	check(DesertWells.plan(gen,Vector3i(0,1,0),73,previous).is_empty(),"a sandstone slab in the foundation prevents repeat placement")
	var top_air: Callable = func(p): return Nodes.AIR if p == Vector3i(2,0,2) else flat.call(p)
	check(not DesertWells.plan(gen,Vector3i(0,1,0),73,top_air).is_empty(),"surface-level gaps are accepted as in the source foundation test")
	check(DesertWells.candidate(TerrainGenerator.new(1,"nether"),Vector2i.ZERO).is_empty(),"the placed feature excludes other dimensions")
	var nearby: Vector3i = DesertWells.nearest(gen,Vector3(8,35,8))
	check(nearby != Vector3i.ZERO and gen.biome(nearby.x,nearby.z) == "Desert","native rarity and biome filter provide a locatable desert well")
	print("DESERT WELL ",nearby)
	if nearby != Vector3i.ZERO:
		var column := Vector2i(nearby.x >> 4,nearby.z >> 4)
		var a := PackedInt32Array(); a.resize(18*18*64); a.fill(Nodes.SAND)
		var b := PackedInt32Array(); b.resize(a.size()); b.fill(Nodes.SAND)
		var deep := PackedInt32Array(); deep.resize(18*18*128); deep.fill(Nodes.STONE)
		var other_deep := deep.duplicate()
		DesertWells.overlay(gen,column,a,deep); DesertWells.overlay(gen,column+Vector2i.RIGHT,b,other_deep)
		var seam: bool = true
		for y in 64:
			for z in 18:
				for x in 2:
					if a[16+x+z*18+y*324] != b[x+z*18+y*324]: seam = false
		check(seam,"neighboring columns agree on the complete well at their shared halo")
	for x in 40: DesertWells.generated(gen,Vector2i(x,3))
	check(gen.well_cache.size() <= 32,"well planning cache remains bounded")
	print("DESERT WELL REFERENCE TESTS: ",failed," failed")
	quit(1 if failed else 0)
