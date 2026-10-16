extends SceneTree

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_new_game()
	game.show_map()
	if "--capture" in OS.get_cmdline_user_args():
		await process_frame
		await process_frame
		root.get_texture().get_image().save_png("res://build/box-map.png")
	var buttons: Array = game.ui.find_children("BoxButton", "Button", true, false)
	assert(buttons.size() == 1)
	assert(buttons[0].icon != null)
	buttons[0].pressed.emit()
	assert(game.screen == game.Screen.BOX)
	for i in 31: game.state.reserve.append(GameData.make_pokemon("pikachu"))
	game.show_box()
	if "--capture" in OS.get_cmdline_user_args():
		await process_frame
		await process_frame
		root.get_texture().get_image().save_png("res://build/box-storage.png")
	game.change_box_page(1)
	assert(game.box_page == 1)
	var original: String = game.state.party[0].species
	game.swap_box_pokemon(30)
	assert(game.state.party[0].species == "pikachu")
	assert(game.state.reserve[30].species == original)
	assert(game.screen == game.Screen.BOX)
	var saved = JSON.parse_string(FileAccess.get_file_as_string(game.SAVE_PATH))
	assert(saved.party[0].species == "pikachu")
	game.change_box_page(-1)
	assert(game.box_page == 0)
	print("Box button, navigation, swap and save checks passed.")
	quit()
