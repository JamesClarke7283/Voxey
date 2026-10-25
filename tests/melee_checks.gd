extends RefCounted

static func held(game: Node3D, id: int, enchants: Dictionary = {}, wear: int = 0) -> void:
	game.inventory.slots[game.inventory.selected] = {"id":id,"count":1,"wear":0,"data":{"enchantments":enchants.duplicate()}}
	Durability.set_normalized(game.inventory.held(),wear)
	game.player.melee_elapsed = 3; game.player.velocity = Vector3.ZERO; game.player.sprinting = false

static func target(game: Node3D, kind: String = "cow") -> Creature:
	var mob: Creature = game.spawn_creature(kind,game.player.position+Vector3(0,0,2))
	mob.set_physics_process(false); mob.health = 100; mob.grounded = true; mob.velocity = Vector3.ZERO
	return mob

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false)
	var old_inv: Array = game.inventory.slots.duplicate(true); var old_mode: String = game.gamemode
	var old_time: float = game.player.combat_time; var old_stamp: int = game.player.mace_stamp
	game.gamemode = "survival"; PotionEffects.clear(game.player)
	var mob: Creature = target(game)
	held(game,98)
	MeleeCombat.attack(game.player,mob)
	t.check(is_equal_approx(mob.health,93) and Durability.normalized(game.inventory.held()) == 41,"a diamond sword deals its source seven damage and deterministic punch wear")
	t.check(is_equal_approx(mob.knock.z,7.371) and is_equal_approx(mob.velocity.y,6.75),"ordinary melee applies source horizontal and vertical knockback")
	held(game,98,{"Sharpness":5}); mob.health = 100
	MeleeCombat.attack(game.player,mob)
	t.check(is_equal_approx(mob.health,91),"Sharpness follows the source capability's integer damage-group conversion")
	held(game,98,{"Sharpness":5}); mob.health = 100; game.player.melee_elapsed = 0.3125
	MeleeCombat.attack(game.player,mob)
	t.check(is_equal_approx(mob.health,95.5),"an early punch deals the source's linear fraction of the weapon's damage")
	held(game,98,{"Unbreaking":3}); mob.health = 100
	MeleeCombat.attack(game.player,mob)
	t.check(Durability.normalized(game.inventory.held()) == 10,"Unbreaking III divides sword punch wear without a chance roll")
	held(game,98,{"Smite":5}); mob.health = 100
	MeleeCombat.attack(game.player,mob)
	t.check(is_equal_approx(mob.health,93) and mob.bonuses.is_empty(),"Smite adds no damage to a target without the undead group and queues no second bonus")
	mob.free(); mob = target(game,"zombie")
	held(game,98,{"Smite":5}); MeleeCombat.attack(game.player,mob)
	t.check(is_equal_approx(mob.health,82.9),"both sword and Smite damage pass through the zombie's group armor exactly once")
	mob.free(); mob = target(game,"spider")
	held(game,98,{"Bane of Arthropods":3}); MeleeCombat.attack(game.player,mob,EnchantRolls.new(1))
	t.check(PotionEffects.level(mob,"slowness") == 4 and float(mob.get_meta("effect_slowness",0)) >= 1 and float(mob.get_meta("effect_slowness",0)) <= 2.5,"Bane applies its source Slowness IV duration through the live attack path")
	mob.free(); mob = target(game)
	held(game,98,{"Fire Aspect":2}); MeleeCombat.attack(game.player,mob)
	t.check(float(mob.get_meta("effect_burning",0)) == 8,"Fire Aspect II ignites a surviving target for eight seconds")
	held(game,98,{"Knockback":2,"Looting":3},65535); mob.health = 100; mob.velocity = Vector3.ZERO
	MeleeCombat.attack(game.player,mob)
	t.check(game.inventory.held().id == 0 and is_equal_approx(mob.knock.z,7.371),"a broken sword is removed before the source reads its Knockback enchantment")
	t.check(int(mob.get_meta("looting",-1)) == 0,"a broken normal weapon also loses its Looting bonus before damage is delivered")
	held(game,138,{},12000); MeleeCombat.attack(game.player,mob)
	t.check(Durability.normalized(game.inventory.held()) == 12000,"an item without punch uses does not spend durability merely for hitting")
	held(game,98); game.player.sprinting = true; game.player.velocity = Vector3(2,-3,0)
	var critical: Dictionary = MeleeCombat.attack(game.player,mob,EnchantRolls.new(1))
	t.check(critical.critical,"a falling sprint still produces the source critical rather than a grounded sprint shove")
	held(game,98); game.gamemode = "creative"; MeleeCombat.attack(game.player,mob)
	t.check(Durability.normalized(game.inventory.held()) == 0,"creative melee preserves weapon durability")
	game.gamemode = "survival"
	held(game,VillageContent.MACE); game.player.combat_time = 1; game.player.mace_stamp = -1; mob.health = 100
	var denied: Dictionary = MeleeCombat.attack(game.player,mob)
	t.check(not denied.accepted and mob.health == 100 and game.player.mace_stamp == 0,"the mace uses the source's integer-time initial cooldown without spending an attack")
	game.player.combat_time = 2
	MeleeCombat.attack(game.player,mob)
	t.check(mob.health == 94 and Durability.normalized(game.inventory.held()) == 131,"a stationary mace deals six and spends its fixed source wear")
	game.player.combat_time = 3.99
	t.check(not MeleeCombat.attack(game.player,mob).accepted,"the mace cannot attack again before two integer game seconds have elapsed")
	game.player.health = 20; game.player.damage_cooldown = 0
	game.player.hurt(2,true,Vector3.INF,"fall")
	t.check(game.player.health == 20,"a recent mace attack suppresses fall damage inside the source window")
	game.player.combat_time = 4; game.player.damage_cooldown = 0
	game.player.hurt(2,true,Vector3.INF,"fall")
	t.check(game.player.health == 18,"fall damage resumes at the end of the mace's two-second window")
	held(game,VillageContent.MACE,{"Density":5,"Wind Burst":3,"Unbreaking":3}); mob.health = 100
	game.player.combat_time = 10; game.player.velocity.y = -20
	var smash: Dictionary = MeleeCombat.attack(game.player,mob)
	t.check(mob.health == 42 and game.player.velocity.y == 24 and not smash.critical,"a ten-block Density smash deals 58 and Wind Burst III adds the source upward velocity")
	t.check(Durability.normalized(game.inventory.held()) == 131,"mace smash wear retains the source's fixed increment even with Unbreaking")
	held(game,VillageContent.MACE,{"Breach":4}); mob.health = 100; game.player.combat_time = 20
	MeleeCombat.attack(game.player,mob)
	t.check(is_equal_approx(mob.health,90.4),"Breach IV applies the source's final sixty-percent damage increase")
	mob.free()
	mob = target(game,"shulker"); held(game,98)
	MeleeCombat.attack(game.player,mob)
	t.check(mob.knock.is_zero_approx(),"a shulker retains the source's complete resistance to melee knockback")
	mob.free()
	game.inventory.slots = old_inv; game.gamemode = old_mode
	game.player.combat_time = old_time; game.player.mace_stamp = old_stamp
	game.player.health = 20; game.player.velocity = Vector3.ZERO; game.player.sprinting = false
	game.player.melee_elapsed = 100; game.player.damage_cooldown = 0; PotionEffects.clear(game.player)
