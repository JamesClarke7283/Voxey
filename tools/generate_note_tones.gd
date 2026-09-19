extends SceneTree

# Run with Godot --headless --path PROJECT --script res://tools/generate_note_tones.gd.
# This generates original audio only; no Mineclonia sound files are inputs.
func _init() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/audio/noteblocks")
	for instrument in NoteBlockTones.INSTRUMENTS:
		var stream: AudioStreamWAV = NoteBlockTones.synthesize(instrument)
		var error: Error = stream.save_to_wav("res://assets/audio/noteblocks/"+instrument+".wav")
		if error != OK: push_error("Failed to save "+instrument); quit(1); return
		var settings := ConfigFile.new()
		var config_path: String = "res://assets/audio/noteblocks/"+instrument+".wav.import"
		settings.load(config_path); settings.set_value("params","compress/mode",0); settings.save(config_path)
	print("Generated 16 original note-block WAVs.")
	quit()
