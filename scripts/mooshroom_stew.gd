class_name MooshroomStew
extends RefCounted

# Mineclonia mobs_mc/cow+mooshroom.lua. The flower is an entity state, not a
# recipe: FoodFeatures owns the one suspicious-stew effect registry used here,
# by crafting, and by Eating.
const KIND = "mooshroom"
const BROWN_META = "mooshroom_brown"
const FLOWER_META = "mooshroom_stew_flower"
const PART_META = "mooshroom_part"

# Original 16x16 skins, shared by variant and role. The meshes and their
# materials belong to each creature; refreshing one never rebuilds its model.
static var presentation_textures: Dictionary = {}

static func _presentation_texture(role: String, brown: bool) -> Texture2D:
	var key: String = role+("_brown" if brown else "_red")
	if presentation_textures.has(key): return presentation_textures[key]
	var base: Color = Color("775c4c") if brown else Color("a83238")
	var accent: Color = Color("c8b9a1") if brown else Color("eadfc8")
	if role == "cap":
		base = Color("80634f") if brown else Color("bd363b")
		accent = Color("c9b697") if brown else Color("f2e7cf")
	elif role == "stem":
		base = Color("b6a087") if brown else Color("d8c9ab")
		accent = base.darkened(0.18)
	var image := Image.create(16,16,false,Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			var color: Color = base
			var grain: int = (x/2*7+y/2*13+x/4*y/3*3)%17
			match role:
				"body":
					# Broad, pale cow-like patches over a saturated red or brown coat.
					if (x/3*7+y/3*11+x/5)%13 < 5: color = accent
					color *= 0.94+float(grain%4)*0.025
				"cap":
					# Three irregular pixel spots read as mushroom markings at mob scale.
					if Vector2(x-3,y-3).length_squared() <= 3 or Vector2(x-11,y-5).length_squared() <= 3 or Vector2(x-7,y-12).length_squared() <= 2:
						color = accent
					else: color *= 0.93+float(grain%5)*0.025
				"stem":
					color = accent if x%5 == 0 or (x+y)%11 == 0 else base*(0.95+float(grain%3)*0.025)
			color.a = 1.0
			image.set_pixel(x,y,color)
	var texture := ImageTexture.create_from_image(image)
	presentation_textures[key] = texture
	return texture

# Variant metadata is initialized before Creature._build_model. Refresh is also
# safe then: there are simply no parts to update yet. Later calls only replace
# textures on the existing materials, retaining meshes, joints, pose and scale.
static func refresh(mob: Creature) -> void:
	if mob == null or mob.kind != KIND: return
	var brown: bool = is_brown(mob)
	for part in mob.parts:
		if not is_instance_valid(part) or not part.has_meta(PART_META): continue
		var material: StandardMaterial3D = part.material_override
		if material == null: continue
		material.albedo_texture = _presentation_texture(str(part.get_meta(PART_META,"body")),brown)

static func handles(kind: String) -> bool:
	return kind in ["cow",KIND]

static func is_brown(mob: Creature) -> bool:
	return mob != null and mob.kind == KIND and bool(mob.get_meta(BROWN_META,false))

static func ingredient(mob: Creature) -> int:
	if mob == null or mob.kind != KIND: return 0
	return int(mob.get_meta(FLOWER_META,0))

# The source chooses one of its two texture sets on a fresh spawn. Restoration
# later overwrites this initial choice; an existing value is never rerolled.
static func initialize(mob: Creature, brown: Variant = null) -> void:
	if mob.kind != KIND or mob.has_meta(BROWN_META): return
	set_brown(mob,randi_range(0,1) == 1 if brown == null else (brown is bool and brown))

static func set_brown(mob: Creature, brown: bool) -> void:
	if mob.kind != KIND: return
	mob.set_meta(BROWN_META,brown)
	refresh(mob)

static func snapshot(mob: Creature) -> Dictionary:
	if mob == null or mob.kind != KIND: return {}
	return {"brown":is_brown(mob),"flower":ingredient(mob)}

static func restore(mob: Creature, entry: Dictionary) -> void:
	if mob == null or mob.kind != KIND: return
	var restored_brown: Variant = entry.get("brown",false)
	set_brown(mob,restored_brown is bool and restored_brown)
	var raw: Variant = entry.get("flower",0)
	var flower: int = 0
	if (raw is int or raw is float) and is_finite(float(raw)) and float(raw) == floorf(float(raw)):
		var candidate: int = int(raw)
		if candidate > 0 and FoodFeatures.stew_ingredient(candidate): flower = candidate
	# Keep a valid ingredient on a red mooshroom. Lightning only changes colour;
	# it does not discard the source's hidden `_sus_ingredient_held`.
	mob.set_meta(FLOWER_META,flower)

static func _usable(game: Node3D, mob: Creature) -> bool:
	return mob != null and handles(mob.kind) and not mob.is_queued_for_deletion() and mob.health > 0 and mob.growth_remaining <= 0 and game != null

static func _give_at_mob(game: Node3D, mob: Creature, stack: Dictionary) -> void:
	var id: int = int(stack.get("id",0))
	var count: int = int(stack.get("count",0))
	var data: Dictionary = stack.get("data",{})
	var rest: int = game.inventory.add_item(id,count,int(stack.get("wear",0)),data)
	if rest > 0: game.spawn_drop(mob.position+Vector3.UP*0.5,id,rest,0,data)

static func _milk(game: Node3D, mob: Creature) -> bool:
	if int(game.inventory.held().id) != Nodes.BUCKET: return false
	# These source callbacks remove the input in every gamemode.
	game.inventory.consume_selected()
	_give_at_mob(game,mob,{"id":Nodes.MILK_BUCKET,"count":1,"wear":0})
	game.sound_at("cow",mob.position,0.75)
	game.achievements.award("milkmaid")
	return true

static func _bowl(game: Node3D, mob: Creature) -> bool:
	if mob.kind != KIND or int(game.inventory.held().id) != Nodes.BOWL: return false
	var stack: Dictionary = {"id":Nodes.MUSHROOM_STEW,"count":1,"wear":0}
	var flower: int = ingredient(mob)
	var suspicious: bool = is_brown(mob) and flower != 0
	if suspicious:
		stack = FoodFeatures.stew_item(flower)
		if stack.is_empty(): return false
	# These source callbacks remove the input in every gamemode.
	game.inventory.consume_selected()
	if suspicious:
		mob.set_meta(FLOWER_META,0)
		Farming.remember(mob)
	_give_at_mob(game,mob,stack)
	game.sound_at("cow",mob.position,0.75)
	return true

static func _flower(game: Node3D, mob: Creature) -> bool:
	if mob.kind != KIND or not is_brown(mob): return false
	var held: Dictionary = game.inventory.held()
	var flower: int = int(held.get("id",0))
	if int(held.get("count",0)) <= 0 or not FoodFeatures.stew_ingredient(flower): return false
	# A brown mooshroom holds exactly one flower. A second valid flower is a
	# consumed click but not a consumed item, and never replaces the first.
	if ingredient(mob) != 0: return true
	mob.set_meta(FLOWER_META,flower)
	game.inventory.consume_selected()
	Farming.remember(mob)
	return true

# `mcl_util.replace_mob` creates a fresh cow, retaining only child, nametag,
# persistence and yaw. Babies never reach this branch in the source callback.
static func shear(game: Node3D, mob: Creature) -> Creature:
	if not _usable(game,mob) or mob.kind != KIND or int(game.inventory.held().id) != Nodes.SHEARS: return null
	var brown: bool = is_brown(mob)
	var yaw: float = mob.model.rotation.y if mob.model != null else mob.rotation.y
	var cow: Creature = game.spawn_creature("cow",mob.position,"",{"baby":false,"jockey":false})
	if cow == null: return null
	cow.custom_name = mob.custom_name
	NameTags.refresh(cow)
	if mob.has_meta("persistent"): cow.set_meta("persistent",true)
	cow.rotation.y = mob.rotation.y
	if cow.model != null: cow.model.rotation.y = yaw
	Farming.forget(mob)
	Farming.remember(cow)
	mob.queue_free()
	game.spawn_drop(mob.position+Vector3.UP*1.4,Nodes.BROWN_MUSHROOM if brown else Nodes.RED_MUSHROOM,5)
	game.sound_at("sheep",mob.position,1.2)
	if game.gamemode != "creative": game.inventory.damage_tool()
	return cow

# The whole item portion of cow/mooshroom:on_rightclick. Farming.use runs first
# for wheat, matching feed_tame's priority; this function also rejects babies.
static func use(game: Node3D, mob: Creature) -> bool:
	if not _usable(game,mob): return false
	if int(game.inventory.held().get("count",0)) <= 0: return false
	if mob.kind == KIND:
		if shear(game,mob) != null: return true
		if _bowl(game,mob): return true
		if _flower(game,mob): return true
	return _milk(game,mob)

# `_on_lightning_strike` toggles colour, keeps the ingredient, and suppresses
# lightning damage by returning true to Weather.strike.
static func lightning(mob: Creature) -> bool:
	if mob == null or mob.kind != KIND or mob.is_queued_for_deletion() or mob.health <= 0: return false
	set_brown(mob,not is_brown(mob))
	Farming.remember(mob)
	return true
