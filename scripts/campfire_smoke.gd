class_name CampfireSmoke
extends Node3D

# Original voxel smoke. Kept separate from refreshed food/light displays so
# smoke can reach its full lifetime, especially above a hay signal fire.
var game: Node3D
var dimension: String = "overworld"
var age: float = 0.0
var max_age: float = 7.25
var velocity := Vector3(randf_range(-0.04,0.04),randf_range(0.7,1.0),randf_range(-0.04,0.04))
var acceleration: float = randf_range(0.2,0.4)
var material: StandardMaterial3D

func _ready() -> void:
	var visual := MeshInstance3D.new()
	var box := BoxMesh.new(); box.size = Vector3.ONE*randf_range(0.28,0.4)
	visual.mesh = box
	material = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.63,0.63,0.63,0.6)
	visual.material_override = material
	add_child(visual)

func _process(delta: float) -> void:
	if game == null or game.dimension != dimension: queue_free(); return
	if not game.playing(): return
	if not game.world.loaded_at(position): queue_free(); return
	age += delta
	if age >= max_age: queue_free(); return
	velocity.y += acceleration*delta
	var next: Vector3 = position+velocity*delta
	if not game.world.intersects(next,0.12,0.24): position = next
	else: velocity = Vector3.ZERO
	scale = Vector3.ONE*(1+age*0.12)
	material.albedo_color.a = 0.6*(1-age/max_age)
