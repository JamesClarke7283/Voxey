extends RefCounted

const P = Vector3i(40,2800,40)

static func ensure(game: Node3D, p: Vector3i) -> bool:
	var world: VoxelWorld = game.world
	if world.loaded_at(Vector3(p)): return true
	world._apply_column(world.generator.generate_column(Vector2i(floori(p.x/16.0),floori(p.z/16.0)),world.edits))
	return world.loaded_at(Vector3(p))

static func clear_cell(world: VoxelWorld, p: Vector3i) -> void:
	world.set_node(p,Nodes.AIR)
	for direction in HugeMushrooms.FACES: world.set_node(p+direction,Nodes.AIR)

static func clear_plot(world: VoxelWorld) -> void:
	for x in range(-2,20):
		for z in range(-3,4):
			for y in range(-2,25): world.set_node(P+Vector3i(x,y,z),Nodes.AIR)

static func run(t: SceneTree, game: Node3D) -> void:
	var world: VoxelWorld = game.world
	game.world.active = false; game.world.set_process(false)
	for column_x in range(floori((P.x-2)/16.0),floori((P.x+20)/16.0)+1):
		for column_z in range(floori((P.z-3)/16.0),floori((P.z+4)/16.0)+1):
			var sample := Vector3(column_x*16+8,P.y,column_z*16+8)
			if not game.world.loaded_at(sample): game.world._apply_column(game.world.generator.generate_column(Vector2i(column_x,column_z),game.world.edits))
	clear_plot(world)


	# Registration covers the complete source family without replacing legacy IDs.
	t.check(HugeMushrooms.DATA.size() == 132 and HugeMushrooms.BLOCKS.size() == 132 and HugeMushrooms.CAPS.size() == 128,"four stems and all 64 masks for both species are registered")
	t.check(HugeMushrooms.BROWN_CAP == 1209 and HugeMushrooms.RED_CAP == 1210 and HugeMushrooms.BROWN_PORES == 1211 and HugeMushrooms.RED_PORES == 1212,"legacy cap IDs remain stable")
	var unique: Dictionary = {}
	var registrations_valid: bool = true
	var drops_valid: bool = true
	for small in [Nodes.BROWN_MUSHROOM,Nodes.RED_MUSHROOM]:
		for mask in 64:
			var id: int = HugeMushrooms.cap_for(small,mask)
			unique[id] = true
			var expected_source: String = "mcl_mushrooms:"+("red" if small == Nodes.RED_MUSHROOM else "brown")+"_mushroom_block_cap_"+HugeMushrooms.mask_string(mask)
			var snapshot: Dictionary = HugeMushrooms.state_snapshot(id)
			registrations_valid = registrations_valid and HugeMushrooms.mask_of(id) == mask and HugeMushrooms.species_of(id) == small and HugeMushrooms.source_name(id) == expected_source
			registrations_valid = registrations_valid and HugeMushrooms.DATA[id].get("hidden",false) == (mask < 63) and snapshot.id == id and snapshot.mask == mask and snapshot.source_node == expected_source
			registrations_valid = registrations_valid and snapshot.skin == HugeMushrooms.face_states(id) and snapshot.textures.size() == 6
			for face in 6:
				var skin: bool = bool(mask & HugeMushrooms.FACE_BITS[face])
				registrations_valid = registrations_valid and HugeMushrooms.face_states(id)[face] == skin and HugeMushrooms.face_texture(id,face) == HugeMushrooms.cap_for(small,63 if skin else 0)
			drops_valid = drops_valid and HugeMushrooms.silk_touch_drop(id) == HugeMushrooms.cap_for(small) and HugeMushrooms.species_of(id) == small
	t.check(unique.size() == 128,"cap masks map one-to-one to 128 distinct content IDs")
	t.check(registrations_valid,"source names, hidden states, face textures and snapshots follow +Y,-Y,+X,-X,+Z,-Z bit order")
	t.check(drops_valid,"Silk Touch canonicalizes every cap mask while the ordinary-drop species stays intact")

	# Each direction updates both touching bits through the real world edit path,
	# and removing the neighbour does not restore either bit.
	for face in 6:
		var p: Vector3i = P+Vector3i(face*3,0,0)
		var at: Vector3i = p+HugeMushrooms.FACES[face]
		clear_cell(world,p)
		clear_plot(world)
		world.set_node(at,HugeMushrooms.BROWN_CAP)
		world.set_node(p,HugeMushrooms.BROWN_CAP)
		HugeMushrooms.changed(world,p,Nodes.AIR,HugeMushrooms.BROWN_CAP)
		var own_mask: int = HugeMushrooms.mask_of(world.node_at(p))
		var neighbor_mask: int = HugeMushrooms.mask_of(world.node_at(at))
		t.check(own_mask == (63 & ~HugeMushrooms.FACE_BITS[face]) and neighbor_mask == (63 & ~HugeMushrooms.FACE_BITS[HugeMushrooms.OPPOSITE[face]]),"touching +Y,-Y,+X,-X,+Z,-Z face "+str(face)+" becomes pores on both caps")
		world.set_node(at,Nodes.AIR); HugeMushrooms.changed(world,at,HugeMushrooms.BROWN_CAP,Nodes.AIR)
		t.check(HugeMushrooms.mask_of(world.node_at(p)) == own_mask,"cleared face "+str(face)+" stays pores after neighbour removal")

	# A single construct scans cumulatively; the centre reaches the all-pore state.
	var cumulative: Vector3i = P+Vector3i(0,6,0)
	clear_cell(world,cumulative)
	for direction in HugeMushrooms.FACES: world.set_node(cumulative+direction,HugeMushrooms.BROWN_CAP)
	world.set_node(cumulative,HugeMushrooms.BROWN_CAP); HugeMushrooms.changed(world,cumulative,Nodes.AIR,HugeMushrooms.BROWN_CAP)
	t.check(world.node_at(cumulative) == HugeMushrooms.BROWN_PORES,"six same-species neighbours cumulatively clear all six centre bits")
	t.check(world.edits.get(cumulative,Nodes.AIR) == HugeMushrooms.BROWN_PORES and not world.block_states.has(VoxelWorld.station_key(cumulative)),"the internal mask is persisted as the voxel ID with no side-channel state")
	for direction in HugeMushrooms.FACES: world.set_node(cumulative+direction,Nodes.AIR)
	t.check(world.node_at(cumulative) == HugeMushrooms.BROWN_PORES,"the cumulative all-pore state is permanent")

	# cap_000000 has group huge_mushroom_cap=0 in the source and consequently does
	# not satisfy the callback's ~=0 neighbour test.
	var zero: Vector3i = P+Vector3i(0,10,0)
	clear_cell(world,zero); world.set_node(zero+Vector3i.RIGHT,HugeMushrooms.BROWN_PORES); world.set_node(zero,HugeMushrooms.BROWN_CAP)
	HugeMushrooms.changed(world,zero,Nodes.AIR,HugeMushrooms.BROWN_CAP)
	t.check(world.node_at(zero) == HugeMushrooms.BROWN_CAP and world.node_at(zero+Vector3i.RIGHT) == HugeMushrooms.BROWN_PORES,"all-pore group-zero neighbour does not trigger a touching-face change")
	t.check(not HugeMushrooms.placed(world,zero+Vector3i.RIGHT),"only the all-skin cap has the source construct callback")

	# Other species and either stem kind never hide a cap face.
	var distinct: Vector3i = P+Vector3i(0,14,0)
	var neighbours: Array = [HugeMushrooms.RED_CAP,HugeMushrooms.RED_PORES,HugeMushrooms.BROWN_STEM,HugeMushrooms.BROWN_FULL_STEM,HugeMushrooms.RED_STEM,HugeMushrooms.RED_FULL_STEM,Nodes.STONE]
	var distinction_valid: bool = true
	for neighbor in neighbours:
		clear_cell(world,distinct); world.set_node(distinct+Vector3i.RIGHT,neighbor); world.set_node(distinct,HugeMushrooms.BROWN_CAP)
		HugeMushrooms.changed(world,distinct,Nodes.AIR,HugeMushrooms.BROWN_CAP)
		distinction_valid = distinction_valid and world.node_at(distinct) == HugeMushrooms.BROWN_CAP and world.node_at(distinct+Vector3i.RIGHT) == neighbor
	t.check(distinction_valid,"different species, ordinary stems, full stems and non-caps leave all-skin caps unchanged")

	# Ordinary stems have pore ends and skin sides; full stems are skin on all six.
	for small in [Nodes.BROWN_MUSHROOM,Nodes.RED_MUSHROOM]:
		var stem: int = HugeMushrooms.stem_for(small)
		var full: int = HugeMushrooms.full_stem_for(small)
		t.check(HugeMushrooms.is_stem(full) and HugeMushrooms.is_full_stem(full) and not HugeMushrooms.is_cap(full),"full stem is a separate registered stem for "+str(small))
		t.check(HugeMushrooms.face_states(stem) == [false,false,true,true,true,true] and HugeMushrooms.face_states(full) == [true,true,true,true,true,true],"ordinary/full stem face states match the source tiles for "+str(small))
		t.check(HugeMushrooms.render_texture(stem,2) == HugeMushrooms.pores_for(small) and HugeMushrooms.render_texture(stem,0) == stem and HugeMushrooms.render_texture(full,2) == full,"renderer face mapping preserves pore ends and full-stem skin for "+str(small))
		t.check(HugeMushrooms.silk_touch_drop(stem) == stem and HugeMushrooms.silk_touch_drop(full) == full,"Silk Touch preserves ordinary and full stems for "+str(small))
		t.check(HugeMushrooms.source_name(full).ends_with("_mushroom_block_stem_full"),"full stem uses the exact source node name for "+str(small))

	# Schematics retain their layout while every cap cell receives its complete
	# adjacency mask, including horizontal and vertical contacts.
	for small in [Nodes.BROWN_MUSHROOM,Nodes.RED_MUSHROOM]:
		var plan: Dictionary = HugeMushrooms.shape(small,3)
		var schematic_masks: bool = true
		for offset in plan:
			var id: int = plan[offset]
			if not HugeMushrooms.is_cap(id): continue
			var expected: int = 63
			for face in 6:
				if HugeMushrooms.is_cap(plan.get(offset+HugeMushrooms.FACES[face],Nodes.AIR)): expected &= ~HugeMushrooms.FACE_BITS[face]
			schematic_masks = schematic_masks and HugeMushrooms.mask_of(id) == expected
		t.check(schematic_masks,"source schematic cap masks include every touching direction for "+str(small))

	for x in range(-2,20):
		for z in range(-3,4):
			for y in range(-2,25): world.set_node(P+Vector3i(x,y,z),Nodes.AIR)
