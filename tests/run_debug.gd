extends SceneTree

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
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
	game.open_debug()
	game.close_debug()
	game.start_new_game(game.STARTERS[0])
	game.show_map()
	game.start_battle("meadow_1", "meadow")
	game.open_debug()
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
