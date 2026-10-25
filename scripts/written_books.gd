class_name WrittenBooks
extends RefCounted

# Mineclonia mcl_books/init.lua and mcl_util/misc.lua. Native implementation of
# text limits, signing, descriptions and metadata-preserving book copies.
const MAX_TEXT = 12800
const MAX_TITLE = 64

static func _prefix(text: String, max_bytes: int, max_nonascii: int) -> Dictionary:
	var bytes: int = 0; var nonascii: int = 0; var count: int = 0
	for i in text.length():
		var code: int = text.unicode_at(i)
		var length: int = 1 if code <= 0x7f else 2 if code <= 0x7ff else 3 if code <= 0xffff else 4
		if max_bytes >= 0 and bytes+length > max_bytes: break
		if code > 0x7f:
			if nonascii >= max_nonascii: break
			nonascii += 1
		bytes += length; count += 1
	return {"text":text.left(count),"count":count,"nonascii":nonascii}

static func cap(text: String, limit: int) -> String:
	var maximum: int = limit/6
	var prefix: Dictionary = _prefix(text,limit,maximum)
	var estimate: int = int(prefix.count)+int(prefix.nonascii)*5
	if estimate > limit:
		maximum -= ceili(float(estimate-limit)/6)
		return _prefix(prefix.text,-1,maximum).text
	return prefix.text

static func normalize(raw: Dictionary) -> Dictionary:
	var result: Dictionary = raw.duplicate(true)
	# Recover copies produced by the old extra data wrapper before those items
	# are cleaned or saved again.
	for i in 8:
		if not result.get("data") is Dictionary: break
		var nested: Dictionary = result.data
		if not nested.has("text") and not nested.has("title") and not nested.has("generation"): break
		result.erase("data"); nested = nested.duplicate(true); nested.merge(result,true); result = nested
	return result

static func generation(raw: Dictionary) -> int:
	var value: Variant = raw.get("generation",0)
	if not value is int and not value is float or not is_finite(float(value)): return 0
	return clampi(int(value),-2147483648,2147483647)

static func copy_data(ingredients: Array) -> Dictionary:
	var original: Dictionary = {}
	for item in ingredients:
		if int(item.get("id",0)) == Nodes.WRITTEN_BOOK and int(item.get("count",0)) > 0: original = item
	if original.is_empty(): return {"error":"no original book"}
	var raw: Dictionary = normalize(original.get("data",{}))
	var old: int = generation(raw)
	if old >= 2: return {"error":"a copy of a copy cannot be copied"}
	var result: Dictionary = raw.duplicate(true)
	result.title = cap(str(raw.get("title","")),MAX_TITLE)
	result.text = cap(str(raw.get("text","")),MAX_TEXT)
	result.generation = maxi(1,old+1)
	return result

static func can_copy(item: Dictionary) -> bool:
	return int(item.get("id",0)) == Nodes.WRITTEN_BOOK and generation(normalize(item.get("data",{}))) < 2

static func draft(item: Dictionary, text: String) -> bool:
	if int(item.get("id",0)) != Nodes.WRITABLE_BOOK or int(item.get("count",0)) <= 0: return false
	if not item.get("data") is Dictionary: item["data"] = {}
	item.data.text = cap(text,MAX_TEXT)
	return true

static func sign(item: Dictionary, title: String, author: String, timestamp: int) -> bool:
	if int(item.get("id",0)) != Nodes.WRITABLE_BOOK or int(item.get("count",0)) <= 0: return false
	var text: String = str(item.get("data",{}).get("text",""))
	item.id = Nodes.WRITTEN_BOOK; item.count = 1; item.wear = 0
	item["data"] = {"title":cap("Nameless Book" if title.is_empty() else title,MAX_TITLE),"text":cap(text,MAX_TEXT),"author":author,"date":timestamp,"generation":0}
	return true

static func description(item: Dictionary) -> String:
	var raw: Dictionary = normalize(item.get("data",{}))
	if str(raw.get("author","")).is_empty(): return "Written Book"
	var title: String = str(raw.get("title","")); var value: int = generation(raw)
	var label: String = "Tattered Book"
	if value == 0: label = "“%s”" % title
	elif value == 1: label = "Copy of “%s”" % title
	elif value == 2: label = "Copy of Copy of “%s”" % title
	return label+"\nby "+str(raw.author)
