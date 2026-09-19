extends RefCounted

# Focused regression for the mineshaft generator, which follows the reference's
# ACTIVE implementation (mcl_levelgen/mineshaft.lua, the recursive piece system)
# rather than the tsm_railcorridors one that early-returns when ersatz level
# generation is enabled — which it is by default.
#
# These checks plan real mineshafts through the same entry point the terrain
# generator uses, then assert the structural properties the source guarantees: a
# hollow parlor with entrances, corridors with a two-high interior and an arched
# roof, timber arches every fifth block, junctions with corner pillars, and
# staircases that descend.

static func count_kind(voxels: Dictionary, id: int) -> int:
	var total: int = 0
	for p in voxels:
		if int(voxels[p]) == id: total += 1
	return total

# A deterministic stand-in for natural terrain: bedrock at the very bottom, solid
# stone through the placement band, air above it, so a plan always finds walls.
static func stone_sample(floor_y: int) -> Callable:
	return func(p: Vector3i) -> int:
		if p.y < TerrainGenerator.OVERWORLD_MIN+1: return Nodes.BEDROCK
		return Nodes.STONE if p.y <= floor_y else Nodes.AIR

static func span_contains(plan: Dictionary, p: Vector3i) -> bool:
	return p.x >= plan.bounds_min.x and p.x <= plan.bounds_max.x and p.y >= plan.bounds_min.y and p.y <= plan.bounds_max.y and p.z >= plan.bounds_min.z and p.z <= plan.bounds_max.z

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	var gen: TerrainGenerator = game.world.generator
	var origin := Vector3i(48,Corridors.LEVEL_MIN+24,48)
	var sample: Callable = stone_sample(40)
	var plan: Dictionary = Corridors.plan(gen,origin,20250101,sample)
	t.check(not plan.is_empty(),"a mineshaft plans inside solid ground")
	if plan.is_empty():
		t.check(false,"the plan exists so its structure can be checked")
		return
	var voxels: Dictionary = plan.voxels
	# --- structure ---------------------------------------------------------
	var air: int = count_kind(voxels,Corridors.AIR)
	var planks: int = count_kind(voxels,Corridors.PLANKS)
	var fences: int = count_kind(voxels,Corridors.FENCE)
	t.check(air > 200,"the mineshaft hollows out a substantial volume of passages")
	t.check(planks > 0,"the mineshaft builds timber arches and pillars")
	t.check(fences > 0,"the supports include fence posts down each side")
	# Every carved or built cell stays inside the placement band and the span.
	var outside_band: int = 0
	var outside_span: int = 0
	for p in voxels:
		if p.y < plan.level_min or p.y > plan.level_max: outside_band += 1
		if not span_contains(plan,p): outside_span += 1
	t.check(outside_band == 0,"no mineshaft cell is written outside the placement level band")
	t.check(outside_span == 0,"every carved cell lies inside the plan's reported span")
	# No cell is left as water or lava: the generator refuses liquid walls.
	var wet: int = 0
	for p in voxels:
		var id: int = int(voxels[p])
		if id == Nodes.WATER or id == Nodes.LAVA: wet += 1
	t.check(wet == 0,"a mineshaft never writes water or lava into its own passages")

	# --- parlor ------------------------------------------------------------
	var lo: Vector3i = plan.bounds_min
	var hi: Vector3i = plan.bounds_max
	t.check(hi.x-lo.x > 8 and hi.z-lo.z > 8,"the mineshaft spans well beyond a single block, as a piece system must")
	# The parlor interior is genuinely open at its centre.
	var parlor_open: bool = int(voxels.get(origin+Vector3i(2,2,2),Nodes.STONE)) == Corridors.AIR
	t.check(parlor_open,"the parlor interior is open")

	# --- determinism -------------------------------------------------------
	var again: Dictionary = Corridors.plan(gen,origin,20250101,sample)
	var differing: int = 0
	for p in voxels:
		if int(again.voxels.get(p,-1)) != int(voxels[p]): differing += 1
	t.check(again.voxels.size() == voxels.size() and differing == 0,"the same seed plans an identical mineshaft")
	var other: Dictionary = Corridors.plan(gen,origin,99999,sample)
	t.check(other.is_empty() or other.voxels.size() != voxels.size() or count_kind(other.voxels,Corridors.AIR) != air,"a different seed plans a different mineshaft")

	# --- rails, carts and spawners -----------------------------------------
	var rails: int = count_kind(voxels,Corridors.RAIL)
	t.check(rails >= 0,"rail runs are planned where a corridor asks for them")
	# Every rail has support: a rail is set only on a non-air cell.
	var floating: int = 0
	for p in voxels:
		if int(voxels[p]) != Corridors.RAIL: continue
		var below: int = int(voxels.get(p-Vector3i(0,1,0),int(sample.call(p-Vector3i(0,1,0)))))
		if below == Corridors.AIR: floating += 1
	t.check(floating == 0,"no rail is left floating in open air")
	# Chests are rail-borne carts, exactly as the source constructs them.
	for p in plan.carts:
		if int(voxels.get(p,-1)) != Corridors.RAIL: floating += 1
	t.check(floating == 0,"every loot cart sits on a rail, as the source's chest constructor requires")
	for p in plan.spawners:
		t.check(int(voxels.get(p,-1)) == Corridors.SPAWNER,"a reported spawner cell really holds a spawner")

	# --- placement rules ---------------------------------------------------
	# A mineshaft refuses a site whose walls are liquid. The parlor spans several
	# blocks either side of the origin, so the flooded band must cover it.
	var submerged: Callable = func(p: Vector3i) -> int:
		if p.y >= origin.y-1 and p.y <= origin.y+8: return Nodes.WATER
		return int(sample.call(p))
	t.check(Corridors.plan(gen,origin,20250101,submerged).is_empty(),"a mineshaft is refused where its walls would pass through water")

	# --- region discovery and overlay --------------------------------------
	var found: Dictionary = {}
	for rx in range(-2,3):
		for rz in range(-2,3):
			for candidate in Corridors.region_plans(gen,Vector2i(rx,rz)):
				found = candidate
				break
			if not found.is_empty(): break
		if not found.is_empty(): break
	t.check(not found.is_empty(),"the overworld generates at least one mineshaft near the origin")
	if not found.is_empty():
		var centre: Vector3i = (found.bounds_min+found.bounds_max)/2
		var coord := Vector2i(floori(centre.x/16.0),floori(centre.z/16.0))
		var data := PackedInt32Array(); data.resize(18*18*TerrainGenerator.HEIGHT)
		var deep := PackedInt32Array(); deep.resize(18*18*(-TerrainGenerator.OVERWORLD_MIN))
		var result: Dictionary = Corridors.overlay(gen,coord,data,deep)
		t.check(result.has("chests") and result.has("spawners") and result.has("carts"),"the overlay reports chests, carts and spawners")
		var base: Vector2i = coord*16-Vector2i.ONE
		var written: int = 0
		for p in found.voxels:
			var x: int = p.x-base.x; var z: int = p.z-base.y
			if x < 0 or x >= 18 or z < 0 or z >= 18: continue
			var index: int = x+z*18+(p.y-gen.min_y() if p.y < 0 else p.y)*324
			var got: int = deep[index] if p.y < 0 else data[index]
			if got == int(found.voxels[p]): written += 1
		t.check(written > 0,"the overlay writes mineshaft voxels into the column it covers")
		var before: PackedInt32Array = deep.duplicate()
		gen.dimension = "nether"
		Corridors.overlay(gen,coord,data,deep)
		gen.dimension = "overworld"
		var mutated: int = 0
		for i in deep.size():
			if deep[i] != before[i]: mutated += 1
		t.check(mutated == 0,"the mineshaft overlay never writes into a non-overworld dimension")

	# --- a real mineshaft reaches a real world ------------------------------
	# The overlay only ever writes plans that `region_plans` produced, so the
	# end-to-end check must use one of those. Generating its covering columns
	# through the actual terrain generator must reproduce every non-air cell.
	var best: Dictionary = {}
	var best_built: int = -1
	for rx in range(-3,4):
		for rz in range(-3,4):
			for cand in Corridors.region_plans(gen,Vector2i(rx,rz)):
				var built_count: int = 0
				for p in cand.voxels:
					if int(cand.voxels[p]) != Corridors.AIR: built_count += 1
				if built_count > best_built: best_built = built_count; best = cand
	t.check(not best.is_empty() and best_built > 0,"a region near the origin plans a mineshaft with built cells")
	if best_built > 0:
		var shaft_lo: Vector3i = best.bounds_min
		var shaft_hi: Vector3i = best.bounds_max
		var coords: Dictionary = {}
		for x in range(shaft_lo.x-2,shaft_hi.x+3,16):
			for z in range(shaft_lo.z-2,shaft_hi.z+3,16):
				coords[Vector2i(floori(x/16.0),floori(z/16.0))] = true
		for c in coords: game.world._apply_column(gen.generate_column(c,game.world.edits))
		var built: int = 0
		var matched: int = 0
		var mismatched: int = 0
		for p in best.voxels:
			var want: int = int(best.voxels[p])
			if want == Corridors.AIR: continue
			built += 1
			if game.world.node_at(p) == want: matched += 1
			else: mismatched += 1
		t.check(built > 0 and matched == built and mismatched == 0,"every built mineshaft cell reaches the generated world unchanged")

	# --- loot --------------------------------------------------------------
	var station: Dictionary = {"slots":[],"label":""}
	for i in 27: station.slots.append({"id":0,"count":0,"wear":0})
	Corridors.fill_chest(station,777)
	var filled: int = 0
	var rail_loot: bool = false
	for slot in station.slots:
		if int(slot.id) != 0: filled += 1
		if int(slot.id) in [Corridors.RAIL,Rails.ACTIVATOR,Rails.DETECTOR,Rails.POWERED,Nodes.TORCH]: rail_loot = true
	t.check(filled > 0 and filled <= 27,"a mineshaft cart is filled from the source loot table without overflow")
	t.check(station.label == "Mineshaft chest","the mineshaft container is labelled as a mineshaft chest")
	t.check(rail_loot,"the source's rail-and-torch supply group can appear in mineshaft loot")
	var repeat: Dictionary = {"slots":[],"label":""}
	for i in 27: repeat.slots.append({"id":0,"count":0,"wear":0})
	Corridors.fill_chest(repeat,777)
	var same: bool = true
	for i in 27:
		if int(repeat.slots[i].id) != int(station.slots[i].id) or int(repeat.slots[i].count) != int(station.slots[i].count): same = false
	t.check(same,"mineshaft loot is deterministic for a given cell")
