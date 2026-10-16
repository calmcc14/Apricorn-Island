extends SceneTree

func _init() -> void:
	var pokemon := GameData.make_pokemon("bulbasaur")
	for stat_name in ItemMechanics.IV_STATS: pokemon.ivs[stat_name] = 0
	ItemMechanics.apply_iv_bonuses(pokemon)
	var progress := ItemMechanics.level_progress(pokemon)
	assert(progress.current == 0 and progress.remaining > 0)
	var hp := int(pokemon.max_hp)
	var attack := int(pokemon.attack)
	assert(ItemMechanics.grant_experience(pokemon,int(progress.remaining)-1) == 0)
	assert(ItemMechanics.level_progress(pokemon).remaining == 1)
	assert(ItemMechanics.grant_experience(pokemon,1) == 1)
	assert(pokemon.level == 6 and pokemon.max_hp == hp+2 and pokemon.attack == attack+1)
	assert(ItemMechanics.level_progress(pokemon).current == 0)
	pokemon.hp = 0
	assert(ItemMechanics.grant_experience(pokemon,2000000) == 94)
	assert(pokemon.hp == 0 and pokemon.level == 100)
	assert(ItemMechanics.level_progress(pokemon).label == "MAX LEVEL")
	assert(ItemMechanics.grant_experience(pokemon,100) == 0)
	var restored: Dictionary = JSON.parse_string(JSON.stringify(pokemon))
	assert(ItemMechanics.level_progress(restored).ratio == 1.0)
	print("Level progression tests passed.")
	quit()
