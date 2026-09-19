extends RefCounted
const Helper = preload("res://tests/barrier_checks.gd")

static func freeze(game: Node3D) -> void:
	game.set_process(false); game.world.active = false; game.world.set_process(false)
	game.player.set_process(false); game.player.set_physics_process(false)

static func target(p: Vector3i) -> Dictionary:
	return {"id":NoteBlocks.ID,"pos":p,"normal":Vector3i.BACK,"distance":3.0,"point":Vector3(p)+Vector3(0.5,0.5,1)}

static func voice(game: Node3D) -> AudioStreamPlayer3D:
	return game.audio_players_3d[posmod(game.audio_index_3d-1,game.audio_players_3d.size())]

static func advance(before: int, game: Node3D, amount: int = 1) -> bool:
	return game.audio_index_3d == (before+amount)%game.audio_players_3d.size()

static func run(t: SceneTree, game: Node3D) -> void:
	var inv := Inventory.new(); var index: int = inv.recipe_index(NoteBlocks.ID)
	t.check(index >= 0 and inv.recipes[index].ingredients == {Nodes.PLANKS:8,Nodes.REDSTONE_WIRE:1} and inv.recipes[index].count == 1 and inv.recipes[index].station == "table","note block uses the source eight-plank/redstone crafting-table recipe")
	for species in 6:
		inv.restore([]); inv.add_item(WoodTypes.PLANKS[species],8); inv.add_item(Nodes.REDSTONE_WIRE)
		t.check(inv.fill_grid(index,"table") and inv.take_grid_result("table").get("id",0) == NoteBlocks.ID,"note block guide consumes actual species through source group:wood: "+str(species))
	var pattern: Array = [Nodes.PLANKS,6035,6067,6099,Nodes.REDSTONE_WIRE,6131,6163,6035,Nodes.PLANKS]
	for cell in 9: inv.grid[cell] = {"id":pattern[cell],"count":1,"wear":0}
	t.check(inv.take_grid_result("table").get("id",0) == NoteBlocks.ID and inv.grid.all(func(slot): return slot.id == 0),"mixed wood species craft one note block without converting leftover ingredients")
	t.check(Nodes.exists(NoteBlocks.ID) and Nodes.placeable(NoteBlocks.ID) and Nodes.solid(NoteBlocks.ID) and not Nodes.transparent(NoteBlocks.ID) and Nodes.hardness(NoteBlocks.ID) == 0.8 and Nodes.preferred_tool(NoteBlocks.ID) == 1 and Nodes.fuel_time(NoteBlocks.ID) == 15 and not Fire.flammable(NoteBlocks.ID),"note block is a solid wooden cube with source hardness, axe preference, fuel and non-spreading fire behavior")
	var choices: Dictionary = {Nodes.DIRT:"piano",Nodes.PLANKS:"bass_guitar",Nodes.STONE:"bass_drum",Nodes.SAND:"snare",Nodes.GLASS:"hit",Nodes.GOLD_BLOCK:"bell",Nodes.CLAY:"flute",Nodes.WOOL:"guitar",Nodes.IRON_BLOCK:"xylophone_metal",Nodes.SOUL_SAND:"cowbell",Nodes.PUMPKIN:"didgeridoo",VillageContent.EMERALD_BLOCK:"squarewave",Nodes.HAY_BALE:"banjo",Nodes.GLOWSTONE:"piano_digital"}
	choices[DenseMaterials.PACKED_ICE] = "chime"; choices[DenseMaterials.BONE] = "xylophone_wood"
	for base in choices:
		t.check(NoteBlocks.instrument(base) == choices[base],"source exact-node/material instrument selection: "+Nodes.title(base)+" → "+choices[base])
	for base in [Nodes.ICE,Nodes.SNOW_BLOCK,Nodes.DIAMOND_BLOCK,Nodes.COPPER_NODE,Nodes.LEAVES,Nodes.SAPLING,Nodes.BED_FOOT,Signs.STANDING,VillageContent.LECTERN,VillageContent.CARPET_WHITE,Campfires.LIT]:
		t.check(NoteBlocks.instrument(base) == "piano","source groups do not infer an instrument merely from appearance: "+Nodes.title(base))
	for species in 6:
		var wood: int = WoodTypes.PLANKS[species]
		t.check(NoteBlocks.instrument(wood) == "bass_guitar" and NoteBlocks.instrument(WoodTypes.base(species)+6) == "bass_guitar" and NoteBlocks.instrument(BuildingShapes.slab_for(wood)) == "bass_guitar","all classic planks, bark and wooden slabs use bass guitar: "+str(species))
	t.check(NoteBlocks.instrument(Nodes.GRAVEL) == "snare" and NoteBlocks.instrument(VillageContent.GLASS_PANE) == "hit" and NoteBlocks.instrument(VillageContent.WOOL_RED) == "guitar","gravel, glass panes and dyed wool use their actual source groups")
	t.check(NoteBlocks.instrument(Barriers.FENCE_BASES[2]) == "bass_guitar" and NoteBlocks.instrument(Barriers.FENCE_BASES[1]) == "bass_drum" and NoteBlocks.instrument(Trapdoors.OAK) == "bass_guitar" and NoteBlocks.instrument(Trapdoors.IRON) == "piano","wood/Nether barriers and wood/iron trapdoors retain their distinct source groups")
	t.check(NoteBlocks.instrument(VillageContent.SMOKER) == "bass_drum" and NoteBlocks.instrument(PortableStorage.ENDER_CHEST) == "bass_drum" and NoteBlocks.instrument(VillageContent.CARTOGRAPHY_TABLE) == "bass_guitar" and NoteBlocks.instrument(VillageContent.TERRACOTTA_WHITE) == "bass_drum","source furnace/Ender-chest, workstation and terracotta groups select percussion or bass")
	t.check(NoteBlocks.instrument(DenseMaterials.BONE_X) == "xylophone_wood" and NoteBlocks.instrument(DenseMaterials.BONE_Z) == "xylophone_wood" and NoteBlocks.instrument(DenseMaterials.BLUE_ICE) == "piano","bone axis variants retain the exact-node xylophone instrument while blue ice does not substitute for packed ice")
	t.check(NoteBlocks.instrument(Jukeboxes.ID) == "bass_guitar","source jukebox wood group provides bass guitar")
	for id in RedstoneInputs.items():
		var expected: String = "bass_guitar" if RedstoneInputs.wooden(id) else ("bass_drum" if RedstoneInputs.kind(id) in [0,7] else "piano")
		t.check(NoteBlocks.instrument(id) == expected,"new redstone input preserves its source material group: "+RedstoneInputs.title(id))
	for note in 25:
		t.check(is_equal_approx(NoteBlocks.pitch(note),pow(2.0,(note-12)/12.0)) and NoteBlocks.color(note).a == 1,"note pitch follows exact semitone tuning and has a visible color: "+str(note))
	t.check(NoteBlocks.color(0) == Color8(0,255,0) and NoteBlocks.color(8) == Color8(255,0,0) and NoteBlocks.color(16) == Color8(0,0,255) and NoteBlocks.color(24) == Color8(0,226,28),"source note particle colors retain floor rounding, including the final green/blue step")
	var signatures: Dictionary = {}; var synthesis_started: int = Time.get_ticks_usec()
	for instrument in NoteBlockTones.INSTRUMENTS:
		var sample: AudioStreamWAV = NoteBlockTones.sample(instrument)
		var energy: float = 0; var peak: int = 0
		for offset in range(0,sample.data.size(),2):
			var value: int = sample.data.decode_s16(offset); peak = maxi(peak,absi(value)); energy += value*value
		var signature: int = hash(sample.data); signatures[signature] = true
		t.check(sample.format == AudioStreamWAV.FORMAT_16_BITS and sample.mix_rate == 22050 and sample.data.size() >= 5500 and peak > 2000 and peak <= 26000 and energy > 1000000 and NoteBlockTones.sample(instrument) == sample,"original synthesized instrument is audible, bounded and cached: "+instrument)
	t.check(signatures.size() == 16,"all sixteen synthesized instruments have distinct waveforms")
	print("NOTE TONES: 16 cold asset loads and waveform checks in %.3f ms"%[(Time.get_ticks_usec()-synthesis_started)/1000.0])
	var world: VoxelWorld = game.world; var p := Vector3i(8,940,8)
	var old: Dictionary = {"position":game.player.position,"target":game.player.target,"mode":game.gamemode,"touch":game.touch,"audio":game.audio_enabled,"inventory":game.inventory.slots.duplicate(true),"selected":game.inventory.selected}
	var temporary_controls: bool = not is_instance_valid(game.controls)
	if temporary_controls: game.controls = TouchControls.new(); game.controls.game = game; game.add_child(game.controls)
	var old_sneak: bool = game.controls.sneak_held
	game.pause(); freeze(game); game.state = "playing"; game.audio_enabled = true; game.touch = true; game.controls.sneak_held = false; game.gamemode = "survival"
	for mob in game.creatures.get_children(): mob.queue_free()
	await t.process_frame
	for x in range(-2,5):
		for z in range(-2,3):
			for y in range(-1,3): world.set_node(p+Vector3i(x,y,z),Nodes.AIR)
	game.player.position = Vector3(p)+Vector3(0.5,0,3)
	world.set_node(p,NoteBlocks.ID); world.set_node(p+Vector3i.DOWN,Nodes.DIRT)
	game.player.target = target(p); Helper.equip(game,Nodes.APPLE,3)
	t.check(world.circuits.tracked.has(p) and NoteBlocks.state(world,p).note == 0 and not NoteBlocks.state(world,p).powered,"new note block registers with pitch zero and unpowered metadata")
	var before: int = game.audio_index_3d
	game.player.use()
	t.check(NoteBlocks.state(world,p).note == 1 and advance(before,game) and game.inventory.held().count == 3 and game.player.eating.is_empty(),"real right-click tunes before food use, plays once and preserves the held item")
	t.check(voice(game).stream == NoteBlockTones.sample("piano") and is_equal_approx(voice(game).pitch_scale,NoteBlocks.pitch(1)) and voice(game).max_distance == 48 and voice(game).global_position == Vector3(p)+Vector3.ONE*0.5,"playback reaches a positioned audio voice with the exact pitch and source 48-block range")
	for i in 24: NoteBlocks.use(game,target(p))
	t.check(NoteBlocks.state(world,p).note == 0,"twenty-five hand tunings cycle back to the first note")
	before = game.audio_index_3d; game.controls.sneak_held = true
	t.check(not NoteBlocks.use(game,target(p)) and NoteBlocks.state(world,p).note == 0 and game.audio_index_3d == before,"touch sneaking bypasses tuning for block placement")
	game.controls.sneak_held = false; game.player.mining_pos = Vector3i(99999,99999,99999); game.player.mining = 0
	game.player.mine(0.001); var first_punch: int = game.audio_index_3d; game.player.mine(0.001)
	t.check(advance(before,game) and first_punch == game.audio_index_3d and NoteBlocks.state(world,p).note == 0 and world.node_at(p) == NoteBlocks.ID,"initial mining stroke punches once without tuning or repeated playback every mining frame")
	for blocker in [Nodes.STONE,Nodes.GLASS,Nodes.WATER,Nodes.FLOWER]:
		world.set_node(p+Vector3i.UP,blocker); before = game.audio_index_3d
		var pitch_before: int = NoteBlocks.state(world,p).note
		NoteBlocks.use(game,target(p))
		t.check(NoteBlocks.state(world,p).note == (pitch_before+1)%25 and game.audio_index_3d == before and not NoteBlocks.punch(game,target(p)),"literal-air gate silences tuning and punching beneath "+Nodes.title(blocker)+" while pitch still advances")
	world.set_node(p+Vector3i.UP,Nodes.AIR)
	for base in choices:
		world.set_node(p+Vector3i.DOWN,base); before = game.audio_index_3d
		t.check(NoteBlocks.play(world,p) and advance(before,game) and voice(game).stream == NoteBlockTones.sample(choices[base]),"real note playback chooses the current support instrument: "+choices[base])
	world.set_node(p+Vector3i.DOWN,Nodes.DIRT)
	var lever: Vector3i = p+Vector3i.LEFT
	world.set_node(lever,Nodes.LEVER); world.circuits.state(lever).on = true
	before = game.audio_index_3d; var pitch_before: int = NoteBlocks.state(world,p).note
	world.circuits.step(); world.circuits.step(); world.circuits.step()
	t.check(advance(before,game) and NoteBlocks.state(world,p).powered and NoteBlocks.state(world,p).note == pitch_before,"redstone rising edge plays once without tuning or repeating while held powered")
	before = game.audio_index_3d; world.circuits.state(lever).on = false; world.circuits.step()
	t.check(game.audio_index_3d == before and not NoteBlocks.state(world,p).powered,"falling edge arms the next note without playing")
	world.set_node(p+Vector3i.UP,Nodes.GLASS); world.circuits.state(lever).on = true; world.circuits.step()
	world.set_node(p+Vector3i.UP,Nodes.AIR); world.circuits.step()
	t.check(game.audio_index_3d == before and NoteBlocks.state(world,p).powered,"a blocked rising edge is consumed and uncovering a still-powered block stays silent")
	world.circuits.state(lever).on = false; world.circuits.step(); world.circuits.state(lever).on = true; world.circuits.step()
	t.check(advance(before,game),"a fresh redstone edge after uncovering plays normally")
	world.set_node(p+Vector3i.RIGHT,Nodes.REDSTONE_WIRE); world.circuits.step()
	t.check(world.circuits.output(p+Vector3i.RIGHT,Vector3i.RIGHT) > 0,"note block remains a solid conductor between a strong-power control and dust")
	world.set_node(p+Vector3i.RIGHT,Nodes.AIR)
	NoteBlocks.state(world,p).note = 23
	t.check(game.save_game("user://note-blocks.json"),"note pitch and powered state write through the real world save")
	var saved: Dictionary = game.read_save("user://note-blocks.json")
	game.set_process(true); game.load_world_data(saved)
	while game.state == "loading": await t.process_frame
	game.pause(); freeze(game); game.state = "playing"; world = game.world; before = game.audio_index_3d
	world.circuits.step(); world.circuits.step()
	t.check(world.node_at(p) == NoteBlocks.ID and NoteBlocks.state(world,p).note == 23 and NoteBlocks.state(world,p).note is int and NoteBlocks.state(world,p).powered and game.audio_index_3d == before,"restart preserves integer tuning and held power without an extra rising-edge sound")
	world.set_node(lever,Nodes.AIR); world.circuits.step()
	world.set_node(p+Vector3i.LEFT,Nodes.PISTON); world.circuits.configure(p+Vector3i.LEFT,Vector3i.RIGHT)
	game.player.position = Vector3(p)+Vector3(0,0,4)
	t.check(world.circuits.piston(p+Vector3i.LEFT,true) and world.node_at(p+Vector3i.RIGHT) == NoteBlocks.ID and NoteBlocks.state(world,p+Vector3i.RIGHT).note == 23,"piston movement carries the tuned note in ordinary block metadata")
	world.circuits.piston(p+Vector3i.LEFT,false); world.set_node(p+Vector3i.LEFT,Nodes.AIR)
	var before_drops: int = Helper.drops(game,NoteBlocks.ID)
	game.break_node(p+Vector3i.RIGHT,NoteBlocks.ID,0)
	t.check(Helper.drops(game,NoteBlocks.ID) == before_drops+1 and not world.block_states.has(VoxelWorld.station_key(p+Vector3i.RIGHT)),"hand breaking drops one plain note block and clears tuning metadata")
	world.set_node(p+Vector3i.RIGHT,NoteBlocks.ID)
	t.check(NoteBlocks.state(world,p+Vector3i.RIGHT).note == 0,"replacing a broken note block starts from the first note")
	for x in range(-2,5):
		for z in range(-2,3):
			for y in range(-1,3): world.set_node(p+Vector3i(x,y,z),Nodes.AIR)
	game.player.position = old.position; game.player.target = old.target; game.gamemode = old.mode; game.audio_enabled = old.audio; game.touch = old.touch
	game.inventory.slots = old.inventory; game.inventory.selected = old.selected
	if is_instance_valid(game.controls): game.controls.sneak_held = old_sneak
	if temporary_controls and is_instance_valid(game.controls): game.controls.queue_free(); game.controls = null
	game.pause(); freeze(game)
