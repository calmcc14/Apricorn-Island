extends Control

enum Screen { TITLE, INTRO, MAP, BATTLE, PARTY, INVENTORY, SETTINGS, ENDING, UPGRADE, RUN_END, CHEST, DEBUG, FUN_EVENT, SECRET_HALL, BOX, STARTER, SUMMARY, POKEDEX, GLITCH, GLITCH_SHIFT, GLITCH_ARCHIVE, GLITCH_PROFILE, CARTRIDGE }

const STARTERS := ["bulbasaur", "charmander", "squirtle", "pikachu", "eevee"]

const SecretHall = preload("res://scripts/secret_hall.gd")
const FunRules = preload("res://scripts/fun_rules.gd")
const GlitchDimension = preload("res://scripts/glitch_dimension.gd")
const GlitchArt = preload("res://scripts/glitch_art.gd")
const BattleEffects = preload("res://scripts/battle_effects.gd")
const YellowSprites = preload("res://scripts/yellow_sprites.gd")
const RUN_SAVE_PATH := Cartridge.ENDLESS_PATH
const SAVE_PATH := Cartridge.ISLAND_PATH
const SETTINGS_PATH := "user://apricorn_settings.cfg"
const DEFAULT_SETTINGS := {"volume":0.8,"fullscreen":false,"difficulty":"normal","animations":true}
const MAP_RECT := Rect2(0, 330, 480, 290)
const COLOR_INK := Color("#203d45")
const COLOR_CREAM := Color("#fff9e9")
const COLOR_GOLD := Color("#f5bf42")
const COLOR_GREEN := Color("#54b86b")
const COLOR_BLUE := Color("#55a9dc")
const COLOR_CORAL := Color("#ee6f69")
const ATTACK_RESULT_LABELS := {"miss":"Miss","blocked":"Blocked","no_effect":"No effect","absorbed":"Absorbed","substitute":"Substitute"}

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
var standard_sprites: Dictionary = {}
var yellow_sprites: Dictionary = {}
var cartridge_profile: Dictionary = {}
var cartridge: String:
	get: return str(cartridge_profile.get("active", Cartridge.RED))
var cartridge_menu_return := Screen.TITLE
var swapping_cartridge := false
var battle_menu := "main"
var drag_origin := Vector2.ZERO
var drag_moved := false
var sfx := RetroAudio.new()
var route_cache: Array = []
var route_cache_key := ""
var resolving_round := false
var animation_enabled := true
var settings_animation_toggles := 0
var battle_busy := false
var animation_events: Array = []
var visual_party: Array = []
var visual_enemies: Array = []
var active_effect: Dictionary = {}
var quick_attack_results: Dictionary = {}
var quick_attack_results_until := 0.0
var effect_time := 0.0
var battle_entry_time := 1.0
var elapsed := 0.0
var trainer_from := Vector2.ZERO
var trainer_slide := 1.0
var rng := RandomNumberGenerator.new()
const DEBUG_CODE := [KEY_UP, KEY_UP, KEY_DOWN, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_LEFT, KEY_RIGHT, KEY_B, KEY_A]
const DEBUG_ANIMATION_TOGGLES := 10
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
var dex_page := 0
const DEX_PAGE_SIZE := 49
var summary_return := Screen.PARTY
const TrainerStyle = preload("res://scripts/trainer_style.gd")
var trainer_style := TrainerStyle.new()
var character_customization_open := false
var glitch_shift_time := 0.0
var glitch_archive_query := ""
var glitch_archive_generation := 0
var glitch_profile: Dictionary = {}
var glitch_pokedex_scan: Texture2D
var glitch_reference_section := -1

func _ready() -> void:
	rng.randomize()
	cartridge_profile = Cartridge.initial_profile()
	add_child(sfx)
	animation_enabled = DisplayServer.get_name() != "headless"
	overworld_chest_texture = load("res://assets/overworld_chest.webp")
	island_texture = load("res://assets/island_bg.png")
	load_cartridge_sprites()
	route_background = load("res://assets/route_pixel_background.png")
	trainer_texture = load("res://assets/trainer_player.png")
	trainer_style.load_profile()
	trainer_texture = trainer_style.make_texture()
	configure_theme()
	load_preferences()
	apply_settings()
	fit_startup_window()
	# Leave the drawn map available to unhandled input; panel controls still consume clicks.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process_unhandled_input(true)
	show_title()
	if "--verify-items" in OS.get_cmdline_user_args(): call_deferred("_verify_item_release")

func fit_startup_window() -> void:
	if DisplayServer.get_name() != "Windows" or "--resolution" in OS.get_cmdline_args(): return
	var window := get_window()
	if window.mode != Window.MODE_WINDOWED or window.is_embedded(): return
	var work_area := DisplayServer.screen_get_usable_rect(window.current_screen)
	var frame := (window.get_size_with_decorations() - window.size).max(Vector2i.ZERO)
	var available := work_area.size - frame
	if available.x <= 0 or available.y <= 0: return
	var scale_factor := minf(float(available.x) / window.size.x, float(available.y) / window.size.y)
	if scale_factor >= 1.0: return
	window.size = Vector2i(Vector2(window.size) * scale_factor)
	var frame_center := window.get_position_with_decorations() + window.get_size_with_decorations() / 2
	window.position += work_area.get_center() - frame_center

func _verify_item_release() -> void:
	preload("res://scripts/item_release_check.gd").run(self)

func configure_theme() -> void:
	var theme := Theme.new()
	var font := FontVariation.new()
	font.base_font = ThemeDB.fallback_font
	font.fallbacks = [GlitchArt.pokedollar_font()] + font.base_font.fallbacks
	theme.default_font = font
	theme.default_font_size = 20
	theme.set_color("font_color", "Label", COLOR_INK)
	theme.set_color("font_color", "Button", COLOR_INK)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", Color.WHITE)
	theme.set_color("font_focus_color", "Button", COLOR_INK)
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
	hover.bg_color = Color("#24645f")
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
	theme.set_color("font_disabled_color", "Button", Color("#393d3c"))
	var popup := button_style.duplicate() as StyleBoxFlat
	popup.set_content_margin_all(12)
	popup.shadow_size = 0
	theme.set_stylebox("panel", "PopupMenu", popup)
	theme.set_stylebox("hover", "PopupMenu", hover)
	theme.set_color("font_color", "PopupMenu", COLOR_INK)
	theme.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	theme.set_color("font_disabled_color", "PopupMenu", Color("#687680"))
	theme.set_font_size("font_size", "PopupMenu", 22)
	theme.set_constant("v_separation", "PopupMenu", 22)
	theme.set_stylebox("panel", "AcceptDialog", popup)
	theme.set_constant("buttons_min_height", "AcceptDialog", 48)
	for mode in ["normal", "hover", "pressed", "focus", "disabled"]:
		theme.set_stylebox(mode, "OptionButton", theme.get_stylebox(mode, "Button"))
	theme.set_font_size("font_size", "OptionButton", 20)
	theme.set_color("font_color", "OptionButton", COLOR_INK)
	theme.set_color("font_hover_color", "OptionButton", Color.WHITE)
	theme.set_color("font_pressed_color", "OptionButton", Color.WHITE)
	theme.set_color("font_focus_color", "OptionButton", COLOR_INK)
	theme.set_constant("modulate_arrow", "OptionButton", 1)
	theme.set_constant("arrow_margin", "OptionButton", 12)
	self.theme = theme

func clear_ui() -> void:
	if screen != Screen.BATTLE: quick_attack_results.clear()
	get_window().content_scale_size = Vector2i(480,900)
	for child in ui.get_children():
		ui.remove_child(child)
		child.queue_free()
	queue_redraw()

func show_dialog(dialog: AcceptDialog, parent: Node = null) -> void:
	dialog.dialog_autowrap = true
	dialog.unresizable = true
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	(self if parent == null else parent).add_child(dialog)
	dialog.popup_centered(Vector2i(440, 200))

func add_option_button(parent: Node) -> OptionButton:
	var button := OptionButton.new()
	button.custom_minimum_size.y = 48
	parent.add_child(button)
	return button

func add_vertical_scroll(parent: Node) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	return scroll

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
	if parent is VBoxContainer or parent is GridContainer:
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.disabled = disabled
	button.custom_minimum_size = Vector2(0, 48)
	button.pressed.connect(func(): sfx.play_effect("select"))
	button.pressed.connect(callback)
	if in_glitch() and screen in [Screen.GLITCH,Screen.GLITCH_ARCHIVE,Screen.GLITCH_PROFILE,Screen.BATTLE]:
		for mode in ["normal","hover","pressed"]:
			var style: StyleBoxFlat = theme.get_stylebox(mode,"Button").duplicate()
			style.bg_color = Color("#e8d4f5") if mode == "normal" else Color("#663e83")
			style.border_color = Color("#8660a4")
			button.add_theme_stylebox_override(mode,style)
	parent.add_child(button)
	return button

func make_panel(rect: Rect2, color := Color("#fff9e9f5")) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.position = rect.position
	panel.size = rect.size
	var style := StyleBoxFlat.new()
	style.bg_color = GlitchArt.PANEL if screen == Screen.BATTLE and battle.get("glitch",false) else color
	style.border_color = Color("#9473aa") if screen == Screen.GLITCH or (screen == Screen.BATTLE and battle.get("glitch",false)) else Color("#c5d6c8")
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
	if not cartridge_profile.has("active"):
		show_first_cartridge(message)
		return
	screen = Screen.TITLE
	clear_ui()
	var box := make_panel(Rect2(20,75,440,704))
	add_label(box,Cartridge.version_name(cartridge).to_upper(),19,Cartridge.COLORS[cartridge])
	add_label(box,"Apricorn Island",42)
	add_label(box,"A new route. A stronger team.
How far can you go?",23)
	add_button(box,"New Endless Run  →",request_new_game.bind(true))
	add_button(box,"Continue Endless Run",continue_endless,not FileAccess.file_exists(cartridge_save_path(true)))
	add_button(box,"New Island Adventure",request_new_game.bind(false))
	add_button(box,"Continue Island Adventure",continue_game,not FileAccess.file_exists(cartridge_save_path(false)))
	if cartridge_profile.get("yellow_unlocked", false):
		add_button(box,"Swap cartridge",show_cartridge_menu)
	add_button(box,"Settings",func(): open_settings(Screen.TITLE))
	add_button(box,"Quit",func(): get_tree().quit())
	add_label(box,"Endless: random encounters, upgrades and a fresh start when your team falls.",17)
	if message != "": add_label(box,message,16,COLOR_CORAL)
	add_label(box,"Tab / arrows to navigate • Enter to choose",14,Color("#647b71"))

func show_first_cartridge(message := "") -> void:
	screen = Screen.CARTRIDGE
	clear_ui()
	var box := make_panel(Rect2(20,140,440,550))
	add_label(box,"Apricorn Island",42)
	add_label(box,"Choose your first cartridge",24)
	add_label(box,"Red and Blue have different wild Pokémon and items. Each version keeps its own Island Adventure and Endless Run saves.",19)
	for version in [Cartridge.RED, Cartridge.BLUE]:
		var button := add_button(box,Cartridge.version_name(version),choose_first_cartridge.bind(version))
		button.add_theme_color_override("font_color",Cartridge.COLORS[version])
		if version == Cartridge.RED: button.grab_focus()
	if message != "": add_label(box,message,16,COLOR_CORAL)

func choose_first_cartridge(version: String) -> void:
	if screen != Screen.CARTRIDGE or cartridge_profile.has("active") or version not in [Cartridge.RED, Cartridge.BLUE]: return
	var profile := cartridge_profile.duplicate()
	profile.active = version
	if not profile.has("original"): profile.original = version
	if not Cartridge.write_dictionary(Cartridge.PROFILE_PATH, profile):
		show_first_cartridge("Could not save your cartridge choice. Please try again.")
		return
	cartridge_profile = Cartridge.initial_profile()
	load_cartridge_sprites()
	show_title()

func show_cartridge_menu() -> void:
	if screen != Screen.DEBUG and screen != Screen.ENDING:
		if screen != Screen.TITLE or not cartridge_profile.get("yellow_unlocked",false): return
	cartridge_menu_return = screen
	screen = Screen.CARTRIDGE
	clear_ui()
	var box := make_panel(Rect2(20,118,440,590))
	add_label(box,"Swap cartridge",40)
	add_label(box,"Choose a version. Each cartridge keeps its own Island Adventure and Endless Run.",19)
	for version in Cartridge.VERSIONS:
		if not Cartridge.version_available(cartridge_profile, version): continue
		add_label(box,Cartridge.version_name(version),22,Cartridge.COLORS[version])
		var status := "New adventure"
		var island := Cartridge.read_dictionary(cartridge_save_path(false, version))
		if island.get("finished",false): status = "Island Adventure complete"
		elif island.has("party"): status = "Island Adventure saved"
		if FileAccess.file_exists(cartridge_save_path(true, version)):
			status = "Endless Run saved" if status == "New adventure" else status + " · Endless Run saved"
		add_label(box,status,16)
		add_button(box,"Currently inserted" if version == cartridge else "Insert %s" % version.capitalize(),confirm_cartridge_swap.bind(version),version == cartridge)
	if not Cartridge.version_available(cartridge_profile, Cartridge.YELLOW):
		add_label(box,"Complete Island Adventure to unlock Yellow Version.",16)
	add_button(box,"Back",close_cartridge_menu)

func close_cartridge_menu(message := "") -> void:
	if swapping_cartridge or not cartridge_profile.has("active"): return
	match cartridge_menu_return:
		Screen.DEBUG: show_debug(message)
		Screen.ENDING: show_ending(message)
		_: show_title(message)

func confirm_cartridge_swap(version: String) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Insert %s?" % Cartridge.version_name(version)
	dialog.dialog_text = "Your current progress will be waiting when you put this cartridge back."
	dialog.ok_button_text = "Swap cartridge"
	dialog.confirmed.connect(swap_cartridge.bind(version))
	show_dialog(dialog)

func swap_cartridge(version: String) -> void:
	if screen != Screen.CARTRIDGE or swapping_cartridge or not cartridge_profile.has("active"): return
	if version == cartridge or not Cartridge.version_available(cartridge_profile, version): return
	var return_screen := debug_return if cartridge_menu_return == Screen.DEBUG else cartridge_menu_return
	var playing := return_screen != Screen.TITLE and (return_screen != Screen.SETTINGS or settings_return != Screen.TITLE)
	if playing and state.has("party"):
		screen = return_screen
		var saved := save_game(true)
		screen = Screen.CARTRIDGE
		if not saved:
			close_cartridge_menu("Could not save progress. Try swapping again.")
			return
	var next_profile := cartridge_profile.duplicate()
	next_profile.active = version
	if not Cartridge.write_dictionary(Cartridge.PROFILE_PATH, next_profile):
		close_cartridge_menu("Could not insert the cartridge. Try again.")
		return
	cartridge_profile = next_profile
	swapping_cartridge = true
	state = {}
	battle = {}
	battle_finished = false
	battle_log.clear()
	visual_party.clear()
	visual_enemies.clear()
	pending_action = {}
	map_zoom = 1.0
	map_pan = Vector2.ZERO
	box_page = 0
	dex_page = 0
	dex_query = ""
	dex_filter = 0
	clear_ui()
	var box := make_panel(Rect2(20,298,440,180))
	add_label(box,"Inserting cartridge…",27)
	add_label(box,Cartridge.version_name(version),36,Cartridge.COLORS[version])
	await get_tree().create_timer(0.4 if animation_enabled else 0.0).timeout
	load_cartridge_sprites()
	load_preferences()
	apply_settings()
	swapping_cartridge = false
	var island_path := cartridge_save_path(false)
	var endless_path := cartridge_save_path(true)
	var island_time := FileAccess.get_modified_time(island_path) if FileAccess.file_exists(island_path) else 0
	var endless_time := FileAccess.get_modified_time(endless_path) if FileAccess.file_exists(endless_path) else 0
	var welcome := "%s loaded." % Cartridge.version_name(version)
	if endless_time > island_time: continue_endless(welcome)
	elif island_time > 0: continue_game(welcome)
	else: show_title("Fresh cartridge. Choose an expedition to begin.")

func request_new_game(endless: bool) -> void:
	var path := cartridge_save_path(endless)
	if not FileAccess.file_exists(path):
		show_starter_selection(endless)
		return
	if not endless and Cartridge.read_dictionary(path).get("finished",false) and not Cartridge.unlock_yellow(cartridge_profile):
		show_title("Could not save the Yellow Version unlock. Please try again.")
		return
	var dialog := ConfirmationDialog.new()
	dialog.title = "Start a new expedition?"
	if endless:
		dialog.dialog_text = "Choose a new partner to replace this Endless Run. Your Pokédex records carry over."
	else:
		dialog.dialog_text = "Choose a new partner to replace this Island Adventure. Your Endless Run is kept."
	dialog.ok_button_text = "Choose a new partner"
	dialog.cancel_button_text = "Keep my save"
	dialog.confirmed.connect(func(): show_starter_selection(endless))
	show_dialog(dialog)

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
		portrait.texture = species_sprite(species_id)
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

func continue_game(message := "Welcome back to the island!") -> void:
	if load_game():
		apply_settings()
		focus_current_stop()
		if in_glitch():
			resume_glitch()
		elif state.has("battle_checkpoint"):
			resume_battle_checkpoint()
		else: show_map(message)
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
	var box := make_panel(Rect2(20, 490, 440, 340))
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
	if in_glitch():
		show_glitch_level(message)
		return
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
	var title := add_label(heading,Cartridge.version_name(cartridge).to_upper(),18,Cartridge.COLORS[cartridge])
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
	if node.id == "lookout" and state.get("finished",false):
		var survey_panel := make_panel(Rect2(246,790,214,78))
		var survey_button := add_button(survey_panel,"Survey for wild Pokémon",start_battle.bind("survey", "lookout"))
		survey_button.add_theme_font_size_override("font_size",15)
	elif glitch_available():
		var rift_panel := make_panel(Rect2(246,790,214,78),GlitchArt.PANEL)
		add_button(rift_panel,"Activate glitch",confirm_glitch_entry)
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
		state.chest_rewards[id] = ItemCatalog.chest_rewards(seed_value, id, depth if is_endless() else 0, supplies, cartridge)
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

func in_glitch() -> bool:
	return state.has("glitch_dimension")

func glitch_available() -> bool:
	if in_glitch(): return false
	if is_endless():
		var depth := int(state.run.depth)
		return depth >= 5 and state.current_node == "run_%d" % depth and not state.run.get("pending_upgrade",false)
	return state.current_node == "airstrip" and "meadow" in state.cleared

func confirm_glitch_entry() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Unstable signal"
	dialog.dialog_text = "This glitch leads to a 50-floor dimension. The only exit is on floor 50. Activate it?"
	dialog.ok_button_text = "Activate glitch"
	dialog.confirmed.connect(enter_glitch)
	show_dialog(dialog, ui)

func enter_glitch(debug_travel := false) -> void:
	if debug_travel:
		if screen != Screen.DEBUG or not can_debug_enter_glitch(): return
	elif not glitch_available(): return
	var before := state.duplicate(true)
	var previous_battle := battle
	state.glitch_dimension = {
		"seed":rng.randi_range(1,2000000000), "floor":1, "cleared":false,
		"cache_taken":false, "return_node":state.current_node,
	}
	state.erase("battle_checkpoint")
	battle = {}
	restore_party()
	if not save_game():
		state = before
		battle = previous_battle
		if debug_travel: show_debug("The trip could not be saved. Try again.")
		else: show_map("The glitch could not be saved. Try activating it again.")
		return
	if not animation_enabled:
		show_glitch_level()
		return
	glitch_shift_time = 0.0
	screen = Screen.GLITCH_SHIFT
	clear_ui()
	sfx.play_effect("glitch")

func resume_glitch() -> void:
	battle = state.get("battle_checkpoint",{}).duplicate(true)
	if not battle.get("glitch",false):
		show_glitch_level("Your progress was saved.")
		return
	battle_finished = bool(battle.get("finished",false))
	action_index = 0
	pending_action = {}
	battle_menu = "main"
	battle_log = ["The signal reconnects."]
	show_battle()

func show_glitch_level(message := "", rewards: Dictionary = {}) -> void:
	screen = Screen.GLITCH
	clear_ui()
	var dimension: Dictionary = state.glitch_dimension
	var floor_number := int(dimension.floor)
	var cleared := bool(dimension.cleared)
	var exit_ready := cleared and floor_number == GlitchDimension.FLOOR_COUNT
	var selected_signal := GlitchDimension.Signals.get_entry(str(dimension.get("signal","")))
	var top := make_panel(Rect2(20,22,440,82),GlitchArt.PANEL)
	var tools := HBoxContainer.new()
	top.add_child(tools)
	for action in [["Party",show_party],["Bag",show_inventory],["Menu",func(): open_settings(Screen.MAP)]]:
		add_button(tools,action[0],action[1]).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var heading := VBoxContainer.new()
	heading.position = Vector2(20,143)
	heading.size = Vector2(440,140)
	ui.add_child(heading)
	var title := add_label(heading,"GLITCH DIMENSION",24,GlitchArt.LILAC)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var floor_label := add_label(heading,"Floor %02d / %02d" % [floor_number,GlitchDimension.FLOOR_COUNT],53,GlitchArt.LIGHT)
	floor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var progress := ProgressBar.new()
	progress.max_value = GlitchDimension.FLOOR_COUNT
	progress.value = floor_number if cleared else floor_number - 1
	progress.show_percentage = false
	progress.custom_minimum_size.y = 6
	var track := StyleBoxFlat.new()
	track.bg_color = Color("#52356b")
	progress.add_theme_stylebox_override("background",track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = GlitchArt.LILAC
	progress.add_theme_stylebox_override("fill",fill)
	heading.add_child(progress)
	var bottom := make_panel(Rect2(20,643,440,190),GlitchArt.PANEL)
	if not rewards.is_empty():
		add_label(bottom,"Recovered from the cache",22)
		for id in rewards:
			add_label(bottom,"%s ×%d" % [item_definition(id).name,rewards[id]],17)
	elif message != "":
		add_label(bottom,message,17)
	elif not cleared and not selected_signal.is_empty():
		add_label(bottom,"Next encounter · %s" % selected_signal.name,18)
	else:
		add_label(bottom,"A glowing door leads back to the island." if exit_ready else ("Floor cleared." if cleared else "Defeat the glitch Pokémon to clear this floor."),18)
	if cleared and floor_number % 5 == 0 and not dimension.cache_taken:
		add_button(bottom,"Open corrupted cache",open_glitch_cache)
	if exit_ready: add_button(bottom,"Open glowing door",leave_glitch)
	elif cleared: add_button(bottom,"Descend to floor %02d  →" % (floor_number + 1),advance_glitch)
	else:
		add_button(bottom,"Enter battle",start_glitch_battle)
		if floor_number < GlitchDimension.FLOOR_COUNT: add_button(bottom,"Signal archive",show_glitch_archive)

func show_glitch_archive(focus_id := "") -> void:
	screen = Screen.GLITCH_ARCHIVE
	clear_ui()
	var panel := make_panel(Rect2(20,22,440,820),GlitchArt.PANEL)
	add_label(panel,"Signal Archive",31)
	add_label(panel,"View profiles and choose this floor’s lead opponent.",17)
	var search := LineEdit.new()
	search.placeholder_text = "Name, Dex number, or index (e.g. 0xC1)"
	search.text = glitch_archive_query
	search.custom_minimum_size.y = 46
	panel.add_child(search)
	var generation := add_option_button(panel)
	generation.add_item("All generations")
	var archive_generations := [0,1,2,3,4,5,6,7,9]
	for number in archive_generations.slice(1): generation.add_item("Generation %d" % number,number)
	generation.select(archive_generations.find(glitch_archive_generation))
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = 453
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	var results := VBoxContainer.new()
	results.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(results)
	var refresh := func(focused_id: String):
		for row in results.get_children():
			results.remove_child(row)
			row.queue_free()
		scroll.scroll_vertical = 0
		var matches := GlitchDimension.Signals.find(archive_generations[generation.selected],search.text)
		if matches.is_empty(): add_label(results,"No signals found.",17)
		for record in matches:
			var label := "%s\n%s" % [record.name,GlitchDimension.Signals.details(record,true)]
			var id := str(record.id)
			var button := add_button(results,label,show_glitch_profile.bind(id))
			var profile: Dictionary = record.get("profile",{})
			if profile.has("menu_sprite"):
				button.icon = load(GlitchArt.ASSET_DIR + str(profile.menu_sprite)) as Texture2D
			else:
				button.icon = GlitchArt.encounter_sprite(GlitchDimension.signal_shape(id),record)
			button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.expand_icon = true
			button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			button.add_theme_constant_override("icon_max_width",44)
			button.add_theme_constant_override("h_separation",12)
			button.custom_minimum_size.y = 62
			button.add_theme_font_size_override("font_size",16)
			button.clip_text = true
			button.tooltip_text = "%s\n%s" % [record.name,GlitchDimension.Signals.details(record)]
			if id == focused_id: button.grab_focus.call_deferred()
	search.text_changed.connect(func(value: String): glitch_archive_query = value; refresh.call(""))
	generation.item_selected.connect(func(value: int): glitch_archive_generation = archive_generations[value]; refresh.call(""))
	add_button(panel,"Use roaming encounter",tune_glitch_signal.bind(""),not state.glitch_dimension.has("signal"))
	add_button(panel,"Back",show_glitch_level)
	refresh.call(focus_id)

func show_glitch_profile(id: String, section := -1) -> void:
	var record := GlitchDimension.Signals.get_entry(id)
	if record.is_empty(): return
	var profile: Dictionary = record.get("profile",{})
	glitch_profile = record
	var has_reference := profile.has("reference")
	var has_cartridge := profile.has("cartridge")
	var generation := int(record.generation)
	var generation_name := glitch_generation_name(generation)
	glitch_reference_section = -1
	if (section in [0,1,2,3] and has_reference) or (section == 4 and has_cartridge):
		glitch_reference_section = section
	glitch_pokedex_scan = null
	if profile.has("dex_image"):
		glitch_pokedex_scan = load(GlitchArt.ASSET_DIR + str(profile.dex_image)) as Texture2D
	screen = Screen.GLITCH_PROFILE
	clear_ui()
	var title := make_panel(Rect2(20,22,440,137),GlitchArt.PANEL)
	add_label(title,str(record.name),29)
	add_label(title,GlitchDimension.Signals.details(record),17)
	if glitch_reference_section >= 0:
		show_glitch_reference(id,profile,glitch_reference_section)
		return
	var detail := make_panel(Rect2(20,490,440,360) if glitch_pokedex_scan == null else Rect2(20,450,440,400),GlitchArt.PANEL)
	var shape := GlitchDimension.signal_shape(id)
	var species: Dictionary = GameData.SPECIES[GlitchDimension.species_id(shape)]
	var moves := PackedStringArray()
	for move in species.moves: moves.append(str(GameData.MOVES[move].name))
	var move_readout := "Moves   %s" % " · ".join(moves)
	if profile.is_empty():
		add_label(detail,"Island battle data",22)
		add_label(detail,"Form   %s" % species.name,18)
		add_label(detail,"Type   %s" % str(species.type).capitalize(),18)
		add_label(detail,move_readout,18)
		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		detail.add_child(spacer)
	else:
		add_glitch_scan_details(detail,profile,move_readout)
	var actions := HBoxContainer.new()
	detail.add_child(actions)
	add_button(actions,"Tune this encounter",tune_glitch_signal.bind(id)).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if has_reference or has_cartridge:
		var button_text := "Gen %s data" % generation_name if not generation_name.is_empty() else "Reference"
		add_button(actions,button_text,show_glitch_profile.bind(id,0 if has_reference else 4)).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_button(detail,"Back to Signal Archive",show_glitch_archive.bind(id))

func add_glitch_scan_details(detail: VBoxContainer, profile: Dictionary, move_readout: String) -> void:
	if profile.has("name_image"):
		var name_row := HBoxContainer.new()
		name_row.add_theme_constant_override("separation",12)
		detail.add_child(name_row)
		add_label(name_row,"Name readout",16).autowrap_mode = TextServer.AUTOWRAP_OFF
		var strip := TextureRect.new()
		strip.name = "NameReadout"
		strip.texture = load(GlitchArt.ASSET_DIR + str(profile.name_image)) as Texture2D
		strip.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		strip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		strip.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var strip_size := strip.texture.get_size()
		strip.custom_minimum_size = strip_size * minf(2.0,260.0 / strip_size.x)
		strip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		name_row.add_child(strip)
	var types := glitch_profile_types(profile)
	var category := str(profile.get("category","N/A"))
	if not types.is_empty():
		add_label(detail,types + ("  ·  %s Pokémon" % category if category != "N/A" else ""),20)
	var measurements := HBoxContainer.new()
	detail.add_child(measurements)
	if not str(profile.get("height","")).is_empty():
		add_label(measurements,"Height  %s" % profile.height,17).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not str(profile.get("weight","")).is_empty():
		add_label(measurements,"Weight  %s" % profile.weight,17).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_label(detail,move_readout,17)
	var note := str(profile.get("note",""))
	if note.is_empty():
		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		detail.add_child(spacer)
	else:
		add_label(detail,note,18,Color("#493854")).size_flags_vertical = Control.SIZE_EXPAND_FILL

func glitch_generation_name(generation: int) -> String:
	return ["","I","II","III","IV","V","VI","VII","VIII","IX"][clampi(generation,0,9)]

func glitch_profile_types(profile: Dictionary) -> String:
	var types := PackedStringArray()
	for type in profile.get("types",[]):
		var name := str(type)
		if name.ends_with(")") and name.length() > 4 and name.substr(name.length() - 4,1) == "(":
			name = name.left(-3) + name.right(3).to_upper()
		types.append(name.left(1).to_upper() + name.substr(1))
	return " / ".join(types)

func show_glitch_reference(id: String, profile: Dictionary, section: int) -> void:
	var panel := make_panel(Rect2(20,175,440,675),GlitchArt.PANEL)
	var generation := int(glitch_profile.generation)
	var generation_name := glitch_generation_name(generation)
	add_label(panel,"Generation %s reference" % generation_name if not generation_name.is_empty() else "Cartridge reference",22)
	if profile.has("reference"):
		var tabs := HBoxContainer.new()
		panel.add_child(tabs)
		var sections := ["Stats","Moves","Evolution","Sprites"]
		if profile.has("cartridge"): sections.append("Cartridge")
		var compact := sections.size() > 4
		for index in sections.size():
			var button := add_button(tabs,sections[index],show_glitch_profile.bind(id,index))
			button.custom_minimum_size.y = 40
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.add_theme_font_size_override("font_size",14 if compact else 16)
			if compact:
				for mode in ["normal","hover","pressed"]:
					var style: StyleBoxFlat = button.get_theme_stylebox(mode).duplicate()
					style.content_margin_left = 7
					style.content_margin_right = 7
					button.add_theme_stylebox_override(mode,style)
			button.toggle_mode = true
			button.set_pressed_no_signal(section == index)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_RESERVE
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.focus_mode = Control.FOCUS_ALL
	panel.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",5 if section in [0,2] else 10)
	scroll.add_child(body)
	var reference: Dictionary = profile.get("reference",{})
	match section:
		0:
			var stats: Array = reference.get("stats",[])
			if not stats.is_empty():
				add_label(body,"Base stats",20)
				if stats[0].size() == 4:
					add_glitch_reference_table(body,["Stat","Base","Lv. 50","Lv. 100"],stats,[96,55,97,105])
					add_label(body,"Ranges use 0–15 IVs and 0–63,001 stat experience.",15,Color("#493854"))
				else:
					add_glitch_reference_table(body,["Stat","Base"],stats,[130,85])
				var total := "Total %d" % reference.total
				if int(reference.split_total) != int(reference.total):
					total += " · %d with Special counted twice" % reference.split_total
				add_label(body,total,16)
			var matchups: Array = reference.get("matchups",[])
			if not matchups.is_empty():
				add_label(body,"Type effectiveness · %s" % glitch_profile_types(profile),20)
				for row in matchups:
					add_label(body,"%s   %s" % [row[0],row[1]],16)
			if stats.is_empty() and matchups.is_empty():
				add_label(body,"The reference has no fixed stats or type matchups for this entry.",17)
			if reference.has("matchup_note"):
				add_label(body,str(reference.matchup_note),15,Color("#493854"))
			if reference.has("catch_rate") and not profile.has("cartridge"):
				add_glitch_cartridge_stats(body,profile)
		1:
			var columns := [52,104,84,34,41,25]
			add_label(body,"Level-up moves",20)
			if reference.get("level_moves",[]).is_empty():
				add_label(body,"No level-up moves listed.",17)
			else:
				add_glitch_reference_table(body,["Level","Move","Type","Pwr","Acc","PP"],reference.level_moves,columns)
			add_label(body,"TM and HM moves",20)
			if reference.get("machine_moves",[]).is_empty():
				add_label(body,"No TM or HM moves listed.",17)
			else:
				add_glitch_reference_table(body,["TM/HM","Move","Type","Pwr","Acc","PP"],reference.machine_moves,columns)
		2:
			add_label(body,"Evolution",20)
			if not reference.has("evolutions"): add_label(body,"No evolution data listed.",18)
			elif reference.evolutions.is_empty(): add_label(body,"Does not evolve",18)
			for row in reference.get("evolutions",[]):
				var step := VBoxContainer.new()
				step.add_theme_constant_override("separation",1)
				body.add_child(step)
				add_label(step,"%s → %s" % [row[0],row[2]],18)
				add_label(step,"%s → %s" % [row[1],row[3]],15,Color("#493854"))
				add_label(step,str(row[4]),16)
			for note in reference.get("evolution_notes",[]):
				add_label(body,str(note),16,Color("#493854"))
		3:
			add_glitch_reference_sprites(body,profile)
		4:
			add_glitch_cartridge_details(body,profile)
	add_button(panel,"Back to Profile",show_glitch_profile.bind(id))

func add_glitch_cartridge_details(body: VBoxContainer, profile: Dictionary) -> void:
	var cartridge: Dictionary = profile.cartridge
	if profile.has("aliases"):
		add_label(body,"Also called  %s" % ", ".join(PackedStringArray(profile.aliases)),17)
	if cartridge.has("japanese_name"):
		var romanized := str(cartridge.get("romanized_name",""))
		var japanese := str(cartridge.japanese_name)
		add_label(body,"Japanese name  %s" % (japanese if romanized.is_empty() else "%s · %s" % [japanese,romanized]),18)
	if cartridge.has("hex_identifier"):
		add_label(body,"Hexadecimal identifier  %s" % cartridge.hex_identifier,17)
	for note in cartridge.get("notes",[]):
		add_label(body,str(note),17)
	if cartridge.has("regional_dexes"):
		add_label(body,"Regional Pokédex numbers  —",17)
		add_label(body,str(cartridge.regional_dexes),15,Color("#493854"))
	if cartridge.has("level_100_experience"):
		add_label(body,"Exp. at Lv. 100  %s" % cartridge.level_100_experience,17)
	if cartridge.has("indices"):
		add_label(body,"Version measurements",20)
		for measurement in cartridge.measurements:
			add_label(body,"%s\n%s" % [measurement[0],measurement[1]],16)
		if profile.get("reference",{}).has("catch_rate") or cartridge.has("catch_rate"):
			add_glitch_cartridge_stats(body,profile)
		var indices: Array = cartridge.indices
		add_label(body,"Hexadecimal identifiers",20)
		add_label(body,", ".join(PackedStringArray(indices.map(func(index): return "%02X" % int(index)))),16)
		add_label(body,"Mew glitch Special stats",20)
		add_label(body,", ".join(PackedStringArray(indices.map(func(index): return str(int(index))))),16)
		add_label(body,"Time Capsule equivalents",20)
		add_label(body,str(cartridge.time_capsule_equivalent),16)
	else:
		if cartridge.has("mew_glitch_special"):
			add_label(body,"Mew glitch Special stat  %s" % cartridge.mew_glitch_special,17)
		if cartridge.has("time_capsule_equivalent"):
			add_label(body,"Time Capsule equivalent  %s" % cartridge.time_capsule_equivalent,17)
		if profile.get("reference",{}).has("catch_rate") or cartridge.has("catch_rate"):
			add_glitch_cartridge_stats(body,profile)
	if cartridge.has("counterpart"):
		var counterpart := GlitchDimension.Signals.get_entry(str(cartridge.counterpart))
		add_label(body,"Equivalent in %s" % counterpart.version,17)
		add_button(body,str(counterpart.name),show_glitch_profile.bind(str(counterpart.id),4))
	if profile.has("source"):
		add_button(body,"Bulbapedia article",func(): OS.shell_open(str(profile.source)))

func add_glitch_cartridge_stats(body: VBoxContainer, profile: Dictionary) -> void:
	var reference: Dictionary = profile.get("reference",{})
	if not reference.has("catch_rate"): reference = profile.get("cartridge",{})
	var base_exp: Variant = reference.get("base_experience","Unknown")
	var experience := str(int(base_exp)) if base_exp is float else str(base_exp)
	var raw_rate: Variant = reference.catch_rate
	var catch_rate := str(int(raw_rate)) if raw_rate is float else str(raw_rate)
	add_label(body,"Cartridge data",20)
	var rate_separator := "\n" if catch_rate.length() > 16 else "  ·  "
	add_label(body,"Catch rate  %s%sBase Exp.  %s" % [catch_rate,rate_separator,experience],16)
	add_label(body,"Category  %s  ·  Hybrid of  %s" % [profile.category,reference.hybrid],16)
	add_label(body,"EV yield  %s" % reference.get("ev_yield","Unknown"),16)

func add_glitch_reference_table(body: VBoxContainer, headings: Array, rows: Array, widths: Array) -> void:
	var table := GridContainer.new()
	table.columns = headings.size()
	table.add_theme_constant_override("h_separation",5)
	table.add_theme_constant_override("v_separation",5)
	body.add_child(table)
	var data_rows := [headings] + rows
	for row_index in data_rows.size():
		var row: Array = data_rows[row_index]
		for column in headings.size():
			var value: Variant = row[column]
			var display := str(int(value)) if value is float else str(value)
			var cell := add_label(table,display,15,Color("#563674") if row_index == 0 else COLOR_INK)
			cell.custom_minimum_size.x = widths[column]
			cell.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if headings.size() > 4 and column in [1,2] else TextServer.AUTOWRAP_OFF

func add_glitch_reference_sprites(body: VBoxContainer, profile: Dictionary) -> void:
	var back: Texture2D
	if profile.has("back_sprite"):
		back = load(GlitchArt.ASSET_DIR + str(profile.back_sprite)) as Texture2D
	elif profile.get("back_obscured",false):
		var pixels := Image.create_empty(56,56,false,Image.FORMAT_RGBA8)
		pixels.fill(Color.BLACK)
		back = ImageTexture.create_from_image(pixels)
	var menu: Texture2D
	if profile.has("menu_sprite"):
		menu = load(GlitchArt.ASSET_DIR + str(profile.menu_sprite)) as Texture2D
	var entries := []
	if profile.has("sprite"): entries.append(["Front",GlitchArt.profile_sprite(profile),2.0])
	if back != null: entries.append(["Back",back,2.0])
	if menu != null: entries.append(["Menu",menu,4.0])
	if entries.is_empty(): add_label(body,"No cartridge sprites are available for this entry.",17)
	else: add_glitch_sprite_row(body,entries)
	var alternate_names: Array = profile.get("alternate_front_sprites",[])
	if not alternate_names.is_empty():
		var alternates := []
		for index in alternate_names.size():
			var texture := load(GlitchArt.ASSET_DIR + str(alternate_names[index])) as Texture2D
			alternates.append(["Front %d" % (index + 2),texture,2.0])
		add_glitch_sprite_row(body,alternates)
	if profile.get("back_obscured",false):
		add_label(body,"A solid black glitch screen covers the back sprite.",16,Color("#493854"))
	if profile.has("sprite_note"):
		add_label(body,str(profile.sprite_note),16,Color("#493854"))

func add_glitch_sprite_row(body: VBoxContainer, entries: Array) -> void:
	var gallery := HBoxContainer.new()
	gallery.add_theme_constant_override("separation",8)
	body.add_child(gallery)
	for entry in entries:
		var tile := VBoxContainer.new()
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gallery.add_child(tile)
		var frame := PanelContainer.new()
		frame.custom_minimum_size.y = 146
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#1c122c")
		style.set_corner_radius_all(8)
		frame.add_theme_stylebox_override("panel",style)
		tile.add_child(frame)
		var center := CenterContainer.new()
		frame.add_child(center)
		var sprite := TextureRect.new()
		sprite.name = "%sReferenceSprite" % str(entry[0]).replace(" ","")
		sprite.texture = entry[1]
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		var pixels := sprite.texture.get_size()
		sprite.custom_minimum_size = pixels * minf(float(entry[2]),minf(115.0 / pixels.x,135.0 / pixels.y))
		center.add_child(sprite)
		add_label(tile,entry[0],17).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func tune_glitch_signal(id: String) -> void:
	var dimension: Dictionary = state.glitch_dimension
	if dimension.cleared or int(dimension.floor) >= GlitchDimension.FLOOR_COUNT: return
	if not id.is_empty() and GlitchDimension.Signals.get_entry(id).is_empty(): return
	var before := state.duplicate(true)
	if id.is_empty(): dimension.erase("signal")
	else: dimension["signal"] = id
	if not save_game():
		state = before
		show_glitch_level("The signal could not be saved. Try again.")
		return
	show_glitch_level()

func open_glitch_cache() -> void:
	var dimension: Dictionary = state.glitch_dimension
	var floor_number := int(dimension.floor)
	if not dimension.cleared or dimension.cache_taken or floor_number % 5 != 0: return
	var before := state.duplicate(true)
	var rewards := GlitchDimension.cache_loot(int(dimension.seed),floor_number)
	grant_items(rewards)
	dimension.cache_taken = true
	if not save_game():
		state = before
		show_glitch_level("The cache could not be saved. Try opening it again.")
		return
	sfx.play_effect("glitch")
	show_glitch_level("",rewards)

func advance_glitch() -> void:
	var dimension: Dictionary = state.glitch_dimension
	if not dimension.cleared or int(dimension.floor) >= GlitchDimension.FLOOR_COUNT: return
	var before := state.duplicate(true)
	dimension.floor = int(dimension.floor) + 1
	dimension.cleared = false
	dimension.cache_taken = false
	dimension.erase("signal")
	if not save_game():
		state = before
		show_glitch_level("The next floor could not be saved. Try again.")
		return
	sfx.play_effect("travel")
	show_glitch_level()

func leave_glitch(debug_travel := false) -> void:
	var dimension: Dictionary = state.get("glitch_dimension",{})
	var completed := bool(dimension.get("cleared",false)) and int(dimension.get("floor",0)) == GlitchDimension.FLOOR_COUNT
	if debug_travel:
		if screen != Screen.DEBUG or dimension.is_empty() or battle_busy or resolving_round: return
	elif not completed: return
	var before := state.duplicate(true)
	var previous_battle := battle
	state.current_node = dimension.return_node
	if completed: state.glitch_completed = true
	state.erase("glitch_dimension")
	state.erase("battle_checkpoint")
	battle = {}
	restore_party()
	if not save_game():
		state = before
		battle = previous_battle
		if debug_travel: show_debug("The exit could not be saved. Try again.")
		else: show_glitch_level("The exit could not be saved. Try the door again.")
		return
	battle_finished = false
	pending_action = {}
	sfx.play_effect("travel")
	focus_current_stop()
	show_map("Returned from the Glitch Dimension." if debug_travel else "You escaped the Glitch Dimension!")

func start_glitch_battle() -> void:
	var dimension: Dictionary = state.glitch_dimension
	if dimension.cleared: return
	var before := state.duplicate(true)
	if living_party_indices().is_empty(): restore_party()
	battle = {
		"glitch":true, "enemies":GlitchDimension.encounter(dimension,state.party),
		"node_id":"glitch_floor_%d" % int(dimension.floor), "actions":[], "rewards":{},
		"context":{"turn":1,"night":true}, "participants":living_party_indices(),
	}
	for pokemon in state.party + battle.enemies:
		ItemMechanics.reset_battle(pokemon)
		ItemProgression.form(pokemon,true)
	action_index = 0
	pending_action = {}
	battle_menu = "main"
	battle_finished = false
	visual_party.clear()
	visual_enemies.clear()
	var opponents := PackedStringArray()
	for pokemon in battle.enemies: opponents.append(GameData.pokemon_name(pokemon))
	battle_log = ["The signal takes shape. %s appeared." % ", ".join(opponents)]
	MoveEffects.start_abilities(battle,state,battle_log)
	for pokemon in state.party: ItemMechanics.activate_berry(pokemon,GameData.ITEMS,battle_log)
	if not save_game():
		state = before
		battle = {}
		show_glitch_level("The encounter could not be saved. Try again.")
		return
	start_battle_presentation()

func finish_glitch_battle(won: bool) -> void:
	var previous_state := state.duplicate(true)
	var previous_battle := battle.duplicate(true)
	var dimension: Dictionary = state.glitch_dimension
	if won:
		var messages: Array[String] = []
		award_battle_experience(messages)
		dimension.cleared = true
		for pokemon in state.party: ItemMechanics.reset_battle(pokemon)
	var recovered := not won or int(dimension.floor) % 5 == 0
	if recovered: restore_party()
	state.erase("battle_checkpoint")
	battle = {}
	if not save_game():
		state = previous_state
		battle = previous_battle
		if won:
			battle_log.append("Clear could not be saved. Choose Continue to retry saving.")
			show_battle()
		else:
			restore_party()
			state.erase("battle_checkpoint")
			battle = {}
			show_glitch_level("Recovery could not be saved. Your team can retry this floor.")
		return
	battle_finished = false
	if not won: show_glitch_level("Your team recovered. This floor is ready to retry.")
	elif int(dimension.floor) == GlitchDimension.FLOOR_COUNT: show_glitch_level()
	else: show_glitch_level("Floor cleared. Your team recovered." if recovered else "Floor cleared.")

func show_party() -> void:
	screen = Screen.PARTY
	clear_ui()
	var box := make_panel(Rect2(20, 20, 440, 860), Color("#fff4d6fa"))
	add_label(box, "Party & Reserve Box", 32)
	add_label(box, "Choose a party slot, then choose a reserve Pokémon to swap.", 16, Color("#536b77"))
	add_label(box, "Earn EXP by defeating opponents. Each level adds HP and battle stats, up to level 100.", 16, Color("#536b77"))
	var party_row := VBoxContainer.new()
	box.add_child(party_row)
	for i in state.party.size():
		var p: Dictionary = state.party[i]
		var data: Dictionary = GameData.SPECIES[p.species]
		var button := add_button(party_row, "%s · Lv.%d · HP %d/%d" % [data.name,int(p.get("level",5)),p.hp,p.max_hp], select_party_slot.bind(i))
		button.icon = pokemon_sprite(p)
		button.add_theme_constant_override("icon_max_width",40)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text += "\n" + str(ItemMechanics.level_progress(p).label)
		button.tooltip_text = "Level up: +2 maximum HP and +1 Attack, Defense, Special Attack, Special Defense and Speed."
		if i == selected_party_index:
			button.modulate = Color("#fff0a8")
	add_button(box,"View selected Pokémon",show_pokemon_summary.bind(selected_party_index,false))
	if not state.party[selected_party_index].get("pending_moves",[]).is_empty() or state.party[selected_party_index].get("pending_evolution","") != "":
		add_button(box,"Level-up moves / Evolution",show_level_choices.bind(selected_party_index))
	add_label(box, "Reserve Pokémon", 23)
	var scroll := add_vertical_scroll(box)
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
			add_button(reserve_row, "Swap in %s\nLv.%d · HP %d/%d" % [data.name,int(p.get("level",5)),p.hp,p.max_hp], swap_party.bind(i)).size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	summary.setup(collection,pokemon_sprite,index)

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
	var panel := make_panel(Rect2(20, 20, 440, 860), Color("#e2f3eafa"))
	add_label(panel, "POKÉMON BOX • PC STORAGE", 30)
	add_label(panel, "Choose a party slot, then a stored Pokémon to swap. Caught Pokémon arrive here automatically.", 17)
	add_button(panel,"View selected Pokémon",show_pokemon_summary.bind(selected_party_index,false))
	add_button(panel,"Stored Pokémon: Details" if box_inspect else "Stored Pokémon: Swap",func(): box_inspect = not box_inspect; show_box())
	var party_row := VBoxContainer.new()
	panel.add_child(party_row)
	for i in state.party.size():
		var pokemon: Dictionary = state.party[i]
		var button := add_button(party_row, "%s · Lv.%d • HP %d/%d" % [GameData.SPECIES[pokemon.species].name, int(pokemon.get("level",5)), pokemon.hp, pokemon.max_hp], func():
			selected_party_index = i
			show_box()
		)
		button.icon = pokemon_sprite(pokemon)
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
	var scroll := add_vertical_scroll(panel)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(grid)
	for slot in 30:
		var index := box_page * 30 + slot
		var occupied: bool = index < state.reserve.size()
		var pokemon: Dictionary = state.reserve[index] if occupied else {}
		var button := add_button(grid, str(GameData.SPECIES[pokemon.species].name) if occupied else "—", show_pokemon_summary.bind(index,true) if box_inspect else swap_box_pokemon.bind(index), not occupied)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 15)
		if occupied:
			button.icon = pokemon_sprite(pokemon)
			button.add_theme_constant_override("icon_max_width", 42)
			button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
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
	var probability := ItemCatalog.item_probability(id,depth,cartridge)
	if item.get("glitched",false):
		add_label(detail,"Found in corrupted caches. The effect applies before the break roll.",18)
	elif probability > 0:
		add_label(detail,"At depth %d: %.5f%% per roll; %.5f%% in three rolls." % [depth,probability*100.0,(1.0-pow(1.0-probability,3))*100.0],18)
	else:
		var availability := "Guaranteed island supplies; also retained in existing rewards."
		if not Cartridge.has_item(cartridge,id): availability = "This item was kept from an earlier save."
		elif GameData.DLC_ITEMS.has(id): availability = "Found in Yellow Version or the spinoff DLC."
		add_label(detail,availability,18)
	if GameData.DLC_ITEMS.has(id) and not spinoff_items_available(): return
	if item.kind == "boss_orb":
		BossOrbs.initialize(state)
		for i in state.orb_instances.get(id,[]).size():
			add_button(detail,"Summon · Copy %d · %s" % [i+1,BossOrbs.label(state.orb_instances[id][i],state.orb_boss_caught.get(id,false))],start_orb_boss.bind(id,i),in_glitch() or not Cartridge.has_species(cartridge,BossOrbs.SPECIES[id]) or not BossOrbs.available(state,id,i))
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
	if party_index < 0 or party_index >= state.party.size(): return
	var item := item_definition(item_id)
	if item.kind not in ["heal","revive","medicine","cure_berry","held_berry"]: return
	if int(state.inventory.get(item_id, 0)) <= 0: return
	var before := state.duplicate(true)
	var pokemon: Dictionary = state.party[party_index]
	if not ItemCatalog.apply(item,pokemon): return
	var broke := spend_item(item_id)
	sfx.play_effect("heal")
	finish_bag_item(before,item_id,broke)

func spend_item(id: String) -> bool:
	var item := item_definition(id)
	if item.get("glitched",false):
		if not GlitchDimension.breaks_on_use(rng): return false
		state.inventory[id] -= 1
		return true
	if not debug_options.unlimited_items and not item.get("reusable",false): state.inventory[id] -= 1
	return false

func finish_bag_item(before: Dictionary, id: String, broke: bool) -> void:
	if not save_game():
		state = before
		show_inventory()
		return
	show_inventory()
	if broke:
		var notice := AcceptDialog.new()
		notice.dialog_text = "%s broke after use." % item_definition(id).name
		show_dialog(notice, ui)

func open_settings(return_screen: Screen) -> void:
	character_customization_open = false
	settings_return = return_screen
	settings_animation_toggles = 0
	screen = Screen.SETTINGS
	clear_ui()
	if state.is_empty():
		state = {"settings":{"volume":0.8,"fullscreen":false}}
	if not state.has("settings"):
		state.settings = {"volume":0.8,"fullscreen":false}
	var box := make_panel(Rect2(20, 20, 440, 860), Color("#fff4d6fa"))
	add_label(box, "Settings", 34)
	add_button(box, "Customize character", show_character_customization)
	add_label(box, "Adventure difficulty", 18)
	var difficulty := add_option_button(box)
	difficulty.add_item("Easy — a relaxed island trip")
	difficulty.add_item("Normal — a gentle challenge")
	difficulty.add_item("Hard — tougher battles")
	var difficulty_ids := ["easy", "normal", "hard"]
	var selected_difficulty := difficulty_ids.find(state.settings.get("difficulty", "normal"))
	difficulty.selected = selected_difficulty if selected_difficulty >= 0 else 1
	difficulty.item_selected.connect(func(index: int):
		settings_animation_toggles = 0
		state.settings.difficulty = difficulty_ids[index]
		save_preferences()
	)
	add_label(box, "Master Volume", 18)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 1
	slider.step = 0.05
	slider.custom_minimum_size.y = 30
	slider.value = float(state.settings.volume)
	slider.value_changed.connect(func(value: float):
		settings_animation_toggles = 0
		state.settings.volume = value
		AudioServer.set_bus_volume_db(0, linear_to_db(max(0.001,value)))
		AudioServer.set_bus_mute(0,value <= 0.0)
		save_preferences()
	)
	box.add_child(slider)
	var full := CheckButton.new()
	full.text = "Fullscreen"
	full.custom_minimum_size.y = 48
	full.add_theme_color_override("font_color", COLOR_INK)
	full.add_theme_color_override("font_focus_color", COLOR_INK)
	full.button_pressed = bool(state.settings.fullscreen)
	full.toggled.connect(func(value: bool):
		settings_animation_toggles = 0
		state.settings.fullscreen = value
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED)
		save_preferences()
	)
	box.add_child(full)
	var animations := CheckButton.new()
	animations.text = "Battle animations"
	animations.custom_minimum_size.y = 48
	animations.add_theme_color_override("font_color", COLOR_INK)
	animations.add_theme_color_override("font_focus_color", COLOR_INK)
	animations.button_pressed = bool(state.settings.get("animations",true))
	animations.toggled.connect(func(value: bool):
		state.settings.animations = value
		animation_enabled = value and DisplayServer.get_name() != "headless"
		save_preferences()
		settings_animation_toggles += 1
		if settings_animation_toggles == DEBUG_ANIMATION_TOGGLES:
			settings_animation_toggles = 0
			open_debug()
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
				show_dialog(warning, ui)
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
	var encounter: Dictionary
	var survey := encounter_id == "survey"
	if is_endless():
		var depth := int(get_node_data(node_id).floor)
		encounter = RogueRules.encounter(int(state.run.seed), depth, state.get("pokedex", {}), cartridge)
	elif survey:
		if not state.get("finished", false) or state.current_node != "lookout": return
		var outing := int(state.get("survey_count", 0))
		encounter = RogueRules.encounter(int(state.loot_seed) + outing, 14, state.get("pokedex", {}), cartridge)
		encounter.rewards = ItemCatalog.chest_rewards(int(state.loot_seed), "survey_%d" % outing, 14, encounter.rewards, cartridge)
	else:
		encounter = GameData.ENCOUNTERS[encounter_id]
	battle_menu = "main"
	if node_id == "summit":
		restore_party()
	var enemies: Array = []
	if is_endless() or survey:
		enemies = encounter.enemies
	else:
		var victories := 0
		var cleared: Array = state.get("cleared", [])
		for stop in GameData.NODES:
			if stop.kind == "battle" and stop.id in cleared: victories += 1
		for species_id in Cartridge.story_species(cartridge, encounter.enemies):
			var pokemon := GameData.make_pokemon(species_id)
			if victories > 0:
				GameData.scale_wild(pokemon, 5 + victories,
					1.0 + victories * 0.045, 1.0 + victories * 0.035, 1.0 + victories * 0.025)
			enemies.append(pokemon)
	for p in state.party:
		ItemMechanics.reset_battle(p)
	for p in enemies:
		register_dex(str(p.species), false)
		ItemMechanics.reset_battle(p)
	for p in state.party+enemies: ItemProgression.form(p,true)
	battle = {"encounter_id":encounter_id,"node_id":node_id,"return_node":state.current_node,"enemies":enemies,"actions":[],"rewards":encounter.rewards.duplicate()}
	var hour := int(Time.get_time_dict_from_system().hour)
	var node := get_node_data(node_id)
	battle.context = {"turn":1,"night":hour < 6 or hour >= 18,"cave":bool(node.get("cave",false)),"water":node_id in ["brook","falls"] or str(node.name) in ["Coral Shore","Starlight Marsh","Crystal Brook"],"fishing":false}
	battle.participants = living_party_indices()
	action_index = 0
	pending_action = {}
	battle_log = ["Wild Pokémon appeared! Choose one action for each teammate."]
	for pokemon in enemies:
		if pokemon.get("shiny", false):
			battle_log.append("A shiny %s appeared!" % GameData.pokemon_name(pokemon))
	MoveEffects.start_abilities(battle,state,battle_log)
	for pokemon in state.party+enemies: ItemMechanics.activate_berry(pokemon,GameData.ITEMS,battle_log)
	battle_finished = false
	visual_party.clear()
	visual_enemies.clear()
	start_battle_presentation()
	if is_endless(): save_game()

func start_battle_presentation() -> void:
	battle_entry_time = 0.0 if animation_enabled else 1.0
	if animation_enabled:
		for pokemon in state.party + battle.enemies:
			if pokemon.get("shiny", false) and int(pokemon.hp) > 0:
				sfx.play_effect("shiny")
				break
	show_battle()

func show_battle() -> void:
	for pokemon in battle.get("enemies",[]): register_dex(str(pokemon.species), false)
	screen = Screen.BATTLE
	clear_ui()
	if battle_busy:
		var busy_panel := make_panel(Rect2(16,482,448,190))
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
	var dialogue := make_panel(Rect2(16, 482, 448, 154))
	dialogue.add_theme_constant_override("separation", 4)
	add_label(dialogue, "VICTORY!" if battle_finished else "BATTLE  /  ROUND %d" % int(battle.get("round", 1)), 15, Color("#3b8176"))
	var ally_index: int = living[min(action_index, living.size()-1)]
	var ally: Dictionary = state.party[ally_index]
	add_label(dialogue, "Well done, team!" if battle_finished else "What will %s do?" % GameData.SPECIES[ally.species].name, 27)
	var log_scroll := add_vertical_scroll(dialogue)
	var log_label := add_label(log_scroll, "\n".join(battle_log), 17)
	log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var commands := make_panel(Rect2(16, 646, 448, 238))
	if battle_finished:
		if battle.get("glitch",false):
			add_label(commands,"Floor %02d cleared." % int(state.glitch_dimension.floor),21)
			add_button(commands,"Continue  →",finish_victory)
		else:
			add_label(commands, "Choose an upgrade. HP carries into the next fight." if is_endless() else "Your team will recover all HP.", 21)
			add_button(commands, "Collect rewards & explore  →", finish_victory)
		return
	var grid := GridContainer.new()
	grid.columns = 2 if pending_action.is_empty() and battle_menu == "main" else 1
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_vertical_scroll(commands).add_child(grid)
	if not pending_action.is_empty():
		if pending_action.kind == "heal_item":
			var item := item_definition(str(pending_action.item))
			if pending_action.has("target") and item.kind == "pp_medicine":
				var patient: Dictionary = state.party[int(pending_action.target)]
				for move_id in patient.moves:
					add_button(grid,str(GameData.MOVES[move_id].name),confirm_pp_target.bind(str(move_id)),not PendingItems.pp_use(item,patient,str(move_id),false))
			else:
				for i in state.party.size():
					var pokemon: Dictionary = state.party[i]
					add_button(grid,"%s %d/%d HP" % [GameData.SPECIES[pokemon.species].name,pokemon.hp,pokemon.max_hp],confirm_item_target.bind(i),not ItemCatalog.can_apply(item,pokemon))
		else:
			for enemy_index in living_enemy_indices():
				var enemy: Dictionary = battle.enemies[enemy_index]
				var label := "%s  %d/%d HP" % [GameData.pokemon_name(enemy), enemy.hp, enemy.max_hp]
				var button := add_button(grid,label,confirm_target.bind(enemy_index))
				button.clip_text = true
				button.tooltip_text = label
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
	battle_entry_time = 1.0
	resolving_round = true
	animation_events.clear()
	quick_attack_results.clear()
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
		var results: Array[Dictionary] = []
		actor.acted_this_turn = true
		if action.kind == "heal_item": use_heal_in_battle(action,messages)
		elif action.kind == "ball": resolve_ball_action(action,messages)
		elif player_side: resolve_player_move(action,messages,results)
		else:
			var targets := living_party_indices()
			var target_index := int(action.target)
			if target_index not in targets: target_index = int(targets[0])
			results.append(resolve_move(actor,state.party[target_index],str(action.move),messages,false))
		if battle.get("escaped",false):
			resolving_round = false
			flee_battle()
			return
		for pokemon in state.party+battle.enemies: PendingItems.activate(pokemon,battle,rng)
		if battle.get("glitch",false): glitch_damage_reactions(before_enemies,messages)
		queue_battle_effect(action,player_side,before_party,before_enemies,messages.slice(message_start),results)
	var before_residual: Array = battle.enemies.duplicate(true) if battle.get("glitch",false) else []
	for pokemon in state.party+battle.enemies:
		MoveEffects.end_turn(pokemon,battle,rng,messages,state)
		ItemMechanics.activate_berry(pokemon,GameData.ITEMS,messages)
	if not before_residual.is_empty(): glitch_damage_reactions(before_residual,messages)
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
	if is_endless() or battle.get("glitch",false): save_game()
	if animation_enabled and not animation_events.is_empty():
		play_round_animation()
	else:
		finish_round_presentation()

func glitch_damage_reactions(before: Array, messages: Array[String]) -> void:
	for i in before.size():
		var enemy: Dictionary = battle.enemies[i]
		if int(enemy.hp) >= int(before[i].hp): continue
		enemy.glitch_impact = int(enemy.glitch_impact) + 1
		var name := GameData.pokemon_name(enemy)
		messages.append("%s folds into static. Its signal is gone." % name if int(enemy.hp) <= 0 else "%s comes apart, then pulls itself back together." % name)

func resolve_player_move(action: Dictionary, messages: Array[String], results: Array[Dictionary]) -> void:
	var actor: Dictionary = state.party[int(action.actor)]
	var move: Dictionary = GameData.MOVES[str(action.move)]
	if int(move.get("target",10)) in [9,11]:
		if not MoveEffects.can_act(actor,str(action.move),rng,messages): return
		if actor.has("pp"): actor.pp[str(action.move)] = maxi(0,int(actor.pp.get(str(action.move),35))-1)
		for enemy in battle.enemies:
			if int(enemy.hp) > 0: results.append(resolve_move(actor,enemy,str(action.move),messages,true,false))
		return
	if move.kind in ["heal","buff"] or int(move.get("target",10)) in [4,5,7,12,13,14]:
		results.append(resolve_move(actor,actor,str(action.move),messages,true))
		return
	var target_index := int(action.target)
	if target_index < 0 or target_index >= battle.enemies.size() or battle.enemies[target_index].hp <= 0:
		var alternatives := living_enemy_indices()
		if alternatives.is_empty(): return
		target_index = alternatives[0]
	results.append(resolve_move(actor,battle.enemies[target_index],str(action.move),messages,true))

func resolve_move(actor: Dictionary, target: Dictionary, move_id: String, messages: Array[String], player_actor: bool, check_action: bool = true) -> Dictionary:
	var move: Dictionary = GameData.MOVES[move_id]
	if check_action and not MoveEffects.can_act(actor,move_id,rng,messages):
		actor.metronome_count = 0
		ItemMechanics.activate_berry(actor,GameData.ITEMS,messages)
		return {}
	if check_action and move_id != "struggle" and actor.has("pp") and actor.get("charging_move","") != move_id:
		actor.pp[move_id] = maxi(0,int(actor.pp.get(move_id,35))-1)
	actor.acted_this_turn = true
	if move.has("effect_id") or move.kind in ["damage","heal","buff","debuff"]:
		var result := MoveEffects.resolve(actor,target,move_id,battle,state,rng,messages,enemy_damage_scale() if not player_actor else 1.0,player_actor and debug_options.accuracy,player_actor and debug_options.one_hit,not player_actor and debug_options.invincible)
		ItemMechanics.activate_berry(actor,GameData.ITEMS,messages)
		ItemMechanics.activate_berry(target,GameData.ITEMS,messages)
		return result
	var actor_name := GameData.pokemon_name(actor)
	var target_name := GameData.pokemon_name(target)
	if target.get("protected",false) or (rng.randf() > MoveEffects.accuracy(actor,target,move) and not (actor.get("accuracy_bypass",false) or (player_actor and debug_options.accuracy))):
		messages.append("%s used %s, but missed!" % [actor_name,move.name])
		return {"target":target,"kind":"blocked" if target.get("protected",false) else "miss"}
	var result := {}
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
				return {"target":target,"kind":"no_effect"}
			var damage := GameRules.calculate_damage(boosted_power,ItemMechanics.stat(actor,attack_stat),ItemMechanics.stat(target,defense_stat),effect,rng.randf_range(0.9,1.1))
			if not player_actor:
				damage = max(1, int(round(damage * enemy_damage_scale())))
			if not player_actor and debug_options.invincible: damage = 0
			if player_actor and debug_options.one_hit: damage = int(target.hp)
			result = {"target":target,"kind":"hit","damage":mini(int(target.hp),damage),"max_hp":int(target.max_hp)}
			target.hp = max(0,target.hp-damage)
			var suffix := " It's super effective!" if effect > 1.0 else (" It's not very effective." if effect < 1.0 else "")
			messages.append("%s used %s on %s for %d damage.%s" % [actor_name,move.name,target_name,damage,suffix])
			if target.hp <= 0:
				messages.append("%s fainted!" % target_name)
	ItemMechanics.activate_berry(actor,GameData.ITEMS,messages)
	ItemMechanics.activate_berry(target,GameData.ITEMS,messages)
	return result

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
	var broke := spend_item(ball_id)
	var item: Dictionary = available[ball_id]
	var name := GameData.pokemon_name(target)
	if battle.get("glitch",false):
		target.glitch_impact = int(target.glitch_impact) + 1
		messages.append("%s splits around the %s and reforms outside it." % [name,item.name])
		if broke: messages.append("%s broke after use." % item.name)
		return
	var context: Dictionary = battle.get("context",{}).duplicate()
	context.turn = int(battle.get("action_turn",battle.get("round",1)))
	var multiplier := ItemMechanics.ball_multiplier(ball_id,target,state.party[int(action.actor)],context,state.get("caught_species",[]),item)
	var guaranteed: bool = ball_id == "item_master_ball" or (ball_id == "item_dreamy_ball" and bool(context.get("entree_forest",false)))
	var chance := 1.0 if guaranteed else (GameRules.capture_chance(float(item.bonus),target.hp,target.max_hp) if ball_id in ["apricorn_ball","great_apricorn_ball"] or item.get("glitched",false) else ItemMechanics.capture_chance(multiplier,target))
	if rng.randf() <= chance or debug_options.capture:
		target.hp = max(1,target.hp)
		var caught := target.duplicate(true)
		caught.cartridge = cartridge
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
		var joins_party: bool = state.party.size() < 3
		if joins_party:
			state.party.append(caught)
		else:
			state.reserve.append(caught)
		if not state.has("caught_species"): state.caught_species = []
		if str(target.species) not in state.caught_species: state.caught_species.append(str(target.species))
		register_dex(str(target.species), true)
		target.captured = true
		target.hp = 0
		if caught.get("shiny", false): name = "Shiny " + name
		var destination := "party" if joins_party else "reserve box"
		messages.append("Click... sparkle! %s joined your %s!" % [name, destination])
	else:
		messages.append("%s popped free of the %s!" % [name,item.name])
	if broke: messages.append("%s broke after use." % item.name)

func battle_items() -> Dictionary:
	var result := GameData.ITEMS.duplicate()
	result.merge(GameData.GLITCH_ITEMS)
	if spinoff_items_available(): result.merge(GameData.DLC_ITEMS)
	return result

func spinoff_items_available() -> bool:
	return cartridge == Cartridge.YELLOW or state.get("enabled_dlc", "") == "spinoff"

func item_definition(id: String) -> Dictionary:
	if GameData.ITEMS.has(id): return GameData.ITEMS[id]
	if GameData.GLITCH_ITEMS.has(id): return GameData.GLITCH_ITEMS[id]
	if GameData.DLC_ITEMS.has(id):
		var item: Dictionary = GameData.DLC_ITEMS[id].duplicate()
		if cartridge == Cartridge.YELLOW: item.description = str(item.description).get_slice(" Reserved", 0)
		return item
	return {"id":id,"name":id.trim_prefix("item_").replace("_"," ").capitalize(),"category":"Stored legacy items","rarity":"common","kind":"collectible","status":"awaiting_mechanics","description":"Retained from an older save.","requirement":"Legacy item effect"}

func finish_victory() -> void:
	if battle.get("glitch",false):
		if battle_finished and all_enemies_gone(): finish_glitch_battle(true)
		return
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
	state.erase("battle_checkpoint")
	if battle.get("encounter_id", "") == "survey": state.survey_count = int(state.get("survey_count", 0)) + 1
	save_game()
	show_map("Team fully rested! Rewards: " + reward_text(battle.rewards))

func handle_defeat() -> void:
	if battle.get("glitch",false):
		finish_glitch_battle(false)
		return
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
	state.erase("battle_checkpoint")
	save_game()
	battle = {}
	show_map("Your team is fully rested. Try a different move or return whenever you are ready.")

func flee_battle() -> void:
	if battle.get("glitch",false):
		battle.erase("escaped")
		battle_log.append("The way back has vanished. The exit is beyond floor 50.")
		show_battle()
		return
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
	state.erase("battle_checkpoint")
	save_game()
	battle = {}
	show_map("You safely left the encounter. Its wild Pokémon will be waiting.")

func show_ending(message := "") -> void:
	if not state.get("finished",false):
		var previous := state.duplicate(true)
		mark_cleared("lookout")
		state.finished = true
		if not save_game():
			state = previous
			show_map("Could not save completion. Visit the lookout again to retry.")
			return
	var newly_unlocked := not bool(cartridge_profile.get("yellow_unlocked",false))
	var yellow_unlocked := Cartridge.unlock_yellow(cartridge_profile)
	screen = Screen.ENDING
	clear_ui()
	var box := make_panel(Rect2(20, 280, 440, 590), Color("#fff4d6f2"))
	var title := add_label(box, "ISLAND ADVENTURE COMPLETE!", 34, COLOR_GREEN)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_label(box, "Your team reaches the lookout as sunset colors dance over the sea. The island still holds friends to catch and paths to revisit.", 21)
	add_label(box, "Reserve friends: %d   •   Map progress: %s" % [state.reserve.size(),progress_text()], 18)
	if newly_unlocked:
		if yellow_unlocked: add_label(box, "Yellow Version unlocked! Choose it under Swap cartridge.", 19, Cartridge.COLORS[Cartridge.YELLOW])
		else: add_label(box, "Could not save the Yellow Version unlock. Revisit the lookout to retry.", 17, COLOR_CORAL)
	if message != "": add_label(box, message, 17, COLOR_CORAL)
	add_button(box, "Swap cartridge", show_cartridge_menu)
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
		if not Cartridge.has_item(cartridge, str(item_id)): continue
		for count in int(rewards[item_id]):
			var target: String = "item_sacred_ash_ketchum" if item_id == "item_sacred_ash" and rng.randi_range(1,100) == 1 else str(item_id)
			received[target] = int(received.get(target,0))+1
			state.inventory[target] = int(state.inventory.get(target,0)) + 1
	rewards.clear()
	rewards.merge(received)

func reward_text(rewards: Dictionary) -> String:
	var parts: Array[String] = []
	for item_id in rewards:
		parts.append("%s ×%d" % [item_definition(item_id).name,rewards[item_id]])
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

func cartridge_save_path(endless: bool, version := "") -> String:
	return Cartridge.save_path(cartridge if version == "" else version, str(cartridge_profile.get("original", cartridge)), endless)

func save_game(keep_battle := false) -> bool:
	if resolving_round: return false
	if not state.has("party"): return false
	if not cartridge_profile.has("active"): return false
	if (screen == Screen.BATTLE and not battle.is_empty() and (keep_battle or is_endless() or state.has("battle_checkpoint"))) or battle.has("orb_item") or (in_glitch() and battle.get("glitch",false)):
		state.battle_checkpoint = battle.duplicate(true)
		state.battle_checkpoint.actions = []
		state.battle_checkpoint.finished = battle_finished
	prepare_save_state()
	return Cartridge.write_dictionary(cartridge_save_path(is_endless()), state)

func load_game() -> bool:
	var saved := Cartridge.read_dictionary(cartridge_save_path(false))
	if not saved.has("party") or not saved.has("inventory") or not saved.has("current_node"): return false
	state = saved
	prepare_save_state()
	return true

func prepare_save_state() -> void:
	for pokemon in state.get("party", []) + state.get("reserve", []): pokemon.cartridge = cartridge
	sync_pokedex()
	ItemCatalog.migrate(state)
	FunRules.initialize(state)

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
		elif screen in [Screen.MAP, Screen.PARTY, Screen.GLITCH]:
			show_inventory()
		else: return
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if battle_busy: return
	if screen == Screen.DEBUG and event.is_action_pressed("pause_menu"):
		close_debug()
		return
	if event.is_action_pressed("pause_menu"):
		if screen in [Screen.MAP,Screen.GLITCH]: open_settings(Screen.MAP)
		elif screen == Screen.SETTINGS:
			if character_customization_open: open_settings(settings_return)
			else: close_settings()
		elif screen == Screen.STARTER: show_title()
		elif screen == Screen.CARTRIDGE: close_cartridge_menu()
		elif screen == Screen.BATTLE and not battle_finished:
			pending_action = {}
			battle_menu = "main"
			show_battle()
		elif screen == Screen.SUMMARY: close_pokemon_summary()
		elif screen == Screen.GLITCH_PROFILE:
			if glitch_reference_section >= 0: show_glitch_profile(str(glitch_profile.id))
			else: show_glitch_archive(str(glitch_profile.id))
		elif screen in [Screen.PARTY,Screen.INVENTORY,Screen.BOX,Screen.POKEDEX,Screen.GLITCH_ARCHIVE]: show_map()
		return
	if screen == Screen.SUMMARY and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_LEFT: ui.get_child(0).browse(-1)
		elif event.keycode == KEY_RIGHT: ui.get_child(0).browse(1)
		return
	if screen == Screen.GLITCH:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_P: show_party()
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
		Screen.MAP,Screen.PARTY,Screen.INVENTORY,Screen.SETTINGS:
			if in_glitch(): GlitchArt.space(self,size,int(state.glitch_dimension.floor),0.0,false)
			else: draw_map_background()
		Screen.GLITCH: draw_glitch_floor()
		Screen.GLITCH_ARCHIVE: GlitchArt.space(self,size,int(state.glitch_dimension.floor),0.0,false)
		Screen.GLITCH_PROFILE: draw_glitch_profile()
		Screen.GLITCH_SHIFT:
			draw_map_background()
			GlitchArt.transition(self,size,glitch_shift_time / 0.88)
		Screen.BATTLE: draw_battle_background()
		Screen.ENDING: draw_ending_background()
		Screen.CARTRIDGE: draw_rect(Rect2(Vector2.ZERO,size),Cartridge.COLORS[cartridge].lightened(0.88))
		Screen.UPGRADE,Screen.RUN_END,Screen.CHEST,Screen.BOX,Screen.SUMMARY: draw_rect(Rect2(Vector2.ZERO,size),Color("#dbe9df"))

func draw_glitch_profile() -> void:
	GlitchArt.space(self,size,int(state.glitch_dimension.floor),0.0,false)
	if glitch_reference_section >= 0: return
	var stage := Rect2(40,175,size.x - 80,300 if glitch_pokedex_scan == null else 260)
	draw_rect(stage,Color("#1c122cea"))
	draw_rect(stage,Color("#9978b6"),false,2.0)
	var font := ThemeDB.fallback_font
	var shape := GlitchDimension.signal_shape(str(glitch_profile.id))
	var sprite := GlitchArt.encounter_sprite(shape,glitch_profile)
	if glitch_pokedex_scan == null:
		var middle := stage.get_center() + Vector2(0,12)
		for offset in range(-144,145,18):
			draw_line(middle + Vector2(offset,-93),middle + Vector2(offset,93),Color("#332246"))
		for offset in range(-90,91,18):
			draw_line(middle + Vector2(-145,offset),middle + Vector2(145,offset),Color("#332246"))
		draw_arc(middle,88,0.0,TAU,64,Color("#594170"),1.0)
		draw_string(font,Vector2(stage.position.x,204),"Battle sprite",HORIZONTAL_ALIGNMENT_CENTER,stage.size.x,16,GlitchArt.LIGHT)
		GlitchArt.draw_portrait(self,middle,sprite,minf(7.0, minf(280.0 / sprite.get_width(),185.0 / sprite.get_height())))
		return
	draw_string(font,Vector2(44,204),"Battle sprite",HORIZONTAL_ALIGNMENT_CENTER,156,16,GlitchArt.LIGHT)
	draw_string(font,Vector2(204,204),"Pokédex scan",HORIZONTAL_ALIGNMENT_CENTER,224,16,GlitchArt.LIGHT)
	var center := Vector2(122,322)
	draw_arc(center,62,0.0,TAU,48,Color("#594170"),1.0)
	GlitchArt.draw_portrait(self,center,sprite,2.0)
	var scan_size := glitch_pokedex_scan.get_size()
	var scan_scale := minf(224.0 / scan_size.x,202.0 / scan_size.y)
	draw_texture_rect(glitch_pokedex_scan,Rect2(Vector2(204,219),scan_size * scan_scale),false)

func draw_glitch_floor() -> void:
	var dimension: Dictionary = state.glitch_dimension
	var floor_number := int(dimension.floor)
	var time := elapsed if animation_enabled else 0.0
	GlitchArt.space(self,size,floor_number,time,false)
	var exit_ready := bool(dimension.cleared) and floor_number == GlitchDimension.FLOOR_COUNT
	GlitchArt.rift(self,Vector2(size.x * 0.5,451),time,exit_ready)
	if dimension.cleared and floor_number % 5 == 0:
		paint_chest(self,Vector2(size.x * 0.5 - 51,542),6.4,true,bool(dimension.cache_taken))

func draw_title_background() -> void:
	draw_rect(Rect2(Vector2.ZERO,size), Color("#174c60"))
	for i in 3:
		draw_sprite(species_sprite(["bulbasaur", "charmander", "squirtle"][i]), Vector2(100+i*140, 798), 72)

func draw_intro_background() -> void:
	draw_rect(Rect2(Vector2.ZERO,size), Color("#b8e1e0"))
	draw_circle(Vector2(115,165), 58, Color("#fff1b7"))
	if intro_page == 0:
		if island_texture: draw_texture_rect(island_texture, Rect2(170,180,290,290),false)
		draw_string(ThemeDB.fallback_font, Vector2(36,208), "NEXT STOP", HORIZONTAL_ALIGNMENT_LEFT, 408, 18, COLOR_INK)
		draw_string(ThemeDB.fallback_font, Vector2(36,265), "Apricorn Island", HORIZONTAL_ALIGNMENT_LEFT, 408, 46, COLOR_INK)
		draw_rect(Rect2(55,340,185,17), COLOR_CREAM)
		draw_colored_polygon(PackedVector2Array([Vector2(99,340),Vector2(150,296),Vector2(173,340)]), COLOR_CREAM)
		draw_colored_polygon(PackedVector2Array([Vector2(99,357),Vector2(150,398),Vector2(173,357)]), COLOR_CREAM)
		draw_circle(Vector2(240,349), 11, COLOR_CORAL)
	else:
		for i in state.party.size():
			var center := Vector2(240,290)
			draw_circle(center, 102, Color("#ffffff70"))
			draw_sprite(pokemon_sprite(state.party[i]), center, 160)
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
	draw_rect(Rect2(0,0,size.x,240), Color("#d9aaa0") if volcano else Color("#b4dfdf"))
	draw_circle(Vector2(400,85), 44, Color("#fff0bd"))
	for x in range(-80,480,180):
		draw_colored_polygon(PackedVector2Array([Vector2(x,240),Vector2(x+150,120),Vector2(x+350,240)]), Color("#ad8b84") if volcano else Color("#8fbeb0"))
	if ocean_boss:
		draw_rect(Rect2(Vector2.ZERO,size),Color("#142b63"))
		for y in range(70,430,50): draw_line(Vector2(0,y),Vector2(size.x,y+20),Color("#407fb0"),6)
	if battle.get("glitch",false):
		GlitchArt.space(self,size,int(state.glitch_dimension.floor),elapsed if animation_enabled else 0.0,true)
	var shown_enemies: Array = visual_enemies if battle_busy else battle.get("enemies",[])
	for i in shown_enemies.size():
		var enemy: Dictionary = shown_enemies[i]
		var pos := combat_position(false,i)
		draw_set_transform(pos+Vector2(0,55),0,Vector2(1,0.25))
		draw_circle(Vector2.ZERO,65,Color("#52695535"))
		draw_set_transform(Vector2.ZERO)
		var center := animated_position(pos,false,i)
		var sprite_top := draw_creature(center,enemy,true,i)
		draw_shiny_entrance(center, sprite_top, enemy, i)
		draw_status_card(Rect2(pos.x-71,18,142,75),enemy,false)
		draw_attack_result(center.x,sprite_top,false,i)
	var shown_party: Array = visual_party if battle_busy else state.get("party",[])
	for i in shown_party.size():
		var ally: Dictionary = shown_party[i]
		var pos := combat_position(true,i)
		draw_set_transform(pos+Vector2(0,55),0,Vector2(1,0.25))
		draw_circle(Vector2.ZERO,65,Color("#52695535"))
		draw_set_transform(Vector2.ZERO)
		var center := animated_position(pos,true,i)
		var sprite_top := draw_creature(center,ally,false)
		draw_shiny_entrance(center, sprite_top, ally, i)
		var living := living_party_indices()
		var active: bool = not battle_finished and action_index < living.size() and living[action_index] == i
		draw_status_card(Rect2(pos.x-71,372,142,94),ally,active)
		draw_attack_result(center.x,sprite_top,true,i)
	draw_move_effect()

func draw_creature(center: Vector2, pokemon: Dictionary, facing_left: bool, enemy_slot := -1) -> float:
	if pokemon.get("captured", false): return center.y
	var faded := 0.35 if int(pokemon.hp) <= 0 else 1.0
	if pokemon.has("glitch_shape"):
		var reacting: bool = battle_busy and animation_enabled and int(pokemon.get("glitch_impact",0)) != int(active_effect.get("old_glitch_impact",{}).get(enemy_slot,pokemon.get("glitch_impact",0)))
		var time := effect_time if reacting else (elapsed if animation_enabled else 0.0)
		var signal_id := str(pokemon.get("glitch_signal",""))
		var record := GlitchDimension.Signals.get_entry(signal_id)
		var sprite := GlitchArt.encounter_sprite(int(pokemon.glitch_shape),record)
		var authored_art: bool = record.get("profile",{}).has("sprite")
		var scale_factor := minf(3.0 if authored_art else 6.0,minf(140.0 / sprite.get_width(),138.0 / sprite.get_height()))
		if not reacting and not authored_art:
			center.y += roundf(sin(time * 2.3) * 3.0)
		GlitchArt.draw_portrait(self,center,sprite,scale_factor,time,faded,reacting)
		return center.y - sprite.get_height() * scale_factor / 2.0
	var texture := pokemon_sprite(pokemon, not facing_left)
	if texture == null: return center.y
	var native_size := texture.get_size()
	var scale_factor := minf(2.4, minf(138.0 / native_size.x, 124.0 / native_size.y))
	var extent := native_size * scale_factor
	var origin := center + Vector2(-extent.x / 2.0, 55.0 - extent.y)
	draw_texture_rect(texture, Rect2(origin.round(), extent.round()), false, Color(1, 1, 1, faded))
	return origin.y

func draw_shiny_entrance(position: Vector2, sprite_top: float, pokemon: Dictionary, index: int) -> void:
	if not animation_enabled or battle_entry_time >= 1.0 or int(pokemon.hp) <= 0 or not pokemon.get("shiny", false): return
	var progress := (battle_entry_time - 0.18 - index * 0.04) / 0.72
	var center := Vector2(position.x, lerpf(sprite_top, position.y + 55.0, 0.4))
	BattleEffects.draw_shiny(self, center, progress)

func draw_hp_bar(pos: Vector2, pokemon: Dictionary) -> void:
	draw_rect(Rect2(pos,Vector2(110,15)),COLOR_INK)
	var ratio: float = clamp(float(pokemon.hp)/float(max(1,pokemon.max_hp)),0.0,1.0)
	var color: Color = COLOR_GREEN if ratio > 0.5 else (COLOR_GOLD if ratio > 0.2 else COLOR_CORAL)
	draw_rect(Rect2(pos+Vector2(3,3),Vector2(104*ratio,9)),color)

func draw_ending_background() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("#ef9a71"))
	draw_circle(Vector2(240,180),100,Color("#ffd66b"))
	draw_rect(Rect2(0,232,size.x,size.y-232),Color("#267f9b"))
	for y in range(260,900,45):
		draw_line(Vector2(0,y),Vector2(size.x,y-20),Color("#85d8d7"),5)
	for x in range(90,480,140):
		draw_circle(Vector2(x,222),35,Color("#3e8d62"))

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
	var item := item_definition(item_id)
	if int(state.inventory.get(item_id,0)) <= 0 or not ItemCatalog.can_apply(item,state.party[target]): return
	pending_action.target = target
	if item.kind == "pp_medicine":
		show_battle()
		return
	battle.actions.append(pending_action.duplicate())
	pending_action = {}
	action_index += 1
	battle_menu = "main"
	show_battle()

func use_heal_in_battle(action: Dictionary, messages: Array[String]) -> void:
	var item_id := str(action.item)
	if int(state.inventory.get(item_id,0)) <= 0: return
	var item := item_definition(item_id)
	var target := int(action.get("target",action.actor))
	if target < 0 or target >= state.party.size(): return
	var actor: Dictionary = state.party[target]
	if item.kind == "pp_medicine":
		if not PendingItems.pp_use(item,actor,str(action.get("pp_move","")),true): return
	elif not ItemCatalog.apply(item,actor): return
	var broke := spend_item(item_id)
	messages.append("%s %s %s." % [GameData.SPECIES[actor.species].name,"used" if item.kind == "battle_boost" else "recovered with",item.name])
	if broke: messages.append("%s broke after use." % item.name)

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

func load_cartridge_sprites() -> void:
	sprites = yellow_sprites if cartridge == Cartridge.YELLOW else standard_sprites

func species_sprite(species_id: String, back := false, shiny := false) -> Texture2D:
	var art_id := "giratina-altered" if species_id == "giratina" else species_id
	var art_key := art_id + ("_back" if back else "_front")
	var key := art_key + ("_shiny" if shiny else "")
	if sprites.has(key): return sprites[key]
	var art := load_sprite_image("shiny/" + art_key if shiny else art_key)
	if shiny and art == null: return species_sprite(species_id, back)
	if art != null:
		sprites[key] = YellowSprites.from_art(art) if cartridge == Cartridge.YELLOW and not shiny else ImageTexture.create_from_image(art)
	else:
		var info := ItemProgression.info(species_id)
		if info.is_empty(): return null
		sprites[key] = YellowSprites.field_portrait(info, back)
	return sprites[key]

func load_sprite_image(key: String) -> Image:
	var path := "res://assets/sprites/" + key + ".png"
	if not ResourceLoader.exists(path): return null
	var texture := load(path) as Texture2D
	if texture == null: return null
	var image := texture.get_image()
	if image == null: return null
	if image.is_compressed() and image.decompress() != OK: return null
	var bounds := image.get_used_rect()
	return image.get_region(bounds) if bounds.has_area() else null

func pokemon_sprite(pokemon: Dictionary, back := false) -> Texture2D:
	var species_id := str(pokemon.species)
	var form := str(pokemon.get("form", ""))
	var shiny := bool(pokemon.get("shiny", false))
	if form != "" and form == ItemProgression.FORMS.get(species_id, ""):
		return species_sprite(form, back, shiny)
	return species_sprite(species_id, back, shiny)

func draw_sprite(texture: Texture2D, center: Vector2, extent: float) -> void:
	if texture == null: return
	var native_size := texture.get_size()
	var dimensions := (native_size * (extent / maxf(native_size.x, native_size.y))).round()
	draw_texture_rect(texture, Rect2((center - dimensions / 2.0).round(), dimensions), false)

func draw_status_card(rect: Rect2, pokemon: Dictionary, active: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#fff9e9")
	style.border_color = COLOR_CORAL if active else Color("#709589")
	style.set_border_width_all(3 if active else 2)
	style.set_corner_radius_all(9)
	draw_style_box(style,rect)
	var display_name := GameData.pokemon_name(pokemon)
	if not pokemon.has("glitch_signal"): display_name += " Lv.%d" % int(pokemon.get("level",5))
	var shiny := bool(pokemon.get("shiny", false))
	draw_string(theme.default_font,rect.position+Vector2(8,23),display_name,HORIZONTAL_ALIGNMENT_LEFT,108 if shiny else 126,14,COLOR_INK)
	if shiny: draw_string(theme.default_font,rect.position+Vector2(116,23),"★",HORIZONTAL_ALIGNMENT_CENTER,18,18,Color("#95651c"))
	draw_hp_bar(rect.position+Vector2(10,33),pokemon)
	var status := "Caught" if pokemon.get("captured", false) else "%d/%d %s" % [pokemon.hp,pokemon.max_hp,MoveEffects.status_label(pokemon)]
	if pokemon.has("glitch_signal"): status += "  Lv.%d" % int(pokemon.get("level",5))
	draw_string(ThemeDB.fallback_font,rect.position+Vector2(10,65),status,HORIZONTAL_ALIGNMENT_LEFT,122,14,COLOR_INK)
	if rect.size.y > 80:
		var progress := ItemMechanics.level_progress(pokemon)
		draw_rect(Rect2(rect.position+Vector2(10,72),Vector2(122,5)),Color("#c8d2dc"))
		draw_rect(Rect2(rect.position+Vector2(10,72),Vector2(122*float(progress.ratio),5)),Color("#508fe0"))
		draw_string(ThemeDB.fallback_font,rect.position+Vector2(10,89),"MAX LEVEL" if int(pokemon.level) >= 100 else "%d EXP to next level" % int(progress.remaining),HORIZONTAL_ALIGNMENT_LEFT,122,11,COLOR_INK)

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
	var pokedex := {}
	var previous := Cartridge.read_dictionary(cartridge_save_path(true))
	best = int(previous.get("run",{}).get("best",0))
	var previous_dex: Variant = previous.get("pokedex", {})
	if previous_dex is Dictionary: pokedex = previous_dex
	state = {"version":2,"mode":"endless","current_node":"run_0","cleared":[],"opened_chests":[],"party":[GameData.make_pokemon(starter)],"reserve":[],"inventory":{"potion":3,"super_potion":1,"berry":2,"apricorn_ball":6,"great_apricorn_ball":1},"settings":preferences,"run":{"seed":rng.randi_range(1,2000000000),"depth":0,"best":best,"ended":false,"pending_upgrade":false}}
	state.pokedex = pokedex
	battle = {}
	focus_current_stop()
	show_map("HP carries over. Use your supplies wisely. Defeat ends the run.")
	save_game()

func continue_endless(message := "Your expedition continues.") -> void:
	var saved := Cartridge.read_dictionary(cartridge_save_path(true))
	if saved.get("mode","") != "endless" or not saved.has("party") or not saved.has("inventory") or not saved.has("current_node") or not saved.has("run"):
		show_title("This run could not be loaded.")
		return
	state = saved
	prepare_save_state()
	apply_settings()
	focus_current_stop()
	if in_glitch(): resume_glitch()
	elif state.has("secret_checkpoint"): show_secret_hall()
	elif state.run.ended: show_run_end()
	elif state.run.pending_upgrade: show_upgrade()
	elif state.has("battle_checkpoint"): resume_battle_checkpoint()
	else: show_map(message)

func resume_battle_checkpoint() -> void:
	battle = state.battle_checkpoint.duplicate(true)
	battle_entry_time = 1.0
	battle_finished = bool(battle.get("finished",false))
	action_index = 0
	pending_action = {}
	battle_menu = "main"
	battle_log = ["Your expedition resumes."]
	if living_party_indices().is_empty(): handle_defeat()
	else: show_battle()

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
	var in_battle := (screen == Screen.BATTLE or (screen == Screen.SUMMARY and summary_return == Screen.BATTLE)) and (not battle_finished or battle_busy)
	var glitch_music := in_glitch() and screen not in [Screen.TITLE,Screen.STARTER,Screen.GLITCH_SHIFT]
	sfx.set_glitch_music(glitch_music,in_battle)
	if not glitch_music: sfx.set_battle_music(in_battle,boss_music)
	elapsed += delta
	trainer_slide = minf(1.0,trainer_slide+delta*3.5)
	battle_entry_time = minf(1.0, battle_entry_time + delta / 0.9)
	if battle_busy and effect_time >= BattleEffects.IMPACT:
		visual_enemies = active_effect.after_enemies
		if not active_effect.caught or effect_time >= 1.0:
			visual_party = active_effect.after_party
	if screen == Screen.GLITCH_SHIFT:
		glitch_shift_time += delta
		if glitch_shift_time >= 0.88: show_glitch_level()
	if screen in [Screen.MAP,Screen.BATTLE,Screen.GLITCH,Screen.GLITCH_SHIFT]: queue_redraw()

func attack_result_popups(results: Array[Dictionary]) -> Dictionary:
	var popups := {}
	for result in results:
		if result.is_empty(): continue
		var kind := str(result.kind)
		var label := str(ATTACK_RESULT_LABELS.get(kind,""))
		if kind == "hit":
			var percent := float(result.damage) * 100.0 / float(maxi(1,int(result.max_hp)))
			label = "<1%" if percent > 0.0 and percent < 1.0 else "−%d%%" % roundi(percent)
			if percent == 0.0: label = "0%"
		for side in [0,1]:
			var team: Array = state.party if side == 1 else battle.enemies
			for index in team.size():
				if is_same(team[index],result.target):
					popups[Vector2i(index,side)] = {"text":label,"kind":kind}
					break
	return popups

func queue_battle_effect(action: Dictionary, player_side: bool, before_party: Array, before_enemies: Array, messages: Array, results: Array[Dictionary]) -> void:
	var popups := attack_result_popups(results)
	if not animation_enabled:
		quick_attack_results.merge(popups,true)
		if not popups.is_empty(): quick_attack_results_until = elapsed + 1.25
		return
	var kind := "hit"
	if action.kind == "ball": kind = "capture"
	elif action.kind == "heal_item": kind = "heal"
	elif action.has("move"):
		var move: Dictionary = GameData.MOVES[action.move]
		kind = "heal" if move.kind in ["heal","buff"] else str(move.type)
		if kind in ["psychic","ghost","dark","fairy"]: kind = "aura"
		if kind not in BattleEffects.PALETTES and kind != "heal": kind = "hit"
	var target_index := int(action.get("target",action.actor))
	var target_player := player_side if kind == "heal" else not player_side
	var missed := false
	if kind == "heal" and action.kind != "heal_item": target_index = int(action.actor)
	var before: Array = before_enemies if player_side else before_party
	var after: Array = battle.enemies if player_side else state.party
	if not popups.is_empty() and kind != "heal":
		var recipient: Vector2i = popups.keys()[0]
		target_index = recipient.x
		target_player = bool(recipient.y)
		missed = popups[recipient].kind == "miss"
	elif kind != "heal":
		for i in before.size():
			if before[i].hp != after[i].hp: target_index = i; break
	var old_glitch_impact := {}
	var glitch_reaction := false
	if battle.get("glitch",false):
		for i in before_enemies.size():
			var enemy: Dictionary = before_enemies[i]
			old_glitch_impact[i] = enemy.glitch_impact
			if enemy.glitch_impact != battle.enemies[i].glitch_impact: glitch_reaction = true
	var caught: bool = kind == "capture" and target_index >= 0 and target_index < after.size() and after[target_index].get("captured",false)
	animation_events.append({"actor":int(action.actor),"target":target_index,"target_player":target_player,"player":player_side,"kind":kind,"message":"\n".join(messages),"before_party":before_party,"before_enemies":before_enemies,"after_party":state.party.duplicate(true),"after_enemies":battle.enemies.duplicate(true),"old_glitch_impact":old_glitch_impact,"glitch_reaction":glitch_reaction,"popups":popups,"missed":missed,"caught":caught})

func play_round_animation() -> void:
	battle_busy = true
	for event in animation_events:
		active_effect = event
		visual_party = event.before_party
		visual_enemies = event.before_enemies
		effect_time = 0.0
		show_battle()
		if not event.missed:
			var sound := "hit" if event.kind in ["ice","aura"] else str(event.kind)
			sfx.play_effect("glitch_hit" if event.glitch_reaction else sound)
		var tween := create_tween()
		tween.tween_property(self,"effect_time",1.0,0.95 if event.kind == "capture" else 0.72)
		if not event.popups.is_empty(): tween.tween_interval(0.34)
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
		if animation_enabled and battle_entry_time < 1.0:
			var entry := smoothstep(0.0, 0.48, battle_entry_time - index * 0.05)
			return base + Vector2((-74.0 if player_side else 74.0) * (1.0 - entry), -sin(entry * PI) * 16.0)
		return base+Vector2(0,sin(elapsed*2.2+index)*2.0) if animation_enabled else base
	if bool(active_effect.player) == player_side and int(active_effect.actor) == index:
		var lunge := sin(effect_time * PI)
		var reach := 48.0 if active_effect.kind == "hit" else 18.0
		return base + Vector2(lunge * reach * (1 if player_side else -1), -lunge * 10.0)
	if active_effect.kind != "heal" and not active_effect.missed and bool(active_effect.target_player) == player_side and int(active_effect.target) == index and effect_time > BattleEffects.IMPACT:
		return base + Vector2(sin((effect_time - BattleEffects.IMPACT) * 53.0) * 16.0 * (1.0 - effect_time), 0)
	return base

func combat_position(player_side: bool, index: int) -> Vector2:
	var combatants: Array = state.party if player_side else battle.enemies
	var x := 240.0 + (index - (combatants.size() - 1) / 2.0) * 152.0
	return Vector2(x,309 if player_side else 164)

func draw_move_effect() -> void:
	if not battle_busy or active_effect.is_empty() or effect_time >= 1.0: return
	var start := combat_position(bool(active_effect.player),int(active_effect.actor))
	var target := combat_position(bool(active_effect.target_player),int(active_effect.target))
	BattleEffects.draw_move(self, str(active_effect.kind), start, target, effect_time, bool(active_effect.missed), bool(active_effect.caught))

func draw_attack_result(x: float, sprite_top: float, player_side: bool, index: int) -> void:
	var slot := Vector2i(index,int(player_side))
	var popup: Dictionary
	var rise := 0.0
	if battle_busy:
		if effect_time < BattleEffects.IMPACT: return
		popup = active_effect.popups.get(slot,{})
		rise = smoothstep(0.5,1.0,effect_time) * 16.0
	else:
		if elapsed >= quick_attack_results_until: return
		popup = quick_attack_results.get(slot,{})
	if popup.is_empty(): return
	var font := ThemeDB.fallback_font
	var font_size := 29
	var label := str(popup.text)
	var baseline := maxf(225.0 if player_side else 124.0,sprite_top - 7.0 - rise)
	var width := font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	var position := Vector2(clampf(x-width/2.0,8.0,size.x-width-8.0),baseline).round()
	var color := Color("#ffba9e") if popup.kind == "hit" else COLOR_CREAM
	draw_string_outline(font,position,label,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,8,COLOR_INK)
	draw_string(font,position,label,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

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
	if in_glitch():
		outline = Color("#22112e")
		wood = Color("#9257bb")
		trim = Color("#d7abf3")
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
	if in_glitch():
		for streak in [Rect2(-2,4,7,1),Rect2(10,8,8,0.5),Rect2(4,13,11,0.5)]:
			canvas.draw_rect(Rect2(origin + streak.position * scale_factor,streak.size * scale_factor),GlitchArt.LILAC)

# Debug tools are explicit actions, available in exported games as well as the editor.
func open_debug() -> void:
	if battle_busy or resolving_round: return
	if screen not in [Screen.TITLE, Screen.MAP, Screen.PARTY, Screen.INVENTORY, Screen.SETTINGS, Screen.BATTLE, Screen.GLITCH, Screen.GLITCH_ARCHIVE, Screen.GLITCH_PROFILE]: return
	debug_return = screen
	show_debug()

func can_debug_enter_glitch() -> bool:
	var on_route := debug_return in [Screen.MAP, Screen.PARTY, Screen.INVENTORY] or (debug_return == Screen.SETTINGS and settings_return == Screen.MAP)
	return on_route and state.has("party") and not in_glitch() and not state.has("battle_checkpoint") and not battle_busy and not resolving_round

func show_debug(message := "") -> void:
	screen = Screen.DEBUG
	clear_ui()
	var shell := make_panel(Rect2(20, 20, 440, 860))
	add_label(shell, "Debug mode", 32)
	add_button(shell, "Back to game (Esc)", close_debug)
	var scroll := add_vertical_scroll(shell)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	scroll.add_child(box)
	add_label(box, "Changes to party and supplies are saved. Esc closes this menu.", 17)
	var in_battle := debug_return == Screen.BATTLE
	var has_party := state.has("party")
	add_label(box, "FPS: %d • Mode: %s\nLocation: %s" % [Engine.get_frames_per_second(), "Endless" if is_endless() else "Island", str(state.get("current_node", "No active adventure"))], 18)
	if message != "": add_label(box, message, 17, COLOR_CORAL)
	add_button(box, "Swap cartridge", show_cartridge_menu)
	if in_glitch() and debug_return != Screen.TITLE and (debug_return != Screen.SETTINGS or settings_return == Screen.MAP):
		add_button(box, "Leave Glitch Dimension", leave_glitch.bind(true))
	else:
		add_button(box, "Travel to Glitch Dimension", enter_glitch.bind(true), not can_debug_enter_glitch())
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
	for entry in [["invincible", "Invincible party (no attack damage)"], ["one_hit", "One-hit player attacks"], ["capture", "Guaranteed catches"], ["unlimited_items", "Unlimited items already owned"], ["accuracy", "Player moves always hit"], ["enemy_turns", "Enemy turns"], ["travel", "Unlock all island destinations"]]:
		add_debug_toggle(box, str(entry[1]), bool(debug_options[entry[0]]), func(value: bool): debug_options[entry[0]] = value)
	add_debug_toggle(box, "Battle animations", animation_enabled, func(value: bool): animation_enabled = value)
	add_button(box, "Reset all testing switches", func():
		debug_options = DEBUG_DEFAULTS.duplicate()
		animation_enabled = DisplayServer.get_name() != "headless"
		show_debug("Testing switches reset.")
	)

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
		Screen.GLITCH_ARCHIVE: show_glitch_archive()
		Screen.GLITCH_PROFILE: show_glitch_profile(str(glitch_profile.id),glitch_reference_section)
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
	toggle.add_theme_color_override("font_color",COLOR_INK)
	toggle.add_theme_color_override("font_focus_color",COLOR_INK)
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
	secret_hall = SecretHall.new()
	secret_hall.scale = Vector2(0.75,0.75)
	secret_hall.position.y = 270
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
	var item := item_definition(item_id)
	if item.get("kind","") != "pp_medicine": return
	var before := state.duplicate(true)
	if not PendingItems.pp_use(item,state.party[party_index],move_id,true): return
	var broke := spend_item(item_id)
	finish_bag_item(before,item_id,broke)

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
	if not BossOrbs.SPECIES.has(id) or not Cartridge.has_species(cartridge,BossOrbs.SPECIES[id]) or in_glitch() or living_party_indices().is_empty(): return
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
	start_battle_presentation()

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
	var box := make_panel(Rect2(20,45,440,810))
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
	if not GameData.SPECIES.has(id) or id.begins_with("anomaly_"): return
	if id == "farfetchd-galar": id = "farfetchd"
	if not state.get("pokedex", null) is Dictionary: state.pokedex = {}
	var entry: Dictionary = state.pokedex.get(id, {"seen":true,"caught":false})
	entry.seen = true
	entry.caught = bool(entry.get("caught",false)) or caught
	state.pokedex[id] = entry

func sync_pokedex() -> void:
	var records = state.get("pokedex", {})
	if records is Dictionary and records.has("farfetchd-galar"):
		register_dex("farfetchd", records["farfetchd-galar"].get("caught", false))
		records.erase("farfetchd-galar")
	for pokemon in state.get("party",[]) + state.get("reserve",[]):
		register_dex(str(pokemon.get("species","")), true)
	for id in state.get("caught_species",[]): register_dex(str(id), true)
	for pokemon in state.get("battle_checkpoint",{}).get("enemies",[]):
		register_dex(str(pokemon.get("species","")), false)

func show_pokedex() -> void:
	sync_pokedex()
	screen = Screen.POKEDEX
	clear_ui()
	var panel := make_panel(Rect2(20,20,440,860), Color.WHITE)
	var seen := 0
	var caught := 0
	for entry in state.get("pokedex",{}).values():
		if entry.get("seen",false): seen += 1
		if entry.get("caught",false): caught += 1
	add_label(panel,"POKÉDEX • %d seen / %d caught / %d species" % [seen,caught,GameData.DEX_SPECIES.size()],28)
	add_label(panel,"Records carry over between Endless Runs." if is_endless() else "Meet Pokémon to reveal their entries.",17)
	var search := LineEdit.new()
	search.placeholder_text = "Discovered name or Pokédex number"
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
	search.custom_minimum_size.y = 48
	panel.add_child(search)
	var row := HBoxContainer.new()
	panel.add_child(row)
	var filter := add_option_button(row)
	filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for label in ["All species","Seen","Caught","Seen, not caught"]: filter.add_item(label)
	filter.select(dex_filter)
	add_button(row,"Back to map",show_map.bind(""))
	var pages := HBoxContainer.new()
	panel.add_child(pages)
	var previous := add_button(pages, "Previous", func(): dex_page -= 1)
	var page_number := add_label(pages, "", 15, Color("#687480"))
	page_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page_number.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var next := add_button(pages, "Next", func(): dex_page += 1)
	var scroll := add_vertical_scroll(panel)
	var list := GridContainer.new()
	list.name = "PokedexGrid"
	list.columns = 3
	list.add_theme_constant_override("h_separation", 10)
	list.add_theme_constant_override("v_separation", 10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var refresh := func():
		var page_count := populate_pokedex(list)
		page_number.text = "Page %d of %d" % [dex_page + 1, page_count]
		previous.disabled = dex_page == 0
		next.disabled = dex_page + 1 >= page_count
		scroll.scroll_vertical = 0
	refresh.call()
	previous.pressed.connect(refresh)
	next.pressed.connect(refresh)
	search.text_changed.connect(func(value: String): dex_query = value; dex_page = 0; refresh.call())
	filter.item_selected.connect(func(index: int): dex_filter = index; dex_page = 0; refresh.call())

func populate_pokedex(list: GridContainer) -> int:
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	var records: Dictionary = state.get("pokedex", {})
	var query := dex_query.strip_edges().to_lower()
	var number_query := query.trim_prefix("#")
	var matching: Array = []
	for id in GameData.DEX_SPECIES:
		var entry: Dictionary = records.get(id, {})
		var seen: bool = entry.get("seen",false)
		var caught: bool = entry.get("caught",false)
		if dex_filter == 1 and not seen: continue
		if dex_filter == 2 and not caught: continue
		if dex_filter == 3 and (not seen or caught): continue
		if number_query.is_valid_int():
			if int(ItemProgression.info(id).dex_id) != number_query.to_int(): continue
		elif not query.is_empty() and (not seen or not str(GameData.SPECIES[id].name).to_lower().contains(query)):
			continue
		matching.append(id)
	var page_count := maxi(1, ceili(float(matching.size()) / DEX_PAGE_SIZE))
	dex_page = clampi(dex_page, 0, page_count - 1)
	for id in matching.slice(dex_page * DEX_PAGE_SIZE, (dex_page + 1) * DEX_PAGE_SIZE):
		var entry: Dictionary = records.get(id, {})
		var seen: bool = entry.get("seen", false)
		var caught: bool = entry.get("caught", false)
		var species: Dictionary = GameData.SPECIES[id]
		var card := PanelContainer.new()
		card.name = "Dex_" + str(id)
		card.custom_minimum_size = Vector2(114,164)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
			picture.texture = species_sprite(str(id))
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
				var enemies: Array = GameData.ENCOUNTERS.get(node.get("encounter",""),{}).get("enemies",[])
				if id in Cartridge.story_species(cartridge,enemies): habitats.append(str(node.name))
			var habitat := ", ".join(habitats) if not habitats.is_empty() else "Endless Run, island surveys, or special encounters"
			if not Cartridge.has_species(cartridge,id): habitat = "Previously recorded on this save"
			card.tooltip_text = "%s • %s\nWhere to find: %s" % [species.name,str(species.type).capitalize(),habitat]
	if matching.is_empty(): add_label(list,"No entries match this search.",20)
	return page_count

func show_character_customization() -> void:
	# Stay in SETTINGS so Escape returns through the same menu path.
	character_customization_open = true
	clear_ui()
	var draft: Dictionary = trainer_style.profile.duplicate(true)
	var box := make_panel(Rect2(20,20,440,860))
	add_label(box,"YOUR TRAINER",32)
	add_label(box,"Make yourself at home on Apricorn Island. Your look follows you in both modes.",18)
	var preview := TextureRect.new()
	preview.name = "TrainerPreview"
	preview.custom_minimum_size.y = 180
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture = trainer_texture
	box.add_child(preview)
	add_label(box,"Trainer name",18)
	var name_field := LineEdit.new()
	name_field.text = str(draft.name)
	name_field.max_length = 20
	name_field.custom_minimum_size.y = 42
	box.add_child(name_field)
	name_field.text_changed.connect(func(value: String): draft.name = value)
	for key in TrainerStyle.OPTIONS:
		var row := HBoxContainer.new()
		box.add_child(row)
		var caption := add_label(row,str(key).capitalize(),18)
		caption.custom_minimum_size.x = 104
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var picker := add_option_button(row)
		picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for title in TrainerStyle.OPTIONS[key]: picker.add_item(title)
		picker.selected = int(draft[key])
		picker.item_selected.connect(func(index: int):
			draft[key] = index
			var style := TrainerStyle.new()
			style.profile = draft.duplicate(true)
			preview.texture = style.make_texture()
		)
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
