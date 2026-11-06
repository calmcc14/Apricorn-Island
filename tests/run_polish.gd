extends SceneTree

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.state.settings.volume = 0.0
	game.state.settings.animations = false
	game.state.settings.difficulty = "hard"
	game.save_preferences()
	game.state = {}
	game.load_preferences()
	game.apply_settings()
	assert(AudioServer.is_bus_mute(0))
	assert(not game.animation_enabled)
	assert(game.state.settings.difficulty == "hard")
	game.start_new_game("eevee")
	assert(game.state.settings.volume == 0.0)
	game.show_map()
	game.open_settings(game.Screen.MAP)
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	game._unhandled_input(escape)
	assert(game.screen == game.Screen.MAP)
	game.request_new_game(false)
	var dialog = game.get_child(game.get_child_count()-1)
	assert(dialog is ConfirmationDialog)
	dialog.canceled.emit()
	assert(game.state.party[0].species == "eevee")
	game.battle = {"orb_item":"red_orb"}
	game.start_new_game("pikachu")
	assert(game.battle.is_empty())
	assert(not game.state.has("battle_checkpoint"))
	game.open_settings(game.Screen.TITLE)
	game._unhandled_input(escape)
	assert(game.screen == game.Screen.TITLE)
	print("Polish: preferences, true mute, Escape navigation, save protection and fresh battle state passed.")
	quit()
