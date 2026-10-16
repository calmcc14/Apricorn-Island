extends SceneTree
func _init() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	game.start_endless()
	game.show_inventory()
	var view = game.ui.get_child(0)
	assert(game.ui.find_child("InventorySlots",true,false).get_child_count() == 27)
	assert(game.ui.find_child("HotbarSlots",true,false).get_child_count() == 9)
	var from = view.grids[0]
	var to = view.grids[35]
	var id = from.stack.id
	var total = game.state.inventory[id]
	view.move_stack(from,to)
	assert(from.stack.is_empty())
	assert(to.stack.id == id)
	assert(game.state.inventory[id] == total)
	game.show_inventory()
	assert(game.ui.get_child(0).grids[35].stack.id == id)
	game.grant_items({"potion":2})
	var before = int(game.state.inventory.get("potion",0))
	game.show_chest_contents({"potion":2})
	view = game.ui.get_child(0)
	assert(game.ui.find_child("ChestSlots",true,false).get_child_count() == 27)
	assert(game.state.chest_storage.potion == 2)
	assert(game.state.inventory.get("potion",0) == before-2)
	var chest = view.grids[0]
	var target = view.grids[62]
	view.move_stack(chest,target)
	assert(game.state.inventory.potion == before)
	assert(not game.state.chest_storage.has("potion"))
	game.show_chest_contents({})
	assert(not game.state.chest_storage.has("potion"))
	var key := InputEventKey.new()
	key.physical_keycode = KEY_E
	key.pressed = true
	game._input(key)
	assert(game.screen == game.Screen.MAP)
	game._input(key)
	assert(game.screen == game.Screen.INVENTORY)
	key.echo = true
	game._input(key)
	assert(game.screen == game.Screen.INVENTORY)
	print("Inventory checks passed: layout, movement, totals, persistence, chest transfers and E toggle.")
	quit()
