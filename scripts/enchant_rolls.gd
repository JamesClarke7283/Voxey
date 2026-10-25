class_name EnchantRolls
extends RefCounted

# A portable 32-bit stream keeps cached offers reproducible through JSON saves.
# Loot generators can instead share their existing RandomNumberGenerator.
var state: int
var native: RandomNumberGenerator

func _init(seed_value: int = 1, rng: RandomNumberGenerator = null) -> void:
	state = seed_value&0xffffffff; native = rng

func next_value() -> int:
	state = (state*1664525+1013904223)&0xffffffff
	return state

func integer(low: int, high: int) -> int:
	return native.randi_range(low,high) if native != null else low+next_value()%(high-low+1)

func unit() -> float:
	return native.randf() if native != null else float(next_value())/4294967295.0
