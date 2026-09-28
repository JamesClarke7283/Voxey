class_name BossBars
extends RefCounted

# Mineclonia HUD/mcl_bossbars/init.lua (`add_bar`/`update_bar`/`update_boss` at
# :53-119, the colour list at :5, the dynamic stacking and the 80-node range) with
# its consumers `ENTITIES/mobs_mc/wither.lua`:370 and
# `ENVIRONMENT/mcl_raids/init.lua`:209-256. GPL-3.0-or-later. Original GDScript
# using the source as a behaviour reference.
#
# Voxey drew one hard-coded End-dragon bar (`hud.gd`:909-916) and nothing else, so
# a summoned wither had **no health readout at all** and a raid showed a text line.
# This is the source's shared bar list: any number of bars, each with a title, a
# fill percentage and a colour, fed by whatever system owns the entity.
#
# The source's own rules:
#
#   * A dynamic bar (a boss) is added for every player within **80** nodes, and
#     identical dynamic bars stack as "text xN".
#   * A static bar (a raid) is added once per player and updated by id.
#   * The colour list is `light_purple, blue, red, green, yellow, dark_purple,
#     white`; a raid is `red` and a wither `dark_purple`.
#   * `update_boss` reads `health / hp_max` and falls back to the mob's name when
#     the nametag is empty.

# `mcl_bossbars.colors`.
const COLORS = ["light_purple","blue","red","green","yellow","dark_purple","white"]
# `update_boss`'s `if d <= 80`.
const RANGE = 80.0
const WITHER_COLOR = "dark_purple"
const RAID_COLOR = "red"

# Every bar the HUD should draw this frame: `[{"id":String,"text":String,
# "fraction":float,"color":String}]`. Rebuilt from live state on each call rather
# than cached, so a dead boss disappears without a teardown path.
static func bars(game: Node3D) -> Array:
	var result: Array = []
	for mob in game.creatures.get_children():
		if mob.is_queued_for_deletion() or mob.health <= 0: continue
		if not boss_mob(mob): continue
		if mob.position.distance_to(game.player.position) > RANGE: continue
		result.append(dynamic_bar(mob,game))
	var raid: Dictionary = game.world.adventure_state.get("raid",{})
	if not raid.is_empty(): result.append(raid_bar(game,raid))
	return result

# A mob that gets a bar: the source calls `update_boss` for the wither and the
# ender dragon, and the dragon already has its own richer display.
static func boss_mob(mob: Creature) -> bool:
	if mob.kind == "ender_dragon": return false
	return mob.kind in ["wither"] or Withers.is_boss(mob.kind)

# `update_boss`: `health / hp_max` with the mob's name as the title. The wither has
# no `hp_max` field in Voxey, so its own table supplies it.
static func dynamic_bar(mob: Creature, game: Node3D) -> Dictionary:
	var maximum: float = mob.info().get("health",mob.health)
	var title: String = mob.custom_name if not mob.custom_name.is_empty() else mob.kind.replace("_"," ").capitalize()
	return {
		"id": "mob:"+str(mob.get_instance_id()),
		"text": title,
		"fraction": clampf(mob.health/maxf(1.0,maximum),0.0,1.0),
		"color": WITHER_COLOR if mob.kind == "wither" else "light_purple",
	}

# `update_bossbar` in `mcl_raids`: the title names the wave, and the fill is the
# surviving raiders' share of the wave's own pool. Voxey keeps the wave number and
# live raider count in `adventure_state.raid`, so the bar reports the wave and the
# remaining fraction of the group that spawned.
static func raid_bar(game: Node3D, raid: Dictionary) -> Dictionary:
	var wave: int = int(raid.get("wave",0))
	var total: int = maxi(1,int(raid.get("size",1)))
	var alive: int = int(raid.get("alive",0))
	return {
		"id": "raid",
		"text": "Raid (%d of %d)"%[maxi(1,wave),RaidMobs.ordinary_waves(int(raid.get("level",1)))],
		"fraction": clampf(float(alive)/float(total),0.0,1.0),
		"color": RAID_COLOR,
	}

# The colour a bar draws with. The names are the source's own; the HUD maps them.
static func color(name: String) -> Color:
	match name:
		"light_purple": return Color("c9a0e8")
		"blue": return Color("6f8fe0")
		"red": return Color("cf5a52")
		"green": return Color("79b85f")
		"yellow": return Color("e0c45c")
		"dark_purple": return Color("b975d3")
		"white": return Color("e6e6e6")
	return Color("b975d3")
