extends SceneTree

const NoiseAPI = preload("res://scripts/mineclonia_noise.gd")
const TARGETS: Array[String] = ["Taiga", "OldGrowthSpruceTaiga", "OldGrowthPineTaiga", "BambooJungle", "MushroomIslands", "LushCaves"]
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

func close(actual: float, expected: float) -> bool:
	return absf(actual - expected) <= 0.000000000001

func same_coordinates(actual: PackedInt64Array, expected: Variant) -> bool:
	if not expected is Array or actual.size() != expected.size():
		return false
	for i in actual.size():
		if actual[i] != int(expected[i]):
			return false
	return true

func synthetic_checks() -> void:
	check(NoiseAPI.mix64(0) == 0 and NoiseAPI.mix64(1) == 6238072747940578789, "Independent Stafford mix64 values")
	var rng = NoiseAPI.Xoroshiro.from_world_seed(0)
	var expected: Array[int] = [3038984756725240190, -3694039286755638414, 4633751808701151732, 2160572957309072155]
	for value in expected:
		check(rng.next_u64() == value, "Actual Luanti Xoroshiro128++ world-seed sequence")
	var hash: Array[int] = NoiseAPI.keyword_hash("abc")
	check(hash == [-8070080442485551184, -2984127896297046158], "MD5 keyword hash uses source big-endian 32-bit words")
	check(NoiseAPI.seed_words(0) == [3847398142028685078, 7192185014346937746], "World seed derivation mixes LO_XOREND/golden-gamma words like the source")
	check(NoiseAPI.seed_words(-1) == [-6556804219199978326, 1893976515633984465], "Negative world seeds reproduce LuaJIT high-word conversion")
	check(NoiseAPI.seed_words(-1) == NoiseAPI.seed_words(-4294967297), "Negative high-word conversion preserves the source's 32-bit collision")
	for bound in [1, 2, 3, 17, 256]:
		var a = NoiseAPI.Xoroshiro.from_world_seed(8675309)
		var b = NoiseAPI.Xoroshiro.from_world_seed(8675309)
		var in_range: bool = true
		for i in 100:
			var value: int = a.next_within(bound)
			in_range = in_range and value >= 0 and value < bound and value == b.next_within(bound)
		check(in_range, "Unsigned next_within rejection and repeatability for bound " + str(bound))

	check(NoiseAPI.wrap_world_border(0.0) == 0.0 and NoiseAPI.wrap_world_border(NoiseAPI.WORLD_BORDER) == 0.0, "World-border wrapping at a full period")
	check(NoiseAPI.wrap_world_border(NoiseAPI.WORLD_BORDER * 0.5) == -NoiseAPI.WORLD_BORDER * 0.5, "World-border positive half-period rounds negative")
	check(NoiseAPI.wrap_world_border(-NoiseAPI.WORLD_BORDER * 0.5) == -NoiseAPI.WORLD_BORDER * 0.5, "World-border negative half-period is retained")
	check(close(NoiseAPI.PerlinNoise.initial_amplitude(4), 8.0 / 15.0), "Octave amplitude normalization uses the full template length")
	check(close(NoiseAPI.NormalNoise.normalization(0, 2), 1.25), "NormalNoise active-octave deviation normalization")
	check(NoiseAPI.RIGHT_NOISE_SCALE == 337.0 / 331.0, "Two-sided NormalNoise right coordinate scale")

	check(NoiseAPI.peaks_valleys(0.0) == -1.0, "Raw ridge to PV at zero")
	check(close(NoiseAPI.peaks_valleys(2.0 / 3.0), 1.0) and close(NoiseAPI.peaks_valleys(-2.0 / 3.0), 1.0), "Raw ridge to PV is two-sided")
	check(close(NoiseAPI.peaks_valleys(1.0), 0.0) and close(NoiseAPI.peaks_valleys(-1.0), 0.0), "Raw ridge to PV at unit magnitude")
	check(NoiseAPI.clamped_gradient(-100.0) == 1.5 and NoiseAPI.clamped_gradient(-64.0) == 1.5, "Depth gradient clamps below Y=-64")
	check(NoiseAPI.clamped_gradient(320.0) == -1.5 and NoiseAPI.clamped_gradient(400.0) == -1.5, "Depth gradient clamps above Y=320")
	check(NoiseAPI.clamped_gradient(128.0) == 0.0, "Depth gradient crosses zero at Y=128")
	var depth_noise = NoiseAPI.new(12345)
	check(close(depth_noise.depth_offset(-1.1, 0.37, -0.42), -0.50375 + 0.044), "Mushroom-continentalness source spline knot")
	check(close(depth_noise.depth_offset(-1.02, 0.37, -0.42), -0.50375 - 0.2222), "Deep-ocean source spline knot")
	check(close(depth_noise.depth_offset(-0.44, 0.37, -0.42), -0.50375 - 0.12), "Ocean source spline knot")
	check(close(depth_noise.depth_from_climate(0.2, 0.1, 0.3, 128.0), depth_noise.depth_offset(0.2, 0.1, 0.3)), "Depth at Y=128 is exactly the offset spline")
	check(NoiseAPI.quantize(-0.00019999) == -1 and NoiseAPI.quantize(0.00019999) == 1, "Climate quantization truncates scaled values toward zero")
	check(NoiseAPI.to_quart(-1) == -1 and NoiseAPI.to_quart(-4) == -1 and NoiseAPI.to_quart(-5) == -2, "Negative block-to-quart conversion uses arithmetic shift")

	var first = NoiseAPI.new(8675309)
	var second = NoiseAPI.new(8675309)
	var different = NoiseAPI.new(8675310)
	var horizontal: Dictionary = first.sample_horizontal(-1237.0, 918.0)
	check(horizontal == second.sample_horizontal(-1237.0, 918.0), "Independent instances reproduce every horizontal channel and shared shift")
	check(horizontal != different.sample_horizontal(-1237.0, 918.0), "A different world seed changes the sampled climate")
	check(first.sample_horizontal(-1237.0, 918.0) == horizontal, "Sampling is repeatable and does not mutate RNG state")
	var quart: PackedInt64Array = first.sample_quart(-2, 17, 3)
	check(quart == first.biome_coordinates(-8, 68, 12), "Quart API samples the exact quart origin")
	for x in range(-8, -4):
		for y in range(68, 72):
			for z in range(12, 16):
				if first.biome_coordinates(x, y, z) != quart:
					check(false, "All blocks in a negative-X quart share coordinates")
					return
	check(true, "All 64 blocks in one quart share climate coordinates")

func source_checks() -> void:
	const PATH: String = "res://assets/data/biome_reference.json"
	if not FileAccess.file_exists(PATH):
		check(false, "Run tools/export_biome_reference.py before source comparison; biome_reference.json is absent")
		return
	var reference: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not reference is Dictionary or not reference.has("cases"):
		check(false, "Biome reference is not valid oracle JSON")
		return
	check(reference.get("coordinate_order", []) == ["temperature", "humidity", "continentalness", "erosion", "depth", "weirdness", "offset"], "Fixture declares the seven source coordinate fields")
	check(reference.get("source_hashes", {}).size() == 6, "Fixture records all six numerical/query source hashes")
	var instances: Dictionary = {}
	var observed_targets: Dictionary = {}
	for row in reference.cases:
		var seed: int = int(row.seed)
		var key: String = str(seed)
		if not instances.has(key):
			instances[key] = NoiseAPI.new(seed)
		var p: Array = row.position
		var actual: PackedInt64Array = instances[key].biome_coordinates(int(p[0]), int(p[1]), int(p[2]))
		check(same_coordinates(actual, row.coordinates), "Actual Luanti climate coordinates seed=%d position=%s biome=%s actual=%s expected=%s" % [seed, str(p), str(row.biome), str(actual), str(row.coordinates)])
		if row.has("target"):
			check(row.target == row.biome and TARGETS.has(row.target), "Source target scan records the requested canonical ID")
			observed_targets[row.target] = true
	for target in TARGETS:
		check(observed_targets.has(target) and reference.targets.has(target), "Actual source fixture covers " + target)
	# Query order must not affect results even when one instance is reused.
	for i in range(reference.cases.size() - 1, -1, -1):
		var row: Dictionary = reference.cases[i]
		var p: Array = row.position
		var actual: PackedInt64Array = instances[str(int(row.seed))].biome_coordinates(int(p[0]), int(p[1]), int(p[2]))
		check(same_coordinates(actual, row.coordinates), "Reverse-order source query remains identical")

func run() -> void:
	synthetic_checks()
	source_checks()
	print("MINECLONIA NOISE: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)
