class_name FlowersExtra
extends RefCounted

# Mineclonia mods/ITEMS/mcl_flowers/register.lua and .../init.lua,
# GPL-3.0-or-later. Original GDScript using the source as a behaviour reference;
# all art is original procedural code.
#
# The source registers thirteen **simple flowers** through
# `mcl_flowers.register_simple_flower` (init.lua:110) and two more families
# through `register_ground_flower` (init.lua:160) and the plant nodes in
# register.lua:302-512. Voxey already has poppy, dandelion, oxeye daisy and tall
# grass (5610-5613, declared in `food_features.gd`); this module closes the ten
# remaining simple flowers plus the small plants the source hangs off the same
# file. `waterlily` is deliberately absent: Voxey has a lily pad already (684).
#
# Source rules reproduced here:
#   * A simple flower is `drawtype = "plantlike"`, `walkable = false`,
#     `sunlight_propagates = true`, `dig_immediate = 3`, `flammable = 2`,
#     `compostability = 65` and `_mcl_hardness = 0` (register.lua:36-146). The
#     ground flowers and the tallgrass family are flammable 3 and compostable 30,
#     except the fern at 65 (register.lua:148-173, 302-512).
#   * Each flower crafts into one dye of the source's own colour, and each is a
#     suspicious-stew ingredient with its own effect and duration (`sus_stew`).
#   * The wither rose additionally withers on contact: `_on_object_in` gives
#     `withering` at factor 1 for two seconds (register.lua:121-123).
#   * The firefly bush is `light_source = 2` (register.lua:419).
#   * The tallgrass family drops nothing by default, a fern rolls the source's
#     1-in-8 wheat seed, and shears or Silk Touch recover the plant itself
#     (`_mcl_shears_drop`/`_mcl_silk_touch_drop`, register.lua:302-335).
#   * Leaf litter is the furnace output of **leaves** (`mcl_trees/api.lua:203`
#     puts `_mcl_cooking_output` on the shared leaves template), and it burns for
#     5 seconds like the two dry grasses (register.lua:163, 454, 492).
#
# Integration (the parent owns every shared file; this module owns only its own
# `DATA`, `BLOCKS` and predicates):
#   * `village_content.gd`: merge `DATA` as `NetherBlocks.DATA` already is, and
#     append `BLOCKS` to `VillageContent.BLOCKS`.
#   * `village_art.gd`/`village_item_art.gd`: dispatch to `pixel`/`draw`.
#   * `FoodFeatures.FLOWERS`: ten more ids give stew, flower pots, the placement
#     gate and the support/`changed` rule; guard its dye line against double
#     registration (this module registers the dye recipes).
#   * `Pasture.emission`: `light_level` (the firefly bush).
#   * `Nodes.drop`: `drop` (the tallgrass family drops nothing, the fern a seed).
#   * `Nodes.smelt_result`: `smelt_output` (leaves to leaf litter).
#   * `Nodes.fuel_time`: `fuel_time` (leaf litter and both dry grasses burn 5s).
#   * Contact damage for the wither rose: `contact` (spec), wired at the source's
#     `_on_object_in` point.

const TULIP_ORANGE = 11400
const TULIP_PINK = 11401
const TULIP_RED = 11402
const TULIP_WHITE = 11403
const ALLIUM = 11404
const AZURE_BLUET = 11405
const BLUE_ORCHID = 11406
const WITHER_ROSE = 11407
const LILY_OF_THE_VALLEY = 11408
const CORNFLOWER = 11409
const FERN = 11410
const BUSH = 11411
const FIREFLY_BUSH = 11412
const SHORT_DRY_GRASS = 11413
const TALL_DRY_GRASS = 11414
const WILDFLOWERS = 11415
const LEAF_LITTER = 11416
const PINK_PETALS = 11417

const FLOWERS = [TULIP_ORANGE,TULIP_PINK,TULIP_RED,TULIP_WHITE,ALLIUM,AZURE_BLUET,BLUE_ORCHID,WITHER_ROSE,LILY_OF_THE_VALLEY,CORNFLOWER]
const PLANTS = [FERN,BUSH,FIREFLY_BUSH,SHORT_DRY_GRASS,TALL_DRY_GRASS,WILDFLOWERS,LEAF_LITTER,PINK_PETALS]
const BLOCKS = FLOWERS+PLANTS

# Source `light_source = 2` (register.lua:419).
const FIREFLY_LIGHT = 2
# Source `_mcl_burntime = 5` on leaf litter and both dry grasses.
const DRY_FUEL = 5
# Source register.lua:121-123:
#   `_on_object_in = function(_, _, obj) mcl_potions.give_effect("withering", obj, 1, 2) end`
# The source calls this once per globalstep for whatever stands in the node, with
# factor 1 (its level-1 rate of -1 HP per second) for two seconds. This module does
# not apply damage; `contact` is the whole spec the parent needs to wire it.
const CONTACT = {WITHER_ROSE:{"effect":"withering","factor":1,"duration":2.0}}
# The tallgrass family: `_mcl_shears_drop = true` and `_mcl_silk_touch_drop = true`.
const SHEARED = [FERN,BUSH,FIREFLY_BUSH,SHORT_DRY_GRASS,TALL_DRY_GRASS]
# The plants whose drop is empty in the source (`drop = ""`): breaking one yields
# nothing at all, and only shears or Silk Touch return the plant. The fern keeps
# the template's wheat-seed drop instead, at the source's rarity of 8.
const NO_DROP = [BUSH,SHORT_DRY_GRASS,TALL_DRY_GRASS]
const SEED_DROPS = [FERN]

# Source soil groups. `soil_generic_plant` is dirt, grass block, mycelium, podzol,
# coarse dirt, rooted dirt, mud, mangrove mud roots, moss and pale moss
# (mcl_core/nodes_base.lua:341,395,457,473,484; mcl_mud/init.lua:13;
# mcl_lush_caves/nodes.lua:83,241; mcl_mangrove/init.lua:373;
# mcl_pale_oak/plants.lua:216). `soil_flower` is that same list **plus** clay
# (mcl_core/nodes_base.lua:649) and both farmland forms (mcl_farming/soil.lua:22,
# 45) — farmland is deliberately *not* in the generic set. Voxey has no mycelium,
# podzol, coarse dirt, rooted dirt, mangrove mud roots or pale moss, so those six
# have no analogue here.
const SOIL_GENERIC = [Nodes.GRASS,Nodes.DIRT,VillageContent.SWAMP_GRASS,VillageContent.MUD,LushCaves.MOSS]
const SOIL_FLOWER = SOIL_GENERIC+[Nodes.CLAY,Farmland.DRY,Farmland.WET]
# The two dry grasses also accept hardened clay and the sands (register.lua:460-467,
# 495-502). Voxey has no red sand; the source's `mcl_sus_nodes:sand` is Voxey's
# suspicious sand.
const SOIL_DRY_EXTRA = [Nodes.TERRACOTTA,Nodes.SAND,Archaeology.SUSPICIOUS_SAND]
# The wither rose short-circuits the soil rule entirely: `soil_generic_plant`,
# netherrack or a soul block (init.lua:98-104).
const SOIL_WITHER = [Nodes.NETHERRACK,Nodes.SOUL_SAND,Campfires.SOUL_SOIL]

# Source `sus_stew = {effect = <e>, duration = <d>}` per flower (register.lua:36-146).
# Every effect key and duration here already exists in `FoodFeatures.STEW_EFFECTS`
# (food_features.gd:22), so the parent needs no new effect vocabulary.
const STEW = {
	TULIP_ORANGE:{"effect":"weakness","duration":9.0},
	TULIP_PINK:{"effect":"weakness","duration":9.0},
	TULIP_RED:{"effect":"weakness","duration":9.0},
	TULIP_WHITE:{"effect":"weakness","duration":9.0},
	ALLIUM:{"effect":"fire_resistance","duration":4.0},
	AZURE_BLUET:{"effect":"blindness","duration":8.0},
	BLUE_ORCHID:{"effect":"saturation","duration":0.5},
	WITHER_ROSE:{"effect":"withering","duration":8.0},
	LILY_OF_THE_VALLEY:{"effect":"poison","duration":12.0},
	CORNFLOWER:{"effect":"leaping","duration":6.0},
}

const DATA = {
	# --- simple flowers (register.lua:36-146) ------------------------------------
	# Colours are original: the source's own textures are never copied. `tool` is
	# -1 because every one of these is `dig_immediate`, so a bare hand harvests it,
	# which is what `Nodes.preferred_tool` and `Nodes.harvestable` need to return
	# true for an empty hand.
	TULIP_ORANGE:{"name":"Orange tulip","block":true,"shape":"plant","color":"e4943e","hardness":0.0,"tool":-1,"transparent":true,"flammable":true,"compostability":65,"source_node":"mcl_flowers:tulip_orange"},
	TULIP_PINK:{"name":"Pink tulip","block":true,"shape":"plant","color":"dd8eac","hardness":0.0,"tool":-1,"transparent":true,"flammable":true,"compostability":65,"source_node":"mcl_flowers:tulip_pink"},
	TULIP_RED:{"name":"Red tulip","block":true,"shape":"plant","color":"b83d41","hardness":0.0,"tool":-1,"transparent":true,"flammable":true,"compostability":65,"source_node":"mcl_flowers:tulip_red"},
	TULIP_WHITE:{"name":"White tulip","block":true,"shape":"plant","color":"e4e4d7","hardness":0.0,"tool":-1,"transparent":true,"flammable":true,"compostability":65,"source_node":"mcl_flowers:tulip_white"},
	ALLIUM:{"name":"Allium","block":true,"shape":"plant","color":"b878cc","hardness":0.0,"tool":-1,"transparent":true,"flammable":true,"compostability":65,"source_node":"mcl_flowers:allium"},
	AZURE_BLUET:{"name":"Azure bluet","block":true,"shape":"plant","color":"e9e4d2","hardness":0.0,"tool":-1,"transparent":true,"flammable":true,"compostability":65,"source_node":"mcl_flowers:azure_bluet"},
	BLUE_ORCHID:{"name":"Blue orchid","block":true,"shape":"plant","color":"79b4d2","hardness":0.0,"tool":-1,"transparent":true,"flammable":true,"compostability":65,"source_node":"mcl_flowers:blue_orchid"},
	# The only flower that does not need light: `on_place_flower` returns before the
	# light test for it (init.lua:98-104), so it grows in the dark, on netherrack
	# and on soul soil.
	WITHER_ROSE:{"name":"Wither rose","block":true,"shape":"plant","color":"333740","hardness":0.0,"tool":-1,"transparent":true,"flammable":true,"compostability":65,"source_node":"mcl_flowers:wither_rose"},
	LILY_OF_THE_VALLEY:{"name":"Lily of the valley","block":true,"shape":"plant","color":"e4e4d7","hardness":0.0,"tool":-1,"transparent":true,"flammable":true,"compostability":65,"source_node":"mcl_flowers:lily_of_the_valley"},
	CORNFLOWER:{"name":"Cornflower","block":true,"shape":"plant","color":"4966ad","hardness":0.0,"tool":-1,"transparent":true,"flammable":true,"compostability":65,"source_node":"mcl_flowers:cornflower"},
	# --- small plants (register.lua:148-512) -------------------------------------
	# The fern inherits `def_tallgrass`: compostability 65, the 1-in-8 wheat-seed
	# drop, and shears/Silk Touch returning the plant (register.lua:348-386).
	FERN:{"name":"Fern","block":true,"shape":"plant","color":"5c8a45","hardness":0.0,"tool":-1,"transparent":true,"flammable":true,"compostability":65,"seeds":true,"drop":0,"source_node":"mcl_flowers:fern"},
	# `drop = ""` (register.lua:390): a bush yields nothing but shears or Silk Touch.
	BUSH:{"name":"Bush","block":true,"shape":"plant","color":"507a32","hardness":0.0,"tool":-1,"transparent":true,"flammable":true,"compostability":30,"drop":0,"source_node":"mcl_flowers:bush"},
	FIREFLY_BUSH:{"name":"Firefly bush","block":true,"shape":"plant","color":"4e7a3c","hardness":0.0,"tool":-1,"transparent":true,"flammable":true,"compostability":30,"light":FIREFLY_LIGHT,"emits":FIREFLY_LIGHT,"source_node":"mcl_flowers:firefly_bush"},
	# The dry grasses are `drop = ""` and burn for five seconds (register.lua:443-512).
	SHORT_DRY_GRASS:{"name":"Short dry grass","block":true,"shape":"plant","color":"b6a05f","hardness":0.0,"tool":-1,"transparent":true,"flammable":true,"compostability":30,"drop":0,"fuel":DRY_FUEL,"source_node":"mcl_flowers:short_dry_grass"},
	TALL_DRY_GRASS:{"name":"Tall dry grass","block":true,"shape":"plant","color":"bcae6a","hardness":0.0,"tool":-1,"transparent":true,"flammable":true,"compostability":30,"drop":0,"fuel":DRY_FUEL,"source_node":"mcl_flowers:tall_dry_grass"},
	# Ground flowers. `wildflowers` and `pink_petals` are the source's `wildflower`
	# group, which places against `soil_generic_plant` and needs no light at all
	# (init.lua:196-204); leaf litter is `placeable_on_anything` (register.lua:161).
	WILDFLOWERS:{"name":"Wildflowers","block":true,"shape":"plant","color":"d9c34a","hardness":0.0,"tool":-1,"transparent":true,"flammable":true,"compostability":30,"source_node":"mcl_flowers:wildflowers"},
	LEAF_LITTER:{"name":"Leaf litter","block":true,"shape":"plant","color":"a37546","hardness":0.0,"tool":-1,"transparent":true,"flammable":true,"compostability":30,"place_anywhere":true,"fuel":DRY_FUEL,"source_node":"mcl_flowers:leaf_litter"},
	PINK_PETALS:{"name":"Pink petals","block":true,"shape":"plant","color":"dd8eac","hardness":0.0,"tool":-1,"transparent":true,"flammable":true,"compostability":30,"source_node":"mcl_flowers:pink_petals"},
}

# --- predicates --------------------------------------------------------------

# The two id runs are contiguous, so the predicates are range tests rather than
# list scans; `FLOWERS` and `PLANTS` must stay in the same order.
static func is_flower(id: int) -> bool: return id >= TULIP_ORANGE and id <= CORNFLOWER
static func is_plant(id: int) -> bool: return id >= FERN and id <= PINK_PETALS
static func is_sheared(id: int) -> bool: return id in SHEARED

# Source `_mcl_crafting_output = {single = {output = "mcl_dyes:<c>"}}`: one flower
# to one dye, in the source's own colour per flower. The three the source calls
# `silver` are Voxey's light grey dye (823), which is the same colour name.
static func dye_of(id: int) -> int:
	match id:
		TULIP_ORANGE: return VillageContent.DYE_ORANGE
		TULIP_PINK,PINK_PETALS: return VillageContent.DYE_PINK
		TULIP_RED: return VillageContent.DYE_RED
		TULIP_WHITE,AZURE_BLUET: return VillageContent.DYE_SILVER
		ALLIUM: return VillageContent.DYE_MAGENTA
		BLUE_ORCHID: return VillageContent.DYE_LIGHT_BLUE
		WITHER_ROSE: return VillageContent.DYE_BLACK
		LILY_OF_THE_VALLEY: return VillageContent.DYE_WHITE
		CORNFLOWER: return VillageContent.DYE_BLUE
		WILDFLOWERS: return VillageContent.DYE_YELLOW
	return 0

static func stew_effect(id: int) -> String: return str(STEW.get(id,{}).get("effect",""))
static func stew_duration(id: int) -> float: return float(STEW.get(id,{}).get("duration",0.0))

# The effect spec a contact-damage hook applies to whatever stands in this node, or
# an empty dictionary when the plant is harmless. The parent wires this to the
# source's `_on_object_in` point (its `mcl_walkover` globalstep, which tests the
# feet and head cells): `PotionEffects.apply(target, spec.effect, spec.duration)`.
static func contact(id: int) -> Dictionary: return CONTACT.get(id,{})
static func contact_effect(id: int) -> String: return str(contact(id).get("effect",""))
static func light_level(id: int) -> int: return FIREFLY_LIGHT if id == FIREFLY_BUSH else 0

# Source `_mcl_burntime = 5`. `Nodes.fuel_time` resolves fuel with hardcoded
# branches rather than reading a `fuel` key, so this is the accessor the parent
# adds one branch for; the DATA entries also carry the value for the record.
static func fuel_time(id: int) -> float: return float(DRY_FUEL) if id in [LEAF_LITTER,SHORT_DRY_GRASS,TALL_DRY_GRASS] else 0.0

# Source `drop = ""` for the bush and both dry grasses; the fern keeps the
# tallgrass template's wheat-seed drop instead (rarity 8, rolled by the parent),
# and the two ground flowers drop themselves.
static func drop(id: int) -> int: return 0 if id in NO_DROP or id in SEED_DROPS else id
static func seeds(id: int) -> bool: return id in SEED_DROPS

# --- placement rules ---------------------------------------------------------

# Whether the source accepts `below` as this plant's soil. Simple flowers and the
# tallgrass family need `group:soil_flower`; the ground flowers, the firefly bush
# and the dry grasses need `group:soil_generic_plant` (the dry grasses also accept
# hardened clay and sand), and leaf litter accepts anything.
static func soil_ok(id: int, below: int) -> bool:
	if id == LEAF_LITTER: return true
	if id == WITHER_ROSE: return below in SOIL_GENERIC or below in SOIL_WITHER
	# Simple flowers, and the fern and bush through the tallgrass template, all go
	# through `mcl_flowers.on_place_flower` and its `soil_flower` test.
	if is_flower(id) or id in [FERN,BUSH]: return below in SOIL_FLOWER
	# The rest replace `on_place` with their own allowed list: `soil_generic_plant`,
	# which the two dry grasses extend with hardened clay and the sands.
	if id in [SHORT_DRY_GRASS,TALL_DRY_GRASS]: return below in SOIL_GENERIC or below in SOIL_DRY_EXTRA
	return below in SOIL_GENERIC

# Only the simple flowers and the tallgrass template test light at all; the
# ground flowers, the firefly bush and the dry grasses do not, and the wither rose
# returns before the test (init.lua:71-108, 196-204, 402-512).
static func needs_light(id: int) -> bool:
	if id == WITHER_ROSE: return false
	return is_flower(id) or id in [FERN,BUSH]

# Shears or Silk Touch recover the tallgrass family itself, and an ordinary break
# yields nothing (or the fern's seed, which the parent rolls).
static func harvest(id: int, slot: Dictionary) -> Array:
	if not is_sheared(id): return []
	if int(slot.get("id",0)) == Nodes.SHEARS or Inventory.enchantment(slot,"Silk Touch") > 0: return [[id,1]]
	return []

# Source `mcl_trees/api.lua:203` gives the shared leaves template
# `_mcl_cooking_output = "mcl_flowers:leaf_litter"`, so smelting any leaf yields
# one. This belongs to an *existing* input id, so it cannot live in `DATA`.
static func smelt_output(id: int) -> int: return LEAF_LITTER if WoodTypes.is_leaves(id) else 0

# --- recipes -----------------------------------------------------------------

# The source's dye crafts are `_mcl_crafting_output = {single = {output = ...}}`,
# i.e. a one-for-one craft from the flower, which is the same shape
# `FoodFeatures.recipes` already uses for poppy, dandelion and oxeye daisy.
# Suspicious stew is *not* registered here: it belongs to `FoodFeatures`, which
# already owns the four-ingredient recipe and reads the effect from the flower.
static func recipes(inv: Inventory) -> void:
	for id in FLOWERS:
		var dye: int = dye_of(id)
		if dye != 0: inv._recipe(Nodes.title(dye),dye,1,[id],1)
	for pair in [[WILDFLOWERS,VillageContent.DYE_YELLOW],[PINK_PETALS,VillageContent.DYE_PINK]]:
		inv._recipe(Nodes.title(pair[1]),pair[1],1,[pair[0]],1)

# --- art ---------------------------------------------------------------------

# The same stalk `food_features.gd:43` draws for Voxey's three existing flowers,
# so a tulip and a poppy read as the same family at 16 pixels.
const STEM = "548448"

static func pixel(id: int, x: int, y: int, noise: Color) -> Color:
	return flower_pixel(id,x,y,noise) if is_flower(id) else plant_pixel(id,x,y,noise)

static func draw(img: Image, id: int) -> void:
	for y in 16:
		for x in 16:
			# A stand-in for `Art.make_atlas`'s per-pixel noise so an inventory icon
			# carries the same grain as the world tile.
			var noise: Color = Color(DATA[id].color)*(0.88+float((x*7+y*13+id)%9)*0.03)
			img.set_pixel(x,y,pixel(id,x,y,noise))

static func flower_pixel(id: int, x: int, y: int, _noise: Color) -> Color:
	# Two flowers are not a bloom over the shared stalk: the lily leans its own
	# stalk and hangs bells from it, and the orchid's lip sits low enough to need its
	# own arrangement. Drawing those here keeps one stalk per flower on screen.
	if id == LILY_OF_THE_VALLEY: return lily_pixel(x,y)
	var base: Color = Color(DATA[id].color)
	var bloom: Color = bloom_pixel(id,x,y,base)
	if bloom.a > 0.0: return bloom
	# A wither rose keeps its colour even in the stalk: it is not a living plant.
	var stem: Color = Color("3c4237") if id == WITHER_ROSE else Color(STEM)
	if x in [7,8] and y in range(7,16): return stem
	if y in [11,12] and x in [5,6,9,10]: return stem
	return Color.TRANSPARENT

static func bloom_pixel(id: int, x: int, y: int, base: Color) -> Color:
	var dx: int = absi(x-7)
	if x >= 4 and x <= 11:
		if id in [TULIP_ORANGE,TULIP_PINK,TULIP_RED,TULIP_WHITE]:
			# A tulip is a cup: a rounded bowl with two notched flower tips above it.
			if y < 2 or y > 7: return Color.TRANSPARENT
			if dx > [2,3,3,3,3,2][y-2]: return Color.TRANSPARENT
			if y == 2 and dx == 0: return Color.TRANSPARENT
			if y == 7: return base.darkened(0.3)
			return base.lightened(0.15 if x < 7 else 0.0)
		if id == ALLIUM:
			# An allium is a ball of florets, so it is a dense disc with a speckle
			# and a ragged rim rather than one petal shape.
			var r: float = Vector2(x-7.5,y-4.0).length()
			if r > 4.2: return Color.TRANSPARENT
			if r > 3.2 and (x+y)%2 == 0: return Color.TRANSPARENT
			return base.lightened(0.24 if (x*3+y*5)%4 == 0 else 0.0).darkened(0.12 if r > 3.0 else 0.0)
		if id == AZURE_BLUET:
			# The same petal disc the existing daisy uses, with a yellow heart.
			var bdx: int = x-7
			var bdy: int = y-4
			if absi(bdx)+absi(bdy) > 4: return Color.TRANSPARENT
			if bdx*bdx+bdy*bdy < 3: return Color("e5b63c")
			return base.lightened(0.1 if (x+y)%2 == 0 else 0.0)
		if id == BLUE_ORCHID:
			# Two upswept petals over a pale lower lip.
			if y in range(0,4) and dx <= 2: return base.lightened(0.16 if dx == 2 else 0.0)
			if y in range(4,6) and dx <= 2: return base.darkened(0.14)
			if y == 6 and dx <= 1: return Color("e8e2c8")
			return Color.TRANSPARENT
		if id == WITHER_ROSE:
			# A rose: a ring of petals around a black heart. The petals are lifted
			# towards grey so the flower reads against its own near-black colour, and
			# the rim is ragged rather than a smooth disc.
			var rr: float = Vector2(x-7.5,y-4.5).length()
			if rr < 1.8: return Color("15151a")
			if rr > 4.4: return Color.TRANSPARENT
			if rr > 3.3 and (x+y)%2 == 1: return Color.TRANSPARENT
			return base.lightened(0.42 if (x*5+y*3)%5 == 0 else 0.28).darkened(0.1 if rr > 3.3 else 0.0)
		if id == CORNFLOWER:
			# A ragged head: petals reaching out in eight directions, dark at the
			# centre, with the outer ring notched so it is not a smooth ball.
			var cdx: int = x-7
			var cdy: int = y-4
			var ad: int = absi(cdx)+absi(cdy)
			if ad > 6: return Color.TRANSPARENT
			if ad >= 5 and (x+y)%2 == 1: return Color.TRANSPARENT
			if ad <= 2: return Color("3d5a8f")
			return base.lightened(0.22 if (ad+absi(cdx-cdy))%2 == 0 else 0.0)
	return Color.TRANSPARENT

# Bell positions for the lily of the valley, hanging off the leaning stalk.
const LILY_BELLS = [[9,4],[10,7],[11,10]]

static func lily_pixel(x: int, y: int) -> Color:
	var base: Color = Color(DATA[LILY_OF_THE_VALLEY].color)
	# A leaning stalk with three small bells, which is what separates it from a
	# white tulip at this size.
	if y in range(3,16) and x == (8 if y > 10 else (9 if y > 7 else 10)): return Color(STEM)
	for bell in LILY_BELLS:
		if x == bell[0] and y == bell[1]-1: return Color(STEM)
		if y in [bell[1],bell[1]+1] and x in [bell[0],bell[0]+1]:
			return base.darkened(0.14) if y == bell[1]+1 else base.lightened(0.08)
	return Color.TRANSPARENT

static func plant_pixel(id: int, x: int, y: int, noise: Color) -> Color:
	var base: Color = Color(DATA[id].color)
	if id == FERN: return frond_pixel(x,y,base)
	if id in [BUSH,FIREFLY_BUSH]: return bush_pixel(id,x,y,noise,base)
	if id == SHORT_DRY_GRASS: return blade_pixel(SHORT_BLADES,x,y,base)
	if id == TALL_DRY_GRASS: return blade_pixel(TALL_BLADES,x,y,base)
	if id == WILDFLOWERS: return wildflower_pixel(x,y)
	if id == LEAF_LITTER: return litter_pixel(x,y,noise)
	return petals_pixel(x,y,noise,base)

# Four fronds arching out of one base, each described by its tip: `[top_y, tip_x]`.
# The rib curves outward quadratically as it rises, and each rib carries leaflets on
# both sides that are longest at the base and taper to the tip, which is what makes a
# fern read as a fern rather than a bundle of straight blades.
const FERN_FRONDS = [[3,1],[4,5],[5,10],[7,14]]

static func frond_pixel(x: int, y: int, base: Color) -> Color:
	for frond in FERN_FRONDS:
		var top: int = int(frond[0])
		if y < top: continue
		var t: float = float(15-y)/float(15-top)
		var rib: int = 7+int(round(float(int(frond[1])-7)*t*t))
		var dx: int = x-rib
		if dx == 0: return base.darkened(0.24)
		var length: int = 1+(15-y)/5
		if absi(dx) > length: continue
		# The outermost leaflet on every other row is dropped, so the frond edge is
		# feathered instead of a smooth blade.
		if absi(dx) == length and length > 1 and (15-y+top)%2 == 0: continue
		if absi(dx) == length: return base.darkened(0.14)
		return base.lightened(0.12 if (x+y)%3 == 0 else 0.0)
	return Color.TRANSPARENT

static func bush_pixel(id: int, x: int, y: int, noise: Color, base: Color) -> Color:
	# A dense leafy mass: an ellipse with a ragged rim and darker gaps between the
	# leaves, so it does not read as a coloured ball.
	var r: float = Vector2((x-7.5)/6.3,(y-8.5)/6.6).length()
	if r > 1.0: return Color.TRANSPARENT
	if r > 0.85 and (x*3+y*5)%3 == 0: return Color.TRANSPARENT
	if id == FIREFLY_BUSH and (x*7+y*11)%19 < 2: return Color("f4f0b4")
	if (x*5+y*3)%7 < 2: return base.darkened(0.3)
	return noise.lerp(base,0.8).lightened(0.1 if (x+y)%4 == 0 else 0.0)

# Dry grass tufts: x, height and lean per blade, grown short and grown long.
const SHORT_BLADES = [[3,3,-1],[5,5,-1],[7,4,0],[9,6,1],[11,4,1],[13,3,1]]
const TALL_BLADES = [[3,9,-1],[5,13,-1],[7,10,0],[9,14,1],[11,11,1],[13,12,0],[15,8,1]]

static func blade_pixel(blades: Array, x: int, y: int, base: Color) -> Color:
	# The same uneven tuft `food_features.gd:51` draws for tall grass, in the dry
	# palette: each blade has its own height and leans harder towards its tip.
	for blade in blades:
		var top: int = 15-blade[1]
		var lean: int = (15-y)*(15-y)/24*blade[2]
		if x == blade[0]+lean and y >= top:
			return base.lightened(0.16 if y == top else 0.0).darkened(0.1 if (x+y)%3 == 0 else 0.0)
	return Color.TRANSPARENT

# Small blooms of several colours on short stems, which is what the source's
# wildflower patch is: x, y and petal colour per bloom.
const WILD_BLOOMS = [[5,10,"e8e0cc"],[8,7,"e5b63c"],[11,9,"dd8eac"],[7,5,"d8d2c4"],[13,12,"df7a7a"]]

static func wildflower_pixel(x: int, y: int) -> Color:
	for bloom in WILD_BLOOMS:
		if x == bloom[0] and y > bloom[1]: return Color(STEM).darkened(0.12 if int(bloom[0])%2 else 0.0)
		if y == bloom[1] and x == bloom[0]: return Color(str(bloom[2]))
		if y == bloom[1]+1 and absi(x-int(bloom[0])) == 1: return Color(str(bloom[2])).darkened(0.12)
	if y in [13,14] and x in [4,5,10,11,14]: return Color(DATA[WILDFLOWERS].color).darkened(0.2)
	return Color.TRANSPARENT

static func litter_pixel(x: int, y: int, noise: Color) -> Color:
	# Leaf litter lies flat: a scatter of small leaves and twigs across the bottom of
	# the tile, with no stalk and no bloom.
	if y < 10: return Color.TRANSPARENT
	if y in [13,14] and (x*7+y*3)%11 < 3: return Color("6f4d2c")
	if (x*5+y*7)%13 < 5: return noise.lerp(Color("b0824f"),0.7)
	if (x*3+y*11)%17 < 3: return Color("8a6136")
	return Color.TRANSPARENT

static func petals_pixel(x: int, y: int, noise: Color, base: Color) -> Color:
	# Pink petals sit on the ground as small clusters of petal shapes.
	if y < 9: return Color.TRANSPARENT
	if (x*5+y*3)%7 < 3 and (x+y)%2 == 0: return noise.lerp(base,0.75).lightened(0.12)
	if (x*11+y*5)%17 < 2: return base.darkened(0.18)
	return Color.TRANSPARENT
