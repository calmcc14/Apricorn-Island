extends SceneTree
var game
func _init() -> void: call_deferred("run")
func capture(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/secret_" + label + ".png")
func run() -> void:
	game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_endless()
	game.state.fun_value = 66
	game.state.run.depth = 65
	game.state.current_node = "run_66"
	game.show_secret_hall()
	root.size = Vector2i(960,720)
	await capture("hall")
	game.secret_hall.player = Vector2(320,270)
	game.secret_hall.interact()
	await capture("room")
	game.secret_hall.menu = "stat"
	await capture("menu")
	quit()
