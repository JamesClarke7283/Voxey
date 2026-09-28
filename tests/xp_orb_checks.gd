extends RefCounted

# Focused regression for the experience orb entity and its delivery API
# (Mineclonia `HUD/mcl_experience/orb.lua` + `init.lua`, and the collection step
# of `ENTITIES/mcl_item_entity/init.lua`).
#
# An award is invisible while every caller pays straight into `game.experience`:
# nothing appears on the ground and nothing can be lost. These checks pin the
# split ladder, the size ladder's own (quirky) boundaries, and the whole flight
# from a thrown orb to the player's balance — including the one case the source
# is explicit about, an orb that is nowhere near the player.

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	game.gamemode = "survival"
	var world: VoxelWorld = game.world
	var old_position: Vector3 = game.player.position
	var old_health: float = game.player.health
	var old_state: String = game.state
	var old_experience: float = game.experience
	# An award runs through `game.experience`'s setter, where `Enchantments.mend`
	# repairs Mending gear out of the award. Earlier groups in a full-suite run can
	# leave such gear equipped, so it is parked for the duration; the mending check
	# at the end puts it back deliberately.
	var old_armor: Array = game.player.armor_slots.duplicate(true)
	var old_selected: int = game.inventory.selected
	game.inventory.selected = 0
	var old_held: Dictionary = game.inventory.slots[0].duplicate(true)
	for index in game.player.armor_slots.size(): game.player.armor_slots[index] = {"id":0,"count":0,"wear":0}
	game.inventory.slots[0] = {"id":0,"count":0,"wear":0}

	# --- the split ladder (`init.lua:137-156`) ------------------------------
	# The source draws `min(random(1, min(32767, total - floor(i/2))), total - i)`
	# until the request is covered or after 100 orbs. The two invariants a caller
	# can observe are that the orbs pay the whole request and that there are never
	# more than a hundred of them.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for request in [1,5,100,101,1234,1000000]:
		var amounts: Array = XpOrbs.split(request,rng)
		var total: int = 0
		for value in amounts: total += int(value)
		t.check(total == request,"splitting %d experience pays the whole request"%request)
		t.check(amounts.size() >= 1 and amounts.size() <= 100,"splitting %d experience stays within the source's hundred-orb cap"%request)
		t.check(amounts.all(func(value): return int(value) >= 1 and int(value) <= 32767),"every orb of a %d-experience split carries a source-drawable value"%request)
	# A one-point award is the only request the source cannot split, because the
	# draw's upper bound is the request itself.
	t.check(XpOrbs.split(1,rng).size() == 1 and int(XpOrbs.split(1,rng)[0]) == 1,"a one-point award is a single orb worth one point")
	# The cap really is the source's hundred, not a per-orb size rule: a request
	# larger than 100 x 32767 is truncated exactly as the source truncates it.
	t.check(XpOrbs.split(100*32767+500,rng).size() == 100,"a request beyond the hundred-orb capacity fills exactly a hundred orbs")
	t.check(XpOrbs.split(0,rng).is_empty() and XpOrbs.split(-5,rng).is_empty(),"a non-positive award throws no orbs")

	# --- the size ladder (`orb.lua:18-27`) ----------------------------------
	# `xp_to_size` walks `size_to_xp` while `xp > size_to_xp[i][1]`, comparing the
	# pair's *lower* field, so a row is selected for
	# `(previous lower field, this lower field]`. Every boundary therefore sits on
	# the table's lower value plus one: bucket 0 (the -32768..2 row) is
	# unreachable for any real amount, and the reachable rows are
	# `<=3, 4..7, 8..17, 18..37, 38..73, 74..149, 150..307, 308..617, 618..1237,
	# 1238+` — one row above the table's own bounds.
	t.check(XpOrbs.orb_for(-32768) == 0 and XpOrbs.orb_for(-32769) == 0,"the ladder's lowest row is reachable only from a negative amount, as the source's loop leaves it")
	t.check(XpOrbs.orb_for(1) == 1 and XpOrbs.orb_for(3) == 1 and XpOrbs.orb_for(4) == 2,"the ladder's first reachable row ends at the table's second lower field")
	t.check(XpOrbs.orb_for(7) == 2 and XpOrbs.orb_for(8) == 3 and XpOrbs.orb_for(17) == 3 and XpOrbs.orb_for(18) == 4,"the ladder advances one past each row's lower field")
	t.check(XpOrbs.orb_for(37) == 4 and XpOrbs.orb_for(38) == 5 and XpOrbs.orb_for(73) == 5 and XpOrbs.orb_for(74) == 6 and XpOrbs.orb_for(149) == 6,"the ladder's middle rows follow the same shifted bounds")
	t.check(XpOrbs.orb_for(150) == 7 and XpOrbs.orb_for(307) == 7 and XpOrbs.orb_for(308) == 8 and XpOrbs.orb_for(617) == 8,"the ladder's later rows follow the same shifted bounds")
	t.check(XpOrbs.orb_for(618) == 9 and XpOrbs.orb_for(1237) == 9 and XpOrbs.orb_for(1238) == 10 and XpOrbs.orb_for(2476) == 10,"the ladder's last row starts one past the table's 1237")
	t.check(XpOrbs.orb_for(2477) == 10 and XpOrbs.orb_for(32767) == 10,"the largest source-drawable orb sits in the ladder's top row")
	# Sprite scale is the source's 20..59 percent of a block.
	t.check(is_equal_approx(XpOrbs.size_for(-32768),0.20) and is_equal_approx(XpOrbs.size_for(1238),0.59),"orb size spans the source's twenty to fifty-nine percent of a block")
	t.check(is_equal_approx(XpOrbs.size_for(1),0.239),"an ordinary orb uses the source's own size for its row")

	# --- a clear patch beside the player ------------------------------------
	var base := Vector3i(8,170,8)
	for x in range(4,13):
		for z in range(4,13):
			for y in range(165,172): world.set_node(Vector3i(x,y,z),Nodes.AIR)
	for x in range(4,13):
		for z in range(4,13): world.set_node(Vector3i(x,164,z),Nodes.STONE)
	game.player.position = Vector3(base)+Vector3(0.5,0.5,0.5)
	game.player.health = 20
	game.state = "paused"

	# --- throwing an award the player is standing beside --------------------
	# `throw_xp` spawns into `game.entities`; the orb flies, is magnetised by the
	# nearby player and pays on arrival. The balance rises by exactly the request
	# and every orb node is freed.
	XpOrbs.clear(game)
	var before: int = game.entities.get_child_count()
	var orb_count: int = XpOrbs.orb_count(game)
	XpOrbs.throw_xp(game,game.player.position+Vector3(1.5,0.5,0.0),37)
	t.check(XpOrbs.orb_count(game) > orb_count and game.entities.get_child_count() > before,"throwing experience spawns orb nodes into the entity group")
	var thrown_orb: XpOrbs.Orb = XpOrbs.orbs(game)[0]
	t.check(thrown_orb.get_child_count() == 1 and thrown_orb.get_child(0) is MeshInstance3D,"a thrown orb carries a visible mesh")
	t.check(thrown_orb.velocity.y >= 2.0 and thrown_orb.velocity.y <= 5.0 and Vector2(thrown_orb.velocity.x,thrown_orb.velocity.z).length() <= 2.0,"a thrown orb uses the source's throw velocity bounds")
	t.check(thrown_orb.acceleration.y < 0.0,"a thrown orb starts under the source's downward gravity")
	var experience_before: float = game.experience
	for frame in 600:
		XpOrbs.update(game,1.0/60.0)
		if XpOrbs.orb_count(game) == 0: break
	t.check(is_equal_approx(game.experience-experience_before,37.0),"a magnetised orb pays its own experience to the player")
	t.check(XpOrbs.orb_count(game) == 0,"collected orbs are freed once their experience is paid")
	await t.process_frame
	# The group is shared with every other entity system, so the check is that no
	# *orb* node survives rather than an exact global child count.
	var leftover: int = 0
	for child in game.entities.get_children():
		if child is XpOrbs.Orb: leftover += 1
	t.check(leftover == 0,"collected orbs leave no orb node behind in the entity group")
	t.check(is_instance_valid(game.player) and game.player.health == 20,"collecting experience does not touch the player's health")

	# The same for a larger award, which splits into several orbs: all of them
	# must pay, not just the first.
	experience_before = game.experience
	XpOrbs.throw_xp(game,game.player.position+Vector3(1.5,0.5,0.0),1234)
	var thrown: int = XpOrbs.orb_count(game)
	for frame in 1200:
		XpOrbs.update(game,1.0/60.0)
		if XpOrbs.orb_count(game) == 0: break
	t.check(thrown > 1 and is_equal_approx(game.experience-experience_before,1234.0),"a split award pays every orb it threw")
	t.check(XpOrbs.orb_count(game) == 0,"every orb of a split award is freed")
	XpOrbs.clear(game)

	# --- an orb twenty blocks away ignores the player -----------------------
	# The magnet radius is the source's 7.25 blocks, so a distant orb must be
	# untouched: no experience, and the orb still alive waiting for its owner.
	var far: Vector3 = game.player.position+Vector3(20,2,0)
	t.check(world.loaded_at(far),"the distant-orb check runs in a loaded column")
	var far_orb: XpOrbs.Orb = XpOrbs.spawn(game,far,5)
	experience_before = game.experience
	for frame in 60: XpOrbs.update(game,1.0/60.0)
	t.check(is_equal_approx(game.experience,experience_before),"an orb twenty blocks away pays nothing")
	t.check(is_instance_valid(far_orb) and not far_orb.is_queued_for_deletion() and not far_orb.collected,"an orb twenty blocks away is left alone on the ground")
	XpOrbs.clear(game)

	# --- the three-hundred second age cap (`orb.lua:29,84-87`) --------------
	# An orb nobody collects expires; the source's cap is 300 s of orb age, not
	# of wall clock.
	var aged: XpOrbs.Orb = XpOrbs.spawn(game,far,5)
	for second in 299: XpOrbs.update(game,1.0)
	t.check(is_instance_valid(aged) and not aged.is_queued_for_deletion(),"an orb survives its two hundred and ninety-ninth second")
	XpOrbs.update(game,1.0); XpOrbs.update(game,1.0)
	t.check(aged.is_queued_for_deletion(),"an orb expires past its three-hundred second source age")
	XpOrbs.clear(game)

	# --- the slippery slide (`orb.lua:113`) --------------------------------
	# `slip_factor = 4.0 / (slippery + 4)`, with ice at 3, so a moving orb on ice
	# decelerates with `-velocity * 4/7`. The source rewrites acceleration only
	# when the moving/slippery state changes, so the first frame on ice is spent
	# recording that state (and, restoring gravity, because the move is a state
	# change); the slide itself starts on the frame after. The player stands more
	# than a magnet radius away, so these orbs are never claimed.
	game.player.position = Vector3(base)+Vector3(4.5,0.5,4.5)
	var ice := Vector3i(6,165,6)
	world.set_node(ice,Nodes.ICE)
	var slider: XpOrbs.Orb = XpOrbs.spawn(game,Vector3(ice)+Vector3(0.5,1.2,0.5),3,Vector3(2,0,0))
	XpOrbs.update(game,1.0/60.0)
	XpOrbs.update(game,1.0/60.0)
	t.check(not slider.collected,"a sliding orb beyond the magnet radius is left to slide")
	t.check(is_equal_approx(slider.acceleration.x,-2.0*(4.0/7.0)),"a moving orb on ice decelerates by the source's slip factor")
	t.check(is_equal_approx(slider.acceleration.y,0.0),"a sliding orb takes no vertical acceleration from the slide rule")
	t.check(slider.velocity.x < 2.0,"the slide actually slows the orb down")
	slider.queue_free()
	# An orb that has come to rest parks exactly, as the source stops it.
	world.set_node(ice,Nodes.STONE)
	var resting: XpOrbs.Orb = XpOrbs.spawn(game,Vector3(ice)+Vector3(0.5,1.2,0.5),3,Vector3.ZERO)
	XpOrbs.update(game,1.0/60.0)
	t.check(resting.acceleration == Vector3.ZERO and resting.velocity == Vector3.ZERO,"a resting orb on a solid node stops, as the source parks it")
	t.check(resting.position.is_equal_approx(Vector3(ice)+Vector3(0.5,1.2,0.5)),"a parked orb does not drift")
	XpOrbs.clear(game)
	world.set_node(ice,Nodes.AIR)
	game.player.position = Vector3(base)+Vector3(0.5,0.5,0.5)

	# --- delivery through the experience setter (`init.lua:99-133`) ---------
	# The source routes an award through `register_on_add_xp`, which is where
	# Mending spends part of it. Voxey puts that hook in the setter on
	# `game.experience`, so an orb's award must reach a Mending tool too — that is
	# the reason the module assigns `game.experience` instead of bypassing it. The
	# setter only mends while the game is in one of its live states, so this check
	# plays as a live game.
	var mending: Dictionary = {"id":Nodes.TOOLS+1,"count":1,"wear":10,"data":{"enchantments":{"Mending":1}}}
	game.inventory.slots[0] = mending
	game.state = "playing"
	experience_before = game.experience
	XpOrbs.throw_xp(game,game.player.position+Vector3(1.5,0.5,0.0),10)
	for frame in 600:
		XpOrbs.update(game,1.0/60.0)
		if XpOrbs.orb_count(game) == 0: break
	t.check(game.inventory.held().wear < 10,"an orb's award repairs Mending gear through the experience setter")
	t.check(game.experience >= experience_before and game.experience <= experience_before+10.0,"a mended award spends part of itself on the repair and keeps the rest")
	game.inventory.slots[0] = {"id":0,"count":0,"wear":0}
	XpOrbs.clear(game)

	game.player.position = old_position
	game.player.health = old_health
	game.state = old_state
	game.experience = old_experience
	game.player.armor_slots = old_armor
	game.inventory.slots[0] = old_held
	game.inventory.selected = old_selected
	XpOrbs.clear(game)
