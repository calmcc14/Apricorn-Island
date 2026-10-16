extends SceneTree
func _init() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	for endless in [false,true]:
		game.show_title()
		var before = game.state.duplicate(true)
		if endless: game.start_endless()
		else: game.start_new_game()
		assert(game.screen == game.Screen.STARTER)
		assert(game.state == before)
		var box = game.ui.get_child(0).get_child(0)
		for i in 5:
			game.show_starter_selection(endless)
			box = game.ui.get_child(0).get_child(0)
			box.get_child(i+2).get_child(1).pressed.emit()
			assert(game.state.party.size() == 1)
			assert(game.state.party[0].species == game.STARTERS[i])
			if endless: game.continue_endless()
			else: game.continue_game()
			assert(game.state.party[0].species == game.STARTERS[i])
	print("All five starter choices and saves passed in both modes.")
	quit()
