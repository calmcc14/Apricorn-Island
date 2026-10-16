extends SceneTree
var game: Control

func _init() -> void: call_deferred("run")

func capture(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/" + label + ".png")

func run() -> void:
	game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	root.size = Vector2i(1280,720)
	game.start_endless()
	game.state.run.depth = 75
	game.state.current_node = "run_75"
	game.state.inventory.item_max_revive = 2
	game.state.inventory.item_master_ball = 1
	game.state.party[1].hp = 0
	game.show_inventory()
	var list: ItemList = game.ui.find_children("*","ItemList",true,false)[0]
	for i in list.item_count:
		if list.get_item_metadata(i) == "item_max_revive":
			list.select(i)
			list.item_selected.emit(i)
			list.ensure_current_is_visible()
			break
	await capture("item_inventory")
	var search: LineEdit = game.ui.find_children("*","LineEdit",true,false)[0]
	search.text = "Bike"
	search.text_changed.emit("Bike")
	list.select(0)
	list.item_selected.emit(0)
	await capture("item_key_search")
	game.state.run.depth = 80
	game.show_milestone_chest()
	await capture("item_chest")
	game.start_battle("procedural","run_80")
	game.battle_menu = "bag"
	game.show_battle()
	await capture("item_battle_bag")
	game.queue_free()
	await process_frame
	print("Item visual captures complete.")
	quit()
