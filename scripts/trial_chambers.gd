class_name TrialChambers
extends RefCounted

# Source room templates and pools: mcl_levelgen/trial_chambers.lua. Coordinates
# are joined by named jigsaws; these are the source rooms, not proxy buildings.
# The placement RNG and terrain embedding use Voxey's deterministic generator.
const SPACING = 544
const SEPARATION = 192
const RANGE = 116
const MAX_DEPTH = 20
static var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/trial_templates.json"))
const SIMPLE = {
	"air":Nodes.AIR,"mcl_core:stone":Nodes.STONE,"mcl_core:dirt":Nodes.DIRT,"mcl_core:podzol":SoilVariants.PODZOL,"mcl_core:mycelium":SoilVariants.MYCELIUM,
	"mcl_core:water_source":Nodes.WATER,"mcl_core:water_flowing":Nodes.WATER,
	"mcl_core:cobble":Nodes.COBBLE,"mcl_core:mossycobble":Nodes.MOSSY_COBBLE,"mcl_core:stonebrick":Nodes.BRICKS,
	"mcl_core:goldblock":Nodes.GOLD_BLOCK,"mcl_core:diamondblock":Nodes.DIAMOND_BLOCK,
	"mcl_core:bone_block":DenseMaterials.BONE,"mcl_core:packed_ice":DenseMaterials.PACKED_ICE,
	"mcl_core:sandstonecarved":Nodes.SANDSTONE_BRICK,"mcl_core:cobweb":VillageContent.COBWEB,
	"mcl_core:glass_purple":GlassColors.FIRST+8,"mcl_core:ladder":Nodes.LADDER,
	"mcl_deepslate:tuff":MinecloniaOres.TUFF,"mcl_deepslate:tuff_bricks":Masonry.TUFF_BRICKS,
	"mcl_deepslate:tuff_polished":Masonry.POLISHED_TUFF,"mcl_deepslate:tuff_chiseled":Masonry.CHISELED_TUFF,
	"mcl_deepslate:tuff_chiseled_bricks":Masonry.CHISELED_TUFF_BRICKS,
	"mcl_barrels:barrel_closed":VillageContent.BARREL,"mcl_chests:chest_small":Nodes.CHEST,
	"mcl_dispensers:dispenser":Nodes.DISPENSER,"mcl_lush_caves:moss":VillageContent.MOSS,
	"mcl_mushrooms:mushroom_red":Nodes.RED_MUSHROOM,"mcl_nether:magma":VillageContent.MAGMA,
	"mcl_trees:tree_oak":Nodes.LOG,"mcl_trees:leaves_oak":Nodes.LEAVES,
	"mcl_pottery_sherds:pot":Archaeology.POT,"mcl_flowerpots:flower_pot":Decor.POT,
	"mcl_flowerpots:flower_pot_allium":Decor.POT,"mcl_trial_spawners:trialspawner":Trials.SPAWNER,
	"mcl_vaults:vault":Trials.VAULT,"mcl_vaults:ominous_vault":Trials.OMINOUS_VAULT,
}

static func rotate(v: Vector3i, turns: int) -> Vector3i:
	for i in posmod(turns,4): v = Vector3i(-v.z,v.y,v.x)
	return v

static func direction(param: int) -> Vector3i:
	return [Vector3i.UP,Vector3i.FORWARD,Vector3i.BACK,Vector3i.RIGHT,Vector3i.LEFT,Vector3i.DOWN][clampi(param/4,0,5)]

static func prepare(gen: TerrainGenerator) -> Dictionary:
	if gen.trial_templates.is_empty():
		for name in source.templates:
			var template: Dictionary = source.templates[name].duplicate(true)
			var nodes := PackedInt64Array()
			for run in template.runs:
				for i in int(run[1]): nodes.append(int(run[0]))
			template.nodes = nodes; template.erase("runs")
			var joints: Array = []
			for raw in template.jigsaws:
				var index: int = int(raw)-1
				var encoded: int = nodes[index]
				var fields: Dictionary = template.metadata[(encoded >> 24)-1].fields
				var joint: Dictionary = fields["mcl_levelgen:structure_jigsaw_save_data"].duplicate(true)
				joint.pos = Vector3i(index/(int(template.height)*int(template.length)),(index/int(template.length))%int(template.height),index%int(template.length))
				joint.dir = direction(encoded&255); joint.roll = (encoded&255)%4
				joints.append(joint)
			template.joints = joints
			gen.trial_templates[name] = template
	return gen.trial_templates

static func anchor(gen: TerrainGenerator, region: Vector2i) -> Vector3i:
	var rng := RandomNumberGenerator.new(); rng.seed = gen.hash_at(region.x,94251327,region.y)
	return Vector3i(region.x*SPACING+rng.randi_range(0,SPACING-SEPARATION-1),rng.randi_range(-40,-20),region.y*SPACING+rng.randi_range(0,SPACING-SEPARATION-1))

static func box(template: Dictionary, origin: Vector3i, turn: int) -> AABB:
	var opposite: Vector3i = origin+rotate(Vector3i(int(template.width)-1,int(template.height)-1,int(template.length)-1),turn)
	var low: Vector3i = origin.min(opposite); var high: Vector3i = origin.max(opposite)
	return AABB(Vector3(low),Vector3(high-low+Vector3i.ONE))

static func plan(gen: TerrainGenerator, region: Vector2i) -> Dictionary:
	if gen.trial_cache.has(region): return gen.trial_cache[region]
	var templates: Dictionary = prepare(gen)
	var origin: Vector3i = anchor(gen,region)
	var rng := RandomNumberGenerator.new(); rng.seed = gen.hash_at(origin.x,origin.y+94251327,origin.z)
	var name: String = "trial_chambers_corridor_end_1"
	var pieces: Array = [{"name":name,"origin":origin,"turn":rng.randi_range(0,3),"depth":0,"parent":-1}]
	pieces[0].box = box(templates[name],origin,pieces[0].turn)
	var index: int = 0
	while index < pieces.size() and pieces.size() < 160:
		var parent: Dictionary = pieces[index]; var template: Dictionary = templates[parent.name]
		if parent.depth >= MAX_DEPTH: index += 1; continue
		for joint in template.joints:
			if pieces.size() >= 160: break
			var pool: Array = source.pools.get(str(joint.target_pool).trim_prefix("mcl_levelgen:"),[])
			if pool.is_empty(): continue
			var candidates: Array = []
			for entry in pool:
				for i in int(entry[1]): candidates.append(entry[0])
			# Weighted sampling without replacement, as source pool expansion does.
			for i in range(candidates.size()-1,0,-1):
				var other: int = rng.randi_range(0,i); var old: Variant = candidates[i]; candidates[i] = candidates[other]; candidates[other] = old
			var position: Vector3i = parent.origin+rotate(joint.pos,parent.turn)
			var facing: Vector3i = rotate(joint.dir,parent.turn)
			var interior: bool = parent.box.grow(-0.01).has_point(Vector3(position+facing))
			var joined: bool = false
			for candidate in candidates:
				var target: Dictionary = templates[candidate]
				for connection in target.joints:
					if connection.name != joint.target_name: continue
					for turn in 4:
						if rotate(connection.dir,turn) != -facing: continue
						if absi(facing.y) == 1 and posmod(int(connection.roll)+turn,4) != posmod(int(joint.roll)+int(parent.turn),4): continue
						var at: Vector3i = position+facing-rotate(connection.pos,turn)
						var bounds: AABB = box(target,at,turn)
						if absf(bounds.get_center().x-origin.x) > RANGE or absf(bounds.get_center().z-origin.z) > RANGE: continue
						if bounds.position.y <= WorldBounds.OVERWORLD_MIN or bounds.end.y >= 60: continue
						if interior and not parent.box.encloses(bounds): continue
						var overlap: bool = false
						for previous in pieces:
							if interior and previous == parent: continue
							if interior and previous.parent != index: continue
							if bounds.grow(-0.01).intersects(previous.box.grow(-0.01)): overlap = true; break
						if overlap: continue
						pieces.append({"name":candidate,"origin":at,"turn":turn,"depth":int(parent.depth)+1,"parent":index if interior else -1,"box":bounds})
						joined = true; break
					if joined: break
				if joined: break
		index += 1
	var result: Dictionary = {"origin":origin,"pieces":pieces}
	if gen.trial_cache.size() >= 8: gen.trial_cache.erase(gen.trial_cache.keys()[0])
	gen.trial_cache[region] = result
	return result

static func stage(name: String) -> int:
	if "oxidized" in name: return 3
	if "weathered" in name: return 2
	if "exposed" in name: return 1
	return 0

static func node_id(name: String, param: int, turn: int) -> int:
	if SIMPLE.has(name): return SIMPLE[name]
	if name in ["mcl_levelgen:structure_void","mcl_levelgen:jigsaw_block","mcl_levelgen:structure_block_data"]: return -1
	if name.begins_with("mcl_beds:"): return Nodes.BED_HEAD if name.ends_with("_top") else Nodes.BED_FOOT
	if name == "mcl_flowers:waterlily": return VillageContent.LILY_PAD
	if name == "mcl_farming:pumpkin_face": return FruitCrops.CARVED+posmod(param+turn,4)
	if name.begins_with("mcl_flowers:"):
		var text: String = name.get_slice(":",1).replace("waterlily","Lily pad").capitalize()
		for id in FlowersExtra.DATA:
			if str(FlowersExtra.DATA[id].name).nocasecmp_to(text) == 0: return id
	if name == "mcl_wool:purple_carpet": return VillageContent.CARPET_PURPLE
	if name.begins_with("mcl_candles:"):
		return Candles.FIRST+clampi(param/8,0,15)*8+(4 if "lit" in name else 0)+int(name.right(1))-1
	if name.begins_with("mcl_buttons:"): return RedstoneInputs.oriented(RedstoneInputs.FIRST+8,rotate(direction(param),turn))
	if name == "mcl_doors:trapdoor_spruce_open": return Trapdoors.ITEMS[1]+8+posmod(param+turn,4)
	var level: int = stage(name)
	if name.begins_with("mcl_stairs:"):
		var material: int = Masonry.TUFF_BRICKS if "tuff" in name else Copper.CUT_STAGES[level]
		var slab: int = BuildingShapes.slab_for(material)
		if "slab" in name: return slab+(2 if "double" in name else (1 if "top" in name else 0))
		return slab+3+posmod(param%4+turn,4)+(4 if param>=20 else 0)
	if name.begins_with("mcl_copper:"):
		if "trapdoor" in name: return Copper.TRAPDOOR_ITEMS[level]+8+posmod(param+turn,4)
		if "door" in name: return Doors.state_id(Copper.DOOR_ITEMS[level],posmod(param+turn,4),false,false,"_t_" in name)
		if "bulb" in name: return Copper.BULB_ON_STAGES[level]
		if "grate" in name: return Copper.GRATE_STAGES[level]
		if "chiseled" in name: return Copper.CHISELED_STAGES[level]
		if "cut" in name: return Copper.CUT_STAGES[level]
		return Copper.BLOCK_STAGES[level]
	if name.begins_with("mcl_lanterns:"):
		if "chain" in name: return CopperDecor.CHAIN_STAGES[level]
		return CopperDecor.LANTERN_CEILING_STAGES[level] if "ceiling" in name else CopperDecor.LANTERN_FLOOR_STAGES[level]
	if name.begins_with("mcl_lightning_rods:"): return Copper.ROD_STAGES[level]
	if name.begins_with("mcl_panes:"): return CopperDecor.BARS+level
	return -1

static func overlay(gen: TerrainGenerator, coord: Vector2i, data: PackedInt32Array, deep: PackedInt32Array) -> Dictionary:
	var result: Dictionary = {"states":{},"stations":{}}
	if gen.dimension != "overworld": return result
	var low := Vector2i(coord.x*16-1,coord.y*16-1)
	var templates: Dictionary = {}
	var memo: Dictionary = {}
	for rx in range(floori((low.x-RANGE)/float(SPACING)),floori((low.x+17+RANGE)/float(SPACING))+1):
		for rz in range(floori((low.y-RANGE)/float(SPACING)),floori((low.y+17+RANGE)/float(SPACING))+1):
			var center: Vector3i = anchor(gen,Vector2i(rx,rz))
			if center.x+RANGE < low.x or center.x-RANGE > low.x+17 or center.z+RANGE < low.y or center.z-RANGE > low.y+17: continue
			if templates.is_empty(): templates = prepare(gen)
			for piece in plan(gen,Vector2i(rx,rz)).pieces:
				var template: Dictionary = templates[piece.name]
				var bounds: AABB = piece.box
				if bounds.end.x <= low.x or bounds.position.x > low.x+17 or bounds.end.z <= low.y or bounds.position.z > low.y+17: continue
				for x in range(maxi(low.x,int(bounds.position.x)),mini(low.x+18,int(bounds.end.x))):
					for z in range(maxi(low.y,int(bounds.position.z)),mini(low.y+18,int(bounds.end.z))):
						var local: Vector3i = rotate(Vector3i(x,0,z)-piece.origin,-int(piece.turn))
						for y in int(template.height):
							var pos := Vector3i(x,int(piece.origin.y)+y,z)
							var encoded: int = template.nodes[(local.x*int(template.height)+y)*int(template.length)+local.z]
							if encoded > 0xffffffff: continue
							var name: String = template.names[str((encoded >> 8)&65535)]
							var fields: Dictionary = {}
							if encoded >> 24 > 0: fields = template.metadata[(encoded >> 24)-1].fields
							if name == "mcl_levelgen:jigsaw_block": name = fields["mcl_levelgen:structure_jigsaw_save_data"].turns_into
							if name == "mcl_levelgen:structure_block_data":
								var info: Dictionary = fields.get("mcl_levelgen:structure_data_save_data",{})
								if info.get("value","") == "mcl_levelgen:set_loot_table": result.stations[pos+Vector3i.DOWN] = {"loot_table":info.param1}
								name = "air"
							var token: String = name+":"+str(encoded&255)+":"+str(piece.turn)
							if not memo.has(token): memo[token] = node_id(name,encoded&255,int(piece.turn))
							var id: int = memo[token]
							if id < 0: continue
							if pos.y < 0: deep[x-low.x+(z-low.y)*18+(pos.y-gen.min_y())*324] = id
							elif pos.y < gen.terrain_ceiling(): data[x-low.x+(z-low.y)*18+pos.y*324] = id
							var state: Dictionary = {}
							if "preserved" in name: state.copper_waxed = true
							if id == Decor.POT and "allium" in name: state.pot_plant = node_id("mcl_flowers:allium",0,0)
							if id == Trials.SPAWNER: result.stations[pos] = {"mob":str(fields.get("mob","mobs_mc:zombie")).trim_prefix("mobs_mc:")}
							if id == Archaeology.POT:
								var rng := RandomNumberGenerator.new(); rng.seed = gen.hash_at(x,pos.y+94251327,z)
								var face: String = ["flow","guster","scrape"][rng.randi_range(0,2)]
								state.pot_patterns = [face,face,face,face]
								state.trial_pot_loot = TrialLoot.roll("trial_chambers_pot",rng)
							if not state.is_empty(): result.states[pos] = state
	return result

static func install(world: VoxelWorld, result: Dictionary) -> void:
	var plan_data: Dictionary = result.get("trials",{})
	for p in plan_data.get("states",{}):
		if Vector2i(p.x >> 4,p.z >> 4) != result.coord or world.edits.has(p): continue
		var key: String = VoxelWorld.station_key(p)
		if not world.block_states.has(key): world.block_states[key] = plan_data.states[p].duplicate(true)
	for p in plan_data.get("stations",{}):
		if Vector2i(p.x >> 4,p.z >> 4) != result.coord or world.edits.has(p): continue
		var key: String = VoxelWorld.station_key(p)
		if world.stations.has(key): continue
		var info: Dictionary = plan_data.stations[p]
		if Trials.is_spawner(world.node_at(p)): Trials.station(world,p).mob = info.get("mob","zombie")
		elif info.has("loot_table") and world.node_at(p) in [Nodes.CHEST,VillageContent.BARREL,Nodes.DISPENSER]:
			var table_name: String = str(info.loot_table).trim_prefix("mcl_levelgen:")
			if not TrialLoot.tables().has(table_name): continue
			fill_container(world,p,table_name)

static func fill_container(world: VoxelWorld, p: Vector3i, table_name: String) -> void:
	# Use the same permanent per-half ledger as other generated structures.
	# An opened or emptied chest must never become new loot after merging.
	var ledger: Dictionary = world._structure_loot_ledger()
	var key: String = VoxelWorld.station_key(p)
	if ledger.has(key): return
	if world.stations.has(key): ledger[key] = true; return
	var partner: Vector3i = world.chest_partner(p) if world.node_at(p) == Nodes.CHEST else p
	var shared: String = world.pair_key(p,partner) if partner != p else ""
	if not shared.is_empty() and world.stations.has(shared):
		if not ledger.has(VoxelWorld.station_key(partner)):
			ledger[key] = true; ledger[VoxelWorld.station_key(partner)] = true; return
		var offset: int = 0 if world.chest_primary(p,partner) == p else 27
		for slot in world.stations[shared].slots.slice(offset,offset+27):
			if int(slot.get("count",0)) > 0: ledger[key] = true; return
	var storage: Dictionary = world._new_station("chest",9 if world.node_at(p) == Nodes.DISPENSER else 27)
	TrialLoot.fill(storage,table_name,world.generator.hash_at(p.x,p.y+94251327,p.z))
	world._store_structure_loot(p,storage,shared)

static func nearest(gen: TerrainGenerator, position: Vector3) -> Vector3i:
	var region := Vector2i(floori(position.x/SPACING),floori(position.z/SPACING))
	var found := Vector3i.ZERO; var distance: float = INF
	for x in range(region.x-1,region.x+2):
		for z in range(region.y-1,region.y+2):
			var candidate: Vector3i = anchor(gen,Vector2i(x,z))
			var gap: float = Vector2(candidate.x-position.x,candidate.z-position.z).length_squared()
			if gap < distance: distance = gap; found = candidate
	return found
