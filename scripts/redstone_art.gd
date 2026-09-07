class_name RedstoneArt
extends RefCounted

static func box(root: Node3D, at: Vector3, size: Vector3, color: Color, glow: float = 0.0) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var mesh := BoxMesh.new(); mesh.size = size
	part.mesh = mesh; part.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	mat.metallic_specular = 0.0
	if glow > 0: mat.emission_enabled = true; mat.emission = color; mat.emission_energy_multiplier = glow
	part.material_override = mat
	root.add_child(part)
	return part

static func build(id: int, state: Dictionary = {}, level: int = 0) -> Node3D:
	var root := Node3D.new()
	var on: bool = state.get("out",0) > 0 or state.get("powered",false)
	var red := Color("ff442d") if on or level > 0 else Color("6c1524")
	var stone := Color("8b9094")
	var glow: float = 0.35 if on or level > 0 else 0.0
	match id:
		Nodes.REDSTONE_WIRE:
			box(root,Vector3(0,0.018,0),Vector3(1,0.035,0.11),red,glow)
			box(root,Vector3(0,0.019,0),Vector3(0.11,0.038,1),red,glow)
			box(root,Vector3(0,0.02,0),Vector3(0.25,0.04,0.25),red,glow)
		Nodes.REDSTONE_TORCH:
			box(root,Vector3(0,0.25,0),Vector3(0.12,0.5,0.12),Color("856340"))
			box(root,Vector3(0,0.55,0),Vector3(0.2,0.18,0.2),red,glow)
		Nodes.LEVER,Nodes.BUTTON,Nodes.PRESSURE_PLATE:
			box(root,Vector3(0,0.06,0),Vector3(0.8 if id == Nodes.PRESSURE_PLATE else 0.4,0.12,0.8 if id == Nodes.PRESSURE_PLATE else 0.35),stone)
			if id == Nodes.LEVER:
				var stick := box(root,Vector3(0,0.3,-0.1 if on else 0.1),Vector3(0.08,0.48,0.08),Color("ad8753"))
				stick.rotation.x = -0.6 if on else 0.6
			else: box(root,Vector3(0,0.13,0),Vector3(0.3,0.05,0.24),red,glow*0.3)
		Nodes.REPEATER,Nodes.COMPARATOR:
			box(root,Vector3(0,0.06,0),Vector3(0.95,0.12,0.95),Color("cdc8bc"))
			box(root,Vector3(0,0.13,0),Vector3(0.055,0.025,0.8),red,glow)
			# Arrow on the plate marks the output direction (-Z).
			for side in [-1,1]:
				var marker := box(root,Vector3(side*0.065,0.135,-0.3),Vector3(0.04,0.02,0.2),red,glow)
				marker.rotation.y = side*0.7
			var pins: Array = [Vector3(0,0.25,-0.21),Vector3(0,0.25,0.0+float(state.get("delay",1))*0.09)] if id == Nodes.REPEATER else [Vector3(-0.23,0.25,0.25),Vector3(0.23,0.25,0.25),Vector3(0,0.25,-0.2)]
			for p in pins:
				box(root,p,Vector3(0.09,0.22,0.09),Color("956743"))
				box(root,p+Vector3.UP*0.1,Vector3(0.14,0.09,0.14),red,glow)
			if state.get("subtract",false): box(root,Vector3(0.28,0.16,-0.25),Vector3(0.17,0.03,0.045),Color("df724b"),1)
			if state.get("locked",false): box(root,Vector3(0,0.24,0),Vector3(0.6,0.12,0.12),Color("33323a"))
		Nodes.PISTON,Nodes.STICKY_PISTON:
			box(root,Vector3(0,0.5,0.09),Vector3(1,1,0.82),stone.darkened(0.12))
			for x in [-0.46,0.46]: box(root,Vector3(x,0.5,0),Vector3(0.08,0.86,0.88),Color("b5ad91"))
			box(root,Vector3(0,0.5,-0.35),Vector3(0.95,0.94,0.22),Color("777268") if state.get("extended",false) else (Color("8bb65e") if id == Nodes.STICKY_PISTON else Color("b99c69")))
			for y in [0.18,0.5,0.82]: box(root,Vector3(0,y,-0.467),Vector3(0.85,0.025,0.012),Color("6e603f"))
		Nodes.PISTON_HEAD:
			box(root,Vector3(0,0.5,0.1),Vector3(0.22,0.22,0.8),Color("b1a184"))
			box(root,Vector3(0,0.5,-0.37),Vector3(1,1,0.25),Color("b99c69"))
		Nodes.REDSTONE_LAMP:
			box(root,Vector3(0,0.5,0),Vector3.ONE*0.99,Color("ffc772") if on else Color("674731"),1.2 if on else 0)
			for axis in 3:
				for a in [-0.49,0.49]:
					for b in [-0.49,0.49]:
						var size := Vector3.ONE*0.07; size[axis] = 1
						var pos := Vector3.ZERO; pos[(axis+1)%3] = a; pos[(axis+2)%3] = b; pos.y += 0.5
						box(root,pos,size,Color("473930"))
			if on:
				var light := OmniLight3D.new(); light.position.y = 0.6; light.omni_range = 7; light.light_energy = 1.2; light.light_color = Color("ffcf88"); root.add_child(light)
		Nodes.REDSTONE_BLOCK:
			box(root,Vector3(0,0.5,0),Vector3.ONE,Color("b92b37"))
			box(root,Vector3(0,1.005,0),Vector3(0.7,0.015,0.7),Color("df4b44"),0.2)
		Nodes.OBSERVER,Nodes.DISPENSER,Nodes.DROPPER:
			box(root,Vector3(0,0.5,0),Vector3.ONE,stone.darkened(0.18))
			box(root,Vector3(0,0.5,-0.508),Vector3(0.75,0.75,0.02),stone)
			if id == Nodes.OBSERVER:
				box(root,Vector3(0,0.5,-0.52),Vector3(0.16,0.16,0.02),red,glow)
				for x in [-0.2,0.2]: box(root,Vector3(x,0.65,0.51),Vector3(0.13,0.15,0.02),Color("242633"))
				box(root,Vector3(0,0.34,0.51),Vector3(0.42,0.055,0.02),Color("242633"))
			else:
				box(root,Vector3(0,0.42,-0.525),Vector3(0.34,0.28 if id == Nodes.DISPENSER else 0.14,0.02),Color("262934"))
				for x in [-0.2,0.2]: box(root,Vector3(x,0.7,-0.525),Vector3(0.14,0.08,0.02),Color("262934"))
		Nodes.HOPPER:
			for x in [-0.43,0.43]: box(root,Vector3(x,0.82,0),Vector3(0.14,0.35,1),Color("515965"))
			for z in [-0.43,0.43]: box(root,Vector3(0,0.82,z),Vector3(0.8,0.35,0.14),Color("515965"))
			box(root,Vector3(0,0.5,0),Vector3(0.66,0.38,0.66),Color("434a54"))
			box(root,Vector3(0,0.21,-0.18),Vector3(0.27,0.42,0.62),Color("343c44"))
		Nodes.IRON_DOOR,Nodes.IRON_DOOR_OPEN:
			var door := Node3D.new(); root.add_child(door)
			if id == Nodes.IRON_DOOR_OPEN: door.rotation.y = PI/2
			box(door,Vector3(0,0.5,0),Vector3(1,1,0.13),Color("afbabd"))
			for x in [-0.25,0.25]: box(door,Vector3(x,0.7,-0.075),Vector3(0.26,0.28,0.015),Color("384953"))
			box(door,Vector3(0.35,0.3,-0.09),Vector3(0.065,0.18,0.04),Color("555d63"))
	return root
