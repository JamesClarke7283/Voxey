class_name TrailRuins
extends RefCounted

# Source templates, processors and pools: mcl_levelgen/trail_ruins.lua.
const SPACING = 544
const SEPARATION = 128
const SALT = 83469867
const RANGE = 80
const DEPTH = 7
static var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/trail_templates.json"))
const SIMPLE = {
	"air":Nodes.AIR,"mcl_core:dirt":Nodes.DIRT,"mcl_core:coarse_dirt":DryTerrain.COARSE_DIRT,
	"mcl_core:gravel":Nodes.GRAVEL,"mcl_core:stone":Nodes.STONE,"mcl_core:cobble":Nodes.COBBLE,
	"mcl_core:stonebrick":Nodes.BRICKS,"mcl_core:brick_block":Nodes.RED_BRICKS,
	"mcl_mud:mud_bricks":EndMud.MUD_BRICKS,"mcl_panes:bar":Nodes.IRON_BARS,"mcl_panes:bar_flat":Nodes.IRON_BARS,
	"mcl_sus_nodes:gravel":Archaeology.SUSPICIOUS_GRAVEL,
}

static func prepare(gen: TerrainGenerator) -> Dictionary:
	if not gen.trail_templates.is_empty(): return gen.trail_templates
	for name in source.templates:
		var t: Dictionary = source.templates[name].duplicate(true)
		var nodes := PackedInt64Array()
		for run in t.runs:
			for i in int(run[1]): nodes.append(int(run[0]))
		t.nodes = nodes; t.erase("runs")
		var joints: Array = []
		for raw in t.jigsaws:
			var index: int = int(raw)-1; var encoded: int = nodes[index]
			var joint: Dictionary = t.metadata[(encoded >> 24)-1].fields["mcl_levelgen:structure_jigsaw_save_data"].duplicate(true)
			joint.pos = Vector3i(index/(int(t.height)*int(t.length)),(index/int(t.length))%int(t.height),index%int(t.length))
			joint.dir = TrialChambers.direction(encoded&255); joint.roll = (encoded&255)%4
			joints.append(joint)
		t.joints = joints
		gen.trail_templates[name] = t
	return gen.trail_templates

static func candidate(gen: TerrainGenerator, region: Vector2i) -> Vector3i:
	var rng := RandomNumberGenerator.new(); rng.seed = gen.hash_at(region.x,SALT,region.y)
	var x: int = region.x*SPACING+rng.randi_range(0,SPACING-SEPARATION-1)
	var z: int = region.y*SPACING+rng.randi_range(0,SPACING-SEPARATION-1)
	return Vector3i(x,gen.terrain_height(x,z)-15,z)

static func eligible(gen: TerrainGenerator, p: Vector3i) -> bool:
	# The local generator's spruce, birch and jungle regions are the available
	# counterparts of the source's taigas, old-growth birch forest and jungle.
	return gen.dimension == "overworld" and WoodTypes.natural_species(gen,p.x,p.z) in [1,2,3]

static func plan(gen: TerrainGenerator, region: Vector2i) -> Dictionary:
	if gen.trail_cache.has(region): return gen.trail_cache[region]
	var origin: Vector3i = candidate(gen,region)
	var result: Dictionary = assemble(gen,origin) if eligible(gen,origin) else {}
	if gen.trail_cache.size() >= 8: gen.trail_cache.erase(gen.trail_cache.keys()[0])
	gen.trail_cache[region] = result
	return result

static func piece(t: Dictionary, entry: Dictionary, origin: Vector3i, turn: int, depth: int) -> Dictionary:
	return {"name":entry.name,"entry":entry,"origin":origin,"turn":turn,"depth":depth,"box":TrialChambers.box(t,origin,turn)}

static func assemble(gen: TerrainGenerator, origin: Vector3i) -> Dictionary:
	var templates: Dictionary = prepare(gen)
	var rng := RandomNumberGenerator.new(); rng.seed = gen.hash_at(origin.x,SALT+origin.y,origin.z)
	var first: Dictionary = source.pools.trail_ruins_tower[0]
	var pieces: Array = [piece(templates[first.name],first,origin,rng.randi_range(0,3),0)]
	var cursor: int = 0
	while cursor < pieces.size() and pieces.size() < 160:
		var parent: Dictionary = pieces[cursor]; cursor += 1
		if parent.depth >= DEPTH: continue
		for joint in templates[parent.name].joints:
			var pool: Array = source.pools.get(str(joint.target_pool).trim_prefix("mcl_levelgen:"),[])
			var choices: Array = []
			for entry in pool:
				for i in int(entry.weight): choices.append(entry)
			for i in range(choices.size()-1,0,-1):
				var j: int = rng.randi_range(0,i); var swap: Variant = choices[i]; choices[i] = choices[j]; choices[j] = swap
			var pos: Vector3i = parent.origin+TrialChambers.rotate(joint.pos,parent.turn)
			var facing: Vector3i = TrialChambers.rotate(joint.dir,parent.turn)
			var joined: bool = false
			for entry in choices:
				var t: Dictionary = templates[entry.name]
				for connector in t.joints:
					if connector.name != joint.target_name: continue
					for turn in 4:
						if TrialChambers.rotate(connector.dir,turn) != -facing: continue
						if absi(facing.y) == 1 and posmod(int(connector.roll)+turn,4) != posmod(int(joint.roll)+int(parent.turn),4): continue
						var at: Vector3i = pos+facing-TrialChambers.rotate(connector.pos,turn)
						var next: Dictionary = piece(t,entry,at,turn,int(parent.depth)+1)
						var box: AABB = next.box
						if box.position.x < origin.x-RANGE or box.end.x > origin.x+RANGE or box.position.z < origin.z-RANGE or box.end.z > origin.z+RANGE: continue
						if box.position.y <= gen.min_y() or box.end.y >= gen.terrain_ceiling(): continue
						if pieces.any(func(previous): return box.grow(-0.01).intersects(previous.box.grow(-0.01))): continue
						pieces.append(next); joined = true; break
					if joined: break
				if joined: break
	var result: Dictionary = {"origin":origin,"pieces":pieces,"voxels":{},"states":{}}
	for p in pieces: materialize(gen,result,p,templates[p.name])
	return result

static func node_id(name: String, param: int, turn: int) -> int:
	if SIMPLE.has(name): return SIMPLE[name]
	if name == "mcl_levelgen:structure_void": return -1
	if name.begins_with("mcl_colorblocks:"):
		var glazed: bool = "glazed_terracotta_" in name
		var color: String = name.trim_prefix("mcl_colorblocks:glazed_terracotta_" if glazed else "mcl_colorblocks:hardened_clay_")
		var index: int = GlassColors.COLORS.find(color)
		return (VillageContent.GLAZED_WHITE if glazed else VillageContent.TERRACOTTA_WHITE)+index if index >= 0 else -1
	if name.begins_with("mcl_stairs:slab_mud_brick"):
		return BuildingShapes.slab_for(EndMud.MUD_BRICKS)+(2 if name.ends_with("double") else (1 if param >= 20 else 0))
	return -1

static func materialize(gen: TerrainGenerator, result: Dictionary, p: Dictionary, t: Dictionary) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = gen.hash_at(p.origin.x,SALT+p.origin.y,p.origin.z)
	var gravel: Array = []
	for i in t.nodes.size():
		var value: int = t.nodes[i]
		if value <= 0xffffffff and t.names[str((value >> 8)&65535)] == "mcl_core:gravel": gravel.append(i)
	for i in range(gravel.size()-1,0,-1):
		var j: int = rng.randi_range(0,i); var old: int = gravel[i]; gravel[i] = gravel[j]; gravel[j] = old
	var selected: Dictionary = {}
	for i in mini(gravel.size(),int(p.entry.common)+int(p.entry.rare)):
		selected[gravel[i]] = "trail_ruins_common" if i < int(p.entry.common) else "trail_ruins_rare"
	for i in t.nodes.size():
		var value: int = t.nodes[i]
		if value > 0xffffffff: continue
		var name: String = t.names[str((value >> 8)&65535)]
		if name == "mcl_levelgen:jigsaw_block": name = t.metadata[(value >> 24)-1].fields["mcl_levelgen:structure_jigsaw_save_data"].turns_into
		var id: int = node_id(name,value&255,p.turn)
		if id < 0: continue
		var local := Vector3i(i/(int(t.height)*int(t.length)),(i/int(t.length))%int(t.height),i%int(t.length))
		var pos: Vector3i = p.origin+TrialChambers.rotate(local,p.turn)
		if p.entry.degrade:
			if id == Nodes.GRAVEL:
				if rng.randf() < 0.2: id = Nodes.DIRT
				elif rng.randf() < 0.1: id = DryTerrain.COARSE_DIRT
			elif id == EndMud.MUD_BRICKS and rng.randf() < 0.1: id = EndMud.PACKED_MUD
		if selected.has(i):
			id = Archaeology.SUSPICIOUS_GRAVEL
			result.states[pos] = {"structure":selected[i],"archaeology_seed":rng.randi()}
		# Existing suspicious gravel has no loot metadata in these templates.
		# Only the processor-selected ordinary gravel receives a reward.
		result.voxels[pos] = id

static func overlay(gen: TerrainGenerator, coord: Vector2i, data: PackedInt32Array, deep: PackedInt32Array) -> Dictionary:
	var result: Dictionary = {"states":{}}
	if gen.dimension != "overworld": return result
	var low: Vector2i = coord*16-Vector2i.ONE
	for x in range(floori((low.x-RANGE)/float(SPACING)),floori((low.x+17+RANGE)/float(SPACING))+1):
		for z in range(floori((low.y-RANGE)/float(SPACING)),floori((low.y+17+RANGE)/float(SPACING))+1):
			var center: Vector3i = candidate(gen,Vector2i(x,z))
			if center.x+RANGE < low.x or center.x-RANGE > low.x+17 or center.z+RANGE < low.y or center.z-RANGE > low.y+17: continue
			var site: Dictionary = plan(gen,Vector2i(x,z))
			for pos in site.get("voxels",{}):
				var lx: int = pos.x-low.x; var lz: int = pos.z-low.y
				if lx < 0 or lx >= 18 or lz < 0 or lz >= 18: continue
				if pos.y < gen.min_y() or pos.y >= gen.terrain_ceiling(): continue
				if pos.y < 0: deep[lx+lz*18+(pos.y-gen.min_y())*324] = site.voxels[pos]
				else: data[lx+lz*18+pos.y*324] = site.voxels[pos]
				if site.states.has(pos): result.states[pos] = site.states[pos]
	return result

static func install(world: VoxelWorld, result: Dictionary) -> void:
	for p in result.get("trails",{}).get("states",{}):
		if Vector2i(p.x >> 4,p.z >> 4) != result.coord or world.edits.has(p) or not Archaeology.is_suspicious(world.node_at(p)): continue
		var key: String = VoxelWorld.station_key(p)
		if not world.block_states.has(key): world.block_states[key] = result.trails.states[p].duplicate(true)

static func nearest(gen: TerrainGenerator, pos: Vector3) -> Vector3i:
	var region := Vector2i(floori(pos.x/SPACING),floori(pos.z/SPACING))
	var found := Vector3i.ZERO; var distance: float = INF
	for x in range(region.x-6,region.x+7):
		for z in range(region.y-6,region.y+7):
			var p: Vector3i = candidate(gen,Vector2i(x,z))
			if not eligible(gen,p): continue
			var gap: float = Vector2(p.x-pos.x,p.z-pos.z).length_squared()
			if gap < distance: distance = gap; found = p
	return found
