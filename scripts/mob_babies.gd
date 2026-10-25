class_name MobBabies
extends RefCounted

const ALIASES = {"baby_zombie":"zombie","baby_husk":"husk","baby_drowned":"drowned","baby_zombie_villager":"zombie_villager"}
const KINDS = ["zombie","husk","drowned","zombie_villager"]

static func baby(mob: Creature) -> bool: return mob.kind in KINDS and bool(mob.get_meta("undead_baby",false))
static func base(kind: String) -> String: return ALIASES.get(kind,kind)
static func natural(kind: String, roll: float) -> String:
	return "baby_"+kind if kind in ["zombie","husk","drowned"] and roll < 0.05 else kind

static func roll_kind(kind: String, rng: RandomNumberGenerator) -> String:
	return natural(kind,rng.randf()) if kind in ["zombie","husk","drowned"] else kind

static func info(mob: Creature, original: Dictionary) -> Dictionary:
	if not baby(mob): return original
	var data: Dictionary = original.duplicate()
	data.speed = float(original.speed)*1.5
	if mob.kind == "zombie_villager":
		data.width = float(original.width)*0.5; data.height = float(original.height)*0.5
	else:
		data.width = 0.25; data.height = 0.99; data.reach = 1.0; data.xp = 12
	return data

static func set_baby(mob: Creature, value: bool) -> void:
	if mob.kind not in KINDS: return
	mob.set_meta("undead_baby",value)
	var data: Dictionary = mob.info(); mob.width = data.width; mob.height = data.height
	if mob.model != null: mob.model.scale = Vector3.ONE*(0.5 if value else 1.0)
	NameTags.refresh(mob)

static func restore(mob: Creature, record: Dictionary) -> void:
	if mob.kind in KINDS: set_baby(mob,bool(record.get("baby",false)))

static func after_attack(mob: Creature, coin: int = 0) -> void:
	if not baby(mob): return
	if (MobJockeys.rng_for(mob.game.world).randi_range(1,2) if coin == 0 else coin) != 1: return
	mob.set_meta("baby_pace",0.5)
	var rng: RandomNumberGenerator = MobJockeys.rng_for(mob.game.world)
	mob.set_meta("baby_pace_direction",Vector3(rng.randf_range(-1,1),0,rng.randf_range(-1,1)).normalized())
	mob.prey_target = null; mob.prey_choice = null

static func pacing(mob: Creature, delta: float) -> bool:
	var remaining: float = float(mob.get_meta("baby_pace",0))
	if remaining <= 0: return false
	mob.set_meta("baby_pace",maxf(0,remaining-delta))
	mob.direction = mob.get_meta("baby_pace_direction",Vector3.ZERO)
	return true
