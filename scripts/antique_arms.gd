class_name AntiqueArms
extends RefCounted

# Original Voxey equipment. Reload progress belongs to the weapon stack, so
# switching hotbar slots or saving cannot skip a reload.
const MUSKET = 12100
const PISTOL = 12101
const BLUNDERBUSS = 12102
const BAYONET = 12103
const SHOT = 12104
const DATA = {
	12100:{"name":"Musket","color":"b8aaa0","stack":1,"durability":320},
	12101:{"name":"Flintlock pistol","color":"c5b28a","stack":1,"durability":240},
	12102:{"name":"Blunderbuss","color":"c59453","stack":1,"durability":200},
	12103:{"name":"Bayonet","color":"c8d5d6","stack":1,"durability":400,"tool_kind":3,"tier":2},
	12104:{"name":"Musket shot","color":"858e93","stack":64},
}
const STATS = {
	MUSKET:{"damage":16.0,"reload":3.0,"speed":70.0,"spread":0.008,"pellets":1},
	PISTOL:{"damage":10.0,"reload":1.8,"speed":55.0,"spread":0.02,"pellets":1},
	BLUNDERBUSS:{"damage":3.0,"reload":3.8,"speed":44.0,"spread":0.15,"pellets":7},
}

static func is_gun(id: int) -> bool: return STATS.has(id)

static func recipes(inv: Inventory) -> void:
	inv._recipe("Musket",MUSKET,1,[0,0,Nodes.IRON,0,Nodes.IRON,Nodes.FLINT,Nodes.PLANKS,Nodes.STICK,0],3,"table")
	inv._recipe("Flintlock pistol",PISTOL,1,[Nodes.IRON,Nodes.IRON,Nodes.FLINT,Nodes.PLANKS,0,0],3,"table")
	inv._recipe("Blunderbuss",BLUNDERBUSS,1,[0,Nodes.IRON,Nodes.COPPER,0,Nodes.IRON,Nodes.FLINT,Nodes.PLANKS,Nodes.STICK,0],3,"table")
	inv._recipe("Bayonet",BAYONET,1,[Nodes.IRON,0,Nodes.IRON,0,Nodes.STICK,0],2,"table")
	inv._recipe("Musket shot",SHOT,8,[Nodes.IRON_NUGGET,Nodes.IRON_NUGGET,Nodes.IRON_NUGGET,Nodes.IRON_NUGGET],2)

static func tick_stack(slot: Dictionary, dt: float) -> void:
	if not is_gun(int(slot.get("id",0))): return
	var data: Dictionary = slot.get("data",{})
	if data.has("reload_remaining"):
		data.reload_remaining = maxf(0.0,float(data.reload_remaining)-dt)
		if data.reload_remaining <= 0: data.erase("reload_remaining")

static func update(game: Node3D, dt: float) -> void:
	for slot in game.inventory.slots: tick_stack(slot,dt)
	tick_stack(game.hud.cursor,dt)

static func fire(game: Node3D) -> bool:
	var slot: Dictionary = game.inventory.held()
	var id: int = slot.id
	if not is_gun(id): return false
	var data: Dictionary = slot.get("data",{})
	if float(data.get("reload_remaining",0)) > 0:
		game.toast("Reloading %s · %.1fs"%[Nodes.title(id),float(data.reload_remaining)])
		return true
	var stats: Dictionary = STATS[id]
	if game.gamemode != "creative":
		if game.inventory.count_item(SHOT) < 1 or game.inventory.count_item(Nodes.GUNPOWDER) < 1:
			game.toast("Each shot needs one musket shot and one gunpowder.")
			return true
		game.inventory.remove_item(SHOT,1)
		game.inventory.remove_item(Nodes.GUNPOWDER,1)
	var camera: Camera3D = game.player.camera
	var origin: Vector3 = camera.global_position-camera.global_basis.z*0.35
	for i in int(stats.pellets):
		var aim: Vector3 = (-camera.global_basis.z+camera.global_basis.x*randf_range(-stats.spread,stats.spread)+camera.global_basis.y*randf_range(-stats.spread,stats.spread)).normalized()
		var bullet := Arrow.new()
		bullet.game = game; bullet.position = origin; bullet.launch_point = origin
		bullet.velocity = aim*stats.speed
		bullet.item_id = SHOT; bullet.damage = stats.damage
		bullet.from_player = true; bullet.recoverable = false
		game.entities.add_child(bullet)
	data["reload_remaining"] = stats.reload
	slot["data"] = data
	if game.gamemode != "creative": game.inventory.damage_tool()
	game.player.swing = 1
	game.sound_at("musket",origin)
	game.puff(origin-camera.global_basis.z*0.35,Color("e5d7b4"),8)
	return true

static func draw(img: Image, id: int) -> void:
	if id == SHOT:
		for y in range(4,12):
			for x in range(4,12):
				if Vector2(x-7.5,y-7.5).length() < 4: img.set_pixel(x,y,Color("bac6cb") if x+y < 14 else Color("65717c"))
		return
	if id == BAYONET:
		ItemArt._line(img,Vector2(3,14),Vector2(7,10),Color("68472e"),3)
		ItemArt._line(img,Vector2(5,8),Vector2(9,12),Color("c59453"),2)
		ItemArt._polygon(img,[[7,9],[13,1],[15,1],[14,4],[9,11]],Color("cad9df"))
		return
	var end := Vector2(12,4) if id == PISTOL else Vector2(14,2)
	ItemArt._line(img,Vector2(2,13),Vector2(8,8),Color("855731"),4)
	ItemArt._line(img,Vector2(5,10),end,Color("404a50"),3)
	ItemArt._line(img,Vector2(5,9),end-Vector2(0,1),Color("c1cbd0"))
	ItemArt._line(img,Vector2(6,11),Vector2(8,12),Color("d0a958"),2)
	img.fill_rect(Rect2i(7,6,2,3),Color("d0a958"))
	if id == BLUNDERBUSS: ItemArt._line(img,Vector2(11,1),Vector2(15,5),Color("c59453"),3)
