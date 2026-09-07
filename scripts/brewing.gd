class_name Brewing
extends RefCounted

# Mineclonia brews up to three bottles per ingredient in ten seconds.
const BREW_SECONDS: float = 10.0
const FUEL_BATCHES: int = 20

static func accepts(index: int, id: int) -> bool:
	if id == 0: return true
	if index == 1: return id == Nodes.BLAZE_POWDER
	if index >= 2: return PotionCatalog.is_bottle(id)
	for bottle in PotionCatalog.ITEMS:
		if PotionCatalog.brew(bottle,id) != 0: return true
	return false

static func step(station: Dictionary, delta: float) -> bool:
	if station.get("slots",[]).size() != 5: return false
	var ingredient: Dictionary = station.slots[0]; var fuel: Dictionary = station.slots[1]
	var outputs: Array = []; var signature: String = str(int(ingredient.id))
	var active: bool = false
	for i in range(2,5):
		var slot: Dictionary = station.slots[i]
		var result: int = PotionCatalog.brew(slot.id,ingredient.id) if ingredient.count > 0 and slot.count == 1 else 0
		outputs.append(result); active = active or result != 0
		signature += ":"+str(int(slot.id))
	if not active:
		station.progress = 0.0; station.erase("brew_signature"); return false
	if signature != station.get("brew_signature",""):
		station.progress = 0.0; station.brew_signature = signature
	if int(station.get("fuel_batches",0)) <= 0:
		if fuel.id != Nodes.BLAZE_POWDER or fuel.count <= 0: return false
		consume(fuel); station.fuel_batches = FUEL_BATCHES
	station.progress = float(station.get("progress",0))+delta
	if station.progress < BREW_SECONDS: return false
	for i in 3:
		if outputs[i] != 0: station.slots[i+2] = {"id":outputs[i],"count":1,"wear":0}
	consume(ingredient); station.fuel_batches -= 1; station.progress = 0.0; station.erase("brew_signature")
	return true

static func consume(slot: Dictionary) -> void:
	slot.count = maxi(0,int(slot.count)-1)
	if slot.count == 0: slot.id = 0; slot.wear = 0; slot.erase("data")
