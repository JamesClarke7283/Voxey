class_name VillageItemArt
extends RefCounted

static func draw(img: Image, id: int, base: Color) -> void:
	var d: Dictionary = VillageContent.DATA.get(id,{})
	var family: String = d.get("family","")
	if family == "pouch":
		var level: int = Pouches.level_of(id)
		var left: int = 5-level
		var right: int = 10+level
		var top: int = 7-level
		ItemArt._polygon(img,[[left+2,top],[right-2,top],[right,top+4],[right,14],[left,14],[left,top+4]],base.darkened(0.25))
		img.fill_rect(Rect2i(left+1,top+3,right-left-1,10-top),base)
		img.fill_rect(Rect2i(left+2,top,right-left-3,3),base.lightened(0.18))
		ItemArt._line(img,Vector2(left+1,top+3),Vector2(right-1,top+3),Color("c5a475"))
		ItemArt._line(img,Vector2(8,top+3),Vector2(8,top+5),Color("e6c993"))
		if level >= 2: img.fill_rect(Rect2i(5,10,6,3),base.darkened(0.18))
		if level >= 3:
			img.fill_rect(Rect2i(left,8,2,5),base.lightened(0.15))
			img.fill_rect(Rect2i(right-1,8,2,5),base.darkened(0.12))
		if level >= 4:
			ItemArt._line(img,Vector2(4,top+1),Vector2(4,13),Color("8c6847"))
			ItemArt._line(img,Vector2(11,top+1),Vector2(11,13),Color("8c6847"))
		for pip in level: img.set_pixel(8-level+pip*2,12,Color("e5cc91"))
	elif id == VillageContent.TRIDENT:
		ItemArt._line(img,Vector2(2,14),Vector2(10,6),Color("7e9c94"),2)
		ItemArt._line(img,Vector2(6,4),Vector2(12,10),base,2)
		for offset in [-3,0,3]: ItemArt._line(img,Vector2(9+offset,7+offset),Vector2(13+offset,3+offset),base,2)
	elif id == VillageContent.MACE:
		ItemArt._line(img,Vector2(3,14),Vector2(9,7),Color("85a5af"),3)
		ItemArt._polygon(img,[[6,2],[12,1],[15,5],[13,10],[8,10],[5,6]],base)
		ItemArt._line(img,Vector2(7,4),Vector2(12,3),base.lightened(0.3),2)
	elif id == VillageContent.HEAVY_CORE:
		ItemArt._polygon(img,[[2,4],[8,1],[14,4],[14,12],[8,15],[2,12]],base)
		ItemArt._line(img,Vector2(3,5),Vector2(8,8),base.lightened(0.3),2)
		ItemArt._line(img,Vector2(8,8),Vector2(13,5),base.darkened(0.3),2)
	elif id == VillageContent.PHANTOM_MEMBRANE:
		ItemArt._polygon(img,[[1,4],[5,5],[9,1],[12,3],[15,9],[11,10],[7,15],[5,11],[1,10]],base)
		ItemArt._line(img,Vector2(4,6),Vector2(10,9),base.darkened(0.25))
	elif id == VillageContent.TURTLE_SCUTE:
		ItemArt._polygon(img,[[4,2],[10,2],[14,7],[11,12],[5,14],[1,9]],base)
		ItemArt._polygon(img,[[5,4],[9,4],[11,8],[8,11],[4,9]],base.lightened(0.25))
	elif id == VillageContent.LEAD:
		for segment in [[Vector2(4,11),Vector2(2,7)],[Vector2(2,7),Vector2(4,3)],[Vector2(4,3),Vector2(9,3)],[Vector2(9,3),Vector2(11,7)],[Vector2(11,7),Vector2(8,11)],[Vector2(8,11),Vector2(4,11)],[Vector2(8,11),Vector2(13,14)]]: ItemArt._line(img,segment[0],segment[1],base,2)
	elif id == VillageContent.EMERALD:
		ItemArt._polygon(img,[[5,1],[11,1],[14,5],[13,11],[10,15],[5,14],[2,10],[2,5]],base)
		ItemArt._polygon(img,[[5,3],[10,3],[11,6],[10,11],[6,12],[4,9]],base.lightened(0.3))
		ItemArt._line(img,Vector2(5,4),Vector2(5,9),Color("ccffe1"))
	elif id in [VillageContent.CARROT,VillageContent.GOLDEN_CARROT]:
		ItemArt._polygon(img,[[4,14],[6,5],[9,3],[13,6],[10,10]],base)
		ItemArt._line(img,Vector2(10,5),Vector2(10,0),Color("69974b"),2); ItemArt._line(img,Vector2(11,4),Vector2(15,2),Color("73a155"),2)
	elif id in [VillageContent.RAW_COD,VillageContent.COOKED_COD,VillageContent.RAW_SALMON,VillageContent.COOKED_SALMON,VillageContent.TROPICAL_FISH,VillageContent.PUFFERFISH]:
		ItemArt._polygon(img,[[1,3],[5,6],[9,3],[13,4],[15,8],[12,11],[6,11],[2,14],[3,8]],base)
		img.fill_rect(Rect2i(11,6,2,2),Color("2e3632")); ItemArt._line(img,Vector2(6,8),Vector2(10,8),base.lightened(0.3))
	elif id == VillageContent.FISHING_ROD:
		ItemArt._line(img,Vector2(2,14),Vector2(11,2),Color("a47b4e"),2)
		ItemArt._line(img,Vector2(11,2),Vector2(14,5),Color("dedaca")); ItemArt._line(img,Vector2(14,5),Vector2(14,11),Color("dedaca")); img.fill_rect(Rect2i(12,11,3,2),Color("e97561"))
	elif id == VillageContent.CROSSBOW:
		ItemArt._line(img,Vector2(4,14),Vector2(11,3),Color("967047"),3)
		ItemArt._line(img,Vector2(2,3),Vector2(12,12),Color("ba9a61"),3)
		ItemArt._line(img,Vector2(2,4),Vector2(6,11),Color("dedaca")); ItemArt._line(img,Vector2(6,11),Vector2(12,12),Color("dedaca"))
	elif family == "arrow":
		ItemArt._line(img,Vector2(2,14),Vector2(12,3),Color("b09262"),2)
		ItemArt._polygon(img,[[10,2],[15,1],[14,6]],base); ItemArt._polygon(img,[[1,10],[5,11],[5,15],[1,14]],Color("e6dec4"))
	elif id in [VillageContent.ENCHANTED_BOOK,VillageContent.EMPTY_MAP,VillageContent.FILLED_MAP,VillageContent.GLOBE_PATTERN]:
		ItemArt._polygon(img,[[2,3],[10,1],[14,4],[14,13],[6,15],[2,12]],base)
		img.fill_rect(Rect2i(5,5,6,7),Color("e9dbb4")); ItemArt._line(img,Vector2(6,7),Vector2(10,7),Color("6f8272"))
		if id == VillageContent.ENCHANTED_BOOK: ItemArt._polygon(img,[[10,0],[11,3],[14,4],[11,5],[10,8],[9,5],[6,4],[9,3]],Color("e3a4f0"))
	elif id in [VillageContent.GLASS_BOTTLE,VillageContent.WATER_BOTTLE,VillageContent.XP_BOTTLE,VillageContent.DRAGON_BREATH] or family == "potion":
		ItemArt._polygon(img,[[6,1],[10,1],[10,5],[13,8],[13,13],[11,15],[4,15],[2,12],[3,8],[6,5]],Color("bed3cd"))
		ItemArt._polygon(img,[[5,8],[11,8],[12,12],[10,14],[5,14],[3,12]],base)
		img.fill_rect(Rect2i(6,1,4,2),Color("ac8a5b"))
		if PotionCatalog.ITEMS.get(id,{}).get("form","") == "splash": ItemArt._line(img,Vector2(9,2),Vector2(13,4),Color("535b57"),2)
		if PotionCatalog.ITEMS.get(id,{}).get("form","") == "lingering": img.fill_rect(Rect2i(3,2,3,2),base); img.fill_rect(Rect2i(12,0,2,2),base.lightened(0.3))
	elif id == VillageContent.SHIELD:
		ItemArt._polygon(img,[[2,1],[14,1],[14,10],[8,15],[2,10]],Color("a3a79b"))
		ItemArt._polygon(img,[[4,3],[12,3],[12,9],[8,12],[4,9]],base)
		ItemArt._line(img,Vector2(8,3),Vector2(8,12),base.darkened(0.3))
	elif family == "boat":
		ItemArt._polygon(img,[[1,6],[7,3],[15,6],[13,12],[7,15],[2,11]],base)
		ItemArt._polygon(img,[[3,7],[7,5],[13,7],[11,10],[7,12],[4,10]],base.darkened(0.4))
		ItemArt._line(img,Vector2(1,4),Vector2(11,13),Color("c4a274"),2)
	elif "stew" in d.get("name","").to_lower() or id == VillageContent.BEETROOT_SOUP:
		ItemArt._polygon(img,[[1,6],[4,4],[12,4],[15,6],[13,12],[10,14],[5,14],[2,11]],Color("956540"))
		ItemArt._polygon(img,[[3,6],[5,5],[11,5],[13,6],[11,9],[5,9]],base)
	elif id == VillageContent.COOKIE:
		ItemArt._polygon(img,[[5,2],[11,2],[14,5],[14,11],[11,14],[4,13],[1,9],[2,4]],base)
		for pos in [Vector2i(5,4),Vector2i(10,6),Vector2i(5,9),Vector2i(9,11)]: img.fill_rect(Rect2i(pos,Vector2i(2,2)),Color("5b3c2e"))
	elif id == VillageContent.CAKE:
		ItemArt._polygon(img,[[1,6],[7,3],[15,6],[14,12],[8,15],[1,11]],Color("bd9963"))
		ItemArt._polygon(img,[[1,6],[7,3],[15,6],[8,10]],Color("f2e8d3")); img.fill_rect(Rect2i(7,4,2,2),Color("bc514b"))
	elif family == "dye":
		ItemArt._polygon(img,[[2,10],[6,4],[10,3],[14,8],[12,13],[6,14]],base)
		ItemArt._line(img,Vector2(5,8),Vector2(10,6),base.lightened(0.3),2)
	else:
		ItemArt._polygon(img,[[5,3],[11,2],[14,6],[12,12],[7,14],[2,10],[2,6]],base)
		ItemArt._line(img,Vector2(4,6),Vector2(9,4),base.lightened(0.25),2)
