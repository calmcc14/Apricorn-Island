extends SceneTree

func _init() -> void:
	for entry in [["classic_super_potion",50],["super_potion",60],["classic_hyper_potion",200],["hyper_potion",120],["fresh_water",30],["freshest_water",50],["dr_pepper",200],["coca_cola",60],["pepsi",60],["unbranded_soda",50],["lemonade",80]]:
		var item: Dictionary = GameData.ITEMS["item_"+str(entry[0])]
		var patient := {"hp":1,"max_hp":400}
		assert(ItemCatalog.apply(item,patient))
		assert(patient.hp == 1+int(entry[1]))
		patient.hp = 399
		assert(ItemCatalog.apply(item,patient) and patient.hp == 400)
		assert(not ItemCatalog.apply(item,patient))
		patient.hp = 0
		assert(not ItemCatalog.apply(item,patient) and patient.hp == 0)
	var soda_save := {"inventory":{"item_soda_pop":7,"item_unbranded_soda":2},"inventory_slots":[{"id":"item_soda_pop","count":7}],"chest_stores":{"old":{"item_soda_pop":3}},"chest_layouts":{"old":[{"id":"item_soda_pop","count":3}]}}
	ItemCatalog.migrate(soda_save)
	assert(soda_save.inventory.item_unbranded_soda == 9)
	assert(soda_save.inventory_slots[0].id == "item_unbranded_soda")
	assert(soda_save.chest_stores.old.item_unbranded_soda == 3)
	assert(soda_save.chest_layouts.old[0].id == "item_unbranded_soda")
	var soda_twice := soda_save.duplicate(true)
	ItemCatalog.migrate(soda_save)
	assert(soda_save == soda_twice)
	print("Approved healing values, caps, fainted targets and soda migration passed.")
	quit()
