class_name RailsArt
extends RefCounted

# Original procedural art for rails and minecarts. Source textures are not used.

static func build(entity: Node3D, kind: int) -> Node3D:
	var root := Node3D.new()
	# A cart body: a tapered metal tub on four small wheels.
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Nodes.color(kind)
	var body := MeshInstance3D.new()
	var box := BoxMesh.new(); box.size = Vector3(1.0,0.55,1.2)
	body.mesh = box; body.position = Vector3(0,0.32,0); body.material_override = mat
	root.add_child(body)
	var inner := MeshInstance3D.new()
	var inner_box := BoxMesh.new(); inner_box.size = Vector3(0.8,0.3,1.0)
	inner.mesh = inner_box; inner.position = Vector3(0,0.5,0)
	var inner_mat := StandardMaterial3D.new()
	inner_mat.albedo_color = _cargo_colour(kind)
	inner.material_override = inner_mat
	root.add_child(inner)
	var wheel_mat := StandardMaterial3D.new(); wheel_mat.albedo_color = Color("4a4e52")
	for side in [-1,1]:
		for end in [-1,1]:
			var wheel := MeshInstance3D.new()
			var disc := CylinderMesh.new(); disc.top_radius = 0.14; disc.bottom_radius = 0.14; disc.height = 0.08
			wheel.mesh = disc; wheel.rotation.z = PI/2.0
			wheel.position = Vector3(0.42*side,0.14,0.42*end)
			wheel.material_override = wheel_mat
			root.add_child(wheel)
	entity.add_child(root)
	return root

static func _cargo_colour(kind: int) -> Color:
	match kind:
		Rails.CHEST_CART: return Color("a47d43")
		Rails.FURNACE_CART: return Color("3a3e42")
		Rails.HOPPER_CART: return Color("2f3438")
		Rails.TNT_CART: return Color("c8402f")
	return Color("6d7378")
