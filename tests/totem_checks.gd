extends RefCounted

# Focused regression for the totem of undying. The reference intercepts lethal
# damage through a damage modifier: the hit is replaced with exactly one health,
# all effects are cleared, and regeneration, fire resistance and absorption are
# applied before the totem is consumed. The void bypasses it entirely.

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	game.gamemode = "survival"
	var player = game.player

	# --- registry ----------------------------------------------------------
	t.check(Totems.is_totem(VillageContent.TOTEM) and not Totems.is_totem(Nodes.IRON),"the totem item is registered")
	t.check(Nodes.title(VillageContent.TOTEM) == "Totem of Undying","the totem is named as the source names it")
	t.check(Nodes.max_stack(VillageContent.TOTEM) == 1,"a totem does not stack, as the source sets stack_max 1")
	t.check(not Nodes.food(VillageContent.TOTEM),"a totem is not food")
	# The source's own effect set and durations.
	t.check(is_equal_approx(Totems.REGEN_DURATION,45.0) and is_equal_approx(Totems.FIRE_DURATION,40.0) and is_equal_approx(Totems.ABSORPTION_DURATION,5.0),"the source's totem effect durations are used")

	# --- bypass rules ------------------------------------------------------
	# Only the void bypasses a totem, which is the source's `out_of_world` reason.
	t.check(Totems.bypasses("out_of_world") and Totems.bypasses("void"),"falling out of the world bypasses a totem")
	for reason in ["mob","arrow","explosion","generic","fall","fire","starve","drowning"]:
		t.check(not Totems.bypasses(reason),"%s does not bypass a totem"%reason)

	# --- interception ------------------------------------------------------
	# Without the totem in hand nothing happens.
	game.inventory.restore([]); game.inventory.add_item(Nodes.IRON,1); game.inventory.selected = 0
	player.health = 2.0; player.damage_cooldown = 0
	player.hurt(10.0,false,Vector3.INF,"mob")
	t.check(player.health <= 0.0,"lethal damage without a totem still kills")
	# With the totem, lethal damage leaves exactly one health.
	game.inventory.restore([]); game.inventory.add_item(VillageContent.TOTEM,1); game.inventory.selected = 0
	player.health = 5.0; player.damage_cooldown = 0
	PotionEffects.clear(player)
	player.hurt(10.0,false,Vector3.INF,"mob")
	t.check(is_equal_approx(player.health,1.0),"a totem leaves the holder at exactly one health")
	t.check(int(game.inventory.held().id) == 0,"the totem is consumed when it saves the holder")
	# The source's three effects are applied.
	t.check(PotionEffects.level(player,"regeneration") > 0,"a totem grants regeneration")
	t.check(PotionEffects.level(player,"fire_resistance") > 0,"a totem grants fire resistance")
	t.check(PotionEffects.level(player,"absorption") > 0,"a totem grants absorption")

	# --- the interception is lethal-only -----------------------------------
	# A non-lethal hit must not consume the totem. The previous interception left
	# absorption active, which would soak this hit, so clear the effects first.
	PotionEffects.clear(player)
	game.inventory.restore([]); game.inventory.add_item(VillageContent.TOTEM,1); game.inventory.selected = 0
	player.health = 20.0; player.damage_cooldown = 0
	player.hurt(2.0,false,Vector3.INF,"mob")
	t.check(player.health < 20.0 and player.health > 1.0,"a non-lethal hit deals its damage normally")
	t.check(int(game.inventory.held().id) == VillageContent.TOTEM,"a non-lethal hit does not consume the totem")

	# --- clearing before applying ------------------------------------------
	# The source clears every effect before applying the totem's, so an old
	# effect must be gone afterwards.
	game.inventory.restore([]); game.inventory.add_item(VillageContent.TOTEM,1); game.inventory.selected = 0
	player.health = 3.0; player.damage_cooldown = 0
	PotionEffects.clear(player)
	PotionEffects.apply(player,"night_vision",600.0,1)
	player.hurt(10.0,false,Vector3.INF,"mob")
	t.check(PotionEffects.level(player,"night_vision") == 0,"a totem clears the holder's other effects first")
	t.check(PotionEffects.level(player,"regeneration") > 0,"the totem's own effects survive the clear")

	# --- the void bypasses it ----------------------------------------------
	game.inventory.restore([]); game.inventory.add_item(VillageContent.TOTEM,1); game.inventory.selected = 0
	player.health = 3.0; player.damage_cooldown = 0
	player.hurt(10.0,false,Vector3.INF,"void")
	t.check(player.health <= 0.0,"the void kills through a totem, as the source's out_of_world reason does")
	t.check(int(game.inventory.held().id) == VillageContent.TOTEM,"a bypassed totem is not consumed")

	# --- breath ------------------------------------------------------------
	# The source tops breath up to ten when it had fallen below eleven, which
	# matters when the lethal hit was drowning.
	game.inventory.restore([]); game.inventory.add_item(VillageContent.TOTEM,1); game.inventory.selected = 0
	player.health = 2.0; player.damage_cooldown = 0; player.breath = 3.0
	player.hurt(10.0,false,Vector3.INF,"drowning")
	t.check(is_equal_approx(player.breath,10.0),"a totem restores breath to the source's ten")
	t.check(is_equal_approx(player.health,1.0),"a drowning kill is still intercepted")

	# --- creative ----------------------------------------------------------
	# The source does not consume the totem in creative.
	game.gamemode = "creative"
	game.inventory.restore([]); game.inventory.add_item(VillageContent.TOTEM,1); game.inventory.selected = 0
	player.health = 2.0; player.damage_cooldown = 0
	player.hurt(10.0,false,Vector3.INF,"mob")
	t.check(is_equal_approx(player.health,1.0),"a totem still saves a creative player")
	t.check(int(game.inventory.held().id) == VillageContent.TOTEM,"a creative totem is not consumed, as the source checks")
	game.gamemode = "survival"
	player.health = 20.0
	PotionEffects.clear(player)

	# --- art ---------------------------------------------------------------
	var art := Image.create(16,16,false,Image.FORMAT_RGBA8)
	Totems.draw(art)
	var painted: int = 0
	for y in 16:
		for x in 16:
			if art.get_pixel(x,y).a > 0.0: painted += 1
	t.check(painted > 0,"the totem draws a non-empty icon")
	t.check(Totems.ID == VillageContent.TOTEM,"the module's totem id matches the registered item")
