extends SceneTree

func _init() -> void: call_deferred("run")

func capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/"+name+".png")

func run() -> void:
	var game: Control = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	root.size = Vector2i(1280,720)
	game.start_new_game()
	game.state.inventory.item_exp_share = 1
	game.state.inventory.item_ripe_figy_berry = 2
	game.state.inventory.item_tm001 = 1
	game.show_inventory()
	var panel = game.ui.get_child(0)
	game.show_item_details("item_exp_share",panel.detail)
	for child in panel.detail.get_children():
		if child is Label: child.add_theme_color_override("font_color",Color.WHITE)
	await capture("approved_experience_inventory")
	var machine := ""
	for item in ItemCatalog.data().items:
		if item.kind == "machine" and item.machine_family == "tm" and ItemMechanics.can_teach(item,game.state.party[0]): machine = str(item.id); break
	game.state.inventory[machine] = 1
	game.show_item_details(machine,panel.detail)
	game.select_machine_target(machine,0,panel.detail)
	await capture("approved_move_teaching")
	game.start_battle("meadow_1","meadow")
	for id in ["item_quick_ball","item_x_accuracy","item_y_attack","item_z_accuracy"]: game.state.inventory[id] = 2
	game.battle_menu = "bag"
	game.show_battle()
	await capture("approved_battle_bag")
	print("Approved item screenshots captured")
	quit()
