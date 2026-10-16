extends SceneTree

func _init() -> void:
	for entry in [["item_coal","fire",1.1],["item_charcoal","fire",1.2],["item_magic_water","water",1.1],["item_mystic_water","water",1.2],["item_miracle_seed","grass",1.1],["item_miraculous_seed","grass",1.2],["item_magnet","electric",1.1],["item_magnetite","electric",1.2],["item_ice","ice",1.1],["item_never_melt_ice","ice",1.2],["item_white_belt","fighting",1.1],["item_black_belt","fighting",1.2],["item_poison_spike","poison",1.1],["item_poison_barb","poison",1.2],["item_hard_sand","ground",1.1],["item_soft_sand","ground",1.2],["item_dull_beak","flying",1.1],["item_sharp_beak","flying",1.2],["item_bent_fork","psychic",1.1],["item_twisted_spoon","psychic",1.2],["item_white_powder","bug",1.1],["item_silver_powder","bug",1.2],["item_soft_stone","rock",1.1],["item_hard_stone","rock",1.2]]:
		var pokemon := {"held_item":entry[0],"species":"charmander"}
		assert(is_equal_approx(ItemCatalog.move_power_multiplier(pokemon,entry[1]),entry[2]))
		for other_type in ["fire","water","grass","electric","ice","fighting","poison","ground","flying","psychic","bug","rock","normal"]:
			if other_type != entry[1]: assert(ItemCatalog.move_power_multiplier(pokemon,other_type) == 1.0)
		assert(GameData.ITEMS[entry[0]].status == "implemented")
		assert(ItemCatalog.item_probability(entry[0],0) > 0)
		assert(GameRules.calculate_damage(100.0 * ItemCatalog.move_power_multiplier(pokemon,entry[1]),10,10,1.0) == int(round(100.0 * entry[2])))
	assert(ItemCatalog.move_power_multiplier({},"rock") == 1.0)
	var patient := {"hp":10,"max_hp":65}
	assert(ItemCatalog.apply(GameData.ITEMS.item_potion,patient))
	assert(patient.hp == 30)
	patient.hp = 0
	assert(not ItemCatalog.apply(GameData.ITEMS.item_potion,patient))
	print("Held power checks passed")
	quit()
