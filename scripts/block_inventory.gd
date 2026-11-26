extends Control

var game: Control
var with_chest := false
var pixel_font: Font = preload("res://assets/inventory_pixel.fnt")
var bags: Dictionary = {}
var grids: Array = []
var detail: VBoxContainer
const Slot = preload("res://scripts/inventory_slot.gd")
const Bevel = preload("res://scripts/minecraft_style.gd")

func rarity_color(id: String) -> Color:
	return {"common":Color.WHITE,"uncommon":Color("#ffff55"),"rare":Color("#55ffff"),"epic":Color("#ff55ff"),"legendary":Color("#ffaa00")}.get(str(game.item_definition(id).rarity),Color.WHITE)

func sync_slots(area: String, totals: Dictionary, capacity: int) -> void:
	var slots: Array = game.state.get(area + "_slots",[]).duplicate(true)
	var remaining := totals.duplicate()
	for i in slots.size():
		var stack: Dictionary = slots[i]
		if stack.is_empty(): continue
		var count := mini(int(stack.count),int(remaining.get(stack.id,0)))
		remaining[stack.id] = int(remaining.get(stack.id,0)) - count
		slots[i] = {"id":stack.id,"count":count} if count > 0 else {}
	for id in remaining:
		var count := int(remaining[id])
		if count <= 0: continue
		var empty := slots.find({})
		if empty < 0:
			empty = slots.size()
			slots.append({})
		slots[empty] = {"id":id,"count":count}
	while slots.size() < capacity: slots.append({})
	bags[area] = slots

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var inventory_theme := Theme.new()
	inventory_theme.default_font = pixel_font
	inventory_theme.default_font_size = 18
	theme = inventory_theme
	sync_slots("inventory",game.state.inventory,36)
	sync_slots("chest",game.state.get("chest_storage",{}),27)
	var shade := ColorRect.new()
	shade.color = Color("#000000b0")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := PanelContainer.new()
	panel.position = Vector2(12,20)
	panel.custom_minimum_size = Vector2(456,0)
	var style = Bevel.new()
	style.fill = Color("#c6c6c6")
	panel.add_theme_stylebox_override("panel",style)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",8)
	panel.add_child(box)
	if with_chest:
		label(box,"Chest")
		grid(box,"chest",0,27,"ChestSlots")
	label(box,"Inventory")
	grid(box,"inventory",0,27,"InventorySlots")
	var gap := Control.new()
	gap.custom_minimum_size.y = 4
	box.add_child(gap)
	grid(box,"inventory",27,9,"HotbarSlots")
	if bags.inventory.size() > 36:
		var extra := ScrollContainer.new()
		extra.custom_minimum_size.y = 62
		extra.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		box.add_child(extra)
		grid(extra,"inventory",36,bags.inventory.size()-36,"ExtraSlots")
	label(box,"Drag to move / swap. Shift-click to transfer.",14)
	var close := Button.new()
	close.text = "Close [E / Esc]"
	close.custom_minimum_size.y = 44
	close.pressed.connect(game.show_map)
	box.add_child(close)
	if not with_chest:
		var detail_panel := PanelContainer.new()
		detail_panel.name = "ItemDetails"
		var top := 414.0 if bags.inventory.size() > 36 else 344.0
		detail_panel.position = Vector2(12,top)
		detail_panel.size = Vector2(456,880-top)
		var detail_style := StyleBoxFlat.new()
		detail_style.bg_color = Color("#201a2af0")
		detail_style.set_content_margin_all(12)
		detail_panel.add_theme_stylebox_override("panel",detail_style)
		add_child(detail_panel)
		var detail_scroll := ScrollContainer.new()
		detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		detail_panel.add_child(detail_scroll)
		detail = VBoxContainer.new()
		detail.name = "ItemDetailsBody"
		detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		detail_scroll.add_child(detail)
	persist()

func label(parent: Node, value: String, font_size := 22) -> void:
	var node := Label.new()
	node.text = value
	node.add_theme_color_override("font_color",Color("#373737"))
	node.add_theme_font_size_override("font_size",font_size)
	parent.add_child(node)

func grid(parent: Node, area: String, start: int, count: int, title: String) -> void:
	var node := GridContainer.new()
	node.name = title
	node.columns = 9
	node.add_theme_constant_override("h_separation",0)
	node.add_theme_constant_override("v_separation",0)
	parent.add_child(node)
	for i in range(start,start+count):
		var slot = Slot.new()
		slot.owner_ui = self
		slot.area = area
		slot.index = i
		slot.custom_minimum_size = Vector2(47,54)
		slot.add_theme_font_size_override("font_size",18)
		slot.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		slot.clip_text = true
		for mode in ["normal","hover","pressed","focus"]:
			var bevel = Bevel.new()
			bevel.inset = true
			bevel.fill = Color("#aaaaaa") if mode == "hover" else Color("#8b8b8b")
			slot.add_theme_stylebox_override(mode,bevel)
		slot.pressed.connect(select_slot.bind(slot))
		node.add_child(slot)
		grids.append(slot)
	refresh()

func refresh() -> void:
	for slot in grids:
		slot.stack = bags[slot.area][slot.index]
		slot.text = ""
		slot.queue_redraw()
		slot.tooltip_text = ""
		if slot.stack.is_empty(): continue
		var id := str(slot.stack.id)
		slot.text = "\n" + str(slot.stack.count)
		slot.tooltip_text = str(game.item_definition(id).name)
		for mode in ["font_color","font_hover_color","font_pressed_color"]:
			slot.add_theme_color_override(mode,Color.WHITE)

func select_slot(slot: Button) -> void:
	if slot.stack.is_empty(): return
	if Input.is_key_pressed(KEY_SHIFT) and with_chest:
		var other := "inventory" if slot.area == "chest" else "chest"
		for target in grids:
			if target.area == other and (target.stack.is_empty() or target.stack.id == slot.stack.id):
				move_stack(slot,target)
				return
	if detail != null:
		game.show_item_details(str(slot.stack.id),detail)
		for child in detail.get_children():
			if child is Label:
				child.add_theme_color_override("font_color",Color.WHITE)
		if detail.get_child_count() > 0:
			detail.get_child(0).add_theme_color_override("font_color",rarity_color(str(slot.stack.id)))

func move_stack(source: Button, target: Button) -> void:
	if source.stack.is_empty(): return
	var first: Dictionary = source.stack.duplicate()
	var second: Dictionary = target.stack.duplicate()
	if not second.is_empty() and first.id == second.id:
		second.count = int(second.count) + int(first.count)
		bags[target.area][target.index] = second
		bags[source.area][source.index] = {}
	else:
		bags[target.area][target.index] = first
		bags[source.area][source.index] = second
	persist()
	refresh()

func persist() -> void:
	for area in bags:
		game.state[area + "_slots"] = bags[area].duplicate(true)
		var totals: Dictionary = {}
		for stack in bags[area]:
			if not stack.is_empty(): totals[stack.id] = int(totals.get(stack.id,0)) + int(stack.count)
		game.state["inventory" if area == "inventory" else "chest_storage"] = totals
	if game.state.has("active_chest"):
		var stores: Dictionary = game.state.get("chest_stores",{})
		stores[game.state.active_chest] = game.state.get("chest_storage",{}).duplicate()
		game.state["chest_stores"] = stores
		var layouts: Dictionary = game.state.get("chest_layouts",{})
		layouts[game.state.active_chest] = bags.chest.duplicate(true)
		game.state["chest_layouts"] = layouts
	game.save_game()
