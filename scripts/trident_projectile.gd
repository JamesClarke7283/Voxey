class_name TridentProjectile
extends Node3D

var game: Node3D
var stack: Dictionary = {}
var velocity := Vector3.ZERO
var age: float = 0.0
var returning: bool = false
var consumed: bool = true

func _ready() -> void:
	var color := Color("79c0ba")
	RedstoneArt.box(self,Vector3.ZERO,Vector3(0.04,0.04,1.1),Color("7c9590"))
	for x in [-0.14,0,0.14]: RedstoneArt.box(self,Vector3(x,0,-0.7),Vector3(0.04,0.05,0.36),color)
	RedstoneArt.box(self,Vector3(0,0,-0.55),Vector3(0.3,0.05,0.05),color)

func _physics_process(delta: float) -> void:
	if not game.playing(): return
	age += delta
	if returning:
		var destination: Vector3 = game.player.position+Vector3.UP
		position = position.move_toward(destination,delta*(8+Inventory.enchantment(stack,"Loyalty")*5))
		if position.distance_to(destination) < 0.8:
			if consumed:
				if game.inventory.capacity(stack.id,stack.wear,stack.get("data",{})) < 1: drop(); return
				game.inventory.add_item(stack.id,1,stack.wear,stack.get("data",{}))
			queue_free()
		return
	if age > 15:
		if Inventory.enchantment(stack,"Loyalty"): returning = true
		else: drop()
		return
	velocity.y -= 12*delta
	var motion: Vector3 = velocity*delta; var steps: int = maxi(1,ceili(motion.length()/0.08))
	for i in steps:
		var next: Vector3 = position+motion/steps
		if game.world.intersects(next,0.04,0.08):
			RedstoneSensors.projectile_hit(game.world,position,motion,true,game.player)
			RedstoneInputs.projectile_hit(game.world,position,motion)
			impact(); return
		position = next
		for mob in game.creatures.get_children():
			if not mob.is_queued_for_deletion() and position.distance_to(mob.center()) < mob.width+0.25:
				var damage: float = 8
				if Fluids.water(game.world.node_at(Vector3i(mob.position.floor()))) or mob.kind == "turtle": damage += Inventory.enchantment(stack,"Impaling")*2.5
				mob.hit(damage,position-velocity)
				# `a_throwaway_joke`: hit a creature with a thrown trident.
				game.achievements.award("a_throwaway_joke")
				if Inventory.enchantment(stack,"Channeling") and game.survival.weather() == "thunder" and game.world.open_sky(Vector3i(mob.position.floor())):
					PotionEffects.apply(mob,"burning",8); mob.hit(5)
					for y in 18: game.puff(mob.position+Vector3.UP*(y+1),Color("e4efff"),1,0.05)
				impact(); return
	if velocity.length() > 0.01: look_at(position+velocity,Vector3.RIGHT if absf(velocity.normalized().y) > 0.99 else Vector3.UP)

func impact() -> void:
	if Inventory.enchantment(stack,"Loyalty") > 0: returning = true
	else: drop()

func drop() -> void:
	if consumed: game.spawn_drop(position,stack.id,1,stack.wear,stack.get("data",{}))
	queue_free()
