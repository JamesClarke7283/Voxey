class_name CharacterSkin
extends RefCounted

const DEFAULT = {"name":"Explorer","skin":"c29470","hair":"4a3026","shirt":"526d58","trousers":"364656","boots":"49362c","hat":false,"slim":false}
const COLORS = ["skin","hair","shirt","trousers","boots"]

static func clean(raw: Dictionary) -> Dictionary:
	var result: Dictionary = DEFAULT.duplicate()
	result.name = str(raw.get("name",DEFAULT.name)).strip_edges().left(24).replace("\n"," ").replace("\r"," ")
	if result.name.is_empty(): result.name = DEFAULT.name
	for key in COLORS:
		var color: String = str(raw.get(key,DEFAULT[key])).trim_prefix("#")
		if color.length() == 6 and color.is_valid_hex_number(): result[key] = color.to_lower()
	result.hat = bool(raw.get("hat",false)); result.slim = bool(raw.get("slim",false))
	return result

static func load_profile(root_path: String) -> Dictionary:
	return clean(WorldStore.read_json(root_path.path_join("appearance.json")))

static func save_profile(root_path: String, profile: Dictionary) -> bool:
	return WorldStore.write_json(root_path.path_join("appearance.json"),clean(profile))

static func model(raw: Dictionary, show_name: bool = true) -> Node3D:
	var profile: Dictionary = clean(raw)
	var root := Node3D.new()
	var skin := Color(profile.skin); var hair := Color(profile.hair)
	var shirt := Color(profile.shirt); var trousers := Color(profile.trousers); var boots := Color(profile.boots)
	var width: float = 0.42 if profile.slim else 0.52
	RedstoneArt.box(root,Vector3(0,1.58,0),Vector3(0.44,0.44,0.44),skin)
	RedstoneArt.box(root,Vector3(0,1.8,0.015),Vector3(0.46,0.10,0.46),hair)
	RedstoneArt.box(root,Vector3(0,1.6,0.215),Vector3(0.46,0.38,0.04),hair)
	RedstoneArt.box(root,Vector3(0,1.07,0),Vector3(width,0.58,0.26),shirt)
	for side in [-1,1]:
		RedstoneArt.box(root,Vector3(side*(width/2+0.1),1.1,0),Vector3(0.18,0.44,0.24),shirt)
		RedstoneArt.box(root,Vector3(side*(width/2+0.1),0.8,0),Vector3(0.17,0.18,0.23),skin)
		RedstoneArt.box(root,Vector3(side*0.135,0.46,0),Vector3(0.22,0.64,0.25),trousers)
		RedstoneArt.box(root,Vector3(side*0.135,0.11,-0.035),Vector3(0.23,0.19,0.32),boots)
		RedstoneArt.box(root,Vector3(side*0.1,1.62,-0.225),Vector3(0.07,0.055,0.02),Color("eeeeee"))
		RedstoneArt.box(root,Vector3(side*0.09,1.62,-0.24),Vector3(0.03,0.04,0.01),Color("26313a"))
	RedstoneArt.box(root,Vector3(0,1.48,-0.225),Vector3(0.10,0.025,0.02),skin.darkened(0.4))
	if profile.hat:
		RedstoneArt.box(root,Vector3(0,1.86,0),Vector3(0.59,0.07,0.59),boots)
		RedstoneArt.box(root,Vector3(0,1.99,0),Vector3(0.42,0.22,0.42),shirt)
	if show_name:
		var label := Label3D.new(); label.text = profile.name
		label.position.y = 2.35; label.font_size = 38; label.pixel_size = 0.007
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED; root.add_child(label)
	return root
