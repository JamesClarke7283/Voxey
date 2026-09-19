class_name NameTags
extends RefCounted

const ITEM = 1200

# Mineclonia limits anvil names to 50 bytes and creature tags to 30 bytes.
# Keep whole Unicode characters when applying those limits.
static func bounded(value: String, limit: int) -> String:
	var result: String = value.replace("\n"," ").replace("\r"," ")
	while result.to_utf8_buffer().size() > limit: result = result.left(result.length()-1)
	return result

static func rename(game: Node, index: int, value: String) -> bool:
	if index < 0 or index >= game.inventory.slots.size(): return false
	var slot: Dictionary = game.inventory.slots[index]
	if slot.id == 0 or slot.count <= 0: return false
	# mcl_books marks signed books no_rename; their authored title is fixed.
	if slot.id == Nodes.WRITTEN_BOOK: game.toast("A signed book keeps its original title."); return false
	var text: String = bounded(value,50)
	var data: Dictionary = slot.get("data",{}).duplicate(true)
	if str(data.get("custom_name","")) == text: return false
	var level: int = game.xp_level()
	if game.gamemode != "creative" and level < 1:
		game.toast("Renaming costs one XP level."); return false
	if text.is_empty(): data.erase("custom_name")
	else: data.custom_name = text
	if data.is_empty(): slot.erase("data")
	else: slot.data = data
	# `mcl_anvils`: a rename costs exactly one level, and it does not add to the
	# prior-work penalty (only a material repair does, at init.lua:229).
	if game.gamemode != "creative": game.experience = maxf(0,game.experience-(7+2*(level-1)))
	game.inventory.changed.emit()
	game.sound("equip")
	game.toast("Item name removed." if text.is_empty() else "Named "+text+".")
	return true

static func editor(game: Node, parent: Control) -> void:
	var title := Label.new(); title.text = "Rename an item · 1 XP level"; parent.add_child(title)
	var choices := OptionButton.new(); choices.name = "RenameItem"; choices.custom_minimum_size = Vector2(650,38); parent.add_child(choices)
	for i in game.inventory.slots.size():
		var slot: Dictionary = game.inventory.slots[i]
		if slot.id == 0 or slot.count <= 0 or slot.id == Nodes.WRITTEN_BOOK: continue
		choices.add_item("%s × %d"%[str(slot.get("data",{}).get("custom_name",Nodes.title(slot.id))),slot.count],i)
		if i == game.inventory.selected: choices.select(choices.item_count-1)
	var field := LineEdit.new(); field.name = "ItemName"; field.placeholder_text = "Name (leave blank to remove)"; field.max_length = 50; field.custom_minimum_size = Vector2(650,40); parent.add_child(field)
	var refresh: Callable = func():
		if choices.item_count > 0: field.text = str(game.inventory.slots[choices.get_selected_id()].get("data",{}).get("custom_name",""))
	choices.item_selected.connect(func(_index: int): refresh.call())
	refresh.call()
	var button := Button.new(); button.name = "SetItemName"; button.text = "Set name"; button.custom_minimum_size = Vector2(650,40); button.disabled = choices.item_count == 0; parent.add_child(button)
	var submit: Callable = func():
		if choices.item_count == 0: return
		if rename(game,choices.get_selected_id(),field.text):
			var slot: Dictionary = game.inventory.slots[choices.get_selected_id()]
			choices.set_item_text(choices.selected,"%s × %d"%[str(slot.get("data",{}).get("custom_name",Nodes.title(slot.id))),slot.count])
			refresh.call()
	button.pressed.connect(submit)
	field.text_submitted.connect(func(_text: String): submit.call())

static func use(game: Node, mob: Creature) -> bool:
	if game.inventory.held().id != ITEM or mob == null: return false
	if mob.kind in ["ender_dragon","end_crystal"] or mob.health <= 0 or mob.is_queued_for_deletion(): return true
	var value: String = bounded(str(game.inventory.held().get("data",{}).get("custom_name","")),30)
	if value.is_empty(): game.toast("Set a name on this tag at an anvil first."); return true
	mob.custom_name = value
	refresh(mob)
	Farming.remember(mob)
	if mob is NetherResident: mob.ensure_record()
	if mob is VillageMob or mob is NetherResident or mob is SnowGolem: mob.store_record()
	if game.gamemode != "creative": game.inventory.consume_selected()
	game.toast("Named "+value+".")
	return true

static func refresh(mob: Creature) -> void:
	var label: Label3D = mob.get_node_or_null("NameTag")
	if mob.custom_name.is_empty():
		if label != null: label.queue_free()
		return
	if label == null:
		label = Label3D.new(); label.name = "NameTag"; label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.pixel_size = 0.007; label.font_size = 28; label.outline_size = 6
		label.visibility_range_end = 32; mob.add_child(label)
	label.text = mob.custom_name; label.position = Vector3(0,mob.height+0.3,0)
