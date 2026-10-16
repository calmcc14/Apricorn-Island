extends SceneTree

func _init() -> void: call_deferred("run")
func capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/"+name+".png")

func run() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	root.size = Vector2i(1280,720)
	game.start_endless("bulbasaur")
	game.state.inventory.item_red_orb = 2
	game.state.inventory.item_pp_up = 3
	game.state.inventory.item_bottle_cap = 2
	game.show_inventory()
	game.show_item_details("item_red_orb",game.ui.get_child(0).detail)
	await capture("pending_orb_inventory")
	game.start_orb_boss("item_red_orb",0)
	await capture("pending_primal_boss")
	game.finish_orb_boss("loss")
	game.state.inventory.item_blue_orb = 1
	game.start_orb_boss("item_blue_orb",0)
	await capture("pending_ocean_boss")
	print("Item and boss screenshots captured.")
	quit()
