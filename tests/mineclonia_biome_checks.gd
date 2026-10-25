extends SceneTree

const Selector = preload("res://scripts/mineclonia_biome_selector.gd")
const NoiseAPI = preload("res://scripts/mineclonia_noise.gd")
var passed: int = 0
var failed: int = 0

func _init() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		if failed <= 20:
			push_error(message)

func run() -> void:
	var selector: MinecloniaBiomeSelector = Selector.new(0)
	check(Selector.data.leaf_count == 7593, "Source default Overworld R-tree exports all 7593 leaves")
	check(Selector.data.has("root") and Selector.data.root.has("children"), "Runtime LUT contains the packed source tree")
	var source = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/biome_reference.json"))
	check(source is Dictionary and source.has("lut_cases"), "Biome reference contains direct R-tree query cases")
	var cases: Array = source.lut_cases
	check(cases.size() == 7593, "Every exported leaf center has a source query")
	var first: int = int(Selector.data.root.children[0].extents[0])
	var low: int = first >> 16
	var high: int = (first & 0xffff) - 32768
	check(Selector.distance_to_value(first, high) == 0 and Selector.distance_to_value(first, low) == 0, "Packed extent endpoints are inclusive")
	check(Selector.distance_to_value(first, high + 1) == 1 and Selector.distance_to_value(first, low - 1) == 1, "Packed extent distance is one outside each endpoint")
	for row in cases:
		var coords := PackedInt64Array(row.coordinates)
		check(selector.select_coordinates(coords) == str(row.biome), "Forward source R-tree query matches %s at %s" % [row.biome, str(row.coordinates)])
	for i in range(cases.size() - 1, -1, -1):
		var row: Dictionary = cases[i]
		var coords := PackedInt64Array(row.coordinates)
		check(selector.select_coordinates(coords) == str(row.reverse_biome), "Reverse source R-tree query and last-result state match %s at %s" % [row.reverse_biome, str(row.coordinates)])
	var observed: Dictionary = {}
	for row in cases:
		observed[str(row.biome)] = true
		observed[str(row.reverse_biome)] = true
	check(observed.size() == 53, "Fixture covers every Overworld biome leaf value")
	var expected_noise = NoiseAPI.new(0)
	for seed_value in [0, 1, -1, 8675309, -8675309, 4294967297, -4294967297]:
		var noise = NoiseAPI.new(seed_value)
		var local_selector: MinecloniaBiomeSelector = Selector.new(seed_value, noise)
		for row in source.cases:
			if int(row.seed) != seed_value:
				continue
			var p: Array = row.position
			check(local_selector.index_biomes_block(int(p[0]), int(p[1]), int(p[2])) == str(row.biome), "Integrated noise and biome lookup matches source %s at seed %d position %s" % [row.biome, seed_value, str(p)])
	var quart_selector: MinecloniaBiomeSelector = Selector.new(0, expected_noise)
	check(quart_selector.index_biomes(0, 0, 0) == quart_selector.index_biomes_block(0, 0, 0), "Quart API and block API agree at the origin")
	print("MINECLONIA BIOMES: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)
