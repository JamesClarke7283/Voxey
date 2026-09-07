class_name Eating
extends RefCounted

# mcl_hunger/holdeat.lua; dried kelp overrides the normal delay in mcl_ocean.
const DURATION = 1.61
static func duration(id: int) -> float:
	return 0.8 if id == VillageContent.DRIED_KELP else DURATION

static func start(player: VoxeyPlayer) -> void:
	var held: Dictionary = player.game.inventory.held()
	if not player.eating.is_empty() or held.count <= 0 or Nodes.food(held.id) <= 0 or player.hunger >= 20: return
	player.eating = {"id":held.id,"slot":player.game.inventory.selected,"data":held.get("data",{}).duplicate(true),"elapsed":0.0,"sound":0.0}

static func update(player: VoxeyPlayer, delta: float, held_down: bool) -> void:
	if player.eating.is_empty(): return
	var game: Node = player.game
	var held: Dictionary = game.inventory.held()
	var progress: Dictionary = player.eating
	if not game.playing() or not held_down or game.inventory.selected != progress.slot or held.id != progress.id or held.count <= 0 or held.get("data",{}) != progress.data or player.hunger >= 20:
		player.eating.clear(); return
	progress.elapsed += delta; progress.sound += delta
	if progress.sound >= 0.2:
		progress.sound = fmod(progress.sound,0.2); game.sound("eat")
	player.hand.position.y = -0.19+sin(progress.elapsed*24)*0.025
	player.hand.rotation.x = -0.7+sin(progress.elapsed*24)*0.1
	if progress.elapsed < duration(held.id): return
	var id: int = held.id
	player.eating.clear()
	player.hunger = minf(20,player.hunger+Nodes.food(id))
	if game.gamemode != "creative":
		game.inventory.consume_selected()
		if id in [Nodes.MUSHROOM_STEW,VillageContent.RABBIT_STEW,VillageContent.SUSPICIOUS_STEW,VillageContent.BEETROOT_SOUP]:
			var remaining: int = game.inventory.add_item(Nodes.BOWL,1)
			if remaining: game.spawn_drop(player.position+Vector3.UP,Nodes.BOWL,remaining)
	game.sound("eat")
	player.use_cooldown = 0
