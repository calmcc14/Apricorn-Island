extends SceneTree
func _init() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_new_game("bulbasaur")
	game.show_map()
	var box = game.ui.find_child("BoxButton",true,false)
	var dex = game.ui.find_child("PokedexButton",true,false)
	assert(dex != null and dex.icon != null)
	assert(dex.size == box.size)
	assert(dex.position.x > box.position.x and dex.position.y == box.position.y)
	await process_frame
	await process_frame
	if "--capture" in OS.get_cmdline_user_args(): root.get_texture().get_image().save_png("res://build/pokedex-button.png")
	dex.pressed.emit()
	assert(game.screen == game.Screen.POKEDEX)
	print("Pokédex map button appearance, placement and navigation passed.")
	quit()
