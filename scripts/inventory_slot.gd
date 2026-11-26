extends Button

var owner_ui: Control
var area := "inventory"
var index := 0
var stack: Dictionary = {}

func _get_drag_data(_at: Vector2) -> Variant:
	if stack.is_empty(): return null
	var preview := Label.new()
	preview.text = text
	preview.add_theme_font_override("font",owner_ui.pixel_font)
	preview.add_theme_color_override("font_color",owner_ui.rarity_color(str(stack.id)))
	set_drag_preview(preview)
	return {"source":self,"owner":owner_ui}

func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("owner") == owner_ui and data.get("source") != self

func _drop_data(_at: Vector2, data: Variant) -> void:
	owner_ui.move_stack(data.source,self)

func _make_custom_tooltip(_value: String) -> Object:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#100010f0")
	style.border_color = Color("#502080")
	style.set_border_width_all(2)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel",style)
	var label := Label.new()
	label.text = str(owner_ui.game.item_definition(str(stack.id)).name)
	label.add_theme_font_override("font",owner_ui.pixel_font)
	label.add_theme_font_size_override("font_size",20)
	label.add_theme_color_override("font_color",owner_ui.rarity_color(str(stack.id)))
	if owner_ui.pixel_font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x > 340:
		label.custom_minimum_size.x = 340
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(label)
	return panel

func _draw() -> void:
	if stack.is_empty(): return
	var item: Dictionary = owner_ui.game.item_definition(str(stack.id))
	var origin := Vector2(9,6)
	var tint: Color = owner_ui.rarity_color(str(stack.id))
	var kind := str(item.get("kind",""))
	if kind in ["heal","revive"]:
		pixel(origin,Rect2(3,0,6,3),Color("#705237"))
		pixel(origin,Rect2(4,3,4,3),Color("#b9dddd"))
		pixel(origin,Rect2(1,6,10,10),Color("#222222"))
		pixel(origin,Rect2(2,7,8,8),Color("#d455bb") if "super" in str(stack.id) else Color("#e84e55"))
		pixel(origin,Rect2(3,8,2,5),Color("#ffc2e4"))
	elif kind == "ball":
		pixel(origin,Rect2(1,3,12,10),Color("#252525"))
		pixel(origin,Rect2(3,1,8,14),Color("#252525"))
		pixel(origin,Rect2(2,4,10,4),Color("#e34a48"))
		pixel(origin,Rect2(4,2,6,2),Color("#ff6a68"))
		pixel(origin,Rect2(2,9,10,3),Color("#eeeeee"))
		pixel(origin,Rect2(4,12,6,2),Color("#cccccc"))
		pixel(origin,Rect2(5,7,4,3),Color("#252525"))
		pixel(origin,Rect2(6,8,2,1),Color.WHITE)
	else:
		pixel(origin,Rect2(2,4,10,10),Color("#303030"))
		pixel(origin,Rect2(3,5,8,8),tint.darkened(0.25))
		pixel(origin,Rect2(4,6,3,3),tint)
		pixel(origin,Rect2(6,1,2,4),Color("#68a14c"))
	if item.get("glitched",false):
		pixel(origin,Rect2(0,5,13,2),Color("#a778c7"))
		pixel(origin,Rect2(6,11,9,2),Color("#f0d8ff"))

func pixel(origin: Vector2, rect: Rect2, color: Color) -> void:
	draw_rect(Rect2(origin + rect.position * 2,rect.size * 2),color)

