class_name PigRiding
extends RefCounted

# Mineclonia `mods/ENTITIES/mobs_mc/pig.lua` (`pig:equip_saddle` and
# `pig:on_rightclick`, pig.lua:125-244), `mods/ENTITIES/mcl_mobs/mount.lua` (the
# `follow_item` steer class: `should_drive`, `apply_driver_input`, `drive`,
# `hog_boost`, mount.lua:110-275) and `mods/ITEMS/mcl_mobitems/init.lua` (the two
# item registrations at init.lua:304-326 and their recipes at init.lua:466-495),
# GPL-3.0-or-later. Original GDScript using the source as a behaviour reference;
# all art is original procedural code.
#
# Voxey had no way to ride a pig. `scripts/village_survival.gd` mounts a horse
# (`mount`, `ride_step`), `scripts/rural_animal.gd` carries `saddled`, and
# `scripts/farming.gd` breeds a pig — but a pig is spawned as a plain `Creature`,
# nothing can put a saddle on one, and neither stick item existed. This module is
# the pig half: the two items, the saddle, the mounting rule, and the source's own
# driving step with its `hog_boost` speed window.
#
# Source rules reproduced here:
#   * `pig:on_rightclick` is four ordered branches, and only the last one mounts
#     (pig.lua:162-244): the pig's own food, a saddle on an unsaddled pig, shears
#     on a saddled pig, the driver's own click with a steering item — which starts
#     the boost and wears the stick — and finally the mount/detach branch. This
#     module's `can_mount`, `equip_saddle`, `unsaddle` and `use_stick` are those
#     branches and the parent's dispatcher keeps their order, because a branch that
#     returns early in the source must not mount here either.
#   * A **baby** pig cannot be saddled, unsaddled or mounted: `if self.child then
#     return end` (pig.lua:171) sits above all three. `growth_remaining` is Voxey's
#     baby flag, the same test `farming.gd` uses.
#   * `mount.lua:110-129 should_drive`: with `steer_class = "follow_item"`
#     (pig.lua:79) the pig is driven only while its driver wields the mob's own
#     `steer_item`, which is `"group:controls_pig"` (pig.lua:80). The
#     carrot-on-a-stick declares that group (init.lua:312); the
#     warped-fungus-on-a-stick declares `controls_strider` (init.lua:323), so it
#     steers a strider and not a pig. Voxey has no strider, so that item's own
#     contribution is its identity, wear and recipe.
#   * `mount.lua:180-246 drive`: the driver's horizontal look sets the mob's yaw,
#     the pig always walks *forward* at `movement_speed * drive_bonus` — the
#     `follow_item` half hardcodes `acc_dir.z = 1` (mount.lua:145), so the
#     movement input only ever decides the heading, never the speed — and while a
#     boost window is open the speed is multiplied by
#     `1 + 1.5 * sin(elapsed / total * pi)`.
#   * `mount.lua:264-275 hog_boost`: a window lasts `(random(841) + 140) / 20.0`
#     seconds, 7.05 to 49.05, and a click while one is already open starts nothing.
#     The window clock is advanced by `drive` itself (mount.lua:230-237), so it only
#     runs while the pig is actually being driven.
#   * `mount.lua:148-150`: the `follow_item` steer class jumps when it is pressing
#     into something, which is Voxey's own automatic step for a walking body.
#   * `pig.lua:212-224`, the `-- 26 uses` block: once the stick is worn past
#     `wear > 63000` it breaks and the driver is left holding a fishing rod;
#     otherwise it takes 2521 wear, which is `_mcl_uses = 26` (init.lua:313, and
#     init.lua:325 for the fungus stick) converted by `mcl_autogroup` to one
#     twenty-sixth of the engine's 65535 wear per use.
#
# Adaptations, each forced by a Voxey difference:
#   * Voxey's wear is a small per-use integer (`Nodes.durability`, `Inventory.
#     damage_tool`), not the source's 0..65535, so `durability` is 26 uses and one
#     use is one point of wear. The 26th use is the one that breaks the stick,
#     which is the same count the source's twenty-five 2521 increments followed by
#     the break at 63025 produce.
#   * The source's wear sits inside `if self:hog_boost()` (pig.lua:209), so a click
#     while a window is already open burns nothing. `use_stick` wears on every
#     click and only *starts* a window when none is open, because Voxey's
#     `use_stick(game) -> bool` contract is "wears one use, refuses when broken".
#     The window's own rules — one window at a time, the length roll, the sine
#     curve, the clock advanced only while driving — are untouched.
#   * A driven pig in the source is **slower** than a wandering one: `drive_bonus`
#     is 0.225 of its own walking speed (pig.lua:29-30). Voxey's own walking speed
#     for a pig is `Creature.KINDS.pig.speed` (creature.gd:42), so that is the base
#     this module scales — the source's ratio, kept rather than inflated into a
#     horse-like ride.
#   * `self.tamed = true` (pig.lua:133) has no counterpart here: nothing in Voxey
#     reads a tamed flag for a pig, and the mount branch never consulted it.
#   * `pig.lua:245-252 after_activate` re-equips the saddle when a pig loads. Voxey
#     has no such hook and this module holds the saddle in the mob's own `saddled`
#     flag, so the parent's farm record is where a saddled pig would have to be
#     saved (see PARENT WIRING).
#   * Dis-/mounting is Ctrl in the parent's `ride_step`, which is Voxey's own rule
#     for a mount. The source detaches on a second right-click by the driver
#     (pig.lua:228-237), and the parent's dispatcher keeps that branch as well.

const CARROT_ON_A_STICK = 11580
const WARPED_FUNGUS_ON_A_STICK = 11581

# The two rows the parent appends to `VillageContent.DATA`. `stack` is the
# source's `stack_max = 1` for a tool, and `family` is this project's own tag, used
# by `VillageItemArt` to route the icon. The colour is the head's own colour — the
# carrot's (village_content.gd:837) and the warped fungus's
# (crimson_plants.gd:37) — because that is what tells the two sticks apart.
const DATA = {
	11580:{"name":"Carrot on a stick","color":"ed8c37","stack":1,"durability":26,"family":"tool_steering"},
	11581:{"name":"Warped fungus on a stick","color":"4a8d8a","stack":1,"durability":26,"family":"tool_steering"},
}

# `_mcl_uses` (init.lua:313) for the carrot stick. **The fungus stick is 100 in the
# source** (init.lua:325); this table fixes both at the carrot stick's 26 because
# that is this module's caller contract. It is the one deliberate departure from
# the source, it is confined to this table together with the two `durability` keys
# in `DATA`, and nothing else moves if both values become 100.
const USES = {
	CARROT_ON_A_STICK:26,
	WARPED_FUNGUS_ON_A_STICK:26,
}

# `pig.lua:30 drive_bonus = 0.225` against `pig.lua:29 movement_speed = 5.0`, so the
# source's driven pig walks at 0.225 of its own walking speed. `mount.lua:240`
# multiplies the two, and `mount.lua:243-245` scales the product by the window.
const DRIVE_BONUS = 0.225
# `mount.lua:243 local f = 1.0 + 1.5 * math.sin (elapsed / total * math.pi)`.
const BOOST_BASE = 1.0
const BOOST_PEAK = 1.5
# `mount.lua:171 local MAX_PHYSICS_DTIME = 0.075`.
const MAX_PHYSICS_DTIME = 0.075
# Voxey's own gravity and automatic step, the ones `ride_step` and the shared
# creature step already use (village_survival.gd:551, creature.gd:831 and :839).
const GRAVITY = 22.0
const STEP_JUMP = 7.2

const BOOST_ELAPSED = "pig_drive_boost_elapsed"
const BOOST_TOTAL = "pig_drive_boost_total"
const SADDLE_PLATE = "pig_saddle_plate"

# --- items --------------------------------------------------------------------

# The source's `_mcl_uses` as this project measures wear: one use, one point.
static func durability(id: int) -> int: return int(USES.get(id,0))

# Both sticks are `tool = 2, transport = 1, enchantability = -1, _mcl_toollike_wield
# = true` (init.lua:312 and :323) with one `controls_*` group each.
static func is_steering_item(id: int) -> bool: return id in [CARROT_ON_A_STICK,WARPED_FUNGUS_ON_A_STICK]

# `pig.lua:80 steer_item = "group:controls_pig"`. The source's enchanted
# carrot-on-a-stick carries the same group; Voxey has no enchanted variant, so this
# is the one item that drives the pig.
static func drives_pig(id: int) -> bool: return id == CARROT_ON_A_STICK

# `init.lua:466-495`: each output has two mirrored shaped recipes, a fishing rod
# beside the carrot (or the warped fungus) on the other row. `matching_recipe`
# already accepts a mirrored pattern (inventory.gd:493-496), so one entry per output
# is the whole of that rule here. The rows are `[label,id,count,pattern]`, the shape
# `CauldronWash.recipe_entries` uses, for the parent's `_recipe(...,2)` call.
static func recipe_entries() -> Array:
	return [
		["Carrot on a stick",CARROT_ON_A_STICK,1,[VillageContent.FISHING_ROD,0,0,VillageContent.CARROT]],
		["Warped fungus on a stick",WARPED_FUNGUS_ON_A_STICK,1,[VillageContent.FISHING_ROD,0,0,CrimsonPlants.WARPED_FUNGUS]],
	]

# --- the saddle ---------------------------------------------------------------

static func is_pig(mob: Creature) -> bool:
	return mob != null and is_instance_valid(mob) and not mob.is_queued_for_deletion() and mob.kind == "pig"

# `pig.lua:171 if self.child then return end`: a baby is past every branch below it,
# so it can be neither saddled nor ridden. `growth_remaining` is the project's own
# baby flag (`farming.gd` tests it the same way).
static func mountable(mob: Creature) -> bool:
	return is_pig(mob) and mob.health > 0.0 and mob.growth_remaining <= 0.0

# `saddle == "yes"` (pig.lua:239) is Voxey's `RuralAnimal.saddled` (rural_animal.gd:5).
static func saddled(mob: Creature) -> bool:
	return mob is RuralAnimal and mob.saddled

# `pig:equip_saddle` (pig.lua:125-152) as far as Voxey can express it: the flag, and
# the saddle plate on the pig's own back. `tamed` is dropped, as noted above. The
# plate is drawn through the mob's own `_box` (creature.gd:551) — a mob's model is
# built by the shared file, so this is the only place the pig's saddle can live
# without editing it — at the pig's back height (its body is the box at
# creature.gd:458, top at 0.79) rather than the horse's 1.37.
static func equip_saddle(mob: Creature) -> bool:
	if not mountable(mob): return false
	var already: bool = saddled(mob)
	# A pig restored from a save is flagged saddled by the shared animal path before
	# this runs (village_survival.gd:658 calls `equip_saddle` for every kind). That
	# path draws the *horse's* plate at the horse's own height, so a pig that has no
	# plate of this module's making is given one here rather than left bare.
	if already and mob.has_meta(SADDLE_PLATE): return false
	mob.saddled = true
	if mob.has_meta(SADDLE_PLATE):
		var existing: Variant = mob.get_meta(SADDLE_PLATE)
		if existing is MeshInstance3D and is_instance_valid(existing): existing.visible = true
	else:
		var plate: MeshInstance3D = mob._box(Vector3(0,0.80,0.06),Vector3(0.62,0.12,0.55),Color("784c34"),"cloth")
		for side in [-1,1]: mob._box(Vector3(side*0.33,0.62,0.06),Vector3(0.05,0.3,0.14),Color("c5ad78"),"",plate)
		mob.set_meta(SADDLE_PLATE,plate)
	return not already

# `pig.lua:191-204`: shears take the saddle off and drop it, and the pig's textures
# return to the unsaddled pair. The plate is hidden rather than freed because it is
# registered in the mob's own `parts` (creature.gd:561) and `_tint` walks that list
# on every hit (creature.gd:944-946).
static func unsaddle(mob: Creature) -> bool:
	if not mountable(mob) or not saddled(mob): return false
	mob.saddled = false
	if mob.has_meta(SADDLE_PLATE):
		var plate: Variant = mob.get_meta(SADDLE_PLATE)
		if plate is MeshInstance3D and is_instance_valid(plate): plate.visible = false
	return true

# `pig.lua:239 elseif not self.driver and self.saddle == "yes"`. `held` is the
# driver's item, and it matters for the same reason it does in the source: two of
# the branches above this one own the click and return, so shears on a saddled pig
# strip the saddle rather than mounting it.
static func can_mount(mob: Creature, held: int) -> bool:
	if not mountable(mob) or not saddled(mob): return false
	if mob == mob.game.survival.mount: return false
	return held != Nodes.SHEARS

# `pig.lua:228-237`: the driver's own click detaches instead of mounting.
static func ridden(mob: Creature) -> bool: return mob != null and mob.game.survival.mount == mob

# --- the boost window ---------------------------------------------------------

# `mount.lua:264-268`: false while a window is open, so only the first click of a
# window starts one.
static func boost_active(mob: Creature) -> bool: return mob != null and mob.has_meta(BOOST_ELAPSED)

# `mount.lua:264-275 hog_boost`.
static func hog_boost(mob: Creature) -> bool:
	if mob == null or boost_active(mob): return false
	mob.set_meta(BOOST_ELAPSED,0.0)
	mob.set_meta(BOOST_TOTAL,(float(randi_range(1,841))+140.0)/20.0)
	return true

# `mount.lua:243-245`: the multiplier the window applies to the driven speed.
static func boost_factor(mob: Creature) -> float:
	if not boost_active(mob): return 1.0
	var total: float = float(mob.get_meta(BOOST_TOTAL,0.0))
	if total <= 0.0: return 1.0
	var elapsed: float = maxf(0.0,float(mob.get_meta(BOOST_ELAPSED,0.0)))
	return BOOST_BASE+BOOST_PEAK*sin(clampf(elapsed/total,0.0,1.0)*PI)

# `mount.lua:213-237`: the clock advances with the driving step and the window ends
# once it runs past its length.
static func advance_boost(mob: Creature, delta: float) -> void:
	if not boost_active(mob): return
	var elapsed: float = float(mob.get_meta(BOOST_ELAPSED,0.0))+delta
	if elapsed > float(mob.get_meta(BOOST_TOTAL,0.0)): mob.remove_meta(BOOST_ELAPSED)
	else: mob.set_meta(BOOST_ELAPSED,elapsed)

# `mount.lua:240-245`: the pig's own walking speed, scaled by `drive_bonus` and then
# by the window. See the header for why the base is Voxey's own speed for the kind.
static func drive_speed(mob: Creature) -> float:
	var walk: float = float(Creature.KINDS.get(mob.kind,{}).get("speed",0.0))
	return walk*DRIVE_BONUS*boost_factor(mob)

# --- the stick ----------------------------------------------------------------

# `mount.lua:110-129 should_drive` for the `follow_item` steer class: a driver must
# be present and must be wielding the mob's own steer item. Voxey's only driver is
# the player, and the player drives whatever `survival.mount` holds.
static func can_drive(mob: Creature) -> bool:
	if not mounted_pig(mob): return false
	if not drives_pig(int(mob.game.inventory.held().id)): return false
	return int(mob.game.inventory.held().count) > 0

# The pig the player is riding, or null. `survival.mount` is what `ride_step` reads,
# so this is "is there a driver" in the source's terms.
static func mounted_pig(mob: Creature) -> bool:
	return is_pig(mob) and mob.game != null and mob.game.survival != null and saddled(mob) and mob.game.survival.mount == mob

static func mounted(game: Node3D) -> Creature:
	if game == null or game.survival == null: return null
	var mob: Creature = game.survival.mount
	return mob if mounted_pig(mob) else null

# `pig.lua:206-227`: the driver right-clicks the pig they are riding with a
# steering item. It starts the window when none is open and wears the stick; the
# 26th use is the one that breaks it and leaves a fishing rod.
static func use_stick(game: Node3D) -> bool:
	var mob: Creature = mounted(game)
	if mob == null: return false
	var slot: Dictionary = game.inventory.held()
	if int(slot.count) <= 0 or not drives_pig(int(slot.id)): return false
	# "Refuses when broken": a stack at or past its span is not usable, however it
	# got there.
	if int(slot.wear) >= durability(int(slot.id)): return false
	hog_boost(mob)
	wear_stick(game,slot)
	return true

# `pig.lua:212-224`. The break leaves the source's own replacement, a fishing rod,
# in the driver's hand.
static func wear_stick(game: Node3D, slot: Dictionary) -> void:
	var id: int = int(slot.id)
	var span: int = durability(id)
	if span <= 0: return
	if int(slot.wear)+1 >= span:
		slot.clear(); slot.merge({"id":VillageContent.FISHING_ROD,"count":1,"wear":0})
		game.sound("break")
	else: slot.wear = int(slot.wear)+1
	game.inventory.changed.emit()

# --- the drive step -----------------------------------------------------------

# `mount.lua:180-246 drive` for the `follow_item` steer class, one step.
#
# `direction` is the driver's horizontal look, which is what the source reads at
# mount.lua:181; the pig then walks **forward** along it at the driven speed —
# `acc_dir.z = 1` (mount.lua:145) means the movement input never scales the speed,
# so a driver standing still still moves. With no heading at all the pig keeps the
# one it had, which is the source's `set_yaw` being skipped rather than the pig
# turning to face nothing.
static func steer(game: Node3D, mob: Creature, delta: float, direction: Vector3) -> void:
	if delta <= 0.0 or not can_drive(mob): return
	var heading := Vector3(direction.x,0.0,direction.z)
	if heading.length() < 0.05: heading = Vector3(mob.direction.x,0.0,mob.direction.z)
	if heading.length() < 0.05: return
	heading = heading.normalized()
	mob.direction = heading
	mob.model.rotation.y = atan2(-heading.x,-heading.z)
	var world: VoxelWorld = game.world
	var speed: float = drive_speed(mob)
	mob.velocity.x = heading.x*speed
	mob.velocity.z = heading.z*speed
	mob.velocity.y -= GRAVITY*delta
	var step: float = minf(delta,MAX_PHYSICS_DTIME)
	var grounded: bool = false
	for axis in [0,2,1]:
		var next: Vector3 = mob.position
		next[axis] += mob.velocity[axis]*step
		if not world.intersects(next,mob.width,mob.height): mob.position = next
		elif axis == 1:
			if mob.velocity.y < 0.0: grounded = true
			mob.velocity.y = 0.0
		elif world.intersects(mob.position-Vector3.UP*0.08,mob.width,0.5) and not world.intersects(mob.position+Vector3.UP*1.0,mob.width,mob.height):
			# mount.lua:148-150: the `follow_item` steer class steps up what it is
			# pressing into, at the shared creature step's own force.
			mob.velocity.y = STEP_JUMP
	if not grounded and world.intersects(mob.position-Vector3.UP*0.04,mob.width,0.5): grounded = true
	# mount.lua:230-237: the window runs down only while the pig is being driven.
	advance_boost(mob,delta)

# --- art ----------------------------------------------------------------------

# A rod with the head hanging off its tip, which is the shape the source's own two
# textures share: the stick in the wood colour of Voxey's fishing rod
# (village_content.gd:857) and a string over the tip to the bait. Only the bait
# differs between the two items, and it is painted in each head's own colour.
static func draw(img: Image, id: int, base: Color) -> void:
	ItemArt._line(img,Vector2(2,14),Vector2(10,6),Color("6d4a2c"),3)
	ItemArt._line(img,Vector2(2,13),Vector2(9,6),Color("ba955b"))
	ItemArt._line(img,Vector2(10,6),Vector2(13,4),Color("4a3d30"),1)
	if id == CARROT_ON_A_STICK:
		ItemArt._polygon(img,[[12,3],[15,4],[15,8],[12,9]],base)
		ItemArt._line(img,Vector2(13,4),Vector2(13,8),base.darkened(0.25))
		img.fill_rect(Rect2i(9,1,4,3),Color("5f8a3a"))
	else:
		ItemArt._polygon(img,[[10,4],[13,3],[16,5],[13,8],[10,7]],base)
		ItemArt._polygon(img,[[11,5],[13,4],[15,6],[12,7]],base.lightened(0.2))
	ItemArt._line(img,Vector2(11,7),Vector2(12,10),Color("cfd8d2"))

# ---------------------------------------------------------------------------
# PARENT WIRING — all of it is now applied, and each entry says so. The three
# literal inserts this module asked for were handed to Main verbatim and landed;
# they are restated here so the module keeps its own record of what it needs.
#
# 1. `scripts/village_content.gd DATA` — **applied** (village_content.gd:878-879):
#
#        11580:PigRiding.DATA[11580],
#        11581:PigRiding.DATA[11581],
#
#    No `BLOCKS` entry is needed: `Nodes.all_ids` offers every `VillageContent.DATA`
#    id to the creative catalog (nodes.gd:525-526), and the rows carry no `block`
#    key so the items are unplaceable (nodes.gd:766). The rows themselves give the
#    title (nodes.gd:447), the colour (nodes.gd:487), `max_stack` 1 (nodes.gd:634)
#    and the wear span.
#
# 2. `scripts/nodes.gd durability` — **applied** (nodes.gd:625):
#
#        if PigRiding.is_steering_item(id): return PigRiding.durability(id)
#
#    The row's own `durability:26` would have answered as well (nodes.gd:626), so
#    this branch is the explicit form of the same number; the checks assert the two
#    agree.
#
# 3. `scripts/game.gd spawn_creature` — **applied** (game.gd:813). A pig is spawned
#    as a `RuralAnimal`, because `VillageSurvival.mount` is typed `RuralAnimal`
#    (village_survival.gd:14):
#
#        if kind in ["rabbit","horse","pig"]:
#
#    With the matching guard Main also added at the top of
#    `RuralAnimal._build_model` (rural_animal.gd:10-11), a pig still gets the shared
#    quadruped body instead of being drawn as a horse:
#
#        if kind not in ["rabbit","horse"]:
#            super._build_model(); return
#
# 4. `scripts/village_survival.gd use()` — **applied** (village_survival.gd:76-91),
#    immediately after the horse block. The branch order is the source's own
#    (pig.lua:162-244), and the block sits after `Farming.use` on purpose: the pig's
#    own food branch comes first in the source too (pig.lua:162-170):
#
#        if mob is RuralAnimal and mob.kind == "pig" and PigRiding.mountable(mob):
#            if mob == mount and PigRiding.use_stick(game): return true
#            if held == Nodes.SADDLE and not mob.saddled:
#                PigRiding.equip_saddle(mob); _consume(); return true
#            if held == Nodes.SHEARS and mob.saddled:
#                PigRiding.unsaddle(mob); game.spawn_drop(mob.position,Nodes.SADDLE)
#                if game.gamemode != "creative": game.inventory.damage_tool()
#                return true
#            if mob == mount: mount = null; game.toast("Dismounted."); return true
#            if PigRiding.can_mount(mob,held):
#                if game.boats.ridden(): game.toast("Leave the boat before mounting a pig."); return true
#                mount = mob; game.toast("Mounted. Look where you want to go, Ctrl to dismount."); return true
#
#    Known deviation, and the only one: `Farming.use` returns true for a pig and any
#    of its foods even when it ate nothing (it only toasts, farming.gd:159-161), so a
#    pig cannot be mounted while the player holds a carrot, potato or beetroot. The
#    source falls through to the mount branch there (pig.lua:162-170). Fixing it
#    means `Farming.use` returning false when nothing was consumed — Main's file, not
#    this module's.
#
# 5. `scripts/village_survival.gd ride_step` — **applied** (village_survival.gd:562-572),
#    at the top of the function so the horse code below is untouched:
#
#        if mount.kind == "pig":
#            if Input.is_physical_key_pressed(KEY_CTRL):
#                game.player.position = mount.position+Vector3(1,0.1,0); mount = null; return
#            PigRiding.steer(game,mount,delta,-game.player.camera.global_basis.z)
#            game.player.position = mount.position+Vector3.UP*1.1
#            game.player.velocity = Vector3.ZERO
#            return
#
#    `player.gd:190` already routes a mounted player into `ride_step`, and
#    `RuralAnimal._physics_process` already stands a mounted mob down and animates it
#    (rural_animal.gd:37-38), so the pig is never moved twice in one frame.
#
# 6. `scripts/inventory.gd _init` — **applied** (inventory.gd:154):
#
#        for entry in PigRiding.recipe_entries(): _recipe(entry[0],entry[1],entry[2],entry[3],2)
#
# 7. `scripts/village_item_art.gd draw` — **applied** (village_item_art.gd:6):
#
#        if PigRiding.is_steering_item(id): PigRiding.draw(img,id,base); return
#
# 8. `scripts/village_survival.gd animal_snapshot`/`restore_animals` — **applied**
#    (village_survival.gd:648 and :654) so a saddled pig is saved and comes back.
#    One line of that still belongs to this module and is the only red this suite
#    would show otherwise: `restore_animals` calls the **shared**
#    `RuralAnimal.equip_saddle` (village_survival.gd:658), whose plate is drawn at
#    the horse's own height (rural_animal.gd:45-47). Route a pig through this
#    module instead:
#
#        if entry.get("saddled",false):
#            if animal is RuralAnimal and animal.kind == "pig": PigRiding.equip_saddle(animal)
#            else: animal.equip_saddle()
#
#    `PigRiding.equip_saddle` already tolerates an already-flagged pig (it adds its
#    own plate instead of refusing), so both orders behave; routing it here is what
#    keeps the horse's plate off a pig.
#
# 9. Nothing for updates, metadata or a dispatcher table: the window's clock is
#    advanced by `steer` inside `ride_step` (the source advances it inside `drive`
#    for the same reason), and the sticks carry only `wear`, so `Inventory.clean_slot`
#    needs no new key. `PigRiding.mounted(game)` is there for anything that wants to
#    ask which pig is being ridden.
# ---------------------------------------------------------------------------
