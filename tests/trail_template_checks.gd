extends SceneTree

var failed: int = 0
func check(ok: bool, message: String) -> void:
	if ok: print("PASS  "+message)
	else: failed += 1; push_error("FAIL  "+message)

func _init() -> void: call_deferred("run")

func run() -> void:
	Copper.register_families(); WoodTypes.register_families(); Archaeology.configure_loot()
	var gen := TerrainGenerator.new(8675309)
	var templates: Dictionary = TrailRuins.prepare(gen)
	check(templates.size() == 14 and TrailRuins.source.pools.size() == 7,"all 14 source trail templates and seven pools are retained")
	check(TrailRuins.source.pools.trail_ruins_buildings_grouped.is_empty(),"the source's empty grouped-room pool stays empty")
	var mapped: bool = true
	for name in templates:
		var t: Dictionary = templates[name]
		check(t.nodes.size() == int(t.width)*int(t.height)*int(t.length),name+" retains every voxel")
		for item in t.names.values():
			if item in ["mcl_levelgen:jigsaw_block","mcl_levelgen:structure_void"]: continue
			var id: int = TrailRuins.node_id(item,0,0)
			if id < 0 or not Nodes.exists(id): mapped = false; print("UNMAPPED ",item," -> ",id)
	check(mapped,"every trail template material resolves to a real node")
	check(TrailRuins.SPACING == 34*16 and TrailRuins.SEPARATION == 8*16 and TrailRuins.DEPTH == 7,"source spacing, separation and seven-level depth are preserved")
	var site: Dictionary = {}; var region := Vector2i.ZERO
	for x in range(-4,5):
		for z in range(-4,5):
			var at := Vector2i(x,z); var candidate: Vector3i = TrailRuins.candidate(gen,at)
			check(candidate.y == gen.terrain_height(candidate.x,candidate.z)-15,"trail tower begins fifteen blocks below the surface")
			if not TrailRuins.eligible(gen,candidate): continue
			site = TrailRuins.plan(gen,at); region = at; break
		if not site.is_empty(): break
	check(not site.is_empty(),"eligible taiga, birch or jungle terrain receives trail ruins")
	if site.is_empty(): quit(1); return
	print("TRAIL SITE ",site.origin," region=",region," pieces=",site.pieces.size()," suspicious=",site.states.size())
	check(site.pieces.size() > 5 and site.pieces.any(func(p):return p.name == "trail_ruins_tower_top_1"),"tower grows its source top, roads and connected rooms")
	var overlaps: bool = false; var depth_ok: bool = true
	for i in site.pieces.size():
		depth_ok = depth_ok and site.pieces[i].depth <= 7
		for j in i:
			if site.pieces[i].box.grow(-0.01).intersects(site.pieces[j].box.grow(-0.01)): overlaps = true
	check(depth_ok and not overlaps,"connected pieces obey source depth and do not overlap")
	var rare: int = 0; var common: int = 0
	var expected: int = 0
	for p in site.pieces:
		var gravel: int = 0
		for encoded in templates[p.name].nodes:
			if templates[p.name].names[str((encoded >> 8)&65535)] == "mcl_core:gravel": gravel += 1
		expected += mini(gravel,int(p.entry.common)+int(p.entry.rare))
	check(site.states.size() == expected,"only processor-selected gravel receives loot; preexisting untagged suspicious nodes stay untagged")
	for p in site.states:
		check(site.voxels[p] == Archaeology.SUSPICIOUS_GRAVEL and site.states[p].has("archaeology_seed"),"a generated loot tag belongs to seeded suspicious gravel")
		if site.states[p].structure == "trail_ruins_rare": rare += 1
		else: common += 1
	check(rare >= 3 and common >= 8,"house and road processors create both source loot pools")
	check(TrailRuins.assemble(TerrainGenerator.new(8675309),site.origin) == site,"fresh generator reproduces the same rooms, erosion and loot seeds")
	check(not TrailRuins.eligible(TerrainGenerator.new(1,"nether"),Vector3i.ZERO),"trail ruins never enter the Nether")
	var coord := Vector2i(site.origin.x >> 4,site.origin.z >> 4)
	var a := PackedInt32Array(); a.resize(18*18*64); a.fill(Nodes.STONE)
	var d := PackedInt32Array(); d.resize(18*18*128); d.fill(Nodes.STONE)
	var metadata: Dictionary = TrailRuins.overlay(gen,coord,a,d)
	check(a.count(Nodes.AIR)+d.count(Nodes.AIR) > 0 and not metadata.states.is_empty(),"the overlay carves real source interiors and emits loot metadata")
	var b := PackedInt32Array(); b.resize(a.size()); b.fill(Nodes.STONE)
	var e := PackedInt32Array(); e.resize(d.size()); e.fill(Nodes.STONE)
	TrailRuins.overlay(gen,coord+Vector2i.RIGHT,b,e)
	var seam: bool = true
	for y in 64:
		for z in 18:
			for x in 2:
				if a[16+x+z*18+y*324] != b[x+z*18+y*324]: seam = false
	for y in 128:
		for z in 18:
			for x in 2:
				if d[16+x+z*18+y*324] != e[x+z*18+y*324]: seam = false
	check(seam,"neighboring column halos agree above and below zero")
	for x in 12: TrailRuins.plan(gen,Vector2i(x,0))
	check(gen.trail_cache.size() <= 8,"exploration keeps the assembled-ruin cache bounded")
	print("TRAIL TEMPLATE TESTS: ",failed," failed")
	quit(1 if failed else 0)
