class_name RecipeButton
extends Button

var item_id: int

func _make_custom_tooltip(for_text: String) -> Object:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	var icon := ItemIcon.new()
	icon.custom_minimum_size = Vector2(80,80)
	icon.item_id = item_id
	icon.show_slot = false
	row.add_child(icon)
	var label := Label.new()
	label.text = for_text
	label.add_theme_color_override("font_color",Color("eeeeee"))
	row.add_child(label)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("292929"); style.border_color = Color("bbbbbb")
	style.set_border_width_all(1)
	style.content_margin_left = 10; style.content_margin_right = 12
	style.content_margin_top = 6; style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel",style)
	panel.add_child(row)
	return panel
