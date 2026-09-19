class_name Lodestones
extends RefCounted

static func bind(game: Node3D, pos: Vector3i) -> bool:
	if game.world.node_at(pos) != Bastions.LODESTONE or game.inventory.held().id != Nodes.COMPASS: return false
	var original: Dictionary = game.inventory.held()
	var bound: Dictionary = original.duplicate(true); bound.count = 1
	if not bound.has("data"): bound.data = {}
	bound.data["lodestone"] = {"dimension":game.dimension,"position":[pos.x,pos.y,pos.z]}
	if original.count == 1:
		game.inventory.slots[game.inventory.selected] = bound; game.inventory.changed.emit()
	else:
		game.inventory.consume_selected()
		if game.inventory.add_item(bound.id,1,0,bound.data) > 0: game.spawn_drop(game.player.position+Vector3.UP,bound.id,1,0,bound.data)
	game.toast("Compass bound to this lodestone.")
	game.achievements.award("country_lode")
	return true

static func describe(game: Node3D, slot: Dictionary) -> String:
	var binding: Dictionary = slot.get("data",{}).get("lodestone",{})
	var destination: Vector3 = game.spawn_point
	var label: String = "Spawn"
	if not binding.is_empty():
		if binding.dimension != game.dimension: return "The lodestone compass spins in this dimension."
		destination = VillageLife.vec(binding.position)
		if game.world.loaded_at(destination) and game.world.node_at(Vector3i(destination)) != Bastions.LODESTONE: return "The compass spins: its lodestone is gone."
		label = "Lodestone"
	elif game.dimension != "overworld": return "The compass spins in this dimension."
	var delta: Vector3 = destination-game.player.position
	var bearing: String = ["north","north-east","east","south-east","south","south-west","west","north-west"][posmod(roundi(atan2(delta.x,-delta.z)/PI*4),8)]
	return "%s lies %d m to the %s."%[label,int(delta.length()),bearing]
