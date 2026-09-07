extends RefCounted

static func advance(world: VoxelWorld, ticks: int = 160, delta: float = 0.25) -> void:
	for tick in ticks: world.fluids.update(delta)

static func platform(world: VoxelWorld, y: int) -> Vector3i:
	world.fluids = Fluids.new(world)
	var p := Vector3i(8,y,8)
	for x in range(-9,10):
		for z in range(-9,10): world.set_node(p+Vector3i(x,-1,z),Nodes.STONE)
	return p

static func run(t: SceneTree, game: Node3D) -> void:
	var world: VoxelWorld = game.world
	var p: Vector3i = platform(world,160)
	world.set_node(p+Vector3i.UP*4,Nodes.WATER)
	advance(world,4)
	t.check(Fluids.falling(world.node_at(p+Vector3i.UP*3)) and world.node_at(p+Vector3i(1,4,0)) == Nodes.AIR,"unsupported water falls down before spreading sideways")
	advance(world)
	var waterfall: bool = true
	for y in 4:
		if not Fluids.falling(world.node_at(p+Vector3i.UP*y)): waterfall = false
	t.check(waterfall and world.node_at(p+Vector3i.UP*4) == Nodes.WATER,"a water source feeds a continuous waterfall down to the floor")
	t.check(Fluids.level(world.node_at(p+Vector3i.RIGHT*7)) == 7 and world.node_at(p+Vector3i.RIGHT*8) == Nodes.AIR,"supported water spreads seven blocks with diminishing depth")
	var shallow: Vector3 = Vector3(p+Vector3i.RIGHT*7)+Vector3(0.5,0.2,0.5)
	t.check(not Fluids.contains(world,shallow,Nodes.WATER) and Fluids.contains(world,shallow-Vector3.UP*0.15,Nodes.WATER),"submersion follows the actual shallow flowing-water surface")
	var hit: Dictionary = world.raycast(Vector3(p)+Vector3(0.5,6,0.5),Vector3.DOWN,10)
	t.check(not hit.is_empty() and hit.id == Nodes.STONE,"ordinary targeting passes through flowing water and sources to the floor")
	hit = world.raycast(Vector3(p)+Vector3(0.5,6,0.5),Vector3.DOWN,10,true)
	t.check(not hit.is_empty() and hit.id == Nodes.WATER,"buckets and water tools can target liquid sources")
	world.set_node(p+Vector3i.UP*4,Nodes.AIR); advance(world,400)
	var dry: bool = true
	for x in range(-8,9):
		for z in range(-8,9):
			for y in 5:
				if Fluids.water(world.node_at(p+Vector3i(x,y,z))): dry = false
	t.check(dry,"removing the source drains the waterfall and its spread without suspended remnants")
	p = platform(world,180); world.set_node(p,Nodes.LAVA)
	world.fluids.update(0.21)
	t.check(world.node_at(p+Vector3i.RIGHT) == Nodes.AIR,"lava spreads more slowly than water")
	advance(world,200)
	t.check(Fluids.lava(world.node_at(p+Vector3i.RIGHT*3)) and world.node_at(p+Vector3i.RIGHT*4) == Nodes.AIR,"Overworld lava has the source's three-block horizontal range")
	p = platform(world,200); world.set_node(p+Vector3i.UP*3,Nodes.LAVA); advance(world,240)
	t.check(Fluids.falling(world.node_at(p)) and Fluids.lava(world.node_at(p+Vector3i.RIGHT)),"lava falls to the ground and spreads from the bottom of the fall")
	world.dimension = "nether"
	p = platform(world,220); world.set_node(p,Nodes.LAVA); advance(world,300)
	t.check(Fluids.lava(world.node_at(p+Vector3i.RIGHT*7)) and world.node_at(p+Vector3i.RIGHT*8) == Nodes.AIR,"Nether lava spreads seven blocks")
	world.dimension = "overworld"
	p = platform(world,240)
	world.set_node(p+Vector3i.LEFT,Nodes.WATER); world.set_node(p+Vector3i.RIGHT,Nodes.WATER); advance(world)
	t.check(world.node_at(p) == Nodes.WATER,"two supported neighboring water sources renew the middle source")
	p = platform(world,260)
	world.set_node(p+Vector3i.LEFT,Nodes.LAVA); world.set_node(p+Vector3i.RIGHT,Nodes.LAVA); advance(world,240)
	t.check(Fluids.flowing(world.node_at(p)) and not Fluids.source(world.node_at(p)),"lava does not create renewable sources")
	p = platform(world,280)
	world.set_node(p,Nodes.LAVA); world.set_node(p+Vector3i.RIGHT,Fluids.flow_id(Nodes.WATER,1))
	t.check(world.node_at(p) == Nodes.OBSIDIAN,"flowing water turns a lava source into obsidian")
	world.set_node(p+Vector3i.LEFT*3,Fluids.flow_id(Nodes.LAVA,1)); world.set_node(p+Vector3i.LEFT*2,Nodes.WATER)
	t.check(world.node_at(p+Vector3i.LEFT*3) == Nodes.COBBLE,"water touching flowing lava from the side forms cobblestone")
	world.set_node(p+Vector3i.RIGHT*4,Nodes.WATER); world.set_node(p+Vector3i(4,1,0),Fluids.flow_id(Nodes.LAVA,0,true))
	t.check(world.node_at(p+Vector3i.RIGHT*4) == Nodes.STONE,"falling lava onto water forms stone")
	p = platform(world,300)
	world.set_node(p,Nodes.TORCH); world.set_node(p+Vector3i.UP*2,Nodes.WATER); advance(world)
	t.check(Fluids.water(world.node_at(p)),"falling water washes away a torch instead of hanging above it")
	var torch_drop: bool = false
	for entity in game.drops.get_children():
		if entity is ItemDrop and entity.item_id == Nodes.TORCH: torch_drop = true
	t.check(torch_drop,"washing away a torch preserves it as a dropped item")
	p = platform(world,320)
	world.set_node(p+Vector3i.UP*2,Nodes.WATER); world.set_node(p,Fire.FLAME); advance(world,40)
	t.check(not Fire.is_fire(world.node_at(p)),"flowing water extinguishes fire")
	var variants_ok: bool = true
	for kind in [Nodes.WATER,Nodes.LAVA]:
		for distance in range(1,9):
			var id: int = Fluids.flow_id(kind,mini(distance,7),distance == 8)
			if not Nodes.exists(id) or Nodes.solid(id) or not Nodes.transparent(id) or Nodes.placeable(id) or Nodes.drop(id) != 0: variants_ok = false
	t.check(variants_ok,"all sixteen saved flow states are passable, non-collectible registered nodes")
	var data := PackedInt32Array(); data.resize(18*18*18)
	var center: int = 8+8*18+8*324
	data[center] = Fluids.flow_id(Nodes.LAVA,7)
	var surface: Array = BlockMesher.build(data)[0]
	var mesh_ok: bool = not surface.is_empty() and surface[Mesh.ARRAY_VERTEX].size() == 24
	if mesh_ok:
		for vertex in surface[Mesh.ARRAY_VERTEX]:
			if vertex.y < 7 or vertex.y > 7.125: mesh_ok = false
	t.check(mesh_ok,"flow meshes match their one-eighth-block shallow surface")
	var winding: bool = true
	if mesh_ok:
		var vertices: PackedVector3Array = surface[Mesh.ARRAY_VERTEX]; var indices: PackedInt32Array = surface[Mesh.ARRAY_INDEX]
		for i in range(0,indices.size(),3):
			var normal: Vector3 = (vertices[indices[i+1]]-vertices[indices[i]]).cross(vertices[indices[i+2]]-vertices[indices[i]])
			if normal.dot(surface[Mesh.ARRAY_NORMAL][indices[i]]) >= 0: winding = false
	t.check(mesh_ok and winding,"all flowing lava faces wind outward for GPU backface culling")
	p = Vector3i(15,340,8)
	world.fluids = Fluids.new(world)
	for x in range(13,20):
		for z in range(6,11): world.set_node(Vector3i(x,339,z),Nodes.STONE)
	world.set_node(p,Nodes.WATER)
	world.columns.erase(Vector2i(1,0)); advance(world,20)
	t.check(not world.fluids.waiting_columns.is_empty(),"fluid changes at an unloaded border wait for the neighboring column")
	world.columns[Vector2i(1,0)] = true; world.fluids.column_loaded(Vector2i(1,0)); advance(world)
	t.check(Fluids.water(world.node_at(p+Vector3i.RIGHT)),"fluid flow resumes across a column boundary when its terrain loads")
	p = platform(world,360)
	world.set_node(p,Fluids.flow_id(Nodes.WATER,7))
	hit = world.raycast(Vector3(p)+Vector3(0.5,2,0.5),Vector3.DOWN,4,true)
	t.check(not hit.is_empty() and is_equal_approx(hit.point.y,p.y+0.125),"water tools target the visible shallow surface instead of empty air above it")
	game.inventory.restore([]); game.inventory.selected = 0; game.inventory.add_item(Nodes.WATER_BUCKET,1)
	game.player.target = {"pos":p+Vector3i.DOWN,"normal":Vector3i.UP,"id":Nodes.STONE,"distance":1.0}
	game.player.use()
	t.check(world.node_at(p) == Nodes.WATER and game.inventory.count_item(Nodes.BUCKET) == 1,"pouring a bucket can replace existing flow with a source")
	var lava: Vector3i = p+Vector3i.RIGHT*4
	world.set_node(lava,Fluids.flow_id(Nodes.LAVA,0,true))
	game.player.position = Vector3(p)+Vector3(0,3,0)
	var ordinary: ItemDrop = game.spawn_drop(Vector3(lava)+Vector3.ONE*0.5,Nodes.DIAMOND,1)
	var resistant: ItemDrop = game.spawn_drop(Vector3(lava)+Vector3.ONE*0.5,Netherite.INGOT,1)
	ordinary.age = 3; resistant.age = 3
	ordinary._physics_process(0.01); resistant._physics_process(0.01)
	t.check(ordinary.is_queued_for_deletion() and not resistant.is_queued_for_deletion(),"flowing lava burns ordinary items and preserves Netherite")
	game.player.position = Vector3(lava)+Vector3(0.5,0.01,0.5)
	game.player.health = 20; game.player.hunger = 10; game.player.damage_cooldown = 0; game.player.survival_timer = 1
	game.player._physics_process(0.01)
	t.check(game.player.health < 20,"standing in flowing lava damages a survival player")
	var kelp := Vector3i(8,370,8)
	world.set_node(kelp,VillageContent.KELP_PLANT)
	for side in Fluids.SIDES: world.set_node(kelp+side,Nodes.WATER)
	var kelp_drops: int = 0
	for drop in game.drops.get_children():
		if drop.item_id == VillageContent.KELP: kelp_drops += 1
	advance(world,40)
	var kelp_after: int = 0
	for drop in game.drops.get_children():
		if drop.item_id == VillageContent.KELP: kelp_after += 1
	t.check(world.node_at(kelp) == VillageContent.KELP_PLANT and kelp_drops == kelp_after,"source water preserves submerged kelp without creating a flood of item drops")
	var flow_pos := Vector3i(8,380,8)
	var flow_id: int = Fluids.flow_id(Nodes.WATER,0,true)
	world.set_node(flow_pos+Vector3i.UP,Nodes.WATER); world.set_node(flow_pos,flow_id)
	var serialized: Array = JSON.parse_string(JSON.stringify(game.dimension_snapshot().edits))
	var saved_edits: Dictionary = {}
	for row in serialized:
		if int(row[1]) >= 379: saved_edits[Vector3i(int(row[0]),int(row[1]),int(row[2]))] = int(row[3])
	var restored := VoxelWorld.new(); restored.configure(world.seed_value,Art.make_atlas())
	game.add_child(restored); restored.set_process(false); restored.edits = saved_edits
	restored._apply_column(restored.generator.generate_column(Vector2i.ZERO,saved_edits))
	t.check(restored.node_at(flow_pos) == flow_id,"falling fluid states survive JSON saves and column regeneration")
	advance(restored,20)
	t.check(Fluids.falling(restored.node_at(flow_pos+Vector3i.DOWN)),"a restored waterfall resumes its downward simulation")
	restored.queue_free()
