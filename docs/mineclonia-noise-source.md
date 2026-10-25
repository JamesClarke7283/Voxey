# Mineclonia biome noise and depth

Reference: `/home/impulse/.minetest/games/mineclonia`, inspected 2026-10-25.
The source-derived algorithms retain Mineclonia's GPL-3.0-or-later attribution.

`scripts/mineclonia_noise.gd` implements the numerical prerequisites for canonical
Overworld biome selection directly from `MAPGEN/mcl_levelgen/random.lua`,
`noise.lua`, `presets.lua`, `density_funcs.lua`, and `biomes.lua`. It does not use
`FastNoiseLite`, Godot's `RandomNumberGenerator`, a modern-Minecraft substitute,
or a biome lookup table.

## Public API

```gdscript
const Noise = preload("res://scripts/mineclonia_noise.gd")
var noise = Noise.new(world_seed) # class_name: MinecloniaNoise

var horizontal: Dictionary = noise.sample_horizontal(block_x, block_z)
var depth: float = noise.depth_at(block_x, quart_y, block_z)
var climate: Dictionary = noise.sample_climate(block_x, block_y, block_z)
var coordinates: PackedInt64Array = noise.biome_coordinates(block_x, block_y, block_z)
var same: PackedInt64Array = noise.sample_quart(quart_x, quart_y, quart_z)
```

- `_init(seed_value: int = 0)` constructs a complete independent default
  Overworld sampler. The signed GDScript integer is interpreted as the low 64
  bits of the source world seed. No global RNG or mutable class state is used.
- `sample_horizontal(x: float, z: float) -> Dictionary` returns `temperature`,
  `humidity`, `continentalness`, `erosion`, raw `weirdness`, derived
  `peaks_valleys`, and the diagnostic `shift_x`/`shift_z` values. Inputs are
  source block coordinates, not Voxey region coordinates.
- `depth_at(x: float, quart_y: int, z: float) -> float` samples horizontal
  climate at block X/Z and evaluates depth at block Y `quart_y * 4`.
- `sample_climate(x: float, y: float, z: float) -> Dictionary` returns all
  `sample_horizontal` fields plus `depth` at the supplied block Y.
- `depth_from_climate(continentalness, erosion, raw_weirdness, y) -> float` and
  `depth_offset(continentalness, erosion, raw_weirdness) -> float` expose the
  derived depth calculation without resampling noise. Weirdness is the raw
  ridge channel, **not** PV.
- `biome_coordinates(x: int, y: int, z: int) -> PackedInt64Array` is the direct
  numerical counterpart of `preset:biome_coordinates(x,y,z)`. It masks each
  input down to its quart origin and returns seven integers in source order:
  temperature, humidity, continentalness, erosion, depth, weirdness, offset.
  Quantization is truncation toward zero after multiplication by 10000; offset
  is zero.
- `sample_quart(qx: int, qy: int, qz: int) -> PackedInt64Array` is the same query
  at `(qx*4,qy*4,qz*4)`. Arithmetic right shift in `to_quart()` preserves the
  source's negative-coordinate behavior.

The public channel objects `temperature`, `humidity`, `continentalness`,
`erosion`, `weirdness`, and `offset` each expose
`sample(x: float, y: float, z: float) -> float`, `first_octave`, `amplitudes`,
`normalization_factor`, and `max_value`. Treat templates and amplitude arrays as
read-only. `TEMPLATES` records the six exact default templates. Diagnostic pure
helpers include `mix64`, `seed_words`, `keyword_hash`, `wrap_world_border`,
`peaks_valleys`, `clamped_gradient`, `quantize`, and `to_quart`; nested
`Xoroshiro`, `PositionalFactory`, `PerlinNoise`, and `NormalNoise` types permit
focused low-level checks.

## Exact numerical compatibility

### Seed and random factories

`random.lua:719-1027` and `presets.lua:1514-1538` are ported literally:

- Xoroshiro128++ state transitions and output use unsigned 64-bit wraparound,
  logical right shifts, and the source rotations 17/49/21/28. GDScript signed
  integers hold the bits; base-65536 limbs implement multiplication without
  losing the high word.
- World seeding XORs `0x6a09e667f3bcc909`, adds
  `0x9e3779b97f4a7c15` for the second word, and applies Stafford `mix64` to
  both. Negative seeds also reproduce the LuaJIT branch's signed high-word
  extension and double-rounding before the first mix operations. The positional
  factory consumes two RNG outputs; each channel has an independent keyword.
- MD5 bytes form four big-endian 32-bit words, assembled into two 64-bit seeds.
  Octaves use independent `octave_N` factories for every nonzero amplitude.
  `PositionalFactory.at_position()` also retains the source positional hash.
- `next_within` uses the low unsigned 32 bits, 32-bit rejection scaling, and the
  source's exact `next_double`/`next_float` divisors (`2^53-1` and `2^24-1`,
  respectively). These divisors intentionally follow this checkout rather than
  substituting a different JVM implementation.

### Improved Perlin and NormalNoise

Each octave consumes three random offsets in `[0,256)`, initializes the values
0 through 255, and performs the source's 256-step `next_within(256-i)` shuffle.
Gradient selection, fade, nested interpolation, and corner order come from
`noise.lua:1-150`.

Every NormalNoise channel has independent left and right Perlin samplers. Right
coordinates are multiplied by `337/331`. Per-octave coordinates are wrapped with
`x - floor(x/33554432 + 0.5)*33554432`; input scale starts at `2^first_octave`
and doubles, while amplitude starts at `2^(n-1)/(2^n-1)` and halves. Only active
octaves contribute. The final multiplier is

\[
r=\frac{1/6}{0.1\left(1+\frac{1}{maxActive-minActive+1}\right)}.
\]

The default channels are:

| Role | Keyword | First octave | Amplitudes |
|---|---|---:|---|
| temperature | `minecraft:temperature` | -10 | `[1.5,0,1,0,0,0]` |
| humidity | `minecraft:vegetation` | -8 | `[1,1,0,0,0,0]` |
| continentalness | `minecraft:continentalness` | -9 | `[1,1,2,2,2,1,1,1,1]` |
| erosion | `minecraft:erosion` | -9 | `[1,1,0,1,1]` |
| weirdness | `minecraft:ridge` | -7 | `[1,2,1,0,0,0]` |
| offset | `minecraft:offset` | -3 | `[1,1,1,0]` |

Both shifts use the one shared offset instance:

\[
s_x=4O(0.25x,0,0.25z),\qquad s_z=4O(0.25z,0.25x,0).
\]

Every horizontal channel is then sampled at
`(0.25x+s_x,0,0.25z+s_z)`. In particular, humidity is `vegetation`, and the
weirdness coordinate remains raw ridge noise.

### PV, offset splines, and depth

The raw ridge value `W` is folded to
`PV = -3*(abs(abs(W)-2/3)-1/3)`. The complete nested continentalness/erosion/PV
spline tree from `presets.lua:518-887` is represented by immutable instance-local
`Spline` objects. Knot locations, values, derivatives, high-continentalness
branches, binary-search endpoint behavior, Hermite interpolation, and outsized
linear extension follow `density_funcs.lua:1588-1685`.

Depth is not another noise channel:

\[
D=\operatorname{clampedGradient}(Y;-64,320,1.5,-1.5)
 -0.50375+\operatorname{overworldOffset}(C,E,PV).
\]

The gradient is linear between the endpoints and clamped outside them. Factor,
jaggedness, sloped cheese, final terrain density, caves, and aquifers are outside
this module and are not silently substituted for biome depth.

## Oracle and checks

Run the exporter against the real checkout, then run the Godot checks:

```sh
python3 tools/export_biome_reference.py
godot --headless --path . --script tests/mineclonia_noise_checks.gd
```

The exporter creates `assets/data/biome_reference.json`; that generated fixture
is intentionally not handwritten. A temporary Luanti world loads `mcl_levelgen`
and records both `preset:biome_coordinates(x,y,z)` and
`preset:index_biomes_block(x,y,z)` for fixed signed seeds. Fixed cases cover
negative coordinates, quart boundaries, and vertical sequences. A deterministic
source-side concentric scan adds cases for `Taiga`, `OldGrowthSpruceTaiga`,
`OldGrowthPineTaiga`, `BambooJungle`, `MushroomIslands`, and `LushCaves`; it does
not rely on guessed modern-Minecraft locations. SHA-256 hashes cover the five
algorithm/query files plus `md5.lua`.

`tests/mineclonia_noise_checks.gd` compares actual quantized source coordinates,
checks source target coverage, repeats source queries in reverse order, and
exercises actual Luanti RNG sequences, signed-seed conversion, MD5 byte order,
unsigned bounded RNG, world wrapping, normalization, PV, depth knots/clamping,
quart behavior, and same-seed instance repeatability. The current suite passes
623 checks. Biome-ID comparison belongs to the later LUT selector; this
prerequisite tests numerical coordinates while retaining source IDs in the fixture.

## Parity boundary

Compatibility means the **default Overworld numerical climate/depth query** and
direct `preset:biome_coordinates` values for the same source seed and source
block coordinates. Once the ordered biome extents and nearest-extent query are
added, these are also the inputs needed for direct `index_biomes_block` parity.

This does **not** claim whole-world terrain seed identity, Voxey height or block
parity, caves/aquifers/carvers, surface rules, feature placement, feature/biome
coordinate munging, structure seeds, or natural-feature seed identity. It also
does not apply the Luanti dimension adapter `(x,y+dim.y_offset,-z-1)`; callers
comparing a Luanti world position must perform that conversion separately.
Large-biome, amplified, legacy JVM temperature/vegetation, Nether, and End
presets are outside this default-Overworld module.
