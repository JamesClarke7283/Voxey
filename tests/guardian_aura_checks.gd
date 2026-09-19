extends RefCounted

# Focused regression for the two guardian behaviours that were missing from the
# ocean monument: the **elder's mining fatigue** and the **guardian's thorns**.
#
# Neither is part of the laser attack Voxey already had. They are separate rules
# the source attaches to the creatures, and the fatigue aura is what makes mining
# through a monument slow — the monument's real obstacle.

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	game.gamemode = "survival"

	# --- the source's constants --------------------------------------------
	t.check(is_equal_approx(GuardianAuras.FATIGUE_RADIUS,50.0),"the source's fifty-block radius is used")
	t.check(is_equal_approx(GuardianAuras.FATIGUE_INTERVAL,60.0),"the aura fires on the source's sixty-second cycle")
	t.check(GuardianAuras.FATIGUE_LEVEL == 3,"the source's mining fatigue level three is used")
	t.check(is_equal_approx(GuardianAuras.FATIGUE_DURATION,300.0),"the source's five-minute duration is used")
	t.check(is_equal_approx(GuardianAuras.THORNS_DAMAGE,2.0),"the source's two thorns damage is used")
	# The effect the aura applies must be a real one, or it would be a no-op.
	t.check(PotionEffects.NAMES.has(GuardianAuras.FATIGUE_EFFECT),"the fatigue effect exists, which the aura applies")

	# --- the elder's aura ---------------------------------------------------
	var elder: Creature = game.spawn_creature("guardian_elder",game.player.position+Vector3(0,2,0))
	t.check(elder != null,"an elder guardian can be spawned")
	if elder == null: return
	PotionEffects.clear(game.player)
	t.check(PotionEffects.level(game.player,GuardianAuras.FATIGUE_EFFECT) == 0,"a fresh player has no fatigue")
	# The aura fires on the elder's own cycle, so it is driven past sixty seconds.
	var fired: bool = false
	for i in 700:
		if not GuardianAuras.aura_step(game,elder,0.1).is_empty(): fired = true
	t.check(fired,"the elder's aura fires on its cycle")
	t.check(PotionEffects.level(game.player,GuardianAuras.FATIGUE_EFFECT) == GuardianAuras.FATIGUE_LEVEL,"a nearby player gets the source's level-three fatigue")
	# The fatigue really slows mining, which is the whole point of it.
	t.check(PotionEffects.mining_speed(game.player) > 1.0,"fatigue slows block breaking")
	PotionEffects.clear(game.player)
	t.check(is_equal_approx(PotionEffects.mining_speed(game.player),1.0),"an unfatigued player mines at normal speed")

	# --- the aura is range-gated --------------------------------------------
	# Fifty blocks is the source's own range, so a player further away is spared.
	elder.position = game.player.position+Vector3(0,0,80)
	elder.set_meta("fatigue_counter",GuardianAuras.FATIGUE_INTERVAL)
	t.check(GuardianAuras.aura_step(game,elder,0.5).is_empty(),"a player beyond fifty blocks is not fatigued")
	t.check(PotionEffects.level(game.player,GuardianAuras.FATIGUE_EFFECT) == 0,"and they stay unfatigued")
	# A plain guardian has no aura at all.
	var plain: Creature = game.spawn_creature("guardian",game.player.position+Vector3(0,2,2))
	t.check(GuardianAuras.aura_step(game,plain,999.0).is_empty(),"an ordinary guardian has no aura")

	# --- the guardian's thorns ----------------------------------------------
	# The source gates the retaliation on the guardian's own movement goal.
	t.check(GuardianAuras.retaliates(plain,false,false),"a hunting guardian retaliates")
	t.check(not GuardianAuras.retaliates(plain,true,false),"a pacing guardian does not retaliate")
	t.check(not GuardianAuras.retaliates(plain,false,true),"a bypassing hit is not retaliated against")
	t.check(GuardianAuras.retaliates(elder,false,false),"the elder is a guardian too, so it retaliates")
	# And the retaliation really deals damage.
	game.player.health = 20.0
	game.player.damage_cooldown = 0
	GuardianAuras.thorns(plain,game.player)
	t.check(game.player.health == 20.0-GuardianAuras.THORNS_DAMAGE,"thorns deals the source's two damage to the attacker")
	# A guardian does not retaliate against itself.
	var before: float = game.player.health
	t.check(not GuardianAuras.thorns(plain,null),"thorns with no attacker does nothing")
	t.check(game.player.health == before,"and it changes nothing")
	PotionEffects.clear(game.player)
