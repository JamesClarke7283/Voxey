class_name ZombieTraits
extends RefCounted

const KINDS = ["zombie","husk","drowned","zombie_villager"]
const ATTEMPTS = 50

static func handles(kind: String) -> bool: return kind in KINDS
static func rng_for(world: VoxelWorld) -> EnchantRolls:
	if not world.has_meta("zombie_traits_rng"):
		var rng := RandomNumberGenerator.new(); rng.seed = world.seed_value+534197
		world.set_meta("zombie_traits_rng",EnchantRolls.new(1,rng))
	return world.get_meta("zombie_traits_rng")

static func generate(factor: float, rng: EnchantRolls) -> Dictionary:
	var result: Dictionary = {"knockback":rng.unit()*0.05,"view":0.0,"reinforcement":0.0,"health_bonus":0.0,"break_doors":false}
	var view: float = factor*1.5*rng.unit()
	if view > 1: result.view = view
	if rng.unit() < factor*0.05:
		result.reinforcement = rng.unit()*0.25+0.5
		result.health_bonus = rng.unit()*3+1; result.break_doors = true
	result.reinforcement = clampf(float(result.reinforcement)+rng.unit()*0.1,0,1)
	return result

static func initialize(mob: Creature) -> void:
	if not handles(mob.kind) or not mob.zombie_traits.is_empty(): return
	mob.zombie_traits = generate(RegionalDifficulty.special(mob.game,mob.position),rng_for(mob.game.world))

static func max_health(mob: Creature, base: float) -> float:
	return base+20*float(mob.zombie_traits.get("health_bonus",0)) if handles(mob.kind) else base

static func view_range(mob: Creature) -> float:
	return 35.0*(1+float(mob.zombie_traits.get("view",0)))

static func knockback_resistance(mob: Creature) -> float:
	return float(mob.zombie_traits.get("knockback",0)) if handles(mob.kind) else 0.0

static func offset(rng: EnchantRolls) -> Vector3i:
	return Vector3i(rng.integer(7,40)*rng.integer(-1,1),rng.integer(7,40)*rng.integer(-1,1),rng.integer(7,40)*rng.integer(-1,1))

static func attenuate(value: float) -> float: return maxf(0,value-0.05)

static func reinforcement_gate(difficulty: int, accepted: bool, living: bool, chance: float, sample: float) -> bool:
	return difficulty >= 3 and accepted and living and sample < chance

static func living_player_near(game: Node3D, at: Vector3, radius: float = 7) -> bool:
	if game.player.health > 0 and game.player.position.distance_to(at) <= radius: return true
	if game.network != null and game.network.active():
		for peer in game.network.ready_peers:
			if peer != 1 and game.network.players.has(peer):
				var player: Node3D = game.network.players[peer]
				var health: float = float(game.world.adventure_state.get("network_players",{}).get(game.network.peer_identity.get(peer,""),{}).get("health",20))
				if health > 0 and player.position.distance_to(at) <= radius: return true
	return false

static func valid_spawn(mob: Creature, cell: Vector3i, rng: EnchantRolls) -> bool:
	var world: VoxelWorld = mob.game.world
	var at: Vector3 = Vector3(cell)+Vector3(0.5,0,0.5)
	if not WorldBounds.contains(at,mob.game.dimension) or not world.loaded_at(at) or living_player_near(mob.game,at): return false
	var info: Dictionary = Creature.KINDS[mob.kind]
	if world.intersects(at,info.width,info.height): return false
	var light: int = RedstoneSensors.natural_light(world,cell)
	if Pasture.block_light(world,cell,1) > 0 or light > 6 or light > rng.integer(0,31): return false
	if mob.kind == "drowned": return UndeadVariants.drowned_cell_allowed(world,cell,TerrainGenerator.SEA,rng.integer(1,6))
	if Fluids.liquid(world.node_at(cell)) or not Nodes.solid(world.node_at(cell+Vector3i.DOWN)): return false
	if mob.kind == "husk" and not Weather.outdoor(world,cell): return false
	return true

static func reinforce(mob: Creature, source: Node3D, rng: EnchantRolls = null, sample: float = -1, spawner: Callable = Callable()) -> Array:
	var result: Array = []
	if not handles(mob.kind) or RegionalDifficulty.source_level(mob.game.difficulty) < 3: return result
	var target: Node3D = mob.zombie_target if is_instance_valid(mob.zombie_target) else source
	if not is_instance_valid(target) or not (target is Creature or target is VoxeyPlayer): return result
	if rng == null: rng = rng_for(mob.game.world)
	if (rng.unit() if sample < 0 else sample) >= float(mob.zombie_traits.get("reinforcement",0)): return result
	var base := Vector3i(mob.position.floor())
	for i in ATTEMPTS:
		var cell: Vector3i = base+offset(rng)
		var next: Creature
		if spawner.is_valid(): next = spawner.call(cell)
		elif valid_spawn(mob,cell,rng): next = mob.game.spawn_creature(MobBabies.natural(mob.kind,rng.unit()),Vector3(cell)+Vector3(0.5,0,0.5))
		if next == null: continue
		mob.zombie_traits.reinforcement = attenuate(float(mob.zombie_traits.reinforcement))
		next.zombie_traits.reinforcement = attenuate(float(next.zombie_traits.reinforcement))
		ZombieTargets.alert(next,mob.zombie_target)
		Farming.remember(next); result.append(next)
	Farming.remember(mob)
	return result

static func snapshot(mob: Creature) -> Dictionary: return mob.zombie_traits.duplicate(true)
static func restore(mob: Creature, data: Dictionary) -> void:
	if not handles(mob.kind) or data.is_empty(): return
	for field in ["knockback","view","reinforcement","health_bonus"]:
		var value: Variant = data.get(field,0)
		if value is int or value is float:
			mob.zombie_traits[field] = clampf(float(value),0,{"knockback":1.0,"view":1.5,"reinforcement":1.0,"health_bonus":4.0}[field])
	mob.zombie_traits.break_doors = bool(data.get("break_doors",false))
