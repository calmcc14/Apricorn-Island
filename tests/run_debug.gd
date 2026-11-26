extends SceneTree

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	if game.screen == game.Screen.CARTRIDGE:
		game.choose_first_cartridge(Cartridge.RED)
	var old_shortcut := InputEventKey.new()
	old_shortcut.physical_keycode = KEY_F3
	old_shortcut.pressed = true
	game._input(old_shortcut)
	assert(game.screen == game.Screen.TITLE)
	for code in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_B, KEY_A]:
		var wrong := InputEventKey.new()
		wrong.physical_keycode = code
		wrong.pressed = true
		game._input(wrong)
	assert(game.screen == game.Screen.TITLE)
	for code in game.DEBUG_CODE:
		var key := InputEventKey.new()
		key.physical_keycode = code
		key.pressed = true
		game._input(key)
		key.echo = true
		game._input(key)
	assert(game.screen == game.Screen.DEBUG)
	game.debug_open_chest()
	assert(game.screen == game.Screen.DEBUG)
	game.close_debug()
	assert(game.screen == game.Screen.TITLE)
	game.open_settings(game.Screen.TITLE)
	var animations := menu_button(game, "Battle animations") as CheckButton
	assert(animations != null)
	for i in range(9):
		animations.button_pressed = not animations.button_pressed
		assert(game.screen == game.Screen.SETTINGS)
	var volume := game.ui.find_children("*", "HSlider", true, false)[0] as HSlider
	volume.value = 0.5 if volume.value != 0.5 else 0.75
	animations.button_pressed = not animations.button_pressed
	assert(game.screen == game.Screen.SETTINGS)
	game.close_settings()
	game.open_settings(game.Screen.TITLE)
	animations = menu_button(game, "Battle animations") as CheckButton
	var original_animations := animations.button_pressed
	for i in range(9):
		animations.button_pressed = not animations.button_pressed
		assert(game.screen == game.Screen.SETTINGS)
	animations.button_pressed = not animations.button_pressed
	assert(game.screen == game.Screen.DEBUG)
	game.close_debug()
	assert(game.screen == game.Screen.SETTINGS)
	animations = menu_button(game, "Battle animations") as CheckButton
	assert(animations.button_pressed == original_animations)
	game.close_settings()
	game.start_endless(game.STARTERS[0])
	game.show_map()
	game.state.party[0].hp = 0
	game.open_debug()
	game.debug_action("heal")
	assert(game.state.party[0].hp == game.state.party[0].max_hp)
	var count = game.state.inventory.potion
	game.debug_action("supplies")
	assert(game.state.inventory.potion == count + 25)
	var location = game.state.current_node
	var cleared = game.state.cleared.duplicate()
	game.debug_open_chest()
	assert(game.screen == game.Screen.CHEST)
	assert(game.state.active_chest == "debug_chest")
	assert(game.state.chest_storage.potion == 2)
	assert(game.state.current_node == location)
	assert(game.state.cleared == cleared)
	var contents = game.state.chest_storage.duplicate()
	game.show_map()
	game.open_debug()
	game.debug_open_chest()
	assert(game.state.chest_storage == contents)
	assert(game.state.opened_chests.count("debug_chest") == 1)
	game.show_map()
	assert(not game.glitch_available())
	game.open_debug()
	var travel := menu_button(game,"Travel to Glitch Dimension")
	assert(travel != null and not travel.disabled)
	travel.pressed.emit()
	assert(game.screen == game.Screen.GLITCH and game.state.glitch_dimension.floor == 1)
	game.show_glitch_archive()
	game.open_debug()
	game.close_debug()
	assert(game.screen == game.Screen.GLITCH_ARCHIVE)
	game.show_glitch_level()
	game.open_debug()
	assert(menu_button(game,"Leave Glitch Dimension") != null)
	game.close_debug()
	game.start_glitch_battle()
	assert(game.state.battle_checkpoint.glitch)
	game.open_debug()
	var leave := menu_button(game,"Leave Glitch Dimension")
	assert(leave != null and not leave.disabled)
	leave.pressed.emit()
	assert(game.screen == game.Screen.MAP and not game.in_glitch())
	assert(game.state.current_node == location and game.state.run.depth == 0)
	assert(not game.state.get("glitch_completed",false) and not game.state.has("battle_checkpoint"))
	assert(game.battle.is_empty())
	game.continue_endless()
	assert(game.screen == game.Screen.MAP and not game.in_glitch())
	game.start_new_game(game.STARTERS[0])
	game.show_map()
	game.start_battle("meadow_1", "meadow")
	game.open_debug()
	assert(menu_button(game,"Travel to Glitch Dimension").disabled)
	var toggles = game.ui.find_children("*", "CheckButton", true, false)
	game.debug_open_chest()
	assert(game.screen == game.Screen.DEBUG)
	assert(toggles.size() == 8)
	toggles[0].button_pressed = true
	assert(game.debug_options.invincible)
	assert(not game.debug_options.one_hit)
	game.close_debug()
	var messages: Array[String] = []
	var hp = game.state.party[0].hp
	game.resolve_move(game.battle.enemies[0], game.state.party[0], "tackle", messages, false)
	assert(game.state.party[0].hp == hp)
	game.debug_options.invincible = false
	game.debug_options.one_hit = true
	game.debug_options.accuracy = true
	game.resolve_move(game.state.party[0], game.battle.enemies[0], "tackle", messages, true)
	assert(game.battle.enemies[0].hp == 0)
	game.debug_options.one_hit = false
	game.start_battle("meadow_1", "meadow")
	game.debug_options.capture = true
	game.debug_options.unlimited_items = true
	var balls = game.state.inventory.apricorn_ball
	var caught_count = game.state.party.size() + game.state.reserve.size()
	game.resolve_ball_action({"actor":0,"ball":"apricorn_ball","target":0}, messages)
	assert(game.state.inventory.apricorn_ball == balls)
	assert(game.state.party.size() + game.state.reserve.size() == caught_count + 1)
	game.debug_options = game.DEBUG_DEFAULTS.duplicate()
	assert(not game.node_unlocked(game.get_node_data("lookout")))
	game.debug_options.travel = true
	assert(game.node_unlocked(game.get_node_data("lookout")))
	game.debug_options.travel = false
	game.start_battle("meadow_1", "meadow")
	game.battle_busy = true
	game.open_debug()
	assert(game.screen == game.Screen.BATTLE)
	game.battle_busy = false
	game.open_debug()
	game.debug_action("win")
	assert(game.screen == game.Screen.MAP)
	assert("meadow" in game.state.cleared)
	print("Debug mode tests passed")
	quit()

func menu_button(game: Control, label: String) -> Button:
	for button in game.ui.find_children("*","Button",true,false):
		if button.text == label: return button
	return null
