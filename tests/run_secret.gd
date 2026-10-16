extends SceneTree

func _init() -> void:
	call_deferred("run")

func press(game, code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	game._input(event)

func run() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.open_debug()
	game.debug_gaster()
	assert(game.screen == game.Screen.SECRET_HALL)
	game.exit_secret_hall()
	assert(game.screen == game.Screen.DEBUG and game.state.is_empty())
	game.close_debug()
	assert(game.screen == game.Screen.TITLE)
	game.start_endless()
	game.open_debug()
	var before_preview: Dictionary = game.state.duplicate(true)
	game.debug_gaster()
	game.secret_hall.progress.vanished = true
	game.secret_hall.remember()
	game.exit_secret_hall()
	assert(game.state == before_preview)
	game.close_debug()
	game.state.run.depth = 65
	game.state.current_node = "run_65"
	game.state.fun_value = 65
	assert(not game.secret_available(game.get_node_data("run_66")))
	game.state.fun_value = 66
	assert(not game.secret_available(game.get_node_data("run_67")))
	assert(game.secret_available(game.get_node_data("run_66")))
	var party: Array = game.state.party.duplicate(true)
	var inventory: Dictionary = game.state.inventory.duplicate(true)
	game.travel_to("run_66")
	assert(game.screen == game.Screen.SECRET_HALL)
	assert(game.battle.is_empty())
	var hall = game.secret_hall
	press(game, KEY_C)
	assert(hall.menu == "main")
	press(game, KEY_DOWN)
	press(game, KEY_Z)
	assert(hall.menu == "stat")
	press(game, KEY_X)
	assert(hall.menu == "main")
	press(game, KEY_CTRL)
	assert(hall.menu == "")
	hall.player = Vector2(320, 270)
	press(game, KEY_Z)
	assert(hall.progress.room == "room")
	hall.player = Vector2(320, 255)
	hall.facing = "up"
	press(game, KEY_ENTER)
	assert(hall.progress.vanished)
	game.continue_endless()
	assert(game.screen == game.Screen.SECRET_HALL)
	hall = game.secret_hall
	assert(hall.progress.room == "room" and hall.progress.vanished)
	hall.player = Vector2(320, 423)
	Input.action_press("ui_down")
	# Room exit is checked while moving, with the same physical-key input as play.
	var down := InputEventKey.new()
	down.physical_keycode = KEY_DOWN
	down.pressed = true
	Input.parse_input_event(down)
	await process_frame
	hall._process(0.01)
	down.pressed = false
	Input.parse_input_event(down)
	Input.action_release("ui_down")
	assert(hall.progress.room == "hall" and hall.progress.door_gone)
	game.exit_secret_hall()
	assert(game.screen == game.Screen.MAP and game.state.run.depth == 66)
	assert(not game.state.has("secret_checkpoint"))
	assert("gaster_hall" in game.state.fun_seen)
	assert(JSON.parse_string(JSON.stringify(game.state.party)) == JSON.parse_string(JSON.stringify(party)))
	assert(JSON.parse_string(JSON.stringify(game.state.inventory)) == JSON.parse_string(JSON.stringify(inventory)))
	assert(not game.secret_available(game.get_node_data("run_66")))
	game.continue_endless()
	assert(game.state.run.depth == 66)
	for direction in [KEY_LEFT, KEY_RIGHT]:
		game.start_endless()
		game.state.fun_value = 66
		game.state.run.depth = 65
		game.state.current_node = "run_66"
		game.show_secret_hall()
		hall = game.secret_hall
		hall.player.x = 0 if direction == KEY_LEFT else 640
		var step := InputEventKey.new()
		step.physical_keycode = direction
		step.pressed = true
		Input.parse_input_event(step)
		Input.flush_buffered_events()
		hall._process(0.02)
		var release: InputEventKey = step.duplicate()
		release.pressed = false
		Input.parse_input_event(release)
		Input.flush_buffered_events()
		assert(game.screen == game.Screen.MAP and game.state.run.depth == 66)
	print("Secret trigger, controls, room transitions, persistence and run completion passed.")
	quit()
