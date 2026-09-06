extends SceneTree

# Standalone art review: isolated from world saves and simulation.
var scene: Node3D
var mobs: Array = []

func _init() -> void:
	call_deferred("run")

func label_at(parent: Node, text_value: String, pos: Vector2, font_size: int, tint: Color) -> void:
	var label := Label.new()
	label.text = text_value
	label.position = pos
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",tint)
	parent.add_child(label)

func run() -> void:
	root.size = Vector2i(1280,920)
	root.content_scale_size = Vector2i(1280,920)
	scene = Node3D.new(); root.add_child(scene)
	Art.make_atlas()
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("202d29")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("b1c6bd")
	environment.environment.ambient_light_energy = 0.45
	scene.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42,-28,0)
	sun.light_color = Color("fff0cd"); sun.light_energy = 0.85
	sun.shadow_enabled = true
	scene.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20,145,0)
	fill.light_color = Color("9bbdcd"); fill.light_energy = 0.25
	scene.add_child(fill)
	var camera := Camera3D.new(); scene.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 7.2
	camera.position = Vector3(0,3.6,9)
	camera.look_at(Vector3(0,0.8,0))
	camera.current = true
	var kinds: Array = ["zombie","skeleton","spider","creeper"]
	for i in 4:
		var mob := Creature.new()
		mob.kind = kinds[i]; mob.set_physics_process(false)
		mob.position = Vector3(-3.3+i*2.2,0.9,0)
		scene.add_child(mob); mob.set_physics_process(false); mobs.append(mob)
		mob.model.rotation.y = PI+0.23
		var pedestal := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.88; mesh.bottom_radius = 0.88; mesh.height = 0.12; mesh.radial_segments = 8
		pedestal.mesh = mesh
		pedestal.position = mob.position+Vector3(0,-0.08,0)
		var mat := StandardMaterial3D.new(); mat.albedo_color = Color("3a4c42"); mat.roughness = 1
		pedestal.material_override = mat; scene.add_child(pedestal)
	var overlay := CanvasLayer.new(); root.add_child(overlay)
	var ui := Control.new(); overlay.add_child(ui)
	label_at(ui,"VOXEY   /   FIELD NOTES",Vector2(54,30),16,Color("a4bc95"))
	label_at(ui,"A more living block world.",Vector2(54,59),36,Color("f0e8d4"))
	label_at(ui,"Original pixel skins  ·  Articulated enemies  ·  16 new Mineclonia-inspired items",Vector2(55,109),16,Color("a5b3a5"))
	for i in 4:
		label_at(ui,["01  ZOMBIE","02  SKELETON","03  SPIDER","04  CREEPER"][i],Vector2(180+i*280,510),17,Color("dfd7bc"))
	var divider := ColorRect.new(); divider.color = Color("50614c"); divider.position = Vector2(54,556); divider.size = Vector2(1172,1); ui.add_child(divider)
	label_at(ui,"GATHER, CRAFT & BUILD",Vector2(54,579),16,Color("a4bc95"))
	var ids: Array = [Nodes.SUGAR_CANE,Nodes.RED_MUSHROOM,Nodes.BROWN_MUSHROOM,Nodes.VINE,Nodes.BOWL,Nodes.MUSHROOM_STEW,Nodes.EGG,Nodes.CHARCOAL,Nodes.RED_BRICKS,Nodes.HAY_BALE,Nodes.MOSSY_COBBLE,Nodes.MOSSY_BRICKS,Nodes.COAL_BLOCK,Nodes.TERRACOTTA,Nodes.GOLD_NUGGET,Nodes.IRON_NUGGET]
	for i in ids.size():
		var pos := Vector2(54+(i%8)*147,620+(i/8)*119)
		var icon := ItemIcon.new(); icon.item_id = ids[i]; icon.size = Vector2(66,66); icon.position = pos; ui.add_child(icon)
		label_at(ui,Nodes.title(ids[i]),pos+Vector2(0,72),13,Color("dfd7bc"))
	label_at(ui,"VOXEY  /  ASSET STUDY",Vector2(54,873),13,Color("7f9684"))
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("/tmp/voxey-shots")
	root.get_texture().get_image().save_png("/tmp/voxey-shots/08_asset_gallery.png")
	# A second render checks silhouettes with the limbs moved around real joints.
	for mob in mobs:
		mob.direction = Vector3.FORWARD; mob.life = 0.18; mob.animate(0.5)
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/voxey-shots/09_enemy_walk.png")
	print("ASSET GALLERY DONE")
	quit()
