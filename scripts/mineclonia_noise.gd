class_name MinecloniaNoise
extends RefCounted

## Source-compatible numerical inputs for the default Mineclonia Overworld.
## All RNG state and Perlin permutations belong to this instance. Sampling does
## not mutate them, so independently constructed instances are worker-safe.

const WORLD_BORDER: float = 33554432.0
const RIGHT_NOISE_SCALE: float = 337.0 / 331.0
const QUANTIZATION: float = 10000.0
const MOUNTAIN_SCALE_RECIPROCAL: float = 1.0 / 2.17
const LO_XOREND: int = 7640891576956012809 # 0x6a09e667f3bcc909

const TEMPLATES: Dictionary = {
	"temperature": {"keyword": "minecraft:temperature", "first_octave": -10, "amplitudes": [1.5, 0.0, 1.0, 0.0, 0.0, 0.0]},
	"humidity": {"keyword": "minecraft:vegetation", "first_octave": -8, "amplitudes": [1.0, 1.0, 0.0, 0.0, 0.0, 0.0]},
	"continentalness": {"keyword": "minecraft:continentalness", "first_octave": -9, "amplitudes": [1.0, 1.0, 2.0, 2.0, 2.0, 1.0, 1.0, 1.0, 1.0]},
	"erosion": {"keyword": "minecraft:erosion", "first_octave": -9, "amplitudes": [1.0, 1.0, 0.0, 1.0, 1.0]},
	"weirdness": {"keyword": "minecraft:ridge", "first_octave": -7, "amplitudes": [1.0, 2.0, 1.0, 0.0, 0.0, 0.0]},
	"offset": {"keyword": "minecraft:offset", "first_octave": -3, "amplitudes": [1.0, 1.0, 1.0, 0.0]},
}

class Xoroshiro:
	## Xoroshiro128++ with signed GDScript ints holding unsigned 64-bit bits.
	const MIX_1: int = -4658895280553007687 # 0xbf58476d1ce4e5b9
	const MIX_2: int = -7723592293110705685 # 0x94d049bb133111eb
	const GOLDEN_GAMMA: int = -7046029254386353131 # 0x9e3779b97f4a7c15
	const DOUBLE_SCALE: float = 1.0 / 9007199254740991.0 # Source uses 2^53-1.
	const FLOAT_SCALE: float = 1.0 / 16777215.0 # Source uses 2^24-1.

	var _lo: int
	var _hi: int

	func _init(lo: int = 0, hi: int = 0) -> void:
		_lo = lo
		_hi = hi
		# Preserve random.lua's fallback exactly: only seedlo is replaced.
		if _lo == 0 and _hi == 0:
			_lo = MinecloniaNoise.LO_XOREND

	static func urshift(value: int, distance: int) -> int:
		if distance == 0:
			return value
		return (value >> distance) & ((1 << (64 - distance)) - 1)

	static func rotl(value: int, distance: int) -> int:
		return (value << distance) | urshift(value, 64 - distance)

	static func mul64(a: int, b: int) -> int:
		# Base-2^16 limbs avoid signed intermediate overflow before truncation.
		var aw: Array[int] = [a & 0xffff, (a >> 16) & 0xffff, (a >> 32) & 0xffff, (a >> 48) & 0xffff]
		var bw: Array[int] = [b & 0xffff, (b >> 16) & 0xffff, (b >> 32) & 0xffff, (b >> 48) & 0xffff]
		var result: Array[int] = [0, 0, 0, 0]
		var carry: int = 0
		for column in 4:
			var total: int = carry
			for i in range(column + 1):
				total += aw[i] * bw[column - i]
			result[column] = total & 0xffff
			carry = total >> 16
		return result[0] | (result[1] << 16) | (result[2] << 32) | (result[3] << 48)

	static func mix64(value: int) -> int:
		value = mul64(value ^ urshift(value, 30), MIX_1)
		value = mul64(value ^ urshift(value, 27), MIX_2)
		return value ^ urshift(value, 31)

	static func _uint64_to_double(value: int) -> float:
		return float(urshift(value, 32)) * 4294967296.0 + float(value & 0xffffffff)

	static func _double_to_uint64(value: float) -> int:
		var high: float = floor(value / 4294967296.0)
		var low: float = value - high * 4294967296.0
		return (int(high) << 32) | int(low)

	static func _mix_negative_world_seed(low: int, high: int) -> int:
		# random.lua's LuaJIT xorull sign-extends negative high words and
		# rounds them through tonumber. Keep that wide word through the first
		# XOR/multiply; subsequent shift/add operations truncate it again.
		var normalized: int = ((high & 0xffffffff) << 32) | low
		var temporary: int = urshift(normalized, 30)
		var next_low: int = (low ^ (temporary & 0xffffffff)) & 0xffffffff
		var next_high: int = high ^ urshift(temporary, 32)
		next_high = _double_to_uint64(_uint64_to_double(next_high))
		var shifted_low: int = mul64(next_low, 0xbf58476d) & 0xffffffff
		var low_product: int = mul64(next_low, 0x1ce4e5b9)
		var high_product: int = mul64(next_high, 0x1ce4e5b9)
		var right_low: int = low_product & 0xffffffff
		var right_high: int = ((high_product & 0xffffffff) + urshift(low_product, 32)) & 0xffffffff
		var value: int = (((shifted_low + right_high) & 0xffffffff) << 32) | right_low
		value = mul64(value ^ urshift(value, 27), MIX_2)
		return value ^ urshift(value, 31)

	static func seed_words(world_seed: int) -> Array[int]:
		var lo: int = world_seed ^ MinecloniaNoise.LO_XOREND
		if world_seed < 0:
			var low: int = lo & 0xffffffff
			var high: int = (world_seed >> 32) ^ (MinecloniaNoise.LO_XOREND >> 32)
			high = _double_to_uint64(_uint64_to_double(high))
			var normalized: int = ((high & 0xffffffff) << 32) | low
			return [_mix_negative_world_seed(low, high), mix64(normalized + GOLDEN_GAMMA)]
		return [mix64(lo), mix64(lo + GOLDEN_GAMMA)]

	static func from_world_seed(world_seed: int) -> Xoroshiro:
		var words: Array[int] = seed_words(world_seed)
		return Xoroshiro.new(words[0], words[1])

	func next_u64() -> int:
		var left: int = _lo
		var hi: int = _hi
		var result: int = rotl(left + hi, 17) + left
		var different: int = hi ^ left
		_lo = rotl(left, 49) ^ different ^ (different << 21)
		_hi = rotl(different, 28)
		return result

	func next_double() -> float:
		return float(urshift(next_u64(), 11)) * DOUBLE_SCALE

	func next_float() -> float:
		return float(urshift(next_u64(), 40)) * FLOAT_SCALE

	func next_within(bound: int) -> int:
		assert(bound > 0)
		while true:
			var product: int = int(next_u64() & 0xffffffff) * bound
			var low: int = product & 0xffffffff
			if low >= bound or low >= (0x100000000 - bound) % bound:
				return product >> 32
		return 0

	func fork_positional() -> PositionalFactory:
		return PositionalFactory.new(next_u64(), next_u64())
class PositionalFactory:
	var _lo: int
	var _hi: int

	func _init(lo: int, hi: int) -> void:
		_lo = lo
		_hi = hi

	static func keyword_hash(keyword: String) -> Array[int]:
		var context := HashingContext.new()
		assert(context.start(HashingContext.HASH_MD5) == OK)
		assert(context.update(keyword.to_utf8_buffer()) == OK)
		var digest: PackedByteArray = context.finish()
		var words: Array[int] = [0, 0]
		for i in 8:
			words[0] = (words[0] << 8) | int(digest[i])
			words[1] = (words[1] << 8) | int(digest[i + 8])
		return words

	func from_keyword(keyword: String) -> Xoroshiro:
		var hash: Array[int] = keyword_hash(keyword)
		return Xoroshiro.new(_lo ^ hash[0], _hi ^ hash[1])

	func at_position(x: int, y: int, z: int) -> Xoroshiro:
		var xf: int = Xoroshiro.mul64(x, 3129871) & 0xffffffff
		if xf & 0x80000000:
			xf -= 0x100000000
		var value: int = xf ^ Xoroshiro.mul64(z, 116129781) ^ y
		var hashed: int = Xoroshiro.mul64(Xoroshiro.mul64(value, value), 42317861) + Xoroshiro.mul64(value, 11)
		return Xoroshiro.new(_lo ^ (hashed >> 16), _hi)


class Octave:
	const GRADIENTS: Array[int] = [
	1, 1, 0, -1, 1, 0, 1, -1, 0, -1, -1, 0,
	1, 0, 1, -1, 0, 1, 1, 0, -1, -1, 0, -1,
	0, 1, 1, 0, -1, 1, 0, 1, -1, 0, -1, -1,
	1, 1, 0, 0, -1, 1, -1, 1, 0, 0, -1, -1,
]

	var _x_offset: float
	var _y_offset: float
	var _z_offset: float
	var _permutation := PackedInt32Array()

	func _init(rng: Xoroshiro) -> void:
		_x_offset = rng.next_double() * 256.0
		_y_offset = rng.next_double() * 256.0
		_z_offset = rng.next_double() * 256.0
		_permutation.resize(256)
		for i in 256:
			_permutation[i] = i
		for i in 256:
			var other: int = i + rng.next_within(256 - i)
			var saved: int = _permutation[i]
			_permutation[i] = _permutation[other]
			_permutation[other] = saved

	static func _fade(value: float) -> float:
		return value * value * value * (value * (value * 6.0 - 15.0) + 10.0)

	static func _lerp(progress: float, below: float, above: float) -> float:
		return (above - below) * progress + below

	func _dot(hash: int, x: float, y: float, z: float) -> float:
		var index: int = (hash & 0xf) * 3
		return GRADIENTS[index] * x + GRADIENTS[index + 1] * y + GRADIENTS[index + 2] * z

	func sample(x: float, y: float, z: float) -> float:
		x += _x_offset
		y += _y_offset
		z += _z_offset
		var grid_x: int = floori(x)
		var grid_y: int = floori(y)
		var grid_z: int = floori(z)
		var fx: float = x - grid_x
		var fy: float = y - grid_y
		var fz: float = z - grid_z
		var x1: int = _permutation[grid_x & 0xff]
		var x2: int = _permutation[(grid_x + 1) & 0xff]
		var y1: int = _permutation[(x1 + grid_y) & 0xff]
		var y2: int = _permutation[(x1 + grid_y + 1) & 0xff]
		var x2y1: int = _permutation[(x2 + grid_y) & 0xff]
		var x2y2: int = _permutation[(x2 + grid_y + 1) & 0xff]
		var s1: float = _dot(_permutation[(y1 + grid_z) & 0xff], fx, fy, fz)
		var s2: float = _dot(_permutation[(x2y1 + grid_z) & 0xff], fx - 1.0, fy, fz)
		var s3: float = _dot(_permutation[(y2 + grid_z) & 0xff], fx, fy - 1.0, fz)
		var s4: float = _dot(_permutation[(x2y2 + grid_z) & 0xff], fx - 1.0, fy - 1.0, fz)
		var s5: float = _dot(_permutation[(y1 + grid_z + 1) & 0xff], fx, fy, fz - 1.0)
		var s6: float = _dot(_permutation[(x2y1 + grid_z + 1) & 0xff], fx - 1.0, fy, fz - 1.0)
		var s7: float = _dot(_permutation[(y2 + grid_z + 1) & 0xff], fx, fy - 1.0, fz - 1.0)
		var s8: float = _dot(_permutation[(x2y2 + grid_z + 1) & 0xff], fx - 1.0, fy - 1.0, fz - 1.0)
		var u: float = _fade(fx)
		var v: float = _fade(fy)
		var w: float = _fade(fz)
		var below: float = _lerp(v, _lerp(u, s1, s2), _lerp(u, s3, s4))
		var above: float = _lerp(v, _lerp(u, s5, s6), _lerp(u, s7, s8))
		return _lerp(w, below, above)

class PerlinNoise:
	var _octaves: Array = []
	var _amplitudes: Array = []
	var _initial_persistence: float
	var _initial_amplitude: float
	var max_value: float

	func _init(factory: PositionalFactory, first_octave: int, amplitudes: Array) -> void:
		_amplitudes = amplitudes.duplicate()
		_octaves.resize(amplitudes.size())
		for i in amplitudes.size():
			if float(amplitudes[i]) != 0.0:
				var rng: Xoroshiro = factory.from_keyword("octave_" + str(first_octave + i))
				_octaves[i] = Octave.new(rng)
		_initial_persistence = pow(2.0, first_octave)
		_initial_amplitude = initial_amplitude(amplitudes.size())
		max_value = get_max_value(2.0)

	static func initial_amplitude(count: int) -> float:
		return pow(2.0, count - 1) / (pow(2.0, count) - 1.0)

	static func wrap(value: float) -> float:
		return value - floor(value / MinecloniaNoise.WORLD_BORDER + 0.5) * MinecloniaNoise.WORLD_BORDER

	func get_max_value(amplitude_scale: float) -> float:
		var amplitude: float = _initial_amplitude
		var result: float = 0.0
		for i in _amplitudes.size():
			if _octaves[i] != null:
				result += float(_amplitudes[i]) * amplitude_scale * amplitude
			amplitude /= 2.0
		return result

	func sample(x: float, y: float, z: float) -> float:
		var persistence: float = _initial_persistence
		var amplitude: float = _initial_amplitude
		var result: float = 0.0
		for i in _amplitudes.size():
			if _octaves[i] != null:
				var xs: float = PerlinNoise.wrap(x * persistence)
				var ys: float = PerlinNoise.wrap(y * persistence)
				var zs: float = PerlinNoise.wrap(z * persistence)
				result += float(_amplitudes[i]) * _octaves[i].sample(xs, ys, zs) * amplitude
			persistence *= 2.0
			amplitude /= 2.0
		return result

class NormalNoise:
	var first_octave: int
	var amplitudes: Array
	var normalization_factor: float
	var max_value: float
	var _left: PerlinNoise
	var _right: PerlinNoise

	func _init(rng: Xoroshiro, first: int, amps: Array) -> void:
		first_octave = first
		amplitudes = amps.duplicate()
		var minimum: int = 0x7fffffff
		var maximum: int = -0x80000000
		for i in amps.size():
			if float(amps[i]) != 0.0:
				minimum = mini(minimum, i)
				maximum = maxi(maximum, i)
		_left = PerlinNoise.new(rng.fork_positional(), first, amps)
		_right = PerlinNoise.new(rng.fork_positional(), first, amps)
		normalization_factor = normalization(minimum, maximum)
		max_value = (_left.max_value + _right.max_value) * normalization_factor

	static func normalization(minimum_active: int, maximum_active: int) -> float:
		var expected_deviation: float = 0.1 * (1.0 + 1.0 / (maximum_active - minimum_active + 1.0))
		return (1.0 / 6.0) / expected_deviation

	func sample(x: float, y: float, z: float) -> float:
		return (_left.sample(x, y, z) + _right.sample(x * MinecloniaNoise.RIGHT_NOISE_SCALE, y * MinecloniaNoise.RIGHT_NOISE_SCALE, z * MinecloniaNoise.RIGHT_NOISE_SCALE)) * normalization_factor

class Spline:
	# axis: 0 = continentalness, 1 = erosion, 2 = peaks and valleys.
	var _axis: int
	var _locations: Array[float] = []
	var _values: Array = []
	var _derivatives: Array[float] = []

	func _init(axis: int, points: Array) -> void:
		_axis = axis
		for point in points:
			_locations.append(float(point[0]))
			_values.append(point[1])
			_derivatives.append(float(point[2]))

	func _value(index: int, continentalness: float, erosion: float, pv: float) -> float:
		var value: Variant = _values[index]
		if value is Spline:
			return value.evaluate(continentalness, erosion, pv)
		return float(value)

	static func _lerp(progress: float, below: float, above: float) -> float:
		return (above - below) * progress + below

	func evaluate(continentalness: float, erosion: float, pv: float) -> float:
		var location: float = continentalness if _axis == 0 else (erosion if _axis == 1 else pv)
		var minimum: int = 0
		var maximum: int = _locations.size()
		while maximum - minimum > 0:
			var middle: int = minimum + ((maximum - minimum) >> 1)
			if _locations[middle] >= location:
				maximum = middle
			else:
				minimum = middle + 1
		if minimum == 0:
			var first: float = _value(0, continentalness, erosion, pv)
			if _derivatives[0] == 0.0:
				return first
			return first + _derivatives[0] * (location - _locations[0])
		if minimum >= _locations.size():
			var last: int = _locations.size() - 1
			var value: float = _value(last, continentalness, erosion, pv)
			if _derivatives[last] == 0.0:
				return value
			return value + _derivatives[last] * (location - _locations[last])
		var below: int = minimum - 1
		var above: int = minimum
		var loc_diff: float = _locations[above] - _locations[below]
		var val_below: float = _value(below, continentalness, erosion, pv)
		var val_above: float = _value(above, continentalness, erosion, pv)
		var val_diff: float = val_above - val_below
		var dev_below: float = _derivatives[below] * loc_diff - val_diff
		var dev_above: float = -_derivatives[above] * loc_diff + val_diff
		var progress: float = (location - _locations[below]) / loc_diff
		return _lerp(progress, val_below, val_above) + progress * (1.0 - progress) * _lerp(progress, dev_below, dev_above)

var world_seed: int
var temperature: NormalNoise
var humidity: NormalNoise
var continentalness: NormalNoise
var erosion: NormalNoise
var weirdness: NormalNoise
var offset: NormalNoise
var _offset_spline: Spline

func _init(seed_value: int = 0) -> void:
	world_seed = seed_value
	var factory: PositionalFactory = Xoroshiro.from_world_seed(seed_value).fork_positional()
	temperature = _make_normal(factory, "temperature")
	humidity = _make_normal(factory, "humidity")
	continentalness = _make_normal(factory, "continentalness")
	erosion = _make_normal(factory, "erosion")
	weirdness = _make_normal(factory, "weirdness")
	offset = _make_normal(factory, "offset")
	_offset_spline = _make_offset_spline()

static func _make_normal(factory: PositionalFactory, role: String) -> NormalNoise:
	var template: Dictionary = TEMPLATES[role]
	return NormalNoise.new(factory.from_keyword(template.keyword), int(template.first_octave), template.amplitudes)

static func seed_words(seed_value: int) -> Array[int]:
	return Xoroshiro.seed_words(seed_value)

static func mix64(value: int) -> int:
	return Xoroshiro.mix64(value)

static func keyword_hash(keyword: String) -> Array[int]:
	return PositionalFactory.keyword_hash(keyword)

static func wrap_world_border(value: float) -> float:
	return PerlinNoise.wrap(value)

static func peaks_valleys(raw_weirdness: float) -> float:
	return -3.0 * (absf(absf(raw_weirdness) - 2.0 / 3.0) - 1.0 / 3.0)

static func clamped_gradient(y: float) -> float:
	var progress: float = (y + 64.0) / 384.0
	if progress < 0.0:
		return 1.5
	if progress > 1.0:
		return -1.5
	return (-3.0) * progress + 1.5

static func quantize(value: float) -> int:
	return ceili(value * QUANTIZATION) if value < 0.0 else floori(value * QUANTIZATION)

static func to_quart(block_coordinate: int) -> int:
	return block_coordinate >> 2

func sample_horizontal(x: float, z: float) -> Dictionary:
	var shift_x: float = offset.sample(x * 0.25, 0.0, z * 0.25) * 4.0
	var shift_z: float = offset.sample(z * 0.25, x * 0.25, 0.0) * 4.0
	var shifted_x: float = x * 0.25 + shift_x
	var shifted_z: float = z * 0.25 + shift_z
	var ridge: float = weirdness.sample(shifted_x, 0.0, shifted_z)
	return {
		"temperature": temperature.sample(shifted_x, 0.0, shifted_z),
		"humidity": humidity.sample(shifted_x, 0.0, shifted_z),
		"continentalness": continentalness.sample(shifted_x, 0.0, shifted_z),
		"erosion": erosion.sample(shifted_x, 0.0, shifted_z),
		"weirdness": ridge,
		"peaks_valleys": peaks_valleys(ridge),
		"shift_x": shift_x,
		"shift_z": shift_z,
	}

static func _lerp(progress: float, below: float, above: float) -> float:
	return (above - below) * progress + below

static func _mountain_continentalness(low: float, height: float, high: float) -> float:
	var base: float = 1.0 - (1.0 - height) * 0.5
	var inverse: float = 0.5 * (1.0 - height)
	var scale: float = (low + 1.17) * MOUNTAIN_SCALE_RECIPROCAL
	return maxf(scale * base - inverse, -0.2222 if low < high else 0.0)

static func _continentalness_origin(height: float) -> float:
	var base: float = 1.0 - (1.0 - height) * 0.5
	var inverse: float = 0.5 * (1.0 - height)
	return inverse / (MOUNTAIN_SCALE_RECIPROCAL * base) - 1.17

static func _spline(axis: int, points: Array) -> Spline:
	return Spline.new(axis, points)

static func _mountain_ridge_spline(height: float, high_continentalness: bool) -> Spline:
	var low: float = _mountain_continentalness(-1.0, height, -0.7)
	var high: float = _mountain_continentalness(1.0, height, -0.7)
	var origin: float = _continentalness_origin(height)
	var points: Array = []
	if -0.65 < origin and origin < 1.0:
		var base: float = _mountain_continentalness(-0.65, height, -0.7)
		var below: float = _mountain_continentalness(-0.75, height, -0.7)
		var first_derivative: float = (low - below) / (-1.0 + 0.75)
		points = [[-1.0, low, first_derivative], [-0.75, below, 0.0], [-0.65, base, 0.0]]
		var ground: float = _mountain_continentalness(origin, height, -0.7)
		var derivative: float = (high - ground) / (1.0 - origin)
		points.append([origin - 0.01, ground, 0.0])
		points.append([origin, ground, derivative])
		points.append([1.0, high, derivative])
	else:
		var derivative: float = (high - low) / 2.0
		if high_continentalness:
			points.append([-1.0, maxf(0.2, low), 0.0])
			points.append([0.0, _lerp(0.5, low, high), derivative])
		else:
			points.append([-1.0, low, derivative])
		points.append([1.0, high, derivative])
	return _spline(2, points)

static func _ridge_spline(valleys: float, low: float, middle: float, high: float, peak: float, minimum_derivative: float) -> Spline:
	var first: float = maxf(0.5 * (low - valleys), minimum_derivative)
	var mid_derivative: float = 5.0 * (middle - low)
	return _spline(2, [
		[-1.0, valleys, first],
		[-0.4, low, minf(first, mid_derivative)],
		[0.0, middle, mid_derivative],
		[0.4, high, 2.0 * (high - middle)],
		[1.0, peak, 0.7 * (peak - high)],
	])

static func _erosion_spline(valleys: float, mid_pv: float, peak_pv: float, mountain_height: float, low_pv: float, high_erosion_low_pv: float, high_continentalness_0: bool, high_continentalness: bool) -> Spline:
	var grade0: Spline = _mountain_ridge_spline(_lerp(mountain_height, 0.6, 1.5), high_continentalness)
	var grade1: Spline = _mountain_ridge_spline(_lerp(mountain_height, 0.6, 1.0), high_continentalness)
	var grade2: Spline = _mountain_ridge_spline(mountain_height, high_continentalness)
	var grade3: Spline = _ridge_spline(valleys - 0.15, 0.5 * mountain_height, 0.5 * mountain_height, 0.5 * mountain_height, 0.6 * mountain_height, 0.5)
	var grade4: Spline = _ridge_spline(valleys, low_pv * mountain_height, mid_pv * mountain_height, 0.5 * mountain_height, 0.6 * mountain_height, 0.5)
	var grade5: Spline = _ridge_spline(valleys, low_pv, low_pv, mid_pv, peak_pv, 0.5)
	var grade6: Spline = _ridge_spline(valleys, low_pv, low_pv, mid_pv, peak_pv, 0.5)
	var grade7: Spline = _spline(2, [[-1.0, valleys, 0.0], [-0.4, grade5, 0.0], [0.0, peak_pv + 0.07, 0.0]])
	var grade8: Spline = _ridge_spline(-0.02, high_erosion_low_pv, high_erosion_low_pv, mid_pv, peak_pv, 0.0)
	var points: Array = [[-0.85, grade0, 0.0], [-0.7, grade1, 0.0], [-0.4, grade2, 0.0], [-0.35, grade3, 0.0], [-0.1, grade4, 0.0], [0.2, grade5, 0.0]]
	if high_continentalness_0:
		points.append([0.4, grade6, 0.0])
		points.append([0.45, grade7, 0.0])
		points.append([0.55, grade7, 0.0])
		points.append([0.58, grade6, 0.0])
	points.append([0.7, grade8, 0.0])
	return _spline(1, points)

static func _make_offset_spline() -> Spline:
	var coast: Spline = _erosion_spline(-0.15, 0.0, 0.0, 0.1, 0.0, -0.03, false, false)
	var inland: Spline = _erosion_spline(-0.1, 0.03, 0.1, 0.1, 0.01, -0.03, false, false)
	var far_inland: Spline = _erosion_spline(-0.1, 0.03, 0.1, 0.7, 0.01, -0.03, true, true)
	var final_inland: Spline = _erosion_spline(-0.05, 0.03, 0.1, 1.0, 0.01, 0.01, true, true)
	return _spline(0, [
		[-1.1, 0.044, 0.0], [-1.02, -0.2222, 0.0], [-0.51, -0.2222, 0.0],
		[-0.44, -0.12, 0.0], [-0.18, -0.12, 0.0], [-0.16, coast, 0.0],
		[-0.15, coast, 0.0], [-0.10, inland, 0.0], [0.25, far_inland, 0.0],
		[1.0, final_inland, 0.0],
	])

func depth_offset(continentalness_value: float, erosion_value: float, raw_weirdness: float) -> float:
	return -0.50375 + _offset_spline.evaluate(continentalness_value, erosion_value, peaks_valleys(raw_weirdness))

func depth_from_climate(continentalness_value: float, erosion_value: float, raw_weirdness: float, y: float) -> float:
	return clamped_gradient(y) + depth_offset(continentalness_value, erosion_value, raw_weirdness)

func depth_at(x: float, quart_y: int, z: float) -> float:
	var horizontal: Dictionary = sample_horizontal(x, z)
	return depth_from_climate(horizontal.continentalness, horizontal.erosion, horizontal.weirdness, quart_y * 4.0)

func sample_climate(x: float, y: float, z: float) -> Dictionary:
	var result: Dictionary = sample_horizontal(x, z)
	result["depth"] = depth_from_climate(result.continentalness, result.erosion, result.weirdness, y)
	return result

func sample_quart(qx: int, qy: int, qz: int) -> PackedInt64Array:
	return biome_coordinates(qx * 4, qy * 4, qz * 4)

func biome_coordinates(x: int, y: int, z: int) -> PackedInt64Array:
	# Equivalent to bit.band(x, -4), including negative block coordinates.
	x = (x >> 2) << 2
	y = (y >> 2) << 2
	z = (z >> 2) << 2
	var climate: Dictionary = sample_climate(x, y, z)
	return PackedInt64Array([
		quantize(climate.temperature), quantize(climate.humidity),
		quantize(climate.continentalness), quantize(climate.erosion),
		quantize(climate.depth), quantize(climate.weirdness), 0,
	])
