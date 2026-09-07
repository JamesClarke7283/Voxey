class_name LuantiValueNoise
extends RefCounted

# The value-noise polynomial and trilinear octave construction from Luanti
# src/noise.cpp. 3-D "defaults" uses linear interpolation, without easing.
# Source attribution and algorithm details: docs/mineclonia-world-source.md.
# Copyright (C) 2010-2014 celeron55, Perttu Ahola; kwolekr, Ryan Kwolek.
# BSD-2-Clause; retained notice: docs/licenses/Luanti-Noise-BSD.txt.
var layers: Array = []
var cells: Dictionary = {}
var source_seed: int

func _init(seed_value: int) -> void:
	source_seed = seed_value+12345
	for octave in 3: layers.append({"frequency":pow(2.0,octave)/250.0,"gain":pow(0.6,octave),"cache":{}})

static func lattice(p: Vector3i, seed_value: int) -> float:
	var n: int = (p.x*1619+p.y*31337+p.z*52591+seed_value*1013)&0x7fffffff
	n = (n >> 13)^n
	var q: int = (((n*n)&0x7fffffff)*60493+19990303)&0x7fffffff
	return 1.0-float((n*q+1376312589)&0x7fffffff)/1073741824.0

func sample(p: Vector3) -> float:
	# All three octave lattices align on 62.5-node boundaries. Their sum is
	# trilinear inside each such cell, so blobs reuse eight combined samples.
	var point: Vector3 = p/62.5
	var cell := Vector3i(point.floor())
	if not cells.has(cell):
		var values := PackedFloat64Array()
		for z in 2:
			for y in 2:
				for x in 2: values.append(_sample_raw(Vector3(cell+Vector3i(x,y,z))*62.5))
		cells[cell] = values
	var c: PackedFloat64Array = cells[cell]
	var f: Vector3 = point-Vector3(cell)
	return lerpf(lerpf(lerpf(c[0],c[1],f.x),lerpf(c[2],c[3],f.x),f.y),lerpf(lerpf(c[4],c[5],f.x),lerpf(c[6],c[7],f.x),f.y),f.z)

func _sample_raw(p: Vector3) -> float:
	var result: float = 0
	for octave in 3:
		var layer: Dictionary = layers[octave]
		var point: Vector3 = p*layer.frequency
		var cell := Vector3i(point.floor())
		if not layer.cache.has(cell):
			var corners := PackedFloat64Array()
			for z in 2:
				for y in 2:
					for x in 2: corners.append(lattice(cell+Vector3i(x,y,z),source_seed+octave))
			layer.cache[cell] = corners
		var c: PackedFloat64Array = layer.cache[cell]
		var f: Vector3 = point-Vector3(cell)
		var low: float = lerpf(lerpf(c[0],c[1],f.x),lerpf(c[2],c[3],f.x),f.y)
		var high: float = lerpf(lerpf(c[4],c[5],f.x),lerpf(c[6],c[7],f.x),f.y)
		result += lerpf(low,high,f.z)*layer.gain
	return result
