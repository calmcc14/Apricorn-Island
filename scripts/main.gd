extends Control

enum Screen { TITLE, INTRO, MAP, BATTLE, PARTY, INVENTORY, SETTINGS, ENDING, UPGRADE, RUN_END, CHEST, DEBUG, FUN_EVENT, SECRET_HALL, BOX, STARTER, SUMMARY, POKEDEX }

const STARTERS := ["bulbasaur", "charmander", "squirtle", "pikachu", "eevee"]

const SecretHall = preload("res://scripts/secret_hall.gd")
const FunRules = preload("res://scripts/fun_rules.gd")
const RUN_SAVE_PATH := "user://apricorn_endless_save.json"
const SAVE_PATH := "user://apricorn_island_save.json"
const SETTINGS_PATH := "user://apricorn_settings.cfg"
const DEFAULT_SETTINGS := {"volume":0.8,"fullscreen":false,"difficulty":"normal","animations":true}
const MAP_RECT := Rect2(0, 330, 480, 290)
const COLOR_INK := Color("#203d45")
const COLOR_CREAM := Color("#fff9e9")
const COLOR_GOLD := Color("#f5bf42")
const COLOR_GREEN := Color("#54b86b")
const COLOR_BLUE := Color("#55a9dc")
const COLOR_CORAL := Color("#ee6f69")

var screen := Screen.TITLE
var state: Dictionary = {}
var ui := Control.new()
var overworld_chest_texture: Texture2D
var island_texture: Texture2D
var route_background: Texture2D
var trainer_texture: Texture2D
var map_zoom := 1.0
var map_pan := Vector2.ZERO
var dragging_map := false
var drag_last := Vector2.ZERO
var intro_page := 0
var settings_return := Screen.TITLE
var status_message := ""
var battle: Dictionary = {}
var action_index := 0
var pending_action: Dictionary = {}
var battle_log: Array[String] = []
var battle_finished := false
var selected_party_index := 0
var sprites: Dictionary = {}
var battle_menu := "main"
var drag_origin := Vector2.ZERO
var drag_moved := false
var sfx := RetroAudio.new()
var route_cache: Array = []
var route_cache_key := ""
var resolving_round := false
var animation_enabled := true
var battle_busy := false
var animation_events: Array = []
var visual_party: Array = []
var visual_enemies: Array = []
var active_effect: Dictionary = {}
var effect_time := 0.0
var elapsed := 0.0
var trainer_from := Vector2.ZERO
var trainer_slide := 1.0
var rng := RandomNumberGenerator.new()
const DEBUG_CODE := [KEY_UP, KEY_UP, KEY_DOWN, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_LEFT, KEY_RIGHT, KEY_B, KEY_A]
const DEBUG_DEFAULTS := {"invincible":false, "one_hit":false, "capture":false, "unlimited_items":false, "accuracy":false, "enemy_turns":true, "travel":false}
var debug_options: Dictionary = DEBUG_DEFAULTS.duplicate()
var debug_keys: Array = []
var debug_return := Screen.MAP
var secret_debug_preview := false
var secret_hall: Control
var inventory_page := 0
var inventory_query := ""
var inventory_category := "All categories"
var inventory_owned_only := false
var box_page := 0
var box_inspect := false
var dex_query := ""
var dex_filter := 0
var summary_return := Screen.PARTY
const TrainerStyle = preload("res://scripts/trainer_style.gd")
var trainer_style := TrainerStyle.new()
var character_customization_open := false

func _ready() -> void:
	rng.randomize()
	add_child(sfx)
	animation_enabled = DisplayServer.get_name() != "headless"
	overworld_chest_texture = load("res://assets/overworld_chest.webp")
	island_texture = load("res://assets/island_bg.png")
	for species_id in GameData.SPECIES.keys()+ItemProgression.data().species.keys():
		for side in ["front", "back"]:
			var key: String = str(species_id) + "_" + side
			if ResourceLoader.exists("res://assets/sprites/" + key + ".png"):
				sprites[key] = load("res://assets/sprites/" + key + ".png")
	route_background = load("res://assets/route_pixel_background.png")
	trainer_texture = load("res://assets/trainer_player.png")
	trainer_style.load_profile()
	trainer_texture = trainer_style.make_texture()
	configure_theme()
	load_preferences()
	apply_settings()
	# Leave the drawn map available to unhandled input; panel controls still consume clicks.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process_unhandled_input(true)
	show_title()
	if "--verify-items" in OS.get_cmdline_user_args(): call_deferred("_verify_item_release")

func _verify_item_release() -> void:
	preload("res://scripts/item_release_check.gd").run(self)

func configure_theme() -> void:
	var theme := Theme.new()
	theme.default_font_size = 20
	theme.set_color("font_color", "Label", COLOR_INK)
	theme.set_color("font_color", "Button", COLOR_INK)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", Color.WHITE)
	theme.set_font_size("font_size", "Button", 18)
	var button_style := StyleBoxFlat.new()
	button_style.bg_color = COLOR_CREAM
	button_style.border_color = COLOR_INK
	button_style.set_border_width_all(2)
	button_style.shadow_color = Color("#142e4030")
	button_style.shadow_size = 3
	button_style.shadow_offset = Vector2(0, 3)
	button_style.corner_radius_top_left = 8
	button_style.corner_radius_top_right = 8
	button_style.corner_radius_bottom_left = 8
	button_style.corner_radius_bottom_right = 8
	button_style.content_margin_left = 14
	button_style.content_margin_right = 14
	button_style.content_margin_top = 9
	button_style.content_margin_bottom = 9
	theme.set_stylebox("normal", "Button", button_style)
	var hover := button_style.duplicate()
	hover.bg_color = Color("#368b83")
	theme.set_stylebox("hover", "Button", hover)
	var pressed := button_style.duplicate()
	pressed.bg_color = Color("#24645f")
	theme.set_stylebox("pressed", "Button", pressed)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = COLOR_GOLD
	focus.set_border_width_all(3)
	focus.set_corner_radius_all(8)
	theme.set_stylebox("focus", "Button", focus)
	var disabled := button_style.duplicate()
	disabled.bg_color = Color("#a8a8a0")
	theme.set_stylebox("disabled", "Button", disabled)
	theme.set_color("font_disabled_color", "Button", Color("#646464"))
	self.theme = theme

func clear_ui() -> void:
	get_window().content_scale_size = Vector2i(720,900) if screen in [Screen.INVENTORY,Screen.CHEST] else Vector2i(480,900) if screen == Screen.MAP else Vector2i(480,854) if screen in [Screen.TITLE,Screen.UPGRADE,Screen.RUN_END,Screen.STARTER] else Vector2i(1280,720)
	fit_window_to_screen()
	for child in ui.get_children():
		ui.remove_child(child)
		child.queue_free()
	queue_redraw()

func fit_window_to_screen() -> void:
	if DisplayServer.get_name() == "headless" or DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED: return
	var landscape := get_window().content_scale_size.x > get_window().content_scale_size.y
	var current := DisplayServer.window_get_size()
	if (current.x > current.y) == landscape: return
	var available := DisplayServer.screen_get_usable_rect()
	var target := Vector2(1152,648) if landscape else Vector2(480,854)
	var limit := Vector2(available.size) - Vector2(40,80)
	var scale_factor := minf(1.0,minf(limit.x / target.x,limit.y / target.y))
	var fitted := Vector2i(target * maxf(0.25,scale_factor))
	DisplayServer.window_set_size(fitted)
	DisplayServer.window_set_position(available.position + (available.size-fitted)/2)

func add_label(parent: Node, text_value: String, size := 20, color := COLOR_INK) -> Label:
	if parent.name == "ItemDetailsBody": color = Color("#f3ece3")
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func add_button(parent: Node, text_value: String, callback: Callable, disabled := false) -> Button:
	var button := Button.new()
	button.text = text_value
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.disabled = disabled
	button.custom_minimum_size = Vector2(0, 48)
	button.pressed.connect(func(): sfx.play_effect("select"))
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func make_panel(rect: Rect2, color := Color("#fff9e9f5")) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.position = rect.position
	panel.size = rect.size
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("#c5d6c8")
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.shadow_color = Color("#102f4055")
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 5)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	panel.add_child(box)
	ui.add_child(panel)
	return box

func show_title(message := "") -> void:
	screen = Screen.TITLE
	clear_ui()
	var box := make_panel(Rect2(20,95,440,650))
	add_label(box,"THE APRICORN EXPEDITION",16,Color("#3b8176"))
	add_label(box,"Apricorn Island",42)
	add_label(box,"A new route. A stronger team.
How far can you go?",23)
	add_button(box,"New Endless Run  →",request_new_game.bind(true))
	add_button(box,"Continue Endless Run",continue_endless,not FileAccess.file_exists(RUN_SAVE_PATH))
	add_button(box,"New Island Adventure",request_new_game.bind(false))
	add_button(box,"Continue Island Adventure",continue_game,not FileAccess.file_exists(SAVE_PATH))
	add_button(box,"Settings",func(): open_settings(Screen.TITLE))
	add_button(box,"Quit",func(): get_tree().quit())
	add_label(box,"Endless: random encounters, upgrades and a fresh start when your team falls.",17)
	if message != "": add_label(box,message,16,COLOR_CORAL)
	add_label(box,"Tab / arrows to navigate • Enter to choose",14,Color("#647b71"))

func request_new_game(endless: bool) -> void:
	var path := RUN_SAVE_PATH if endless else SAVE_PATH
	if not FileAccess.file_exists(path):
		show_starter_selection(endless)
		return
	var dialog := ConfirmationDialog.new()
	dialog.title = "Start a new expedition?"
	dialog.dialog_text = "Choosing a new partner will replace your saved %s.\nYour other game mode will be kept." % ("endless run" if endless else "island adventure")
	dialog.ok_button_text = "Choose a new partner"
	dialog.cancel_button_text = "Keep my save"
	dialog.confirmed.connect(func(): show_starter_selection(endless))
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(420,180))

func show_starter_selection(endless: bool) -> void:
	screen = Screen.STARTER
	clear_ui()
	var box := make_panel(Rect2(20,70,440,710))
	add_label(box,"CHOOSE YOUR FIRST PARTNER",26)
	add_label(box,"Start with one Pokémon, then catch more friends to build your team.",19)
	for species_id in STARTERS:
		var species: Dictionary = GameData.SPECIES[species_id]
		var row := HBoxContainer.new()
		box.add_child(row)
		var portrait := TextureRect.new()
		portrait.texture = sprites.get(species_id + "_front")
		portrait.custom_minimum_size = Vector2(64,64)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(portrait)
		var choose := add_button(row,"%s / %s" % [species.name,str(species.type).capitalize()],func():
			if endless: start_endless(species_id)
			else: start_new_game(species_id)
		)
		choose.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_button(box,"Back",show_title)

func start_new_game(starter := "") -> void:
	if starter not in STARTERS:
		show_starter_selection(false)
		return
	var preferences: Dictionary = state.get("settings", {"volume":0.8,"fullscreen":false,"difficulty":"normal"}).duplicate(true)
	state = {
		"version": 1,
		"current_node": "airstrip",
		"cleared": ["airstrip"],
		"opened_chests": [],
		"loot_seed": rng.randi_range(1,2000000000),
		"party": [GameData.make_pokemon(starter)],
		"reserve": [],
		"inventory": {"potion":3,"super_potion":0,"berry":2,"apricorn_ball":6,"great_apricorn_ball":2,"star_berry":0},
		"settings": {"volume":0.8,"fullscreen":false,"difficulty":"normal"},
		"finished": false
	}
	FunRules.initialize(state)
	state.settings = preferences
	battle = {}
	save_game()
	intro_page = 0
	map_pan = Vector2.ZERO
	show_intro()

func continue_game() -> void:
	if load_game():
		apply_settings()
		focus_current_stop()
		if state.get("battle_checkpoint",{}).has("orb_item"):
			battle = state.battle_checkpoint.duplicate(true)
			battle_finished = battle.get("finished",false)
			action_index = 0
			pending_action = {}
			battle_menu = "main"
			show_battle()
		else: show_map("Welcome back to the island!")
	else:
		show_title("The save could not be read. Start a new adventure safely.")

func show_intro() -> void:
	screen = Screen.INTRO
	clear_ui()
	var headings := ["Your island story starts here", "Your first partner", "Go wherever curiosity takes you"]
	var pages := [
		"Beyond the clouds lies Apricorn Island. Professor Hazel has one request: discover what waits at the volcano lookout.",
		"Your chosen Pokémon is coming with you! Catch more friends to build your team. Grass beats water, water beats fire, and fire beats grass. Choose a move for each friend in battle.",
		"Click any unlocked place to travel there, then choose its activity. Win battles to reveal new places. Your team rests after each victory; weaken wild Pokémon to catch them!"
	]
	var box := make_panel(Rect2(100, 460, 1080, 226))
	add_label(box, "PROFESSOR HAZEL  /  %02d OF 03" % (intro_page + 1), 14, Color("#3b8176"))
	add_label(box, headings[intro_page], 28)
	add_label(box, pages[intro_page], 20)
	var row := HBoxContainer.new()
	box.add_child(row)
	add_button(row, "Land on the island  →" if intro_page == 2 else "Next  →", func():
		if intro_page < 2:
			intro_page += 1
			show_intro()
		else: show_map("Welcome! Click Petal Meadow to begin.")
	).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_button(row, "Skip intro", func(): show_map("Click Petal Meadow to begin."))

func show_map(message := "") -> void:
	if milestone_chest_pending() and not state.run.get("pending_upgrade",false):
		show_milestone_chest()
		return
	screen = Screen.MAP
	status_message = message
	clear_ui()
	var node := get_node_data(str(state.current_node))
	var top := make_panel(Rect2(20,20,440,66))
	var tools := HBoxContainer.new()
	top.add_child(tools)
	add_button(tools,"Party",show_party).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box_button := add_box_button(ui)
	box_button.position = Vector2(20, 786)
	box_button.size = Vector2(96, 96)
	var dex_button := add_pokedex_button(ui)
	dex_button.position = Vector2(128, 786)
	dex_button.size = Vector2(96, 96)
	add_button(tools,"Bag",show_inventory).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_button(tools,"Menu",func(): open_settings(Screen.MAP)).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var heading := VBoxContainer.new()
	heading.position = Vector2(35,132)
	heading.size = Vector2(410,170)
	ui.add_child(heading)
	var title := add_label(heading,"CURRENT AREA",18,Color("#8c699c"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var number := add_label(heading,"%02d" % (int(node.floor) if is_endless() else map_nodes().find(node)+1),66,Color("#e8a23e"))
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var place := add_label(heading,str(node.name),24)
	place.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if node.get("cave",false): add_label(heading,"Cave encounter",15)
	if message != "":
		var note := add_label(heading,message,15,Color("#647b71"))
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var fun_event: Dictionary = FunRules.event_at(state, node)
	if not fun_event.is_empty():
		var secret := make_panel(Rect2(20, 305, 440, 78))
		add_button(secret, str(fun_event.hint), func(): show_fun_event(fun_event))
	var bottom := make_panel(Rect2(20,587,440,184))
	var row := HBoxContainer.new()
	bottom.add_child(row)
	add_button(row,"←",func(): scroll_route(230))
	var hint := add_label(row,"Swipe to explore · Tap a mint stop",15)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_button(row,"→",func(): scroll_route(-230))
	var label := "Enter Area" if secret_available(node) else action_label(node)
	var action := add_button(bottom,label if label != "" else "Area complete",func(): enter_current_node(node),label == "")
	action.custom_minimum_size.y = 64
	var action_style: StyleBoxFlat = theme.get_stylebox("normal","Button").duplicate()
	action_style.bg_color = Color("#b6e881")
	action_style.border_color = Color("#6a9e50")
	action.add_theme_stylebox_override("normal",action_style)
	if can_fish(node): add_button(bottom,"Fish here",start_fishing.bind(node))
	var progress := add_label(bottom,progress_text(),15,Color("#648378"))
	progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	queue_redraw()

func scroll_route(amount: float) -> void:
	map_pan.x = clamp(map_pan.x + amount,-float((map_nodes().size()-1)*136)+250.0,0.0)
	queue_redraw()

func focus_current_stop() -> void:
	var index := map_nodes().find(get_node_data(str(state.current_node)))
	map_pan = Vector2(clamp(36.0-index*136.0,-float((map_nodes().size()-1)*136)+250.0,0.0),0)

func node_kind_text(kind: String) -> String:
	match kind:
		"battle": return "Wild Pokémon battle"
		"boss": return "Summit challenge • three opponents"
		"chest": return "Treasure chest"
		"mystery": return "Something curious is hiding here"
		"finish": return "The island lookout"
	return "Your adventure begins here"

func action_label(node: Dictionary) -> String:
	if is_endless() and int(node.floor) <= int(state.run.depth): return "Next area  →"
	var id := str(node.id)
	if str(node.kind) == "start": return "Rest & Recover"
	if id in state.cleared:
		if str(node.kind) == "finish": return "Visit Lookout"
		return ""
	match str(node.kind):
		"battle", "boss": return "Enter Battle"
		"chest": return "Open Chest"
		"mystery": return "Investigate"
		"finish": return "Visit Lookout"
	return ""

func enter_current_node(node: Dictionary) -> void:
	if secret_available(node):
		show_secret_hall()
		return
	if milestone_chest_pending() and not state.run.get("pending_upgrade",false):
		show_milestone_chest()
		return
	if is_endless():
		if int(node.floor) <= int(state.run.depth):
			travel_to("run_%d" % (int(state.run.depth)+1))
			return
	match str(node.kind):
		"battle", "boss": start_battle(str(node.encounter), str(node.id))
		"chest": open_chest(node)
		"start": rest_at_airstrip(node)
		"mystery": resolve_mystery(node)
		"finish": show_ending()

func open_chest(node: Dictionary) -> void:
	var id := str(node.id)
	if id in state.opened_chests:
		if not state.get("chest_stores",{}).get(id,{}).is_empty():
			show_chest_contents({},id)
			return
		show_map("This chest is already empty.")
		return
	var before := state.duplicate(true)
	var rewards := chest_loot(id, int(node.get("floor",0)), node.reward)
	grant_items(rewards)
	sfx.play_effect("capture")
	state.opened_chests.append(id)
	mark_cleared(id)
	if not save_game():
		state = before
		show_map("Chest could not be saved. Your rewards are safe to try again.")
		return
	focus_current_stop()
	show_chest_contents(rewards,id)

func chest_loot(id: String, depth: int, supplies: Dictionary) -> Dictionary:
	sync_pokedex()
	ItemCatalog.migrate(state)
	FunRules.initialize(state)
	if not state.chest_rewards.has(id):
		var seed_value := int(state.run.seed) if is_endless() else int(state.loot_seed)
		state.chest_rewards[id] = ItemCatalog.chest_rewards(seed_value, id, depth if is_endless() else 0, supplies)
	return state.chest_rewards[id]

func rest_at_airstrip(node: Dictionary) -> void:
	sfx.play_effect("heal")
	restore_party()
	mark_cleared(str(node.id))
	save_game()
	show_map("Your whole party is fully rested.")

func resolve_mystery(node: Dictionary) -> void:
	var reward := {"great_apricorn_ball":1,"berry":3}
	grant_items(reward)
	mark_cleared(str(node.id))
	save_game()
	show_map("A friendly Wingull drops a parcel! " + reward_text(reward))

func show_party() -> void:
	screen = Screen.PARTY
	clear_ui()
	var box := make_panel(Rect2(160, 70, 960, 620), Color("#fff4d6fa"))
	add_label(box, "Party & Reserve Box", 32)
	add_label(box, "Choose a party slot, then choose a reserve Pokémon to swap.", 16, Color("#536b77"))
	add_label(box, "Earn EXP by defeating opponents. Each level adds HP and battle stats, up to level 100.", 16, Color("#536b77"))
	var party_row := HBoxContainer.new()
	party_row.add_theme_constant_override("separation", 12)
	box.add_child(party_row)
	for i in state.party.size():
		var p: Dictionary = state.party[i]
		var data: Dictionary = GameData.SPECIES[p.species]
		var button := add_button(party_row, "%s · Lv.%d\nHP %d/%d\n%s · %s" % [data.name,int(p.get("level",5)),p.hp,p.max_hp,str(p.get("gender","genderless")),str(p.get("nature","hardy")).capitalize()], select_party_slot.bind(i))
		button.icon = sprites.get(str(p.species) + "_front")
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text += "\n" + str(ItemMechanics.level_progress(p).label)
		button.tooltip_text = "Level up: +2 maximum HP and +1 Attack, Defense, Special Attack, Special Defense and Speed."
		if i == selected_party_index:
			button.modulate = Color("#fff0a8")
	add_button(box,"View selected Pokémon",show_pokemon_summary.bind(selected_party_index,false))
	if not state.party[selected_party_index].get("pending_moves",[]).is_empty() or state.party[selected_party_index].get("pending_evolution","") != "":
		add_button(box,"Level-up moves / Evolution",show_level_choices.bind(selected_party_index))
	add_label(box, "Reserve Pokémon", 23)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var reserve_box := VBoxContainer.new()
	reserve_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(reserve_box)
	if state.reserve.is_empty():
		add_label(reserve_box, "The reserve box is empty. Weaken wild Pokémon and throw a ball to befriend them!", 18)
	else:
		for i in state.reserve.size():
			var p: Dictionary = state.reserve[i]
			var data: Dictionary = GameData.SPECIES[p.species]
			var reserve_row := HBoxContainer.new()
			reserve_box.add_child(reserve_row)
			add_button(reserve_row, "Swap in %s · Lv.%d • HP %d/%d\n%s" % [data.name,int(p.get("level",5)),p.hp,p.max_hp,ItemMechanics.level_progress(p).label], swap_party.bind(i)).size_flags_horizontal = Control.SIZE_EXPAND_FILL
			add_button(reserve_row,"Details",show_pokemon_summary.bind(i,true))
	add_button(box, "Back to Map", show_map)

func select_party_slot(index: int) -> void:
	selected_party_index = index
	show_party()

func show_pokemon_summary(index: int, reserve: bool = false) -> void:
	if battle_busy or resolving_round: return
	var collection: Array = state.get("reserve",[]) if reserve else state.get("party",[])
	if index < 0 or index >= collection.size(): return
	summary_return = screen
	screen = Screen.SUMMARY
	clear_ui()
	var summary = preload("res://scripts/pokemon_summary.gd").new()
	ui.add_child(summary)
	summary.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	summary.closed.connect(close_pokemon_summary)
	summary.setup(collection,sprites,index)

func close_pokemon_summary() -> void:
	match summary_return:
		Screen.BOX: show_box()
		Screen.BATTLE: show_battle()
		_: show_party()

func add_box_button(parent: Node) -> Button:
	var button := add_button(parent, "", func():
		box_page = 0
		show_box()
	)
	button.name = "BoxButton"
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.icon = load("res://assets/box_pc_cutout.png")
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 76)
	button.custom_minimum_size = Vector2(96, 96)
	for style_name in ["normal", "hover", "pressed"]:
		var style: StyleBoxFlat = theme.get_stylebox(style_name, "Button").duplicate()
		style.bg_color = Color("#c83e49") if style_name == "normal" else Color("#e4535d") if style_name == "hover" else Color("#952c39")
		style.content_margin_left = 7
		style.content_margin_right = 7
		style.content_margin_top = 7
		style.content_margin_bottom = 7
		style.set_corner_radius_all(48)
		button.add_theme_stylebox_override(style_name, style)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.tooltip_text = "Box • Open Pokémon storage"
	return button

func add_pokedex_button(parent: Node) -> Button:
	var button := add_button(parent, "", show_pokedex)
	button.name = "PokedexButton"
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.icon = load("res://assets/pokedex_icon.png")
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 60)
	button.custom_minimum_size = Vector2(96, 96)
	for style_name in ["normal", "hover", "pressed"]:
		var style: StyleBoxFlat = theme.get_stylebox(style_name, "Button").duplicate()
		style.bg_color = Color("#b6e881") if style_name == "normal" else Color("#ccf2a2") if style_name == "hover" else Color("#8fc65e")
		style.content_margin_left = 16
		style.content_margin_right = 16
		style.content_margin_top = 16
		style.content_margin_bottom = 16
		style.set_corner_radius_all(48)
		button.add_theme_stylebox_override(style_name, style)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.tooltip_text = "Pokédex • View seen and caught Pokémon"
	return button

func show_box(message := "") -> void:
	screen = Screen.BOX
	clear_ui()
	selected_party_index = clampi(selected_party_index, 0, state.party.size() - 1)
	box_page = clampi(box_page, 0, int(state.reserve.size() / 30))
	var panel := make_panel(Rect2(40, 20, 1200, 680), Color("#e2f3eafa"))
	add_label(panel, "POKÉMON BOX • PC STORAGE", 30)
	add_label(panel, "Choose a party slot, then a stored Pokémon to swap. Caught Pokémon arrive here automatically.", 17)
	var detail_row := HBoxContainer.new()
	panel.add_child(detail_row)
	add_button(detail_row,"View selected Pokémon",show_pokemon_summary.bind(selected_party_index,false))
	add_button(detail_row,"Stored Pokémon: Details" if box_inspect else "Stored Pokémon: Swap",func(): box_inspect = not box_inspect; show_box())
	var party_row := HBoxContainer.new()
	panel.add_child(party_row)
	for i in state.party.size():
		var pokemon: Dictionary = state.party[i]
		var button := add_button(party_row, "%s · Lv.%d • HP %d/%d" % [GameData.SPECIES[pokemon.species].name, int(pokemon.get("level",5)), pokemon.hp, pokemon.max_hp], func():
			selected_party_index = i
			show_box()
		)
		button.icon = sprites.get(str(pokemon.species) + "_front")
		button.add_theme_constant_override("icon_max_width",48)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if i == selected_party_index: button.modulate = Color("#fff0a8")
	var navigation := HBoxContainer.new()
	panel.add_child(navigation)
	add_button(navigation, "←", change_box_page.bind(-1), box_page == 0)
	var title := add_label(navigation, "BOX %02d   •   %d stored Pokémon" % [box_page + 1, state.reserve.size()], 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_button(navigation, "→", change_box_page.bind(1), (box_page + 1) * 30 > state.reserve.size())
	var grid := GridContainer.new()
	grid.columns = 6
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	panel.add_child(grid)
	for slot in 30:
		var index := box_page * 30 + slot
		var occupied: bool = index < state.reserve.size()
		var pokemon: Dictionary = state.reserve[index] if occupied else {}
		var button := add_button(grid, str(GameData.SPECIES[pokemon.species].name) if occupied else "—", show_pokemon_summary.bind(index,true) if box_inspect else swap_box_pokemon.bind(index), not occupied)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 15)
		if occupied:
			button.icon = sprites.get(str(pokemon.species) + "_front")
			button.add_theme_constant_override("icon_max_width", 42)
			button.text += "\nLv.%d" % int(pokemon.get("level",5))
			button.tooltip_text = "HP %d/%d • %s • %s" % [pokemon.hp, pokemon.max_hp, ItemMechanics.level_progress(pokemon).label, "View Pokémon details" if box_inspect else "Swap into party slot %d" % (selected_party_index+1)]
	add_label(panel, message if message != "" else "Catch Pokémon to fill your Box. Escape returns to the map.", 16)
	add_button(panel, "Back to Map", show_map)

func change_box_page(amount: int) -> void:
	box_page += amount
	show_box()

func swap_box_pokemon(index: int) -> void:
	if screen != Screen.BOX or index < 0 or index >= state.reserve.size(): return
	var previous := state.duplicate(true)
	var pokemon: Dictionary = state.party[selected_party_index]
	state.party[selected_party_index] = state.reserve[index]
	state.reserve[index] = pokemon
	if not save_game():
		state = previous
		show_box("Could not save the swap. Please try again.")
		return
	show_box("Party updated and saved.")

func swap_party(reserve_index: int) -> void:
	var old: Dictionary = state.party[selected_party_index]
	state.party[selected_party_index] = state.reserve[reserve_index]
	state.reserve[reserve_index] = old
	save_game()
	show_party()

func show_inventory() -> void:
	screen = Screen.INVENTORY
	clear_ui()
	var inventory_ui = preload("res://scripts/block_inventory.gd").new()
	inventory_ui.game = self
	ui.add_child(inventory_ui)

func show_item_details(id: String, detail: VBoxContainer) -> void:
	for child in detail.get_children():
		detail.remove_child(child)
		child.queue_free()
	var item: Dictionary = item_definition(id)
	var count := int(state.inventory.get(id,0))
	add_label(detail,"%s ×%d" % [item.name,count],28)
	add_label(detail,"%s • %s" % [item.category,str(item.rarity).capitalize()],18)
	add_label(detail,str(item.description),19)
	add_label(detail,ItemCatalog.status_text(item),18,Color("#536b77"))
	var depth := int(state.run.depth) if is_endless() else 0
	var probability := ItemCatalog.item_probability(id,depth)
	if probability > 0:
		add_label(detail,"At depth %d: %.5f%% per roll; %.5f%% in three rolls." % [depth,probability*100.0,(1.0-pow(1.0-probability,3))*100.0],18)
	else:
		add_label(detail,"Reserved for the spinoff DLC; excluded from base chest loot." if GameData.DLC_ITEMS.has(id) else "Guaranteed island supplies; also retained in existing rewards.",18)
	if GameData.DLC_ITEMS.has(id) and state.get("enabled_dlc","") != "spinoff": return
	if item.kind == "boss_orb":
		BossOrbs.initialize(state)
		for i in state.orb_instances.get(id,[]).size():
			add_button(detail,"Summon · Copy %d · %s" % [i+1,BossOrbs.label(state.orb_instances[id][i],state.orb_boss_caught.get(id,false))],start_orb_boss.bind(id,i),not BossOrbs.available(state,id,i))
		for i in state.party.size():
			add_button(detail,"Give to %s" % GameData.SPECIES[state.party[i].species].name,equip_power_item.bind(id,i),count <= 0)
	elif item.kind in ["form_item","candy","ability_medicine"]:
		for i in state.party.size():
			var pokemon: Dictionary = state.party[i]
			var valid: bool = pokemon.species == item.get("form_species","") if item.kind == "form_item" else (ItemProgression.candy(pokemon,false) if item.kind == "candy" else PendingItems.ability_patch(pokemon,false))
			add_button(detail,"Use on %s" % GameData.SPECIES[pokemon.species].name,use_progression_item.bind(id,i),count <= 0 or not valid)
	elif item.kind == "escape_item":
		add_label(detail,"Use from the battle BAG inside an eligible cave.",18)
	elif item.kind == "party_revive":
		add_button(detail,"Use on party",use_party_item.bind(id),count <= 0 or not PendingItems.sacred_ash(id,state.party,false))
	elif item.kind == "held_exp":
		add_button(detail,"Enable bag party-wide sharing",set_exp_mode.bind("modern"),count <= 0)
		add_button(detail,"Disable bag party-wide sharing",set_exp_mode.bind("classic"))
		for i in state.party.size():
			add_button(detail,"Give to %s" % GameData.SPECIES[state.party[i].species].name,equip_power_item.bind(id,i),count <= 0)
		for generation in [6,7]: add_button(detail,"Bag EXP formula: generation %d" % generation,set_exp_generation.bind("modern",generation))
	elif item.kind == "hyper_train":
		for i in state.party.size():
			for stat in (["all stats"] if item.get("all_stats",false) else ItemMechanics.IV_STATS):
				add_button(detail,"Train %s: %s" % [GameData.SPECIES[state.party[i].species].name,stat],use_training_item.bind(id,i,str(stat)),count <= 0 or not PendingItems.hyper_train(state.party[i],str(stat),item.get("all_stats",false),false))
	elif item.kind == "ev_medicine":
		for i in state.party.size():
			add_button(detail,"Use on %s" % GameData.SPECIES[state.party[i].species].name,use_ev_item.bind(id,i),count <= 0 or not PendingItems.ev_use(item,state.party[i],false))
	elif item.kind == "pp_medicine":
		for i in state.party.size():
			var pokemon: Dictionary = state.party[i]
			for move_id in pokemon.get("moves",[]):
				add_button(detail,"%s: %s (%d/%d PP)" % [GameData.SPECIES[pokemon.species].name,GameData.MOVES[move_id].name,pokemon.pp[move_id],PendingItems.max_pp(pokemon,move_id)],use_pp_item.bind(id,i,str(move_id)),count <= 0 or not PendingItems.pp_use(item,pokemon,str(move_id),false))
	elif item.kind in ["heal","revive","medicine","cure_berry"] or id in ["item_oran_berry","item_ripe_oran_berry"]:
		for i in state.party.size():
			var pokemon: Dictionary = state.party[i]
			add_button(detail,"Use on %s (%d/%d HP)" % [GameData.SPECIES[pokemon.species].name,pokemon.hp,pokemon.max_hp],use_heal_item.bind(id,i),count <= 0 or not ItemCatalog.can_apply(item,pokemon))
	elif item.kind == "ball":
		add_label(detail,"Use from BAG during battle.",18)
	elif ItemMechanics.held_kind(item):
		for i in state.party.size():
			var pokemon: Dictionary = state.party[i]
			add_button(detail,"Give to %s" % GameData.SPECIES[pokemon.species].name,equip_power_item.bind(id,i),count <= 0)
		if item.kind == "held_exp":
			add_button(detail,"Enable bag party-wide sharing",set_exp_mode.bind("modern"),count <= 0)
			add_button(detail,"Disable bag party-wide sharing",set_exp_mode.bind("classic"))
			add_label(detail,"EXP formula: generation %d" % int(state.get("classic_exp_generation",3)),18)
			for generation in [2,3,4,5]: add_button(detail,"Use generation %d experience formula" % generation,set_exp_generation.bind("classic",generation))
	elif item.kind == "machine":
		for i in state.party.size():
			var pokemon: Dictionary = state.party[i]
			add_button(detail,"Teach %s" % GameData.SPECIES[pokemon.species].name,select_machine_target.bind(id,i,detail),count <= 0 or not ItemMechanics.can_teach(item,pokemon))
	elif item.kind == "battle_boost":
		add_label(detail,"Use from BAG during battle.",18)
	elif item.kind == "exp_mode":
		add_label(detail,"Active sharing: "+str(state.get("exp_mode","classic")),18)
		add_button(detail,"Enable "+item.name,set_exp_mode.bind(str(item.exp_mode)),count <= 0)
		add_button(detail,"Use held Classic Exp. Share rules",set_exp_mode.bind("classic"))
		if item.exp_mode == "modern":
			add_label(detail,"EXP formula: generation %d" % int(state.get("modern_exp_generation",6)),18)
			for generation in [6,7]: add_button(detail,"Use generation %d experience formula" % generation,set_exp_generation.bind("modern",generation))
	if ItemMechanics.held_kind(item) and item.kind in ["cure_berry","pp_medicine","held_berry"]:
		for i in state.party.size():
			add_button(detail,"Give to %s" % GameData.SPECIES[state.party[i].species].name,equip_power_item.bind(id,i),count <= 0)
	for i in state.party.size():
		if str(state.party[i].get("held_item", "")) == id:
			add_button(detail,"Take from %s" % GameData.SPECIES[state.party[i].species].name,equip_power_item.bind("",i))

func equip_power_item(item_id: String, party_index: int) -> void:
	if party_index < 0 or party_index >= state.party.size(): return
	if item_id != "" and (not GameData.ITEMS.has(item_id) or not ItemMechanics.held_kind(GameData.ITEMS[item_id]) or int(state.inventory.get(item_id,0)) <= 0): return
	var pokemon: Dictionary = state.party[party_index]
	var previous := str(pokemon.get("held_item", ""))
	pokemon.erase("held_orb_uid")
	if item_id in BossOrbs.SPECIES:
		BossOrbs.initialize(state)
		for copy in state.orb_instances[item_id]:
			var occupied := false
			for other in state.party+state.get("reserve",[]):
				if other.get("held_orb_uid","") == copy.uid: occupied = true
			if not occupied:
				pokemon.held_orb_uid = copy.uid
				break
	if previous != "": state.inventory[previous] = int(state.inventory.get(previous,0)) + 1
	if item_id != "": state.inventory[item_id] = int(state.inventory.get(item_id,0)) - 1
	pokemon.held_item = item_id
	ItemProgression.form(pokemon,false)
	save_game()
	show_inventory()

func select_machine_target(item_id: String, party_index: int, detail: VBoxContainer) -> void:
	if party_index < 0 or party_index >= state.party.size(): return
	var pokemon: Dictionary = state.party[party_index]
	if not ItemMechanics.can_teach(GameData.ITEMS[item_id],pokemon): return
	if pokemon.moves.size() < 4:
		teach_machine(item_id,party_index)
		return
	for child in detail.get_children():
		detail.remove_child(child)
		child.queue_free()
	add_label(detail,"Choose a move to replace",22,Color.WHITE)
	for i in pokemon.moves.size(): add_button(detail,GameData.MOVES[pokemon.moves[i]].name,teach_machine.bind(item_id,party_index,i))
	add_button(detail,"Cancel",show_inventory)

func teach_machine(item_id: String, party_index: int, replace: int = -1) -> bool:
	if party_index < 0 or party_index >= state.party.size() or int(state.inventory.get(item_id,0)) <= 0: return false
	var item: Dictionary = GameData.ITEMS.get(item_id,{})
	var before := state.duplicate(true)
	if not ItemMechanics.teach(item,state.party[party_index],replace): return false
	if item.get("consumable",true): state.inventory[item_id] = int(state.inventory[item_id])-1
	if not save_game():
		state = before
		return false
	show_inventory()
	return true

func set_exp_mode(mode: String) -> void:
	if mode not in ["classic","modern","all"]: return
	var required := {"modern":"item_exp_share","all":"item_exp_all"}
	if required.has(mode) and int(state.inventory.get(required[mode],0)) <= 0: return
	state.exp_mode = mode
	save_game()
	show_inventory()

func set_exp_generation(mode: String, generation: int) -> void:
	if mode == "classic" and generation in [2,3,4,5]: state.classic_exp_generation = generation
	elif mode == "modern" and generation in [6,7]: state.modern_exp_generation = generation
	else: return
	save_game()
	show_inventory()

func can_fish(node: Dictionary) -> bool:
	if node.kind != "battle": return false
	if not is_endless(): return node.id in ["brook","falls"] and node.id not in state.cleared
	return int(node.floor) > int(state.run.depth) and str(node.name) in ["Coral Shore","Starlight Marsh","Crystal Brook"]

func start_fishing(node: Dictionary) -> void:
	if not can_fish(node): return
	start_battle(str(node.encounter),str(node.id))
	battle.context.fishing = true
	battle.context.water = true
	if is_endless(): save_game()
	show_battle()

func use_heal_item(item_id: String, party_index: int) -> void:
	if not GameData.ITEMS.has(item_id) or party_index < 0 or party_index >= state.party.size(): return
	if GameData.ITEMS[item_id].kind not in ["heal","revive","medicine","cure_berry","held_berry"]: return
	if int(state.inventory.get(item_id, 0)) <= 0: return
	var before := state.duplicate(true)
	var pokemon: Dictionary = state.party[party_index]
	if not ItemCatalog.apply(GameData.ITEMS[item_id],pokemon): return
	if not debug_options.unlimited_items and not GameData.ITEMS[item_id].get("reusable",false): state.inventory[item_id] -= 1
	sfx.play_effect("heal")
	if not save_game(): state = before
	show_inventory()

func open_settings(return_screen: Screen) -> void:
	character_customization_open = false
	settings_return = return_screen
	screen = Screen.SETTINGS
	clear_ui()
	if state.is_empty():
		state = {"settings":{"volume":0.8,"fullscreen":false}}
	if not state.has("settings"):
		state.settings = {"volume":0.8,"fullscreen":false}
	var box := make_panel(Rect2(360, 15, 560, 690), Color("#fff4d6fa"))
	box.add_theme_constant_override("separation",4)
	add_label(box, "Settings", 34)
	add_button(box, "Customize character", show_character_customization)
	add_label(box, "Adventure difficulty", 18)
	var difficulty := OptionButton.new()
	difficulty.add_item("Easy — a relaxed island trip")
	difficulty.add_item("Normal — a gentle challenge")
	difficulty.add_item("Hard — tougher battles")
	var difficulty_ids := ["easy", "normal", "hard"]
	var selected_difficulty := difficulty_ids.find(state.settings.get("difficulty", "normal"))
	difficulty.selected = selected_difficulty if selected_difficulty >= 0 else 1
	difficulty.item_selected.connect(func(index: int):
		state.settings.difficulty = difficulty_ids[index]
		save_preferences()
	)
	box.add_child(difficulty)
	add_label(box, "Master Volume", 18)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 1
	slider.step = 0.05
	slider.value = float(state.settings.volume)
	slider.value_changed.connect(func(value: float):
		state.settings.volume = value
		AudioServer.set_bus_volume_db(0, linear_to_db(max(0.001,value)))
		AudioServer.set_bus_mute(0,value <= 0.0)
		save_preferences()
	)
	box.add_child(slider)
	var full := CheckButton.new()
	full.text = "Fullscreen"
	full.button_pressed = bool(state.settings.fullscreen)
	full.toggled.connect(func(value: bool):
		state.settings.fullscreen = value
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED)
		save_preferences()
	)
	box.add_child(full)
	var animations := CheckButton.new()
	animations.text = "Battle animations"
	animations.button_pressed = bool(state.settings.get("animations",true))
	animations.toggled.connect(func(value: bool):
		state.settings.animations = value
		animation_enabled = value and DisplayServer.get_name() != "headless"
		save_preferences()
	)
	box.add_child(animations)
	add_label(box, "Turn animations off for quicker battles and reduced motion.",16,Color("#536b77"))
	add_label(box, "Mouse: choose • Drag / wheel: scroll map\nTab: navigate • Enter: choose • E: bag • Esc: back", 16, Color("#536b77"))
	add_button(box, "Done", close_settings)
	if return_screen == Screen.MAP:
		add_button(box,"Save & return to title",func():
			if save_game(): show_title("Progress saved. Your expedition will be waiting.")
			else:
				var warning := AcceptDialog.new()
				warning.dialog_text = "Your progress could not be saved. Please try again before leaving."
				add_child(warning)
				warning.confirmed.connect(warning.queue_free)
				warning.canceled.connect(warning.queue_free)
				warning.popup_centered()
		)

func close_settings() -> void:
	save_preferences()
	if state.has("party"): save_game()
	if settings_return == Screen.MAP: show_map()
	else: show_title()

func save_preferences() -> void:
	var config := ConfigFile.new()
	for key in DEFAULT_SETTINGS:
		config.set_value("settings",key,state.get("settings",{}).get(key,DEFAULT_SETTINGS[key]))
	config.save(SETTINGS_PATH)

func load_preferences() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	var preferences := DEFAULT_SETTINGS.duplicate()
	for key in DEFAULT_SETTINGS:
		var value = config.get_value("settings",key,DEFAULT_SETTINGS[key])
		if typeof(value) == typeof(DEFAULT_SETTINGS[key]): preferences[key] = value
	preferences.volume = clampf(float(preferences.volume),0.0,1.0)
	if preferences.difficulty not in ["easy","normal","hard"]: preferences.difficulty = "normal"
	state.settings = preferences

func start_battle(encounter_id: String, node_id: String) -> void:
	var encounter: Dictionary = RogueRules.encounter(int(state.run.seed),int(get_node_data(node_id).floor)) if is_endless() else GameData.ENCOUNTERS[encounter_id]
	battle_menu = "main"
	if node_id == "summit":
		restore_party()
	var enemies: Array = []
	for species_id in encounter.enemies:
		enemies.append(species_id.duplicate(true) if is_endless() else GameData.make_pokemon(species_id))
	for p in state.party:
		ItemMechanics.reset_battle(p)
	for p in enemies:
		register_dex(str(p.species), false)
		ItemMechanics.reset_battle(p)
	for p in state.party+enemies: ItemProgression.form(p,true)
	battle = {"encounter_id":encounter_id,"node_id":node_id,"return_node":state.current_node,"enemies":enemies,"actions":[],"rewards":encounter.rewards}
	var hour := int(Time.get_time_dict_from_system().hour)
	var node := get_node_data(node_id)
	battle.context = {"turn":1,"night":hour < 6 or hour >= 18,"cave":bool(node.get("cave",false)),"water":node_id in ["brook","falls"] or str(node.name) in ["Coral Shore","Starlight Marsh","Crystal Brook"],"fishing":false}
	battle.participants = living_party_indices()
	action_index = 0
	pending_action = {}
	battle_log = ["Wild Pokémon appeared! Choose one action for each teammate."]
	MoveEffects.start_abilities(battle,state,battle_log)
	for pokemon in state.party+enemies: ItemMechanics.activate_berry(pokemon,GameData.ITEMS,battle_log)
	battle_finished = false
	visual_party.clear()
	visual_enemies.clear()
	show_battle()
	if is_endless(): save_game()

func show_battle() -> void:
	for pokemon in battle.get("enemies",[]): register_dex(str(pokemon.species), false)
	screen = Screen.BATTLE
	clear_ui()
	if battle_busy:
		var busy_panel := make_panel(Rect2(28,495,1224,200))
		add_label(busy_panel,str(active_effect.get("message","The round unfolds…")),25)
		add_label(busy_panel,"Watch your team in action",16,Color("#648378"))
		return
	var living := living_party_indices()
	if living.is_empty():
		handle_defeat()
		return
	if not battle_finished and action_index >= living.size():
		resolve_round()
		return
	var dialogue := make_panel(Rect2(28, 495, 580, 200))
	add_label(dialogue, "VICTORY!" if battle_finished else "BATTLE  /  ROUND %d" % int(battle.get("round", 1)), 15, Color("#3b8176"))
	var ally_index: int = living[min(action_index, living.size()-1)]
	var ally: Dictionary = state.party[ally_index]
	add_label(dialogue, "Well done, team!" if battle_finished else "What will %s do?" % GameData.SPECIES[ally.species].name, 27)
	var log_scroll := ScrollContainer.new()
	log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialogue.add_child(log_scroll)
	var log_label := add_label(log_scroll, "\n".join(battle_log), 17)
	log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var commands := make_panel(Rect2(626, 495, 626, 200))
	if battle_finished:
		add_label(commands, "Choose an upgrade. HP carries into the next fight." if is_endless() else "Your team will recover all HP.", 21)
		add_button(commands, "Collect rewards & explore  →", finish_victory)
		return
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	commands.add_child(grid)
	if not pending_action.is_empty():
		if pending_action.kind == "heal_item" and pending_action.has("target") and GameData.ITEMS[pending_action.item].kind == "pp_medicine":
			var patient: Dictionary = state.party[int(pending_action.target)]
			for move_id in patient.moves:
				add_button(grid,str(GameData.MOVES[move_id].name),confirm_pp_target.bind(str(move_id)),not PendingItems.pp_use(GameData.ITEMS[pending_action.item],patient,str(move_id),false))
		elif pending_action.kind == "heal_item":
			for i in state.party.size():
				var pokemon: Dictionary = state.party[i]
				add_button(grid,"%s %d/%d HP" % [GameData.SPECIES[pokemon.species].name,pokemon.hp,pokemon.max_hp],confirm_item_target.bind(i),not ItemCatalog.can_apply(GameData.ITEMS[pending_action.item],pokemon))
		else:
			for enemy_index in living_enemy_indices():
				var enemy: Dictionary = battle.enemies[enemy_index]
				add_button(grid, "%s  %d/%d HP" % [GameData.SPECIES[enemy.species].name, enemy.hp, enemy.max_hp], confirm_target.bind(enemy_index))
		add_button(grid, "← Cancel", func(): pending_action = {}; show_battle())
	elif battle_menu == "fight":
		var usable := false
		for move_id in ally.get("moves",GameData.SPECIES[ally.species].moves):
			var move: Dictionary = GameData.MOVES[move_id]
			var pp := int(ally.get("pp",{}).get(move_id,35))
			var has_pp: bool = pp > 0 or ally.get("charging_move","") == move_id
			if has_pp and PendingItems.move_allowed(ally,str(move_id)): usable = true
			var button := add_button(grid, "%s  ·  %s · %d PP" % [move.name, str(move.type).to_upper(),pp], choose_move.bind(ally_index, str(move_id)),not has_pp or not PendingItems.move_allowed(ally,str(move_id)))
			button.tooltip_text = "Power %d • Accuracy %d%%" % [move.power, int(move.accuracy * 100)] + (" | STAB x1.5" if MoveEffects.stab(ally,str(move.type)) > 1 and move.kind == "damage" else "")
		if not usable: add_button(grid,"STRUGGLE",choose_move.bind(ally_index,"struggle"))
		add_button(commands, "← Back", func(): battle_menu = "main"; show_battle())
	elif battle_menu == "bag":
		var bag_scroll := ScrollContainer.new()
		bag_scroll.custom_minimum_size.y = 110
		bag_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		commands.remove_child(grid)
		commands.add_child(bag_scroll)
		bag_scroll.add_child(grid)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var available_items := battle_items()
		for item_id in available_items:
			var count := int(state.inventory.get(item_id, 0))
			var item: Dictionary = available_items[item_id]
			if count <= 0 or item.status != "implemented" or item.get("pp_upgrade",false): continue
			if item.kind == "escape_item":
				add_button(grid,"Escape Rope ×%d" % count,use_escape_rope,not battle.get("context",{}).get("cave",false) or battle.has("orb_item"))
			elif item.kind == "ball":
				add_button(grid,"%s ×%d" % [item.name,count],choose_ball.bind(ally_index,str(item_id)))
			elif item.kind in ["heal","revive","battle_boost","medicine","cure_berry","pp_medicine"] or item_id in ["item_oran_berry","item_ripe_oran_berry"]:
				var valid := false
				for pokemon in state.party:
					if ItemCatalog.can_apply(item,pokemon): valid = true
				add_button(grid,"%s ×%d" % [item.name,count],choose_battle_item.bind(ally_index,str(item_id)),not valid)
		add_button(commands, "← Back", func(): battle_menu = "main"; show_battle())
	elif battle_menu == "party":
		for i in state.party.size():
			var pokemon: Dictionary = state.party[i]
			add_button(grid, "%s  %d/%d HP" % [GameData.SPECIES[pokemon.species].name, pokemon.hp, pokemon.max_hp], show_pokemon_summary.bind(i,false))
		add_button(commands, "← Back", func(): battle_menu = "main"; show_battle())
	else:
		add_button(grid, "FIGHT", func(): battle_menu = "fight"; show_battle())
		add_button(grid, "BAG", func(): battle_menu = "bag"; show_battle())
		add_button(grid, "POKÉMON", func(): battle_menu = "party"; show_battle())
		add_button(grid, "RUN", flee_battle)
		add_label(commands, "Choose one action for each conscious teammate.", 15, Color("#536b77"))
	for child in grid.get_children(): child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	queue_redraw()

func choose_move(ally_index: int, move_id: String) -> void:
	var move: Dictionary = GameData.MOVES[move_id]
	if move.kind in ["heal","buff"] or int(move.get("target",10)) in [4,5,7,12,13,14]:
		battle.actions.append({"actor":ally_index,"kind":"move","move":move_id,"target":ally_index})
		action_index += 1
		battle_menu = "main"
		show_battle()
	else:
		pending_action = {"actor":ally_index,"kind":"move","move":move_id}
		if living_enemy_indices().size() == 1:
			confirm_target(living_enemy_indices()[0])
		else:
			show_battle()

func choose_ball(ally_index: int, ball_id: String) -> void:
	pending_action = {"actor":ally_index,"kind":"ball","ball":ball_id}
	if living_enemy_indices().size() == 1:
		confirm_target(living_enemy_indices()[0])
	else:
		show_battle()

func confirm_target(enemy_index: int) -> void:
	pending_action.target = enemy_index
	battle.actions.append(pending_action.duplicate(true))
	pending_action = {}
	battle_menu = "main"
	action_index += 1
	show_battle()

func resolve_round() -> void:
	resolving_round = true
	animation_events.clear()
	battle.action_turn = int(battle.get("round",1))
	var messages: Array[String] = []
	for pokemon in state.party+ battle.enemies:
		pokemon.acted_this_turn = false
		pokemon.held_suppressed = int(battle.get("magic_room",0)) > 0
		pokemon.erase("protected")
		pokemon.erase("flinched")
		ItemMechanics.activate_berry(pokemon,GameData.ITEMS,messages)
	var actions: Array = []
	for action in battle.actions:
		var copy: Dictionary = action.duplicate()
		copy.player_side = true
		actions.append(copy)
	if debug_options.enemy_turns:
		for enemy_index in battle.enemies.size():
			var enemy: Dictionary = battle.enemies[enemy_index]
			if int(enemy.hp) <= 0: continue
			var targets := living_party_indices()
			if targets.is_empty(): break
			var choices: Array = []
			for move in enemy.moves:
				if (int(enemy.pp.get(move,0)) > 0 or enemy.get("charging_move","") == move) and PendingItems.move_allowed(enemy,str(move)): choices.append(move)
			if choices.is_empty(): choices.append("struggle")
			actions.append({"player_side":false,"actor":enemy_index,"target":targets[rng.randi_range(0,targets.size()-1)],"kind":"move","move":choices[rng.randi_range(0,choices.size()-1)]})
	for pokemon in state.party+battle.enemies:
		PendingItems.activate(pokemon,battle,rng)
		PendingItems.before_action(pokemon,rng)
	for action in actions:
		action.order = action_speed(action,bool(action.player_side))+rng.randf()*0.001
	actions.sort_custom(func(a: Dictionary,b: Dictionary): return float(a.order) > float(b.order))
	for action in actions:
		if all_enemies_gone() or living_party_indices().is_empty(): break
		var player_side := bool(action.player_side)
		var actor: Dictionary = state.party[int(action.actor)] if player_side else battle.enemies[int(action.actor)]
		if int(actor.hp) <= 0: continue
		var before_party: Array = state.party.duplicate(true)
		var before_enemies: Array = battle.enemies.duplicate(true)
		var message_start := messages.size()
		actor.acted_this_turn = true
		if action.kind == "heal_item": use_heal_in_battle(action,messages)
		elif action.kind == "ball": resolve_ball_action(action,messages)
		elif player_side: resolve_player_move(action,messages)
		else:
			var targets := living_party_indices()
			var target_index := int(action.target)
			if target_index not in targets: target_index = int(targets[0])
			resolve_move(actor,state.party[target_index],str(action.move),messages,false)
		if battle.get("escaped",false):
			resolving_round = false
			flee_battle()
			return
		for pokemon in state.party+battle.enemies: PendingItems.activate(pokemon,battle,rng)
		queue_battle_effect(action,player_side,before_party,before_enemies,messages.slice(message_start))
	for pokemon in state.party+battle.enemies:
		MoveEffects.end_turn(pokemon,battle,rng,messages,state)
		ItemMechanics.activate_berry(pokemon,GameData.ITEMS,messages)
	for key in ["weather_turns","terrain_turns","trick_room","wonder_room","magic_room","gravity"]:
		if int(battle.get(key,0)) > 0: battle[key] = int(battle[key])-1
	if battle.get("weather_turns",1) == 0: battle.erase("weather")
	if battle.get("terrain_turns",1) == 0: battle.erase("terrain")
	award_battle_experience(messages)
	battle.round = int(battle.get("round",1))+1
	battle.actions = []
	action_index = 0
	pending_action = {}
	battle_log = messages if not messages.is_empty() else ["Everyone watched the breeze for a moment."]
	resolving_round = false
	battle_finished = all_enemies_gone()
	if is_endless(): save_game()
	if animation_enabled and not animation_events.is_empty():
		play_round_animation()
	else:
		finish_round_presentation()

func resolve_player_move(action: Dictionary, messages: Array[String]) -> void:
	var actor: Dictionary = state.party[int(action.actor)]
	var move: Dictionary = GameData.MOVES[str(action.move)]
	if int(move.get("target",10)) in [9,11]:
		if not MoveEffects.can_act(actor,str(action.move),rng,messages): return
		if actor.has("pp"): actor.pp[str(action.move)] = maxi(0,int(actor.pp.get(str(action.move),35))-1)
		for enemy in battle.enemies:
			if int(enemy.hp) > 0: resolve_move(actor,enemy,str(action.move),messages,true,false)
		return
	if move.kind in ["heal","buff"] or int(move.get("target",10)) in [4,5,7,12,13,14]:
		resolve_move(actor,actor,str(action.move),messages,true)
		return
	var target_index := int(action.target)
	if target_index < 0 or target_index >= battle.enemies.size() or battle.enemies[target_index].hp <= 0:
		var alternatives := living_enemy_indices()
		if alternatives.is_empty(): return
		target_index = alternatives[0]
	resolve_move(actor,battle.enemies[target_index],str(action.move),messages,true)

func resolve_move(actor: Dictionary, target: Dictionary, move_id: String, messages: Array[String], player_actor: bool, check_action: bool = true) -> void:
	var move: Dictionary = GameData.MOVES[move_id]
	if check_action and not MoveEffects.can_act(actor,move_id,rng,messages):
		actor.metronome_count = 0
		ItemMechanics.activate_berry(actor,GameData.ITEMS,messages)
		return
	if check_action and move_id != "struggle" and actor.has("pp") and actor.get("charging_move","") != move_id:
		actor.pp[move_id] = maxi(0,int(actor.pp.get(move_id,35))-1)
	actor.acted_this_turn = true
	if move.has("effect_id") or move.kind in ["damage","heal","buff","debuff"]:
		MoveEffects.resolve(actor,target,move_id,battle,state,rng,messages,enemy_damage_scale() if not player_actor else 1.0,player_actor and debug_options.accuracy,player_actor and debug_options.one_hit,not player_actor and debug_options.invincible)
		ItemMechanics.activate_berry(actor,GameData.ITEMS,messages)
		ItemMechanics.activate_berry(target,GameData.ITEMS,messages)
		return
	var actor_name := str(GameData.SPECIES[actor.species].name)
	var target_name := str(GameData.SPECIES[target.species].name)
	if target.get("protected",false) or (rng.randf() > MoveEffects.accuracy(actor,target,move) and not (actor.get("accuracy_bypass",false) or (player_actor and debug_options.accuracy))):
		messages.append("%s used %s, but missed!" % [actor_name,move.name])
		return
	match str(move.kind):
		"heal":
			var before := int(actor.hp)
			actor.hp = min(actor.max_hp,actor.hp + int(move.power))
			messages.append("%s used %s and restored %d HP." % [actor_name,move.name,actor.hp-before])
		"buff":
			ItemMechanics.raise_stat(actor,"attack",1)
			messages.append("%s used %s. Its attack rose!" % [actor_name,move.name])
		"debuff":
			ItemMechanics.raise_stat(target,"attack",-1)
			messages.append("%s used %s. %s's attack fell!" % [actor_name,move.name,target_name])
		_:
			var attack_stat := "special_attack" if int(move.get("damage_class",2)) == 3 else "attack"
			var defense_stat := "special_defense" if int(move.get("damage_class",2)) == 3 else "defense"
			var effect := MoveEffects.effectiveness(str(move.type),target)
			var boosted_power := float(move.power) * MoveEffects.stab(actor,str(move.type)) * (0.5 if actor.get("status_condition","") == "burn" and attack_stat == "attack" else 1.0) * ItemCatalog.move_power_multiplier(actor,str(move.type))
			if effect == 0:
				messages.append("%s has no effect on %s." % [move.name,target_name])
				return
			var damage := GameRules.calculate_damage(boosted_power,ItemMechanics.stat(actor,attack_stat),ItemMechanics.stat(target,defense_stat),effect,rng.randf_range(0.9,1.1))
			if not player_actor:
				damage = max(1, int(round(damage * enemy_damage_scale())))
			if not player_actor and debug_options.invincible: damage = 0
			if player_actor and debug_options.one_hit: damage = int(target.hp)
			target.hp = max(0,target.hp-damage)
			var suffix := " It's super effective!" if effect > 1.0 else (" It's not very effective." if effect < 1.0 else "")
			messages.append("%s used %s on %s for %d damage.%s" % [actor_name,move.name,target_name,damage,suffix])
			if target.hp <= 0:
				messages.append("%s fainted!" % target_name)
	ItemMechanics.activate_berry(actor,GameData.ITEMS,messages)
	ItemMechanics.activate_berry(target,GameData.ITEMS,messages)

func resolve_ball_action(action: Dictionary, messages: Array[String]) -> void:
	var ball_id := str(action.ball)
	var available := battle_items()
	if not available.has(ball_id) or available[ball_id].kind != "ball" or available[ball_id].status != "implemented": return
	if int(state.inventory.get(ball_id,0)) <= 0: return
	var target_index := int(action.target)
	if target_index < 0 or target_index >= battle.enemies.size() or battle.enemies[target_index].hp <= 0:
		var alternatives := living_enemy_indices()
		if alternatives.is_empty(): return
		target_index = alternatives[0]
	var target: Dictionary = battle.enemies[target_index]
	if not debug_options.unlimited_items: state.inventory[ball_id] -= 1
	var item: Dictionary = available[ball_id]
	var context: Dictionary = battle.get("context",{}).duplicate()
	context.turn = int(battle.get("action_turn",battle.get("round",1)))
	var multiplier := ItemMechanics.ball_multiplier(ball_id,target,state.party[int(action.actor)],context,state.get("caught_species",[]),item)
	var guaranteed: bool = ball_id == "item_master_ball" or (ball_id == "item_dreamy_ball" and bool(context.get("entree_forest",false)))
	var chance := 1.0 if guaranteed else (GameRules.capture_chance(float(item.bonus),target.hp,target.max_hp) if ball_id in ["apricorn_ball","great_apricorn_ball"] else ItemMechanics.capture_chance(multiplier,target))
	var name := str(GameData.SPECIES[target.species].name)
	if rng.randf() <= chance or debug_options.capture:
		target.hp = max(1,target.hp)
		var caught := target.duplicate(true)
		if caught.has("boss_normal_hp"):
			var ratio := float(caught.hp)/float(caught.max_hp)
			caught.max_hp = int(caught.boss_normal_hp)
			caught.hp = maxi(1,int(ceil(ratio*float(caught.max_hp))))
			caught.erase("boss_normal_hp")
			caught.held_item = ""
		ItemMechanics.reset_battle(caught)
		caught.capture_ball = ball_id
		caught.met_node = str(battle.node_id)
		if ball_id == "item_friend_ball": caught.friendship = 200
		if state.party.size() < 3:
			state.party.append(caught)
		else:
			state.reserve.append(caught)
		if not state.has("caught_species"): state.caught_species = []
		if str(target.species) not in state.caught_species: state.caught_species.append(str(target.species))
		register_dex(str(target.species), true)
		target.captured = true
		target.hp = 0
		messages.append("Click... sparkle! %s joined your reserve box!" % name)
	else:
		messages.append("%s popped free of the %s!" % [name,item.name])

func battle_items() -> Dictionary:
	var result := GameData.ITEMS.duplicate()
	if state.get("enabled_dlc","") == "spinoff": result.merge(GameData.DLC_ITEMS)
	return result

func item_definition(id: String) -> Dictionary:
	if GameData.ITEMS.has(id): return GameData.ITEMS[id]
	if GameData.DLC_ITEMS.has(id): return GameData.DLC_ITEMS[id]
	return {"id":id,"name":id.trim_prefix("item_").replace("_"," ").capitalize(),"category":"Stored legacy items","rarity":"common","kind":"collectible","status":"awaiting_mechanics","description":"Retained from an older save.","requirement":"Legacy item effect"}

func finish_victory() -> void:
	if battle.has("orb_item"):
		finish_orb_boss("capture" if battle.enemies[0].get("captured",false) else "knockout")
		return
	var experience_messages: Array[String] = []
	award_battle_experience(experience_messages)
	for pokemon in state.party: ItemMechanics.reset_battle(pokemon)
	if is_endless():
		if state.run.get("pending_upgrade",false): show_upgrade(); return
		grant_items(battle.rewards)
		mark_cleared(str(battle.node_id))
		state.current_node = str(battle.node_id)
		state.run.pending_upgrade = true
		state.erase("battle_checkpoint")
		show_upgrade()
		save_game()
		return
	restore_party()
	grant_items(battle.rewards)
	mark_cleared(str(battle.node_id))
	state.current_node = str(battle.node_id)
	save_game()
	show_map("Team fully rested! Rewards: " + reward_text(battle.rewards))

func handle_defeat() -> void:
	if battle.has("orb_item"):
		finish_orb_boss("loss")
		return
	if is_endless():
		state.run.ended = true
		state.erase("battle_checkpoint")
		show_run_end()
		save_game()
		return
	restore_party()
	state.current_node = str(battle.return_node)
	save_game()
	battle = {}
	show_map("Your team is fully rested. Try a different move or return whenever you are ready.")

func flee_battle() -> void:
	if battle.has("orb_item"):
		finish_orb_boss("loss")
		return
	for pokemon in state.party: ItemMechanics.reset_battle(pokemon)
	if is_endless():
		state.current_node = "run_%d" % int(state.run.depth)
		state.erase("battle_checkpoint")
		battle = {}
		focus_current_stop()
		show_map("Retreated. Your HP and supplies carry over.")
		save_game()
		return
	state.current_node = str(battle.return_node)
	save_game()
	battle = {}
	show_map("You safely left the encounter. Its wild Pokémon will be waiting.")

func show_ending() -> void:
	mark_cleared("lookout")
	state.finished = true
	save_game()
	screen = Screen.ENDING
	clear_ui()
	var box := make_panel(Rect2(250, 365, 780, 290), Color("#fff4d6f2"))
	var title := add_label(box, "ISLAND ADVENTURE COMPLETE!", 34, COLOR_GREEN)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_label(box, "Your team reaches the lookout as sunset colors dance over the sea. The island still holds friends to catch and paths to revisit.", 21)
	add_label(box, "Reserve friends: %d   •   Map progress: %s" % [state.reserve.size(),progress_text()], 18)
	add_button(box, "Return to Island Map", show_map)
	add_button(box, "Title Screen", show_title)

func living_party_indices() -> Array[int]:
	var result: Array[int] = []
	for i in state.party.size():
		if int(state.party[i].hp) > 0: result.append(i)
	return result

func living_enemy_indices() -> Array[int]:
	var result: Array[int] = []
	for i in battle.enemies.size():
		if int(battle.enemies[i].hp) > 0: result.append(i)
	return result

func all_enemies_gone() -> bool:
	return living_enemy_indices().is_empty()

func grant_items(rewards: Dictionary) -> void:
	var received := {}
	for item_id in rewards:
		for count in int(rewards[item_id]):
			var target: String = "item_sacred_ash_ketchum" if item_id == "item_sacred_ash" and rng.randi_range(1,100) == 1 else str(item_id)
			received[target] = int(received.get(target,0))+1
			state.inventory[target] = int(state.inventory.get(target,0)) + 1
	rewards.clear()
	rewards.merge(received)

func reward_text(rewards: Dictionary) -> String:
	var parts: Array[String] = []
	for item_id in rewards:
		parts.append("%s ×%d" % [GameData.ITEMS[item_id].name,rewards[item_id]])
	return ", ".join(parts)

func mark_cleared(node_id: String) -> void:
	if is_endless():
		var previous_depth := int(state.run.depth)
		state.run.depth = maxi(int(state.run.depth),int(node_id.trim_prefix("run_")))
		BossOrbs.cleared_levels(state,int(state.run.depth)-previous_depth,rng)
		state.run.best = maxi(int(state.run.get("best",0)),int(state.run.depth))
		return
	if node_id not in state.cleared:
		state.cleared.append(node_id)
		BossOrbs.cleared_levels(state,1,rng)

func progress_text() -> String:
	if is_endless(): return "Depth %d  •  Best %d  •  Endless" % [state.run.depth,state.run.best]
	var completed := 0
	for node in map_nodes():
		if str(node.id) in state.cleared: completed += 1
	return "Island progress: %d / %d" % [completed,map_nodes().size()]

func get_node_data(node_id: String) -> Dictionary:
	if is_endless(): return RogueRules.node(int(state.run.seed),int(node_id.trim_prefix("run_")))
	for node in map_nodes():
		if str(node.id) == node_id: return node
	return map_nodes()[0]

func node_unlocked(node: Dictionary) -> bool:
	if debug_options.travel and not is_endless(): return true
	if is_endless(): return int(node.floor) <= int(state.run.depth)+1 and not state.run.ended
	if str(node.id) in state.cleared: return true
	for prereq in node.prereq:
		if str(prereq) not in state.cleared: return false
	return true

func can_travel_to(node_id: String) -> bool:
	if node_id == str(state.current_node): return false
	return node_unlocked(get_node_data(node_id))

func travel_to(node_id: String) -> void:
	if not can_travel_to(node_id): return
	trainer_from = world_to_screen(get_node_data(str(state.current_node)).pos)
	trainer_slide = 0.0
	sfx.play_effect("travel")
	state.current_node = node_id
	focus_current_stop()
	save_game()
	if secret_available(get_node_data(node_id)):
		show_secret_hall()
		return
	show_map("Choose an activity below to explore this place.")

func change_zoom(delta: float) -> void:
	map_zoom = clamp(map_zoom + delta,0.64,1.36)
	if map_zoom <= 0.7: map_pan = Vector2.ZERO
	queue_redraw()
	show_map(status_message)

func save_game() -> bool:
	if resolving_round: return false
	if (is_endless() and screen == Screen.BATTLE and not battle.is_empty()) or battle.has("orb_item"):
		state.battle_checkpoint = battle.duplicate(true)
		state.battle_checkpoint.actions = []
		state.battle_checkpoint.finished = battle_finished
	if not state.has("party"): return false
	sync_pokedex()
	ItemCatalog.migrate(state)
	FunRules.initialize(state)
	var path := RUN_SAVE_PATH if is_endless() else SAVE_PATH
	var file := FileAccess.open(path + ".tmp",FileAccess.WRITE)
	if not file: return false
	file.store_string(JSON.stringify(state,"  "))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK: return false
	return DirAccess.rename_absolute(path + ".tmp",path) == OK

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH): return false
	var file := FileAccess.open(SAVE_PATH,FileAccess.READ)
	if not file: return false
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY: return false
	if not parsed.has("party") or not parsed.has("inventory") or not parsed.has("current_node"): return false
	state = parsed
	sync_pokedex()
	ItemCatalog.migrate(state)
	FunRules.initialize(state)
	return true

func apply_settings() -> void:
	if not state.has("settings"): return
	AudioServer.set_bus_volume_db(0,linear_to_db(max(0.001,float(state.settings.get("volume",0.8)))))
	AudioServer.set_bus_mute(0,float(state.settings.get("volume",0.8)) <= 0.0)
	animation_enabled = bool(state.settings.get("animations",true)) and DisplayServer.get_name() != "headless"
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if bool(state.settings.get("fullscreen",false)) else DisplayServer.WINDOW_MODE_WINDOWED)

func _input(event: InputEvent) -> void:
	if screen == Screen.SECRET_HALL:
		if event is InputEventKey and is_instance_valid(secret_hall): secret_hall.handle_key(event)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if get_viewport().gui_get_focus_owner() is LineEdit:
			debug_keys.clear()
		else:
			debug_keys.append(event.physical_keycode if event.physical_keycode != 0 else event.keycode)
			if debug_keys.size() > DEBUG_CODE.size(): debug_keys.pop_front()
			if debug_keys == DEBUG_CODE:
				debug_keys.clear()
				if screen == Screen.DEBUG: close_debug()
				else: open_debug()
				get_viewport().set_input_as_handled()
				return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E:
		# Let the catalog search field accept normal typing.
		if get_viewport().gui_get_focus_owner() is LineEdit: return
		if screen == Screen.INVENTORY:
			show_map()
		elif screen == Screen.CHEST:
			show_map()
		elif screen in [Screen.MAP, Screen.PARTY]:
			show_inventory()
		else: return
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if battle_busy: return
	if screen == Screen.DEBUG and event.is_action_pressed("pause_menu"):
		close_debug()
		return
	if event.is_action_pressed("pause_menu"):
		if screen == Screen.MAP: open_settings(Screen.MAP)
		elif screen == Screen.SETTINGS:
			if character_customization_open: open_settings(settings_return)
			else: close_settings()
		elif screen == Screen.STARTER: show_title()
		elif screen == Screen.BATTLE and not battle_finished:
			pending_action = {}
			battle_menu = "main"
			show_battle()
		elif screen == Screen.SUMMARY: close_pokemon_summary()
		elif screen in [Screen.PARTY,Screen.INVENTORY,Screen.BOX,Screen.POKEDEX]: show_map()
		return
	if screen == Screen.SUMMARY and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_LEFT: ui.get_child(0).browse(-1)
		elif event.keycode == KEY_RIGHT: ui.get_child(0).browse(1)
		return
	if screen != Screen.MAP: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_HOME:
			focus_current_stop()
			queue_redraw()
		elif event.keycode == KEY_P: show_party()
		elif event.keycode == KEY_D: show_pokedex()
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			scroll_route(110)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			scroll_route(-110)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if not MAP_RECT.has_point(event.position): return
				drag_origin = event.position
				drag_moved = false
				dragging_map = true
				drag_last = event.position
			else:
				if dragging_map and not drag_moved and MAP_RECT.has_point(event.position):
					try_click_node(event.position)
				dragging_map = false
	if event is InputEventMouseMotion and dragging_map:
		if event.position.distance_to(drag_origin) > 8: drag_moved = true
		if not drag_moved: return
		scroll_route(event.relative.x)
		drag_last = event.position - event.relative
		queue_redraw()

func try_click_node(mouse_pos: Vector2) -> void:
	for node in map_nodes():
		if not node_unlocked(node): continue
		var offset: Vector2 = (mouse_pos - world_to_screen(node.pos)) / (Vector2(39, 28) * map_zoom)
		if offset.length_squared() <= 1.0:
			travel_to(str(node.id))
			return

func world_to_screen(world: Vector2) -> Vector2:
	for index in map_nodes().size():
		if map_nodes()[index].pos == world:
			return Vector2(84+index*136+map_pan.x,550)
	return Vector2(84,550)

func _draw() -> void:
	match screen:
		Screen.TITLE: draw_title_background()
		Screen.INTRO: draw_intro_background()
		Screen.MAP,Screen.PARTY,Screen.INVENTORY,Screen.SETTINGS: draw_map_background()
		Screen.BATTLE: draw_battle_background()
		Screen.ENDING: draw_ending_background()
		Screen.UPGRADE,Screen.RUN_END,Screen.CHEST,Screen.BOX,Screen.SUMMARY: draw_rect(Rect2(Vector2.ZERO,size),Color("#dbe9df"))

func draw_title_background() -> void:
	draw_rect(Rect2(Vector2.ZERO,size), Color("#174c60"))
	for i in 3:
		draw_sprite(["bulbasaur", "charmander", "squirtle"][i], Vector2(100+i*140, 798), false, 110)

func draw_intro_background() -> void:
	draw_rect(Rect2(Vector2.ZERO,size), Color("#b8e1e0"))
	if island_texture and intro_page == 0: draw_texture_rect(island_texture, Rect2(770,-80,550,550),false)
	draw_circle(Vector2(190,120), 58, Color("#fff1b7"))
	if intro_page == 0:
		draw_string(ThemeDB.fallback_font, Vector2(90,100), "NEXT STOP", HORIZONTAL_ALIGNMENT_LEFT, 560, 18, COLOR_INK)
		draw_string(ThemeDB.fallback_font, Vector2(90,170), "Apricorn Island", HORIZONTAL_ALIGNMENT_LEFT, 650, 52, COLOR_INK)
		draw_rect(Rect2(235,290,330,26), COLOR_CREAM)
		draw_colored_polygon(PackedVector2Array([Vector2(315,290),Vector2(405,220),Vector2(440,290)]), COLOR_CREAM)
		draw_colored_polygon(PackedVector2Array([Vector2(315,316),Vector2(405,365),Vector2(445,316)]), COLOR_CREAM)
		draw_circle(Vector2(565,303), 17, COLOR_CORAL)
	else:
		for i in state.party.size():
			var center := Vector2(640,290)
			draw_circle(center, 102, Color("#ffffff70"))
			draw_sprite(state.party[i].species, center, false, 235)
			draw_string(ThemeDB.fallback_font, center+Vector2(-100,135), str(GameData.SPECIES[state.party[i].species].name).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 200, 17, COLOR_INK)

func draw_map_background() -> void:
	# Quiet pastel bands and a few pixel-shaped hills leave the route readable.
	draw_rect(Rect2(Vector2.ZERO,size),Color("#f7f8df"))
	var colors := [Color("#edddf5"),Color("#f0e3f1"),Color("#f3ebed"),Color("#f5f1e6")]
	for i in 4: draw_rect(Rect2(0,i*100,480,100),colors[i])
	for hill in [Vector3(30,395,60),Vector3(150,390,46),Vector3(400,420,64)]:
		var tint := Color("#c5e6df") if hill.x < 200 else Color("#e6edb8")
		draw_rect(Rect2(hill.x-hill.z,hill.y-hill.z,2*hill.z,135),tint)
		draw_rect(Rect2(hill.x-hill.z+12,hill.y-hill.z-12,2*hill.z-24,12),tint)
		draw_rect(Rect2(hill.x-hill.z+24,hill.y-hill.z-20,2*hill.z-48,8),tint)
		draw_rect(Rect2(hill.x-18,hill.y-35,12,16),tint.darkened(0.035))
		draw_rect(Rect2(hill.x+16,hill.y+5,12,16),tint.darkened(0.035))
	for cloud in [Vector2(32,300),Vector2(312,328)]:
		draw_rect(Rect2(cloud,Vector2(62,8)),Color("#fffdf4"))
		draw_rect(Rect2(cloud+Vector2(14,-8),Vector2(30,8)),Color("#fffdf4"))
	if state.has("cleared"):
		var first := world_to_screen(map_nodes().front().pos)
		var last := world_to_screen(map_nodes().back().pos)
		draw_line(first+Vector2(0,5),last+Vector2(0,5),Color("#717a7766"),15*map_zoom,false)
		draw_line(first,last,Color.WHITE,15*map_zoom,false)
		for node in map_nodes():
			var point := world_to_screen(node.pos)
			var current: bool = str(node.id) == str(state.current_node)
			var color := Color("#979d9f")
			if node_unlocked(node): color = Color("#78cbb6")
			if current: color = Color("#36a8f2")
			var radius: float = (39.0 if current else 32.0) * map_zoom
			# Squashed circular pads echo the reference's simple raised oval stops.
			draw_set_transform(point+Vector2(0,6),0,Vector2(1,0.65))
			draw_circle(Vector2.ZERO,radius,Color("#7b83817a"))
			draw_set_transform(point+Vector2(0,3),0,Vector2(1,0.65))
			draw_circle(Vector2.ZERO,radius,Color("#dee3de"))
			draw_set_transform(point,0,Vector2(1,0.65))
			draw_circle(Vector2.ZERO,radius,Color.WHITE)
			draw_circle(Vector2.ZERO,radius-7*map_zoom,color)
			draw_set_transform(Vector2.ZERO)
			var milestone: bool = is_endless() and int(node.floor) > 0 and int(node.floor) % 10 == 0
			if milestone or (not is_endless() and str(node.kind) == "chest"):
				var chest_id := "milestone_%d" % int(node.floor) if milestone else str(node.id)
				draw_pixel_chest(point + Vector2(-24,-46), 3.0 * map_zoom, false, chest_id in state.opened_chests)
		# Draw the trainer last so it is always standing in front of the track.
		if trainer_texture and state.has("current_node"):
			var target := world_to_screen(get_node_data(str(state.current_node)).pos)
			var point := trainer_from.lerp(target,smoothstep(0.0,1.0,trainer_slide)) if trainer_slide < 1.0 else target
			point.y -= abs(sin(elapsed*12.0))*3.0 if trainer_slide < 1.0 else sin(elapsed*2.5)*1.0
			var extent := Vector2(70,94)*map_zoom
			draw_texture_rect(trainer_texture,Rect2(point+Vector2(-35,-90)*map_zoom,extent),false)
			var trainer_name := str(trainer_style.profile.name)
			var font := ThemeDB.fallback_font
			var name_point := point + Vector2(-font.get_string_size(trainer_name,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x/2.0,20)
			draw_string_outline(font,name_point,trainer_name,HORIZONTAL_ALIGNMENT_LEFT,-1,14,4,COLOR_CREAM)
			draw_string(font,name_point,trainer_name,HORIZONTAL_ALIGNMENT_LEFT,-1,14,COLOR_INK)

func draw_battle_background() -> void:
	var ocean_boss: bool = battle.get("orb_item","") == "item_blue_orb"
	var volcano: bool = battle.get("node_id", "") == "summit" or battle.get("orb_item","") == "item_red_orb"
	draw_rect(Rect2(Vector2.ZERO,size), Color("#e7c8a6") if volcano else Color("#d9ecda"))
	draw_rect(Rect2(0,0,1280,240), Color("#d9aaa0") if volcano else Color("#b4dfdf"))
	draw_circle(Vector2(1070,85), 44, Color("#fff0bd"))
	for x in range(-80,1300,260):
		draw_colored_polygon(PackedVector2Array([Vector2(x,240),Vector2(x+150,120),Vector2(x+350,240)]), Color("#ad8b84") if volcano else Color("#8fbeb0"))
	if ocean_boss:
		draw_rect(Rect2(Vector2.ZERO,size),Color("#142b63"))
		for y in range(70,430,50): draw_line(Vector2(0,y),Vector2(1280,y+20),Color("#407fb0"),6)
	var shown_enemies: Array = visual_enemies if battle_busy else battle.get("enemies",[])
	for i in shown_enemies.size():
		var enemy: Dictionary = shown_enemies[i]
		var pos := Vector2(745+i*190, 250)
		draw_set_transform(pos+Vector2(0,55),0,Vector2(1,0.25))
		draw_circle(Vector2.ZERO,85,Color("#52695535"))
		draw_set_transform(Vector2.ZERO)
		draw_creature(animated_position(pos,false,i),enemy,true)
		draw_status_card(Rect2(pos.x-85,45,176,75),enemy,false)
	var shown_party: Array = visual_party if battle_busy else state.get("party",[])
	for i in shown_party.size():
		var ally: Dictionary = shown_party[i]
		var pos := Vector2(150+i*195,355)
		draw_set_transform(pos+Vector2(0,55),0,Vector2(1,0.25))
		draw_circle(Vector2.ZERO,88,Color("#52695535"))
		draw_set_transform(Vector2.ZERO)
		draw_creature(animated_position(pos,true,i),ally,false)
		var living := living_party_indices()
		var active: bool = not battle_finished and action_index < living.size() and living[action_index] == i
		draw_status_card(Rect2(pos.x-85,402,176,94),ally,active)
	draw_move_effect()

func draw_creature(center: Vector2, pokemon: Dictionary, facing_left: bool) -> void:
	var data: Dictionary = GameData.SPECIES[pokemon.species]
	var body := Color(data.color)
	var accent := Color(data.accent)
	var faded := 0.35 if int(pokemon.hp) <= 0 else 1.0
	body.a = faded
	accent.a = faded
	draw_sprite(str(pokemon.get("form",pokemon.species)), center, not facing_left, 230, faded)

func draw_hp_bar(pos: Vector2, pokemon: Dictionary) -> void:
	draw_rect(Rect2(pos,Vector2(110,15)),COLOR_INK)
	var ratio: float = clamp(float(pokemon.hp)/float(max(1,pokemon.max_hp)),0.0,1.0)
	var color: Color = COLOR_GREEN if ratio > 0.5 else (COLOR_GOLD if ratio > 0.2 else COLOR_CORAL)
	draw_rect(Rect2(pos+Vector2(3,3),Vector2(104*ratio,9)),color)

func draw_ending_background() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("#ef9a71"))
	draw_circle(Vector2(640,300),130,Color("#ffd66b"))
	draw_rect(Rect2(0,365,1280,355),Color("#267f9b"))
	for y in range(390,720,45):
		draw_line(Vector2(0,y),Vector2(1280,y-20),Color("#85d8d7"),5)
	for x in range(100,1200,180):
		draw_circle(Vector2(x,355),40,Color("#3e8d62"))

func restore_party() -> void:
	for pokemon in state.party:
		ItemMechanics.reset_battle(pokemon)
		pokemon.hp = pokemon.max_hp
		pokemon.status_condition = ""
		pokemon.erase("sleep_turns")
		pokemon.erase("confusion_turns")
		for move_id in pokemon.get("moves",[]): pokemon.pp[move_id] = PendingItems.max_pp(pokemon,move_id)

func enemy_damage_scale() -> float:
	var base: float = {"easy":0.45, "normal":0.65, "hard":1.0}.get(state.settings.get("difficulty", "normal"), 0.65)
	return base * (0.9 if battle.get("node_id", "") == "summit" else 1.0)

func choose_battle_heal(actor: int, item_id: String) -> void:
	battle.actions.append({"actor":actor,"kind":"heal_item","item":item_id})
	action_index += 1
	battle_menu = "main"
	show_battle()

func choose_battle_item(actor: int, item_id: String) -> void:
	pending_action = {"actor":actor,"kind":"heal_item","item":item_id}
	show_battle()

func confirm_item_target(target: int) -> void:
	if pending_action.is_empty() or target < 0 or target >= state.party.size(): return
	var item_id := str(pending_action.item)
	if int(state.inventory.get(item_id,0)) <= 0 or not ItemCatalog.can_apply(GameData.ITEMS[item_id],state.party[target]): return
	pending_action.target = target
	if GameData.ITEMS[item_id].kind == "pp_medicine":
		show_battle()
		return
	battle.actions.append(pending_action.duplicate())
	pending_action = {}
	action_index += 1
	battle_menu = "main"
	show_battle()

func use_heal_in_battle(action: Dictionary, messages: Array[String]) -> void:
	var item_id := str(action.item)
	if not GameData.ITEMS.has(item_id): return
	if int(state.inventory.get(item_id,0)) <= 0: return
	var target := int(action.get("target",action.actor))
	if target < 0 or target >= state.party.size(): return
	var actor: Dictionary = state.party[target]
	if GameData.ITEMS[item_id].kind == "pp_medicine":
		if not PendingItems.pp_use(GameData.ITEMS[item_id],actor,str(action.get("pp_move","")),true): return
	elif not ItemCatalog.apply(GameData.ITEMS[item_id],actor): return
	if not debug_options.unlimited_items and not GameData.ITEMS[item_id].get("reusable",false): state.inventory[item_id] -= 1
	messages.append("%s %s %s." % [GameData.SPECIES[actor.species].name,"used" if GameData.ITEMS[item_id].kind == "battle_boost" else "recovered with",GameData.ITEMS[item_id].name])

func action_speed(action: Dictionary, player_side: bool) -> float:
	var actor: Dictionary = state.party[int(action.actor)] if player_side else battle.enemies[int(action.actor)]
	var priority := 6 if action.kind in ["ball","heal_item"] else MoveEffects.move_priority(actor,GameData.MOVES[str(action.move)])
	var speed := float(ItemMechanics.stat(actor,"speed"))
	if actor.get("quashed",false): return -100000000.0
	if int(actor.get("tailwind",0)) > 0: speed *= 2
	if actor.get("status_condition","") == "paralysis": speed *= 0.5
	if int(battle.get("trick_room",0)) > 0: speed = -speed
	var bracket := 0.0
	if PendingItems.held(actor) in ["item_lagging_tail","item_full_incense"] or actor.get("ability","") == "stall": bracket = -200000.0
	elif actor.get("quick_first",false): bracket = 200000.0
	return priority*1000000.0+bracket+clampf(speed,-99999,99999)

func award_battle_experience(messages: Array[String]) -> void:
	var mode := str(state.get("exp_mode","classic"))
	if mode == "modern" and int(state.inventory.get("item_exp_share",0)) <= 0: mode = "classic"
	if mode == "all" and int(state.inventory.get("item_exp_all",0)) <= 0: mode = "classic"
	for enemy in battle.get("enemies",[]):
		if int(enemy.hp) > 0 or enemy.get("experience_awarded",false) or enemy.get("fled",false): continue
		enemy.experience_awarded = true
		if enemy.get("captured",false) and mode != "modern": continue
		var generation := 1 if mode == "all" else int(state.get("modern_exp_generation",6) if mode == "modern" else state.get("classic_exp_generation",3))
		var enemy_level := int(enemy.get("level",5))
		var total := maxi(1,int(float(ItemMechanics.species(enemy).get("base_experience",50))*enemy_level/(5.0 if generation in [5,7] else 7.0)))
		var shares := ItemMechanics.experience_shares(state.party,battle.get("participants",living_party_indices()),total,mode)
		for i in state.party.size():
			if int(shares[i]) <= 0: continue
			if generation in [5,7]: shares[i] = int(float(shares[i])*pow((2.0*enemy_level+10.0)/(enemy_level+int(state.party[i].level)+10.0),2.5))+1
			var pokemon: Dictionary = state.party[i]
			pokemon.at_met_location = pokemon.get("met_node","") == str(battle.node_id)
			if generation <= 2:
				for stat in ItemMechanics.species(enemy).stats:
					pokemon.stat_experience[stat] = mini(65535,int(pokemon.stat_experience.get(stat,0))+int(ItemMechanics.species(enemy).stats[stat]))
			else:
				for stat in ItemMechanics.species(enemy).get("ev_yield",{}):
					var ev_total := 0
					for value in pokemon.evs.values(): ev_total += int(value)
					pokemon.evs[stat] = mini(252,int(pokemon.evs.get(stat,0))+mini(510-ev_total,int(ItemMechanics.species(enemy).ev_yield[stat])))
			var power_stat := str(PendingItems.POWER_STATS.get(PendingItems.held(pokemon),""))
			if power_stat != "":
				var ev_total := 0
				for value in pokemon.evs.values(): ev_total += int(value)
				pokemon.evs[power_stat] = mini(252,int(pokemon.evs.get(power_stat,0))+mini(4,maxi(0,510-ev_total)))
			PendingItems.apply_ev_bonuses(pokemon)
			var levels := ItemMechanics.grant_experience(state.party[i],int(shares[i]))
			messages.append("%s gained %d EXP%s." % [GameData.SPECIES[state.party[i].species].name,int(shares[i])," and reached level %d" % int(state.party[i].level) if levels > 0 else ""])

func draw_sprite(species_id: String, center: Vector2, back := false, extent := 192.0, opacity := 1.0) -> void:
	var image_species := "giratina-altered" if species_id == "giratina" else species_id
	var key := image_species + ("_back" if back else "_front")
	if sprites.has(key):
		draw_texture_rect(sprites[key],Rect2(center-Vector2.ONE*extent/2,Vector2.ONE*extent),false,Color(1,1,1,opacity))

func draw_status_card(rect: Rect2, pokemon: Dictionary, active: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#fff9e9")
	style.border_color = COLOR_CORAL if active else Color("#709589")
	style.set_border_width_all(3 if active else 2)
	style.set_corner_radius_all(9)
	draw_style_box(style,rect)
	draw_string(ThemeDB.fallback_font,rect.position+Vector2(10,23),"%s Lv.%d" % [GameData.SPECIES[pokemon.species].name,int(pokemon.get("level",5))],HORIZONTAL_ALIGNMENT_LEFT,156,16,COLOR_INK)
	draw_hp_bar(rect.position+Vector2(10,33),pokemon)
	draw_string(ThemeDB.fallback_font,rect.position+Vector2(10,65),"%d/%d %s" % [pokemon.hp,pokemon.max_hp,MoveEffects.status_label(pokemon)],HORIZONTAL_ALIGNMENT_LEFT,156,14,COLOR_INK)
	if rect.size.y > 80:
		var progress := ItemMechanics.level_progress(pokemon)
		draw_rect(Rect2(rect.position+Vector2(10,72),Vector2(156,5)),Color("#c8d2dc"))
		draw_rect(Rect2(rect.position+Vector2(10,72),Vector2(156*float(progress.ratio),5)),Color("#508fe0"))
		draw_string(ThemeDB.fallback_font,rect.position+Vector2(10,89),"MAX LEVEL" if int(pokemon.level) >= 100 else "%d EXP to next level" % int(progress.remaining),HORIZONTAL_ALIGNMENT_LEFT,156,11,COLOR_INK)

func is_endless() -> bool:
	return state.get("mode","") == "endless"

func map_nodes() -> Array:
	if not is_endless(): return GameData.NODES
	var key := "%d:%d" % [state.run.seed,state.run.depth]
	if route_cache_key != key:
		route_cache_key = key
		route_cache = []
		var first := maxi(0,int(state.run.depth)-2)
		for i in 12: route_cache.append(RogueRules.node(int(state.run.seed),first+i))
	return route_cache

func start_endless(starter := "") -> void:
	if starter not in STARTERS:
		show_starter_selection(true)
		return
	var preferences: Dictionary = state.get("settings",{"volume":0.8,"fullscreen":false,"difficulty":"normal"}).duplicate(true)
	var best := 0
	if FileAccess.file_exists(RUN_SAVE_PATH):
		var previous = JSON.parse_string(FileAccess.get_file_as_string(RUN_SAVE_PATH))
		if previous is Dictionary: best = int(previous.get("run",{}).get("best",0))
	state = {"version":2,"mode":"endless","current_node":"run_0","cleared":[],"opened_chests":[],"party":[GameData.make_pokemon(starter)],"reserve":[],"inventory":{"potion":3,"super_potion":1,"berry":2,"apricorn_ball":6,"great_apricorn_ball":1},"settings":preferences,"run":{"seed":rng.randi_range(1,2000000000),"depth":0,"best":best,"ended":false,"pending_upgrade":false}}
	battle = {}
	focus_current_stop()
	show_map("HP carries over. Use your supplies wisely. Defeat ends the run.")
	save_game()

func continue_endless() -> void:
	if not FileAccess.file_exists(RUN_SAVE_PATH): return
	var saved = JSON.parse_string(FileAccess.get_file_as_string(RUN_SAVE_PATH))
	if not saved is Dictionary or saved.get("mode","") != "endless":
		show_title("This run could not be loaded.")
		return
	state = saved
	sync_pokedex()
	ItemCatalog.migrate(state)
	FunRules.initialize(state)
	apply_settings()
	focus_current_stop()
	if state.has("secret_checkpoint"): show_secret_hall()
	elif state.run.ended: show_run_end()
	elif state.run.pending_upgrade: show_upgrade()
	elif state.has("battle_checkpoint"):
		battle = state.battle_checkpoint.duplicate(true)
		battle_finished = bool(battle.get("finished",false))
		action_index = 0
		pending_action = {}
		battle_menu = "main"
		battle_log = ["Your expedition resumes."]
		if living_party_indices().is_empty(): handle_defeat()
		else: show_battle()
	else: show_map("Your expedition continues.")

func show_upgrade() -> void:
	screen = Screen.UPGRADE
	clear_ui()
	var box := make_panel(Rect2(20,135,440,560))
	add_label(box,"AREA %d CLEARED" % int(state.run.depth),18,Color("#3b8176"))
	add_label(box,"Grow your team",32)
	add_label(box,"Choose one reward for this run. Your next encounter is already waiting.",20)
	add_button(box,"Power charm\n+2 attack for the whole team",apply_upgrade.bind("power"))
	add_button(box,"Vitality charm\n+8 max HP and heal 25%",apply_upgrade.bind("vitality"))
	add_button(box,"Supply pack\n2 super potions + 3 great balls",apply_upgrade.bind("supplies"))
	add_label(box,"Supply chests at areas 10, 20, 30… Choose vitality to recover HP between battles.",17)

func apply_upgrade(choice: String) -> void:
	if not is_endless() or not state.run.pending_upgrade: return
	if choice not in ["power","vitality","supplies"]: return
	if choice == "supplies": grant_items({"super_potion":2,"great_apricorn_ball":3})
	else:
		for pokemon in state.party:
			if choice == "power":
				pokemon.attack += 2
				pokemon.special_attack = int(pokemon.get("special_attack",pokemon.attack-2))+2
			else:
				pokemon.max_hp += 8
				pokemon.hp = mini(int(pokemon.max_hp),int(pokemon.hp)+int(ceil(pokemon.max_hp*0.25)))
	state.run.pending_upgrade = false
	battle = {}
	sfx.play_effect("heal")
	focus_current_stop()
	show_map("Reward collected. Onward!")
	save_game()

func show_run_end() -> void:
	screen = Screen.RUN_END
	clear_ui()
	var box := make_panel(Rect2(20,170,440,480))
	add_label(box,"EXPEDITION COMPLETE",18,Color("#3b8176"))
	add_label(box,"Depth %d" % int(state.run.depth),46)
	add_label(box,"Best depth: %d\nFriends caught: %d" % [state.run.best,maxi(0,state.party.size()-1)+state.reserve.size()],23)
	add_label(box,"Your team gave it everything. A fresh route and a new chance await.",20)
	add_button(box,"New Endless Run  →",start_endless)
	add_button(box,"Title Screen",show_title)

func _process(delta: float) -> void:
	var music_node := str(battle.get("node_id", ""))
	var boss_music := music_node == "summit" or battle.has("orb_item")
	sfx.set_battle_music((screen == Screen.BATTLE or (screen == Screen.SUMMARY and summary_return == Screen.BATTLE)) and (not battle_finished or battle_busy), boss_music)
	elapsed += delta
	trainer_slide = minf(1.0,trainer_slide+delta*3.5)
	if battle_busy and effect_time >= 0.55:
		visual_party = active_effect.after_party
		visual_enemies = active_effect.after_enemies
	if screen in [Screen.MAP,Screen.BATTLE]: queue_redraw()

func queue_battle_effect(action: Dictionary, player_side: bool, before_party: Array, before_enemies: Array, messages: Array) -> void:
	if not animation_enabled: return
	var kind := "hit"
	if action.kind == "ball": kind = "capture"
	elif action.kind == "heal_item": kind = "heal"
	elif action.has("move"):
		var move: Dictionary = GameData.MOVES[action.move]
		kind = "heal" if move.kind in ["heal","buff"] else str(move.type)
		if kind not in ["fire","water","grass","electric","heal"]: kind = "hit"
	var target_index := int(action.get("target",action.actor))
	if kind == "heal" and action.kind != "heal_item": target_index = int(action.actor)
	# Use the actual recipient when a queued attack retargeted a fainted enemy.
	var before: Array = before_enemies if player_side else before_party
	var after: Array = battle.enemies if player_side else state.party
	if kind != "heal":
		for i in before.size():
			if before[i].hp != after[i].hp: target_index = i; break
	animation_events.append({"actor":int(action.actor),"target":target_index,"player":player_side,"kind":kind,"message":"\n".join(messages),"before_party":before_party,"before_enemies":before_enemies,"after_party":state.party.duplicate(true),"after_enemies":battle.enemies.duplicate(true)})

func play_round_animation() -> void:
	battle_busy = true
	for event in animation_events:
		active_effect = event
		visual_party = event.before_party
		visual_enemies = event.before_enemies
		effect_time = 0.0
		show_battle()
		sfx.play_effect(str(event.kind))
		var tween := create_tween()
		tween.tween_property(self,"effect_time",1.0,0.95 if event.kind == "capture" else 0.72)
		await tween.finished
	battle_busy = false
	active_effect = {}
	visual_party.clear()
	visual_enemies.clear()
	finish_round_presentation()

func finish_round_presentation() -> void:
	if living_party_indices().is_empty():
		sfx.play_effect("defeat")
		handle_defeat()
		return
	if battle_finished:
		sfx.set_battle_music(false)
		sfx.play_effect("victory")
	battle_menu = "main"
	show_battle()

func animated_position(base: Vector2, player_side: bool, index: int) -> Vector2:
	if not battle_busy:
		return base+Vector2(0,sin(elapsed*2.2+index)*2.0) if animation_enabled else base
	if bool(active_effect.player) == player_side and int(active_effect.actor) == index:
		return base+Vector2(sin(effect_time*PI)*14.0*(1 if player_side else -1),-sin(effect_time*PI)*9.0)
	if active_effect.kind != "heal" and bool(active_effect.player) != player_side and int(active_effect.target) == index and effect_time > 0.45:
		return base+Vector2(sin(effect_time*65)*5.0*(1.0-effect_time),0)
	return base

func combat_position(player_side: bool, index: int) -> Vector2:
	return Vector2(150+index*195,345) if player_side else Vector2(745+index*190,235)

func draw_move_effect() -> void:
	if not battle_busy or active_effect.is_empty(): return
	var start := combat_position(bool(active_effect.player),int(active_effect.actor))
	var target := combat_position(not bool(active_effect.player),int(active_effect.target))
	var kind := str(active_effect.kind)
	if kind == "heal": target = combat_position(bool(active_effect.player),int(active_effect.target))
	var colors := {"fire":Color("#ff964c"),"water":Color("#66d5ff"),"grass":Color("#76db76"),"electric":Color("#ffe866"),"heal":Color("#96f2c4"),"capture":Color("#f26868"),"hit":Color("#fff6dc")}
	var color: Color = colors[kind]
	var position := start.lerp(target,minf(1.0,effect_time*2.0))
	if kind == "capture":
		position.y -= sin(minf(1.0,effect_time*2.0)*PI)*85
		draw_circle(position,14,Color.WHITE)
		draw_arc(position,10,PI,TAU,12,color,9)
		draw_line(position-Vector2(13,0),position+Vector2(13,0),COLOR_INK,3)
		draw_circle(position,4,COLOR_INK)
	elif kind == "heal":
		for i in 5:
			var point := target+Vector2((i-2)*18,-effect_time*90+20)
			draw_rect(Rect2(point-Vector2(3,9),Vector2(6,18)),color)
			draw_rect(Rect2(point-Vector2(9,3),Vector2(18,6)),color)
	else:
		for i in 7:
			var angle := i*TAU/7.0+effect_time*4.0
			var radius := 10.0+maxf(0.0,effect_time-0.45)*90.0
			var point := position+Vector2(cos(angle),sin(angle))*radius
			draw_rect(Rect2(point,Vector2(9,9)*(1.0-effect_time*0.5)),color)
		if kind == "electric":
			draw_polyline(PackedVector2Array([position+Vector2(-12,-25),position+Vector2(8,-5),position+Vector2(-8,5),position+Vector2(12,25)]),color,5)

func milestone_chest_pending() -> bool:
	if not is_endless() or state.run.get("ended",false): return false
	var depth := int(state.run.depth)
	return depth > 0 and depth % 10 == 0 and "milestone_%d" % depth not in state.opened_chests

func show_milestone_chest() -> void:
	screen = Screen.CHEST
	clear_ui()
	var box := make_panel(Rect2(20,170,440,480))
	add_label(box,"TREASURE CHEST",32)
	add_chest_preview(box)
	add_label(box,"Level %d cleared" % int(state.run.depth),23)
	add_label(box,"You found a supply chest!",23)
	add_label(box,"Includes three random catalog items. Rare-item chances improve with depth.",18)
	add_label(box,reward_text({"potion":2,"apricorn_ball":3}),20)
	add_button(box,"Open Chest",collect_milestone_chest)

func collect_milestone_chest() -> void:
	if not milestone_chest_pending(): return
	var before := state.duplicate(true)
	var id := "milestone_%d" % int(state.run.depth)
	var rewards := chest_loot(id,int(state.run.depth),{"potion":2,"apricorn_ball":3})
	grant_items(rewards)
	state.opened_chests.append(id)
	sfx.play_effect("capture")
	if not save_game():
		state = before
		show_milestone_chest()
		return
	show_chest_contents(rewards,id)

func minecraft_style(color: Color, inset := false) -> StyleBox:
	var style := preload("res://scripts/minecraft_style.gd").new()
	style.fill = color
	style.inset = inset
	return style

func add_chest_preview(parent: Node, opened := false) -> void:
	var preview := Control.new()
	preview.custom_minimum_size = Vector2(0,100)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(preview)
	preview.draw.connect(func(): paint_chest(preview,Vector2(preview.size.x / 2 - 48,8),6.0,true,opened))

func show_chest_contents(rewards: Dictionary, chest_id := "") -> void:
	if not chest_id.is_empty():
		state["active_chest"] = chest_id
		state["chest_storage"] = state.get("chest_stores",{}).get(chest_id,{}).duplicate()
		state["chest_slots"] = state.get("chest_layouts",{}).get(chest_id,[]).duplicate(true)
	if not rewards.is_empty():
		var stored: Dictionary = state.get("chest_storage",{})
		for id in rewards:
			var count := mini(int(rewards[id]),int(state.inventory.get(id,0)))
			state.inventory[id] = int(state.inventory.get(id,0)) - count
			stored[id] = int(stored.get(id,0)) + count
		state["chest_storage"] = stored
		save_game()
	screen = Screen.CHEST
	clear_ui()
	var inventory_ui = preload("res://scripts/block_inventory.gd").new()
	inventory_ui.game = self
	inventory_ui.with_chest = true
	ui.add_child(inventory_ui)

func draw_pixel_chest(origin: Vector2, scale_factor: float, inside: bool, opened: bool) -> void:
	if not inside and overworld_chest_texture:
		draw_texture_rect(overworld_chest_texture,Rect2(origin,Vector2(16,16)*scale_factor),false,Color("#b0b0b0") if opened else Color.WHITE)
	else:
		paint_chest(self,origin,scale_factor,inside,opened)

func paint_chest(canvas: CanvasItem, origin: Vector2, scale_factor: float, inside: bool, opened: bool) -> void:
	var outline := Color("#23170f")
	var wood := Color("#a66b28") if inside else Color("#ef9c24")
	var trim := Color("#543a20") if inside else Color("#ffe28a")
	var blocks := [
		[Rect2(0,2,16,12),outline], [Rect2(1,3,14,10),wood],
		[Rect2(2,4,12,2),wood.lightened(0.25)], [Rect2(1,7,14,2),outline],
		[Rect2(1,3,2,10),trim], [Rect2(13,3,2,10),trim],
		[Rect2(3,12,10,1),wood.darkened(0.25)],
		[Rect2(7,6,3,5),outline], [Rect2(7,6,2,4),Color("#d9d9d9") if inside else Color("#ffe68a")]
	]
	if opened:
		blocks.append([Rect2(1,5,14,3),outline])
		blocks.append([Rect2(1,0,14,3),wood.lightened(0.2)])
	for block in blocks:
		var rect: Rect2 = block[0]
		canvas.draw_rect(Rect2(origin + rect.position * scale_factor,rect.size * scale_factor),block[1])

# Debug tools are explicit actions, available in exported games as well as the editor.
func open_debug() -> void:
	if battle_busy or resolving_round: return
	if screen not in [Screen.TITLE, Screen.MAP, Screen.PARTY, Screen.INVENTORY, Screen.SETTINGS, Screen.BATTLE]: return
	debug_return = screen
	show_debug()

func show_debug(message := "") -> void:
	screen = Screen.DEBUG
	clear_ui()
	var shell := make_panel(Rect2(300, 20, 680, 680))
	add_label(shell, "Debug mode", 32)
	add_button(shell, "Back to game (Esc)", close_debug)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 530)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	scroll.add_child(box)
	add_label(box, "Changes to party and supplies are saved. Esc closes this menu.", 17)
	var in_battle := debug_return == Screen.BATTLE
	var has_party := state.has("party")
	add_label(box, "FPS: %d • Mode: %s\nLocation: %s" % [Engine.get_frames_per_second(), "Endless" if is_endless() else "Island", str(state.get("current_node", "No active adventure"))], 18)
	if is_endless():
		add_label(box, "Seed: %s • Depth: %s" % [str(state.run.seed), str(state.run.get("depth", 0))], 18)
	if has_party:
		add_label(box, "FUN: %d (saved per adventure)" % int(state.get("fun_value", 0)), 18)
		var fun_input := SpinBox.new()
		fun_input.min_value = 1
		fun_input.max_value = 99
		fun_input.value = int(state.get("fun_value", 1))
		box.add_child(fun_input)
		add_button(box, "Set FUN value", func(): debug_set_fun(int(fun_input.value)))
	add_button(box, "WD GASTER", debug_gaster)
	add_button(box, "Heal / revive entire party", func(): debug_action("heal"), not has_party)
	add_button(box, "Add 25 potions and 25 capture balls", func(): debug_action("supplies"), not has_party)
	add_button(box, "Open Chest", debug_open_chest, not has_party or in_battle)
	add_button(box, "Win current battle", func(): debug_action("win"), not in_battle or battle_finished)
	add_label(box, "Testing switches (reset when the game restarts)", 20)
	for entry in [["invincible", "Invincible party (no attack damage)"], ["one_hit", "One-hit player attacks"], ["capture", "Guaranteed catches"], ["unlimited_items", "Unlimited owned items (requires at least one)"], ["accuracy", "Player moves always hit"], ["enemy_turns", "Enemy turns"], ["travel", "Unlock all island destinations"]]:
		add_debug_toggle(box, str(entry[1]), bool(debug_options[entry[0]]), func(value: bool): debug_options[entry[0]] = value)
	add_debug_toggle(box, "Battle animations", animation_enabled, func(value: bool): animation_enabled = value)
	add_button(box, "Reset all testing switches", func():
		debug_options = DEBUG_DEFAULTS.duplicate()
		animation_enabled = DisplayServer.get_name() != "headless"
		show_debug("Testing switches reset.")
	)
	if message != "": add_label(box, message, 17, COLOR_CORAL)

func debug_open_chest() -> void:
	if screen != Screen.DEBUG or not state.has("party") or debug_return == Screen.BATTLE or battle_busy or resolving_round: return
	var chest_id := "debug_chest"
	if chest_id in state.opened_chests:
		show_chest_contents({}, chest_id)
		return
	var previous := state.duplicate(true)
	var depth := int(state.run.get("depth", 0)) if is_endless() else 0
	var rewards := chest_loot(chest_id, depth, {"potion":2, "apricorn_ball":3})
	grant_items(rewards)
	state.opened_chests.append(chest_id)
	if not save_game():
		state = previous
		show_debug("Chest could not be saved. Try again.")
		return
	show_chest_contents(rewards, chest_id)

func debug_action(action: String) -> void:
	if screen != Screen.DEBUG or not state.has("party") or battle_busy or resolving_round: return
	if action == "win":
		if debug_return != Screen.BATTLE or battle_finished: return
		battle_finished = true
		battle.actions.clear()
		pending_action.clear()
		visual_party.clear()
		visual_enemies.clear()
		for enemy in battle.enemies: enemy.hp = 0
		finish_victory()
		return
	if action not in ["heal", "supplies"]: return
	var previous := state.duplicate(true)
	if action == "heal":
		restore_party()
		visual_party.clear()
	else:
		grant_items({"potion":25, "apricorn_ball":25})
	# Preserve the active endless battle checkpoint while the menu is open.
	screen = debug_return
	var saved := save_game()
	screen = Screen.DEBUG
	if not saved: state = previous
	show_debug(("Party restored." if action == "heal" else "Supplies added.") if saved else "Save failed; changes were rolled back.")

func close_debug() -> void:
	match debug_return:
		Screen.BATTLE: show_battle()
		Screen.PARTY: show_party()
		Screen.INVENTORY: show_inventory()
		Screen.SETTINGS: open_settings(settings_return)
		Screen.TITLE: show_title()
		_: show_map()

func add_debug_toggle(parent: Node, label: String, enabled: bool, callback: Callable) -> void:
	var toggle := CheckButton.new()
	toggle.text = label
	toggle.button_pressed = enabled
	toggle.custom_minimum_size.y = 44
	toggle.toggled.connect(callback)
	parent.add_child(toggle)

func show_fun_event(event: Dictionary) -> void:
	var available: Dictionary = FunRules.event_at(state, get_node_data(str(state.current_node)))
	if available.is_empty() or available.id != event.id: return
	screen = Screen.FUN_EVENT
	clear_ui()
	var box := make_panel(Rect2(20, 135, 440, 560))
	add_label(box, str(event.title), 28)
	add_label(box, str(event.text), 20)
	add_button(box, "Return to the path", func(): finish_fun_event(str(event.id)))

func finish_fun_event(event_id: String) -> void:
	if screen != Screen.FUN_EVENT: return
	var previous: Array = state.fun_seen.duplicate()
	if event_id not in state.fun_seen: state.fun_seen.append(event_id)
	if not save_game():
		state.fun_seen = previous
		show_map("The moment could not be saved. Try again.")
		return
	show_map("The island seems ordinary again.")

func debug_set_fun(value: int) -> void:
	if screen != Screen.DEBUG or not state.has("party") or battle_busy or resolving_round: return
	var previous: Dictionary = state.duplicate(true)
	state.fun_value = clampi(value, 1, 99)
	if not save_game():
		state = previous
		show_debug("Save failed; FUN was not changed.")
		return
	show_debug("FUN saved. Previously seen events remain completed.")

func secret_available(node: Dictionary) -> bool:
	return is_endless() and int(node.get("floor", 0)) == 66 and int(state.get("fun_value", 0)) == 66 and int(state.run.depth) < 66 and "gaster_hall" not in state.get("fun_seen", [])

func show_secret_hall(preview := false) -> void:
	secret_debug_preview = preview
	var previous: Dictionary = state.duplicate(true)
	if not preview and not state.has("secret_checkpoint"):
		state.secret_checkpoint = {"room":"hall", "x":80, "y":300, "vanished":false, "door_gone":false}
	if not preview and not save_game():
		state = previous
		show_map("The secret could not be saved. Try entering again.")
		return
	screen = Screen.SECRET_HALL
	clear_ui()
	get_window().content_scale_size = Vector2i(640, 480)
	secret_hall = SecretHall.new()
	secret_hall.progress = {"room":"hall", "x":80, "y":300, "vanished":false, "door_gone":false} if preview else state.secret_checkpoint
	secret_hall.profile = SecretHall.PLAYER_PROFILE.duplicate(true)
	secret_hall.checkpoint.connect(func():
		if secret_debug_preview: return
		if not save_game():
			secret_hall.message = "* Could not save. Try leaving again."
	)
	secret_hall.exited.connect(exit_secret_hall)
	ui.add_child(secret_hall)

func exit_secret_hall() -> void:
	if screen != Screen.SECRET_HALL: return
	if secret_debug_preview:
		secret_debug_preview = false
		show_debug("Returned from WD GASTER.")
		return
	var previous: Dictionary = state.duplicate(true)
	if "gaster_hall" not in state.fun_seen: state.fun_seen.append("gaster_hall")
	state.erase("secret_checkpoint")
	mark_cleared("run_66")
	if not save_game():
		state = previous
		secret_hall.progress = state.secret_checkpoint
		secret_hall.player.x = clampf(secret_hall.player.x, 8, 632)
		secret_hall.message = "* Could not save. Try the exit again."
		return
	show_map("You return to your team. Area 66 is complete.")

func debug_gaster() -> void:
	if screen != Screen.DEBUG or battle_busy or resolving_round: return
	show_secret_hall(true)

func use_pp_item(item_id: String, party_index: int, move_id: String) -> void:
	if party_index < 0 or party_index >= state.party.size() or int(state.inventory.get(item_id,0)) <= 0: return
	var item: Dictionary = GameData.ITEMS.get(item_id,{})
	if item.get("kind","") != "pp_medicine": return
	var before := state.duplicate(true)
	if not PendingItems.pp_use(item,state.party[party_index],move_id,true): return
	if not debug_options.unlimited_items: state.inventory[item_id] -= 1
	if not save_game(): state = before
	show_inventory()

func confirm_pp_target(move_id: String) -> void:
	if pending_action.is_empty(): return
	pending_action.pp_move = move_id
	battle.actions.append(pending_action.duplicate())
	pending_action = {}
	action_index += 1
	battle_menu = "main"
	show_battle()

func use_training_item(id: String, party_index: int, stat: String) -> void:
	if int(state.inventory.get(id,0)) <= 0: return
	var before := state.duplicate(true)
	if not PendingItems.hyper_train(state.party[party_index],stat,GameData.ITEMS[id].get("all_stats",false),true): return
	state.inventory[id] -= 1
	if not save_game(): state = before
	show_inventory()

func use_ev_item(id: String, party_index: int) -> void:
	if int(state.inventory.get(id,0)) <= 0: return
	var before := state.duplicate(true)
	state.party[party_index].at_met_location = state.party[party_index].get("met_node","") == state.current_node
	if not PendingItems.ev_use(GameData.ITEMS[id],state.party[party_index],true): return
	state.inventory[id] -= 1
	if not save_game(): state = before
	show_inventory()

func use_party_item(id: String) -> void:
	if screen == Screen.BATTLE or int(state.inventory.get(id,0)) <= 0: return
	var before := state.duplicate(true)
	if not PendingItems.sacred_ash(id,state.party,true): return
	state.inventory[id] -= 1
	if not save_game(): state = before
	show_inventory()

func use_progression_item(id: String, party_index: int) -> void:
	if int(state.inventory.get(id,0)) <= 0: return
	var before := state.duplicate(true)
	var pokemon: Dictionary = state.party[party_index]
	pokemon.at_met_location = pokemon.get("met_node","") == state.current_node
	var kind := str(GameData.ITEMS[id].kind)
	var used := ItemProgression.use_core(id,pokemon) if kind == "form_item" else (ItemProgression.candy(pokemon,true) if kind == "candy" else PendingItems.ability_patch(pokemon,true))
	if not used: return
	if kind != "form_item": state.inventory[id] -= 1
	if not save_game(): state = before
	show_inventory()

func start_orb_boss(id: String, index: int) -> void:
	if living_party_indices().is_empty(): return
	var before := state.duplicate(true)
	if not BossOrbs.attempt(state,id,index,rng):
		save_game()
		show_inventory()
		return
	var boss := GameData.make_pokemon(str(BossOrbs.SPECIES[id]),rng)
	var level := int(state.party[0].get("level",5))
	ItemMechanics.grant_experience(boss,ItemMechanics.experience_at(level,int(ItemMechanics.species(boss).get("growth_rate",2)))-int(boss.experience))
	boss.held_item = id
	ItemProgression.form(boss,true)
	boss.boss_normal_hp = int(boss.max_hp)
	boss.max_hp = int(floor(float(boss.max_hp)*1.5))
	boss.hp = int(boss.max_hp)
	for p in state.party:
		ItemMechanics.reset_battle(p)
		ItemProgression.form(p,true)
	battle = {"enemies":[boss],"actions":[],"rewards":{},"node_id":state.current_node,"return_node":state.current_node,"encounter_id":"orb_boss","orb_item":id,"orb_index":index,"participants":living_party_indices(),"context":{"cave":false,"water":id == "item_blue_orb","turn":1},"round":1}
	action_index = 0
	pending_action = {}
	battle_finished = false
	battle_log = ["BOSS: Primal %s appeared!" % GameData.SPECIES[boss.species].name]
	if not save_game():
		state = before
		battle = {}
		show_inventory()
		return
	show_battle()

func finish_orb_boss(result: String) -> void:
	BossOrbs.outcome(state,str(battle.orb_item),int(battle.orb_index),result)
	for p in state.party: ItemMechanics.reset_battle(p)
	if result == "loss": restore_party()
	state.erase("battle_checkpoint")
	battle = {}
	battle_finished = false
	save_game()
	show_map("Boss captured. This orb is now held-use only." if result == "capture" else ("Boss defeated. Clear five island levels to recharge this orb." if result == "knockout" else "Your team is rested. The orb remains available for another attempt."))

func use_escape_rope() -> void:
	if not battle.get("context",{}).get("cave",false) or battle.has("orb_item") or int(state.inventory.get("item_escape_rope",0)) <= 0: return
	state.inventory.item_escape_rope -= 1
	flee_battle()

func show_level_choices(index: int) -> void:
	screen = Screen.PARTY
	clear_ui()
	var box := make_panel(Rect2(170,45,900,630))
	var pokemon: Dictionary = state.party[index]
	add_label(box,"%s · Level-up choices" % GameData.SPECIES[pokemon.species].name,28)
	var target := ItemProgression.evolution(pokemon)
	if pokemon.get("pending_evolution","") != "" and target != "":
		add_button(box,"Evolve into %s" % GameData.SPECIES[target].name,apply_level_choice.bind(index,"",-2))
	var choices: Array = pokemon.get("pending_moves",[])
	if not choices.is_empty():
		var move := str(choices[0])
		add_label(box,"Learn %s?" % GameData.MOVES[move].name,24)
		for i in pokemon.moves.size(): add_button(box,"Replace %s" % GameData.MOVES[pokemon.moves[i]].name,apply_level_choice.bind(index,move,i))
		add_button(box,"Skip this move",apply_level_choice.bind(index,move,-1))
	add_button(box,"Back",show_party)

func apply_level_choice(index: int, move: String, replacement: int) -> void:
	var before := state.duplicate(true)
	var pokemon: Dictionary = state.party[index]
	if replacement == -2: ItemProgression.evolve(pokemon,ItemProgression.evolution(pokemon))
	elif move in pokemon.get("pending_moves",[]):
		if replacement >= 0 and replacement < pokemon.moves.size():
			pokemon.moves[replacement] = move
			pokemon.pp[move] = int(GameData.MOVES[move].get("pp",35))
		pokemon.pending_moves.erase(move)
	if not save_game(): state = before
	show_level_choices(index)

# Per-adventure records retain species even after they leave the party.
func register_dex(id: String, caught: bool) -> void:
	if not GameData.SPECIES.has(id): return
	if not state.get("pokedex", null) is Dictionary: state.pokedex = {}
	var entry: Dictionary = state.pokedex.get(id, {"seen":true,"caught":false})
	entry.seen = true
	entry.caught = bool(entry.get("caught",false)) or caught
	state.pokedex[id] = entry

func sync_pokedex() -> void:
	for pokemon in state.get("party",[]) + state.get("reserve",[]):
		register_dex(str(pokemon.get("species","")), true)
	for id in state.get("caught_species",[]): register_dex(str(id), true)
	for pokemon in state.get("battle_checkpoint",{}).get("enemies",[]):
		register_dex(str(pokemon.get("species","")), false)

func show_pokedex() -> void:
	sync_pokedex()
	screen = Screen.POKEDEX
	clear_ui()
	var panel := make_panel(Rect2(30,20,1220,680), Color.WHITE)
	var seen := 0
	var caught := 0
	for entry in state.get("pokedex",{}).values():
		if entry.get("seen",false): seen += 1
		if entry.get("caught",false): caught += 1
	add_label(panel,"POKÉDEX • %d seen / %d caught / %d species" % [seen,caught,GameData.SPECIES.size()],28)
	add_label(panel,"Records belong to this adventure. Meet Pokémon to reveal their entries.",17)
	var row := HBoxContainer.new()
	panel.add_child(row)
	var search := LineEdit.new()
	search.placeholder_text = "Search discovered Pokémon"
	search.text = dex_query
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var search_style := StyleBoxFlat.new()
	search_style.bg_color = Color.WHITE
	search_style.border_color = Color("#c5cdd5")
	search_style.set_border_width_all(2)
	search_style.content_margin_left = 12
	search.add_theme_stylebox_override("normal",search_style)
	search.add_theme_color_override("font_color",COLOR_INK)
	search.add_theme_color_override("font_placeholder_color",Color("#687480"))
	row.add_child(search)
	var filter := OptionButton.new()
	for label in ["All species","Seen","Caught","Seen, not caught"]: filter.add_item(label)
	filter.select(dex_filter)
	row.add_child(filter)
	var back := add_button(row,"Back to map",show_map.bind(""))
	for control in [filter,back]:
		for style_name in ["normal","hover","pressed"]:
			var neutral: StyleBoxFlat = theme.get_stylebox(style_name,"Button").duplicate()
			neutral.bg_color = Color.WHITE if style_name == "normal" else Color("#edf2f5")
			control.add_theme_stylebox_override(style_name,neutral)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 480
	panel.add_child(scroll)
	var list := GridContainer.new()
	list.name = "PokedexGrid"
	list.columns = 7
	list.add_theme_constant_override("h_separation", 10)
	list.add_theme_constant_override("v_separation", 10)
	list.custom_minimum_size.x = 1140
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	populate_pokedex(list)
	search.text_changed.connect(func(value: String): dex_query = value; populate_pokedex(list))
	filter.item_selected.connect(func(index: int): dex_filter = index; populate_pokedex(list))

func populate_pokedex(list: GridContainer) -> void:
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	var ids: Array = GameData.SPECIES.keys()
	ids.sort_custom(func(a, b):
		var first := int(ItemProgression.info(str(a)).get("dex_id",9999))
		var second := int(ItemProgression.info(str(b)).get("dex_id",9999))
		return str(a) < str(b) if first == second else first < second
	)
	var matches := 0
	for id in ids:
		var entry: Dictionary = state.get("pokedex",{}).get(id,{})
		var seen: bool = entry.get("seen",false)
		var caught: bool = entry.get("caught",false)
		var species: Dictionary = GameData.SPECIES[id]
		if dex_filter == 1 and not seen: continue
		if dex_filter == 2 and not caught: continue
		if dex_filter == 3 and (not seen or caught): continue
		if not dex_query.strip_edges().is_empty() and (not seen or not str(species.name).to_lower().contains(dex_query.strip_edges().to_lower())): continue
		matches += 1
		var card := PanelContainer.new()
		card.name = "Dex_" + str(id)
		card.custom_minimum_size = Vector2(154,164)
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#f3fff3") if caught else Color.WHITE
		style.border_color = Color("#80bd82") if caught else Color("#d6dce2")
		style.set_border_width_all(2)
		style.set_corner_radius_all(10)
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 6
		style.content_margin_bottom = 6
		card.add_theme_stylebox_override("panel",style)
		list.add_child(card)
		var body := VBoxContainer.new()
		body.add_theme_constant_override("separation",2)
		card.add_child(body)
		var number := int(ItemProgression.info(str(id)).get("dex_id",0))
		var heading := add_label(body,"#%04d" % number,14,Color("#687480"))
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if not seen:
			var mystery := add_label(body,"?",50,Color("#89939e"))
			mystery.name = "UnknownPortrait"
			mystery.custom_minimum_size = Vector2(96,76)
			mystery.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			mystery.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		else:
			var picture := TextureRect.new()
			picture.name = "PokemonPortrait"
			picture.custom_minimum_size = Vector2(96,76)
			picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			var image_id: String = "giratina-altered" if id == "giratina" else str(id)
			picture.texture = sprites.get(image_id+"_front")
			if not caught:
				var silhouette := Shader.new()
				silhouette.code = "shader_type canvas_item; void fragment() { vec4 pixel = texture(TEXTURE, UV); COLOR = vec4(vec3(0.57), pixel.a); }"
				var material := ShaderMaterial.new()
				material.shader = silhouette
				picture.material = material
			body.add_child(picture)
		var title := add_label(body,str(species.name) if seen else "???",17)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var status := add_label(body,"● Caught" if caught else "Seen" if seen else "Undiscovered",14,Color("#387847") if caught else Color("#687480"))
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if seen:
			var habitats: Array[String] = []
			for node in GameData.NODES:
				if id in GameData.ENCOUNTERS.get(node.get("encounter",""),{}).get("enemies",[]): habitats.append(str(node.name))
			card.tooltip_text = "%s • %s\nIsland habitat: %s" % [species.name,str(species.type).capitalize(),", ".join(habitats) if not habitats.is_empty() else "Explore, evolve, or discover special encounters"]
	if matches == 0: add_label(list,"No entries match this search.",20)

func show_character_customization() -> void:
	# Stay in SETTINGS so Escape returns through the same menu path.
	character_customization_open = true
	clear_ui()
	var draft: Dictionary = trainer_style.profile.duplicate(true)
	var box := make_panel(Rect2(200,35,880,650))
	add_label(box,"YOUR TRAINER",32)
	add_label(box,"Make yourself at home on Apricorn Island. Your look follows you in both modes.",18)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",40)
	box.add_child(row)
	var preview := TextureRect.new()
	preview.custom_minimum_size = Vector2(270,420)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture = trainer_texture
	row.add_child(preview)
	var choices := VBoxContainer.new()
	choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(choices)
	add_label(choices,"Trainer name",18)
	var name_field := LineEdit.new()
	name_field.text = str(draft.name)
	name_field.max_length = 20
	name_field.custom_minimum_size.y = 42
	choices.add_child(name_field)
	name_field.text_changed.connect(func(value: String): draft.name = value)
	for key in TrainerStyle.OPTIONS:
		add_label(choices,str(key).capitalize(),18)
		var picker := OptionButton.new()
		picker.custom_minimum_size.y = 42
		for title in TrainerStyle.OPTIONS[key]: picker.add_item(title)
		picker.selected = int(draft[key])
		picker.item_selected.connect(func(index: int):
			draft[key] = index
			var style := TrainerStyle.new()
			style.profile = draft.duplicate(true)
			preview.texture = style.make_texture()
		)
		choices.add_child(picker)
	var feedback := add_label(box,"Changes appear on your map character. Choose Save look when ready.",16)
	var buttons := HBoxContainer.new()
	box.add_child(buttons)
	add_button(buttons,"Save look",func():
		var before: Dictionary = trainer_style.profile.duplicate(true)
		draft.name = str(draft.name).strip_edges()
		if str(draft.name).is_empty(): draft.name = "Trainer"
		trainer_style.profile = draft.duplicate(true)
		if trainer_style.save_profile() != OK:
			trainer_style.profile = before
			feedback.text = "Could not save your look. Please try again."
			return
		trainer_texture = trainer_style.make_texture()
		open_settings(settings_return)
	)
	add_button(buttons,"Cancel",func(): open_settings(settings_return))
