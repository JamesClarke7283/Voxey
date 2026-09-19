class_name PumpkinHelmet
extends RefCounted

static var mask: Texture2D

static func worn(player: VoxeyPlayer) -> bool:
	return int(player.armor_slots[0].get("id",0)) == FruitCrops.CARVED and int(player.armor_slots[0].get("count",0)) > 0

static func texture() -> Texture2D:
	if mask == null:
		var img := Image.create(64,64,false,Image.FORMAT_RGBA8)
		img.fill(Color(0.12,0.055,0.02,0.97))
		ItemArt._polygon(img,[[8,15],[25,22],[25,31],[9,29]],Color.TRANSPARENT)
		ItemArt._polygon(img,[[55,15],[38,22],[38,31],[54,29]],Color.TRANSPARENT)
		ItemArt._polygon(img,[[11,39],[20,42],[25,38],[29,43],[35,43],[39,38],[44,42],[53,39],[49,53],[15,53]],Color.TRANSPARENT)
		mask = ImageTexture.create_from_image(img)
	return mask

static func draw(control: Control) -> void:
	control.draw_texture_rect(texture(),Rect2(Vector2.ZERO,control.size),false)

static func icon_face(control: Control, center: Vector2, scale_value: float, id: int) -> void:
	var color := Color("ffdf83") if FruitCrops.lit(id) else Color("352112")
	for rect in [Rect2(0.18,0.25,0.2,0.17),Rect2(0.62,0.25,0.2,0.17),Rect2(0.2,0.66,0.6,0.15)]:
		var points := PackedVector2Array()
		for uv in [rect.position,rect.position+Vector2(rect.size.x,0),rect.end,rect.position+Vector2(0,rect.size.y)]:
			points.append(center+(Vector2(0,1)+Vector2(9,-5)*uv.x+Vector2(0,10)*uv.y)*scale_value)
		control.draw_colored_polygon(points,color)
