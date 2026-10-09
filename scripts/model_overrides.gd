class_name ModelOverrides
extends RefCounted

# Blender-authored model overrides. A glTF binary at
# `res://assets/models/<content_id>.glb` replaces the procedural mesh for that
# content id, with the atlas texture remapped so the model wears the same
# GIMP-authored tile the block does. The directory ships empty, so this is inert
# unless an artist drops a model in; every id without one keeps its procedural mesh.
#
# The model must be authored in Godot cell coordinates (a 1x1x1 block cell centred
# on `(0.5, *, 0.5)`) and exported from Blender with **+Y up**, which is what the
# loader assumes. Its UVs are expected to span a 0..1 square; the loader maps that
# square onto the atlas cell for the id.

static var cache: Dictionary = {}

static func exists(id: int) -> bool:
	return ResourceLoader.exists("res://assets/models/%d.glb"%id)

# The remapped mesh for an id, or null when no override is present. Built once.
static func mesh(id: int) -> ArrayMesh:
	if cache.has(id): return cache[id]
	var result: ArrayMesh = null
	if exists(id):
		# A `.glb` imports as a `PackedScene`, so instantiate it and take the first
		# mesh the loader produced.
		var packed: PackedScene = load("res://assets/models/%d.glb"%id)
		if packed != null:
			var root: Node = packed.instantiate()
			var found: MeshInstance3D = _find_mesh(root)
			if found != null and found.mesh is ArrayMesh and found.mesh.get_surface_count() > 0:
				result = _remap_uv(found.mesh,_atlas_cell(id))
			root.free()
	cache[id] = result
	return result

static func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D and node.mesh != null: return node
	for child in node.get_children():
		var found: MeshInstance3D = _find_mesh(child)
		if found != null: return found
	return null

# An atlas cell is one 16th of the atlas: the atlas is 8 tiles wide and one tile
# tall, so a cell spans `(1/8, 1/height)` at `(col/8, row/height)`.
static func _atlas_cell(id: int) -> Rect2:
	var tile: int = Nodes.tile(id,0)
	var height: float = maxf(1024.0,ceilf((137+VillageContent.BLOCKS.size()+WoodTypes.TEXTURES.size())/8.0)*16.0)
	return Rect2(float(tile%8)/8.0,float(tile/8)/height,1.0/8.0,1.0/height)

# Copy every surface, rewriting its UVs into the atlas rectangle.
static func _remap_uv(source: ArrayMesh, cell: Rect2) -> ArrayMesh:
	var out := ArrayMesh.new()
	for surface in source.get_surface_count():
		var arrays: Array = source.surface_get_arrays(surface)
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		for i in uvs.size():
			uvs[i] = cell.position+Vector2(uvs[i].x*cell.size.x,uvs[i].y*cell.size.y)
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return out
