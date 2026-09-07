class_name WorldBounds
extends RefCounted

# mcl_init/init.lua: mapgen_limit 31000, chunksize 5, mapblock size 16.
# Voxey keeps separate dimension scenes, so Nether/End Y values are local.
const MIN_XZ = -30912
const MAX_XZ = 30927
const OVERWORLD_MIN = -128
const OVERWORLD_MAX = 30927
const NETHER_TERRAIN_MAX = 128
const NETHER_MAX = 256 # mcl_worlds includes 128 blocks above the bedrock roof.
const END_MAX = 24945 # -2128 (realm barrier) minus -27073 (legacy End origin).

static func horizontal(p: Vector3i) -> bool:
	return p.x >= MIN_XZ and p.x <= MAX_XZ and p.z >= MIN_XZ and p.z <= MAX_XZ

static func maximum(dimension: String) -> int:
	return {"overworld":OVERWORLD_MAX,"nether":NETHER_MAX,"end":END_MAX}.get(dimension,OVERWORLD_MAX)

static func contains(p: Vector3, dimension: String) -> bool:
	return is_finite(p.x) and is_finite(p.y) and is_finite(p.z) and horizontal(Vector3i(p.floor())) and p.y > (OVERWORLD_MIN if dimension == "overworld" else 0) and p.y < maximum(dimension)-1

static func clamp_arrival(p: Vector3, dimension: String) -> Vector3:
	return Vector3(clampf(p.x,MIN_XZ+2,MAX_XZ-2),clampf(p.y,OVERWORLD_MIN+2 if dimension == "overworld" else 2,maximum(dimension)-2),clampf(p.z,MIN_XZ+2,MAX_XZ-2))

static func clean_location(value: Variant) -> Dictionary:
	if not value is Dictionary or value.get("dimension","") not in ["overworld","nether","end"]: return {}
	var coordinates: Variant = value.get("position")
	if not coordinates is Array or coordinates.size() != 3: return {}
	for coordinate in coordinates:
		if not (coordinate is int or coordinate is float) or not is_finite(float(coordinate)): return {}
	return {"dimension":String(value.dimension),"position":coordinates.duplicate(),"yaw":float(value.get("yaw",0)),"pitch":float(value.get("pitch",0))}
