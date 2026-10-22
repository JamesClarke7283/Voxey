extends SceneTree
func _init() -> void:
	var original: Dictionary = CharacterSkin.clean({"name":"Ada","skin":"e6bd8c","hair":"172236","shirt":"22aacc","trousers":"224466","boots":"775522","hat":true,"slim":true})
	assert(original.name == "Ada" and original.skin == "e6bd8c" and original.hat)
	assert(CharacterSkin.clean({"name":"\n","skin":"wrong"}) == CharacterSkin.DEFAULT)
	var path: String = "/tmp/voxey-skin-"+str(OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(path)
	assert(CharacterSkin.save_profile(path,original))
	assert(CharacterSkin.load_profile(path) == original)
	var model: Node3D = CharacterSkin.model(original)
	assert(model.get_child_count() >= 18)
	model.free()
	print("SKIN TESTS: normalization, persistence, and avatar geometry passed")
	quit()
