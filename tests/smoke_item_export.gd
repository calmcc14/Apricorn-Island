extends SceneTree

func _init() -> void: call_deferred("run")

func run() -> void:
	# Explicit checks work in release builds, where assertions are disabled.
	if ItemCatalog.data().items.size() != 1847 or GameData.ITEMS.size() != 1853 or not GameData.MOVES.has("fissure"):
		push_error("Export is missing the full offline item catalog.")
		quit(1)
		return
	var game: Control = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_endless()
	game.state.run.depth = 10
	game.collect_milestone_chest()
	var count := 0
	for id in game.state.inventory:
		if str(id).begins_with("item_"): count += int(game.state.inventory[id])
	for id in game.state.get("chest_storage",{}):
		if str(id).begins_with("item_"): count += int(game.state.chest_storage[id])
	if count != 3 or "milestone_10" not in game.state.opened_chests:
		push_error("Export failed to collect catalog loot.")
		quit(1)
		return
	game.show_inventory()
	game.state.inventory.item_ripe_figy_berry = 1
	game.equip_power_item("item_ripe_figy_berry",0)
	game.state.party[0].hp = 1
	var messages: Array[String] = []
	if not ItemMechanics.activate_berry(game.state.party[0],GameData.ITEMS,messages):
		push_error("Export is missing approved item mechanics.")
		quit(1)
		return
	game.continue_endless()
	if "milestone_10" not in game.state.opened_chests:
		push_error("Export failed to persist chest collection.")
		quit(1)
		return
	print("Export smoke passed: catalog loaded, three loot rolls, inventory and saved collection.")
	game.queue_free()
	await process_frame
	quit()
