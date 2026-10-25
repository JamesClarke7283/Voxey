class_name Shields
extends RefCounted

# Mineclonia ITEMS/mcl_shields/init.lua, GPL-3.0-or-later. Original GDScript
# using the source as a behaviour reference.
#
# The installed source evaluates -math.cos(180/2) directly in radians. Its
# measured threshold is 0.4480736161291701, despite the 180-degree comment.
# Keep the executable rule; see the real-engine shield combat reference.
#
# Three further source rules are reproduced:
#
#   * Only listed attack types are blockable: mob, player, arrow, generic,
#     explosion, dragon breath and trident. Everything else passes through.
#   * Wear is added only for hits of 3 or more damage, and is equal to the
#     ceiling of the damage.
#   * A shield that is disabled (by an axe) blocks nothing until it recovers.
#
# Voxey's earlier implementation raised the shield for one second on use. That is
# not the source's behaviour: the source holds it up for as long as the player
# keeps it raised.

const BLOCK_ARC = 180.0
const BLOCK_COSINE = 0.4480736161291701
# The source's `types` table: only these damage reasons may be blocked.
const BLOCKABLE = ["mob","player","arrow","generic","explosion","dragon_breath","trident"]
# `add_wear` ignores hits below this threshold.
const WEAR_THRESHOLD = 3.0
# Source `_mcl_uses`.
const USES = 336
# `mcl_shields.shield_disable_duration = 5`: an axe hit disables a raised shield.
const DISABLE_SECONDS = 5.0

static func is_shield(id: int) -> bool: return id == VillageContent.SHIELD

static func color(item: Dictionary) -> int:
	var value: Variant = item.get("data",{}).get("shield_color",-1)
	return int(value) if (value is int or value is float) and is_finite(float(value)) and int(value) in range(16) else -1

static func plain(item: Dictionary) -> bool:
	return is_shield(int(item.get("id",0))) and color(item) < 0

# The source only decorates an uncoloured shield. Both inputs are consumed;
# damage, shield enchantments and the preferred name survive on the result.
static func decorate(ingredients: Array) -> Dictionary:
	var shield: Dictionary = {}; var banner: Dictionary = {}
	for item in ingredients:
		if int(item.get("id",0)) == 0 or int(item.get("count",0)) <= 0: continue
		if plain(item) and shield.is_empty(): shield = item
		elif Banners.is_banner(int(item.id)) and banner.is_empty(): banner = item
		else: return {}
	if shield.is_empty() or banner.is_empty() or Banners.layers(banner).size() > Banners.MAX_LAYERS: return {}
	var metadata: Dictionary = {"shield_color":Banners.color_index(int(banner.id))}
	var layers: Array = Banners.layers(banner)
	if not layers.is_empty(): metadata.layers = layers.duplicate(true)
	var title: String = str(shield.get("data",{}).get("custom_name",""))
	if title.is_empty(): title = str(banner.get("data",{}).get("custom_name",""))
	if not title.is_empty(): metadata.custom_name = title
	var enchantments: Dictionary = shield.get("data",{}).get("enchantments",{})
	if not enchantments.is_empty(): metadata.enchantments = enchantments.duplicate(true)
	# These two keys preserve the source's exact normalized wear in the native
	# durability representation. Prior work and unrelated metadata are not copied.
	for key in ["wear_normalized","wear_display"]:
		if shield.get("data",{}).has(key): metadata[key] = shield.data[key]
	return {"id":VillageContent.SHIELD,"count":1,"wear":int(shield.get("wear",0)),"data":metadata}

static func special_recipe(ingredients: Array) -> Dictionary:
	var output: Dictionary = decorate(ingredients)
	if output.is_empty(): return {}
	var ids: Array = []; var needs: Dictionary = {}
	for item in ingredients:
		ids.append(int(item.id))
		if item.id: needs[item.id] = int(needs.get(item.id,0))+1
	return {"name":"Decorated shield","id":VillageContent.SHIELD,"count":1,"station":"hand","dynamic":true,"width":3,"pattern":ids,"ingredients":needs,"output_data":output.data,"output_wear":output.wear,"shield_decoration":true}

static func recipes(inv: Inventory) -> void:
	for i in 16:
		inv._shapeless(Banners.BANNER_NAMES[i]+" shield",VillageContent.SHIELD,1,[VillageContent.SHIELD,Banners.FIRST+i])
		inv.recipes.back()["shield_decoration"] = true

static func description(item: Dictionary) -> String:
	var index: int = color(item)
	var label: String = str(item.get("data",{}).get("custom_name",Banners.BANNER_NAMES[index]+" Shield" if index >= 0 else "Shield"))
	var lines: PackedStringArray = Banners.describe(item).split("\n")
	if lines.size() > 1: label += "\n"+"\n".join(lines.slice(1))
	return label

static var textures: Dictionary = {}

static func texture(item: Dictionary) -> Texture2D:
	var base: int = color(item)
	if base < 0: return ItemArt.texture(VillageContent.SHIELD)
	var key: String = str(base)+":"+JSON.stringify(Banners.layers(item))
	if not textures.has(key):
		if textures.size() > 256: textures.clear()
		var img: Image = ItemArt.texture(VillageContent.SHIELD).get_image().duplicate()
		img.resize(64,64,Image.INTERPOLATE_NEAREST)
		var cloth: Image = Banners.texture({"id":Banners.FIRST+base,"data":{"layers":Banners.layers(item)}}).get_image()
		# Keep all twelve source-pattern columns when fitting the cloth inside
		# the rim; an eight-pixel face erased details such as the Globe grid.
		for y in range(12,48):
			for x in range(16,48):
				if y > 32 and absf(x/4.0-7.5) > 12-y/4.0: continue
				img.set_pixel(x,y,cloth.get_pixel(2+mini(11,(x-16)*12/32),1+mini(13,(y-12)*14/36)))
		textures[key] = ImageTexture.create_from_image(img)
	return textures[key]

static func _surface(mesh: ArrayMesh, vertices: PackedVector3Array, normals: PackedVector3Array, uv: PackedVector2Array, indices: PackedInt32Array, material: Material) -> void:
	var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices; arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uv; arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh.surface_set_material(mesh.get_surface_count()-1,material)

# A solid native model: decoration is confined to its front, with a wooden
# back, metal edge and grip. The same object is used in hand, drops and frames.
static func model(item: Dictionary) -> MeshInstance3D:
	var outline: Array[Vector2] = [Vector2(2,1),Vector2(14,1),Vector2(14,10),Vector2(8,15),Vector2(2,10)]
	var mesh := ArrayMesh.new()
	for front in [true,false]:
		var vertices := PackedVector3Array(); var normals := PackedVector3Array(); var uv := PackedVector2Array(); var indices := PackedInt32Array()
		for point in outline:
			vertices.append(Vector3((point.x-8)/16,(8-point.y)/16,0.035 if front else -0.035))
			normals.append(Vector3.BACK if front else Vector3.FORWARD); uv.append(point/16)
		for i in range(1,4):
			indices.append_array(PackedInt32Array([0,i,i+1] if front else [0,i+1,i]))
		var material := StandardMaterial3D.new(); material.roughness = 0.9
		if front: material.albedo_texture = texture(item); material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		else: material.albedo_color = Color("84633d")
		_surface(mesh,vertices,normals,uv,indices,material)
	var sides := PackedVector3Array(); var side_normals := PackedVector3Array(); var side_uv := PackedVector2Array(); var side_indices := PackedInt32Array()
	for i in outline.size():
		var a: Vector2 = (outline[i]-Vector2(8,8))*Vector2(1,-1)/16
		var b: Vector2 = (outline[(i+1)%outline.size()]-Vector2(8,8))*Vector2(1,-1)/16
		var normal: Vector3 = Vector3(a.y-b.y,b.x-a.x,0).normalized()
		var offset: int = sides.size()
		for vertex in [Vector3(a.x,a.y,0.035),Vector3(b.x,b.y,0.035),Vector3(b.x,b.y,-0.035),Vector3(a.x,a.y,-0.035)]:
			sides.append(vertex); side_normals.append(normal); side_uv.append(Vector2.ZERO)
		side_indices.append_array(PackedInt32Array([offset,offset+1,offset+2,offset,offset+2,offset+3]))
	var edge := StandardMaterial3D.new(); edge.albedo_color = Color("a7ada2"); edge.metallic = 0.35; edge.cull_mode = BaseMaterial3D.CULL_DISABLED
	_surface(mesh,sides,side_normals,side_uv,side_indices,edge)
	var root := MeshInstance3D.new(); root.mesh = mesh
	for at in [Vector3(0,-0.13,-0.095),Vector3(0,0.13,-0.095),Vector3(0,0,-0.145)]:
		var grip := MeshInstance3D.new(); var box := BoxMesh.new()
		box.size = Vector3(0.055,0.055,0.15) if at.y != 0 else Vector3(0.055,0.3,0.045)
		grip.mesh = box; grip.material_override = edge; grip.position = at; root.add_child(grip)
	return root

# `mcl_shields.disable_player_shield`: an axe that lands on a raised shield disables
# it for five seconds and plays the tool-break sound. The source disables the shield
# on the *blocked* hit, so the block still happens and the shield then goes down.
static func disable(survival) -> void:
	survival.shield_disabled = DISABLE_SECONDS
	survival.game.sound("break")

# `find_angle`: the dot product of the attack direction and the player's look,
# measured from the shield centre rather than the feet.
static func angle(player: VoxeyPlayer, attack_pos: Vector3) -> float:
	if is_inf(attack_pos.x): return 1.0
	var centre: Vector3 = player.position+Vector3.UP*1.62*2.0/3.0
	var attack_direction: Vector3 = (centre-attack_pos).normalized()
	var look: Vector3 = -player.camera.global_basis.z
	return attack_direction.dot(look.normalized())

# `can_block`: the source's decision, returning a reason when it refuses.
static func can_block(player: VoxeyPlayer, attack_pos: Vector3, kind: String) -> bool:
	if not raised(player): return false
	return accepts_dot(angle(player,attack_pos),kind)

static func accepts_dot(value: float, kind: String) -> bool:
	return BLOCKABLE.has(str(DeathMessages.ALIASES.get(kind,kind))) and is_finite(value) and value <= BLOCK_COSINE

# The shield is raised while the player holds it and is not attacking, which is
# the source's own held state rather than a one-second window.
static func raised(player: VoxeyPlayer) -> bool:
	var survival = player.game.survival
	if survival.shield_disabled > 0.0: return false
	if not survival.shield_raised: return false
	# A shield must actually be carried, which the source's `is_blocking` checks.
	# The source checks the main hand, then the offhand. Voxey previously borrowed
	# the head armor slot as a stand-in; the player now has a real second hand.
	return is_shield(player.game.inventory.held().id) or is_shield(player.offhand_id())

# `add_wear`: pass the damage ceiling through the source durability routine;
# Unbreaking and the normalized-wear remainder apply. Smaller hits are free.
static func add_wear(player: VoxeyPlayer, damage: float) -> void:
	if not raised(player): return
	# The source wears the raised shield, wherever the player is carrying it.
	var slot: Dictionary = player.carried_slot(VillageContent.SHIELD)
	if slot.is_empty(): return
	if not wear_item(slot,damage,player.game.gamemode == "creative"): return
	player.game.inventory.changed.emit()
	if slot.id == 0:
		player.game.toast("Your shield broke.")
		player.game.sound("break")

static func wear_item(slot: Dictionary, damage: float, creative: bool = false) -> bool:
	if creative or not is_shield(int(slot.get("id",0))) or not is_finite(damage) or damage < WEAR_THRESHOLD: return false
	Durability.use(slot,ceilf(damage))
	return true
