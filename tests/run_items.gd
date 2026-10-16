extends SceneTree

class SaveFailureGame extends "res://scripts/main.gd":
	var fail_saves := false
	func save_game() -> bool:
		if fail_saves: return false
		return super.save_game()

func _init() -> void: call_deferred("run")

func run() -> void:
	var source := ItemCatalog.data()
	assert(source.source_rows.size() == 1473)
	assert(source.key_item_ids.size() == 217)
	assert(source.items.size() == 1859)
	assert(GameData.ITEMS.size() == 1865)
	assert(source.tm_count == 348)
	var old_tms := {"inventory":{"item_tm01":2,"item_tm001":3,"item_tm00":1}}
	ItemCatalog.migrate(old_tms)
	assert(old_tms.inventory == {"item_tm001":6})
	ItemCatalog.migrate(old_tms)
	assert(old_tms.inventory == {"item_tm001":6})
	var ids := {}
	var total_probability := 0.0
	for item in source.items:
		assert(not ids.has(item.id))
		ids[item.id] = true
		assert(GameData.ITEMS.has(item.id))
		assert(item.rarity in ItemCatalog.TIERS)
		assert(item.status in ["implemented","awaiting_mechanics","awaiting_version_choice","originally_without_effect"])
		assert(not str(item.description).is_empty())
		var p := ItemCatalog.item_probability(str(item.id),0)
		assert(p > 0 and ItemCatalog.item_probability(str(item.id),100) > 0)
		total_probability += p
	assert(is_equal_approx(total_probability,1.0))
	for id in source.source_rows + source.key_item_ids: assert(ids.has(id))
	for depth in [-10,0,25,50,75,100,10000]:
		var total := 0.0
		for p in ItemCatalog.tier_odds(depth): total += p
		assert(is_equal_approx(total,1.0))
	assert(is_equal_approx(ItemCatalog.tier_odds(25)[0],0.50))
	assert(is_equal_approx(ItemCatalog.tier_odds(75)[4],0.04))
	assert(ItemCatalog.tier_odds(10000) == ItemCatalog.tier_odds(100))
	var supplies := {"potion":2,"apricorn_ball":3}
	var rewards := ItemCatalog.chest_rewards(123,"green_chest",0,supplies)
	assert(rewards == ItemCatalog.chest_rewards(123,"green_chest",0,supplies))
	assert(supplies.size() == 2)
	var rolled := 0
	for id in rewards:
		if str(id).begins_with("item_"): rolled += int(rewards[id])
	assert(rolled == 3)
	# Statistical check verifies tier selection, not only the configured numbers.
	for depth in [0,100]:
		var counts := [0,0,0,0,0]
		for seed_value in 4000:
			var loot := ItemCatalog.chest_rewards(seed_value,"sample",depth,{})
			for id in loot:
				counts[ItemCatalog.TIERS.find(GameData.ITEMS[id].rarity)] += int(loot[id])
		for i in counts.size():
			assert(abs(float(counts[i])/12000.0 - float(ItemCatalog.tier_odds(depth)[i])) < 0.025)
	var pokemon := {"hp":0,"max_hp":65}
	assert(not ItemCatalog.apply(GameData.ITEMS.item_max_potion,pokemon))
	assert(ItemCatalog.apply(GameData.ITEMS.item_revive,pokemon))
	assert(pokemon.hp == 32)
	assert(not ItemCatalog.apply(GameData.ITEMS.item_max_revive,pokemon))
	assert(ItemCatalog.apply(GameData.ITEMS.item_berry_juice,pokemon))
	assert(pokemon.hp == 52)
	assert(ItemCatalog.apply(GameData.ITEMS.item_max_potion,pokemon))
	assert(pokemon.hp == 65)
	assert(not ItemCatalog.apply(GameData.ITEMS.item_max_potion,pokemon))
	assert(not ItemCatalog.apply(GameData.ITEMS.item_super_potion,pokemon))
	var old := {"party":[pokemon],"reserve":[],"inventory":{"potion":8,"retired_unknown":2}}
	ItemCatalog.migrate(old)
	ItemCatalog.migrate(old)
	assert(old.inventory.potion == 8 and old.inventory.retired_unknown == 2)
	assert(old.party[0].held_item == "" and old.catalog_version == 1)
	var game := SaveFailureGame.new()
	root.add_child(game)
	await process_frame
	game.animation_enabled = false
	game.start_new_game("bulbasaur")
	game.state.party.append(GameData.make_pokemon("charmander"))
	game.state.party.append(GameData.make_pokemon("squirtle"))
	game.open_chest(game.get_node_data("green_chest"))
	var inventory: Dictionary = game.state.inventory.duplicate(true)
	game.open_chest(game.get_node_data("green_chest"))
	assert(game.state.inventory == inventory)
	assert(game.load_game())
	game.open_chest(game.get_node_data("green_chest"))
	assert(game.state.inventory == inventory)
	assert(game.state.chest_rewards.has("green_chest"))
	var before_failure: Dictionary = game.state.duplicate(true)
	game.fail_saves = true
	game.open_chest(game.get_node_data("blue_chest"))
	assert(game.state == before_failure)
	game.fail_saves = false
	game.open_chest(game.get_node_data("blue_chest"))
	assert("blue_chest" in game.state.opened_chests)
	game.start_endless("bulbasaur")
	game.state.party.append(GameData.make_pokemon("charmander"))
	game.state.party.append(GameData.make_pokemon("squirtle"))
	game.state.run.seed = 123
	# Legacy cache collection remains safe even though new routes have no random caches.
	var cache: Dictionary = RogueRules.node(123,2)
	cache.kind = "chest"
	game.state.run.depth = int(cache.floor)-1
	game.state.current_node = cache.id
	game.enter_current_node(cache)
	assert(game.state.run.depth == cache.floor)
	assert(cache.id in game.state.opened_chests)
	inventory = game.state.inventory.duplicate(true)
	game.open_chest(cache)
	assert(game.state.inventory == inventory)
	game.continue_endless()
	assert(game.state.inventory == inventory)
	game.state.run.depth = 20
	game.state.current_node = "run_20"
	game.collect_milestone_chest()
	inventory = game.state.inventory.duplicate(true)
	game.collect_milestone_chest()
	game.continue_endless()
	assert(game.state.inventory == inventory)
	assert(game.state.run.depth == 20)
	game.state.inventory.item_revive = 1
	game.state.party[1].hp = 0
	game.use_heal_item("potion",1)
	assert(game.state.party[1].hp == 0)
	game.use_heal_item("item_revive",1)
	assert(game.state.party[1].hp > 0 and int(game.state.inventory.get("item_revive",0)) == 0)
	game.state.inventory.item_master_ball = 1
	game.start_battle("procedural","run_20")
	var messages: Array[String] = []
	game.resolve_ball_action({"ball":"item_master_ball","actor":0,"target":0},messages)
	assert(int(game.state.inventory.get("item_master_ball",0)) == 0 and game.state.reserve.size() == 1)
	game.resolve_ball_action({"ball":"item_master_ball","actor":0,"target":0},messages)
	assert(game.state.reserve.size() == 1)
	game.state.inventory.item_master_ball = 1
	for enemy in game.battle.enemies: enemy.hp = 0
	game.resolve_ball_action({"ball":"item_master_ball","actor":0,"target":0},messages)
	assert(game.state.inventory.item_master_ball == 1)
	game.state.inventory.item_max_revive = 1
	game.state.party[2].hp = 0
	game.use_heal_in_battle({"actor":0,"target":2,"item":"item_max_revive"},messages)
	assert(game.state.party[2].hp == game.state.party[2].max_hp)
	assert(int(game.state.inventory.get("item_max_revive",0)) == 0)
	var start := Time.get_ticks_msec()
	game.show_inventory()
	assert(Time.get_ticks_msec() - start < 2000)
	var grids := game.ui.find_children("InventorySlots","GridContainer",true,false)
	assert(grids.size() == 1 and grids[0].get_child_count() == 27)
	assert(game.ui.find_children("HotbarSlots","GridContainer",true,false)[0].get_child_count() == 9)
	var detail := VBoxContainer.new()
	game.ui.add_child(detail)
	game.show_item_details("item_master_ball",detail)
	assert(detail.get_child_count() >= 4)
	print("Item tests passed: coverage, odds, seeded loot, three chest paths, reloads, migration, effects and full inventory.")
	game.queue_free()
	await process_frame
	quit()
