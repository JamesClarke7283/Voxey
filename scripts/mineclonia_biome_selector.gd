class_name MinecloniaBiomeSelector
extends RefCounted

## Default-Overworld nearest-extent biome selection from mcl_levelgen/biomes.lua.
## The exported tree is read-only and shared; last_result is instance-local just
## like the source preset's tree. Source-derived data retains GPL-3.0-or-later.

const LUT_PATH: String = "res://assets/data/biome_lut.json"
static var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LUT_PATH))
static var _root: Dictionary = data.root

var noise: MinecloniaNoise
var _last_leaf: Dictionary = {}
var _candidate: Dictionary = {}
var _distance: int = 0

func _init(seed_value: int = 0, sampler: MinecloniaNoise = null) -> void:
	noise = sampler if sampler != null else MinecloniaNoise.new(seed_value)

static func distance_to_value(packed_range: int, value: int) -> int:
	var dmax: int = value - (packed_range & 0xffff) + 32768
	var dmin: int = (packed_range >> 16) - value
	# The source treats both lower and upper extent bounds as inclusive.
	return dmax if dmax > 0 else maxi(dmin, 0)

static func distance_total(extents: Array, coordinates: PackedInt64Array) -> int:
	assert(extents.size() == 7 and coordinates.size() == 7)
	var total: int = 0
	for axis in 7:
		var distance: int = distance_to_value(int(extents[axis]), coordinates[axis])
		total += distance * distance
	return total

func _visit(node: Dictionary, coordinates: PackedInt64Array) -> void:
	var distance: int = distance_total(node.extents, coordinates)
	if distance >= _distance:
		return
	if node.has("value"):
		_candidate = node
		_distance = distance
		return
	for child in node.children:
		_visit(child, coordinates)

func select_coordinates(coordinates: PackedInt64Array) -> String:
	assert(coordinates.size() == 7)
	_candidate = {}
	_distance = 0x7fffffffffffffff
	if not _last_leaf.is_empty():
		_candidate = _last_leaf
		_distance = distance_total(_candidate.extents, coordinates)
	for child in _root.children:
		_visit(child, coordinates)
	assert(not _candidate.is_empty())
	_last_leaf = _candidate
	return str(_candidate.value)

func index_biomes(qx: int, qy: int, qz: int) -> String:
	return select_coordinates(noise.sample_quart(qx, qy, qz))

func index_biomes_block(x: int, y: int, z: int) -> String:
	return select_coordinates(noise.biome_coordinates(x, y, z))

func sample_climate(x: int, y: int, z: int) -> Dictionary:
	return noise.sample_climate(x, y, z)
