class_name WitherSkull
extends Node3D

# The wither's skull projectile, Mineclonia `mobs_mc:wither_skull` and
# `mobs_mc:wither_skull_strong` (`ENTITIES/mobs_mc/wither.lua`:829-930). Original
# GDScript using the source as a behaviour reference.
#
# A plain cube that flies without gravity, turns as it goes, and on impact deals its
# damage *and* explodes. The boss fires one every attack, and every fourth is the
# slower strong variant. `WitherSkulls` owns the numbers and the impact rules; this
# node owns the flight.
#
# A skull aimed by the player exists only for the strong variant, which the source
# marks `redirectable` — that is what the player's own reflected skull is, so the
# node carries a `from_player` flag and treats the player as its target then.

var game: Node3D
var velocity := Vector3.ZERO
var strong: bool = false
var from_player: bool = false
var shooter: Node3D
var life: float = 0.0
var impacted: bool = false
var heading := Vector3.ZERO

func _ready() -> void:
	var core := RedstoneArt.box(self,Vector3.ZERO,Vector3.ONE*0.35,Color("3a3a44") if not strong else Color("6f8fd0"),1.2 if not strong else 1.9)
	core.rotation = Vector3(0.4,0.4,0.2)
	# The source's `rotate = 90` spins the cube in flight.
	heading = velocity.normalized()

func _physics_process(delta: float) -> void:
	if not game.playing() or impacted: return
	life += delta
	if life > WitherSkulls.SKULL_LIFETIME: queue_free(); return
	rotation.x += delta*3.0
	rotation.y += delta*5.0
	rotation.z += delta*2.0
	var motion: Vector3 = velocity*delta
	var steps: int = maxi(1,ceili(motion.length()/0.08))
	for i in steps:
		var next: Vector3 = position+motion/steps
		if not game.world.loaded_at(next): return # Pause at streaming boundaries.
		if game.world.intersects(next,0.2,0.2):
			strike(null,next); return
		# A skull aimed by the boss hits the player; a redirected one hits mobs.
		if from_player:
			for mob in game.creatures.get_children():
				if mob.is_queued_for_deletion() or mob == shooter: continue
				if next.distance_to(mob.center()) < maxf(0.8,mob.width+0.4):
					strike(mob,next); return
		elif game.player.health > 0 and next.distance_to(game.player.position+Vector3.UP*0.9) < 0.9:
			strike(game.player,next); return
		position = next

# The impact itself. `WitherSkulls.impact` performs the damage, the withering, the
# blast, the knockback, the heal and the rose; this reports the outcome and frees
# the node.
func strike(victim: Node3D, at: Vector3) -> void:
	if impacted: return
	impacted = true
	var lethal: bool = WitherSkulls.impact(game,victim,at,heading,game.difficulty)
	# `shooter:heal_mob(5)` on a kill. The shooter may already be gone.
	if lethal and shooter != null and is_instance_valid(shooter) and shooter is Creature:
		shooter.health = minf(shooter.info().health,shooter.health+WitherSkulls.KILL_HEAL)
	game.puff(at,Color("9a9ab0") if not strong else Color("a8c0f0"),14,1.4)
	queue_free()
