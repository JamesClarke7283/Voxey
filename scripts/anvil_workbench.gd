class_name AnvilWorkbench
extends RefCounted

const NO_INPUT = 2147483647

static func selected_input(picker: OptionButton) -> int:
	var index: int = picker.get_selected_id()
	return -1 if index == NO_INPUT else index

static func input(game: Node3D, index: int) -> Dictionary:
	return game.inventory.slots[index].duplicate(true) if index >= 0 and index < game.inventory.slots.size() else {}

static func token(a: Dictionary, b: Dictionary, name_value: String, preview: Dictionary) -> String:
	return JSON.stringify([a,b,name_value,preview]).sha256_text()

static func use(game: Node3D, p: Vector3i, first: int, second: int, name_value: Variant = null, expected: String = "") -> bool:
	if game.world.node_at(p) not in [VillageContent.ANVIL,11446,11447] or first == second: return false
	if first < -1 or second < -1 or first >= game.inventory.slots.size() or second >= game.inventory.slots.size(): return false
	var a: Dictionary = input(game,first); var b: Dictionary = input(game,second)
	var preview: Dictionary = Anvils.plan(a,b,name_value)
	if preview.is_empty(): game.toast("These inputs have no anvil result."); return false
	if not expected.is_empty() and token(a,b,str(name_value),preview) != expected:
		game.toast("The anvil inputs changed. Check the preview again."); return false
	var cost: int = int(preview.cost)
	if game.gamemode != "creative" and game.xp_level() < cost:
		game.toast("This operation needs %d XP levels."%cost); return false
	var staged := Inventory.new(); staged.slots = game.inventory.slots.duplicate(true)
	for i in 2:
		var index: int = first if i == 0 else second
		if index < 0 or int(preview.consume[i]) == 0: continue
		var slot: Dictionary = staged.slots[index]
		if slot.count < int(preview.consume[i]): return false
		slot.count -= int(preview.consume[i])
		if slot.count <= 0: slot.clear(); slot.merge({"id":0,"count":0,"wear":0})
	var output: Dictionary = preview.output
	var placed: bool = false
	for index in [first,second]:
		if index >= 0 and staged.slots[index].id == 0:
			staged.slots[index] = output.duplicate(true); placed = true; break
	if not placed and staged.add_item(output.id,output.count,output.get("wear",0),output.get("data",{})) > 0:
		game.toast("Make room for the anvil result first."); return false
	game.inventory.slots = staged.slots; game.inventory.sync_pouches()
	if game.gamemode != "creative": game.experience = ExperienceCurve.spend(game.experience,cost)
	game.inventory.changed.emit(); game.sound("craft")
	if game.gamemode != "creative": game.survival.damage_anvil(p)
	return true

static func show(game: Node3D, p: Vector3i, first: int = -2, second: int = -1) -> void:
	game.survival.workstation_pos = p; game.survival.workstation_id = VillageContent.ANVIL
	game.state = "workstation"; game.world.active = false; Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var hud: Control = game.hud
	hud._clear(); hud.screen = "workstation"; hud._dim()
	var panel: Panel = hud._fitted_panel(Vector2(760,590))
	hud._label(panel,"REPAIR & NAME",Vector2(28,20),26,hud.ACCENT)
	hud._label(panel,"Choose two inputs to combine or repair. Use one input to rename a stack.",Vector2(28,62),15,hud.MUTED)
	if first == -2:
		first = game.inventory.selected if game.inventory.held().id != 0 else -1
		if first < 0:
			for index in game.inventory.slots.size():
				if game.inventory.slots[index].id != 0: first = index; break
	var selectors: Array = []; var selected: Array = [first,second]
	for i in 2:
		hud._label(panel,"Item" if i == 0 else "Combine with",Vector2(28+i*362,100),15,hud.MUTED)
		var picker := OptionButton.new(); picker.name = "RenameItem" if i == 0 else "AnvilSecondItem"
		picker.position = Vector2(28+i*362,125); picker.size = Vector2(342,42)
		picker.add_item("None",NO_INPUT)
		for index in game.inventory.slots.size():
			var slot: Dictionary = game.inventory.slots[index]
			if slot.id == 0: continue
			picker.add_item("%s × %d · slot %d"%[str(slot.get("data",{}).get("custom_name",Nodes.title(slot.id))),slot.count,index+1],index)
			if selected[i] == index: picker.select(picker.item_count-1)
		panel.add_child(picker); selectors.append(picker)
	var field := LineEdit.new(); field.name = "ItemName"; field.position = Vector2(28,197); field.size = Vector2(704,42)
	field.placeholder_text = "Name (leave blank to remove)"; field.max_length = 50; panel.add_child(field)
	var result_scroll := ScrollContainer.new(); result_scroll.position = Vector2(28,257); result_scroll.size = Vector2(704,160); panel.add_child(result_scroll)
	var result_label: Label = hud._label(result_scroll,"",Vector2.ZERO,17,hud.TEXT,680)
	result_label.custom_minimum_size.x = 680
	var cost_label: Label = hud._label(panel,"",Vector2(28,430),18,hud.ACCENT,704)
	var button := Button.new(); button.name = "SetItemName"; button.position = Vector2(28,470); button.size = Vector2(704,46)
	panel.add_child(button)
	var preview_state: Dictionary = {}
	var update: Callable = func():
		var a: int = selected_input(selectors[0]); var b: int = selected_input(selectors[1])
		var left: Dictionary = input(game,a); var right: Dictionary = input(game,b)
		var preview: Dictionary = Anvils.plan(left,right,field.text) if a != b else {}
		preview_state.clear(); preview_state.merge({"first":a,"second":b,"preview":preview,"name":field.text})
		if preview.is_empty():
			result_label.text = "No result. Choose compatible inputs or change the name."
			cost_label.text = "Current level: %d"%game.xp_level(); button.text = "No result"; button.disabled = true; return
		preview_state.token = token(left,right,field.text,preview)
		var result: Dictionary = preview.output
		result_label.text = "%s × %d"%[str(result.get("data",{}).get("custom_name",Nodes.title(result.id))),result.count]
		if Nodes.durability(result.id) > 0: result_label.text += " · %d / %d durability"%[Nodes.durability(result.id)-int(result.wear),Nodes.durability(result.id)]
		for name in result.get("data",{}).get("enchantments",{}): result_label.text += "\n%s %d"%[name,int(result.data.enchantments[name])]
		var cost: int = 0 if game.gamemode == "creative" else int(preview.cost)
		cost_label.text = "Cost: %d XP levels · Current level: %d"%[cost,game.xp_level()]
		cost_label.add_theme_color_override("font_color",Color("f09a86") if cost > game.xp_level() else hud.ACCENT)
		button.text = preview.operation+" · take result"; button.disabled = cost > game.xp_level()
		button.tooltip_text = "Uses %d from the first input and %d from the second."%[preview.consume[0],preview.consume[1]]
	var refresh_name: Callable = func():
		var target: int = selected_input(selectors[0])
		if target < 0: target = selected_input(selectors[1])
		field.text = str(input(game,target).get("data",{}).get("custom_name","")); update.call()
	for picker in selectors: picker.item_selected.connect(func(_index: int): refresh_name.call())
	field.text_changed.connect(func(_text: String): update.call())
	var submit: Callable = func():
		if preview_state.get("name","") != field.text: update.call()
		if button.disabled: return
		if use(game,p,preview_state.first,preview_state.second,field.text,preview_state.token):
			if game.world.node_at(p) in [VillageContent.ANVIL,11446,11447]: show(game,p,preview_state.first,preview_state.second)
			else: game.resume()
		else: update.call()
	button.pressed.connect(submit); field.text_submitted.connect(func(_text: String): submit.call())
	refresh_name.call()
	hud._button(panel,"Done",Rect2(28,534,704,36),game.resume)
