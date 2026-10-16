extends SceneTree
func _init() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	root.size = Vector2i(720,900)
	game.start_endless()
	game.grant_items({"potion":2,"apricorn_ball":3})
	game.show_chest_contents({"potion":2,"apricorn_ball":3})
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/chest_inventory.png")
	quit()
