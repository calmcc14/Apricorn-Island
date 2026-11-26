extends SceneTree

const Dimension = preload("res://scripts/glitch_dimension.gd")
const Signals = preload("res://scripts/glitch_signals.gd")

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	if not game.cartridge_profile.has("active"):
		game.choose_first_cartridge(Cartridge.RED)
	game.start_new_game("bulbasaur")
	assert(not game.glitch_available())
	game.state.cleared.append("meadow")
	game.show_map()
	assert(game.glitch_available())
	game.enter_glitch()
	assert(game.screen == game.Screen.GLITCH and game.state.current_node == "airstrip")
	game.leave_glitch()
	assert(game.in_glitch())
	game.continue_game()
	assert(game.state.glitch_dimension.floor == 1)
	game.start_glitch_battle()
	var target: Dictionary = game.battle.enemies[0]
	var hp := int(target.hp)
	game.state.inventory.item_master_ball = 1
	game.debug_options.capture = true
	var messages: Array[String] = []
	game.resolve_ball_action({"actor":0,"target":0,"ball":"item_master_ball"},messages)
	assert(target.hp == hp and target.glitch_impact == 1 and not target.has("captured"))
	assert(game.state.party.size() == 1 and game.state.reserve.is_empty())
	assert(game.state.inventory.item_master_ball == 0)
	game.flee_battle()
	assert(game.screen == game.Screen.BATTLE and game.in_glitch())
	game.debug_options.enemy_turns = false
	game.debug_options.accuracy = true
	game.battle.actions = [{"actor":0,"kind":"move","move":"tackle","target":0}]
	game.resolve_round()
	assert(target.hp < hp and target.glitch_impact == 2)
	assert(not game.state.pokedex.has(target.species))
	var target_id: String = target.species
	game.continue_game()
	assert(game.battle.enemies[0].hp == target.hp)
	game.state.party[0].hp = 0
	game.handle_defeat()
	assert(game.in_glitch() and game.state.glitch_dimension.floor == 1)
	assert(game.state.party[0].hp == game.state.party[0].max_hp)
	assert(not game.state.has("battle_checkpoint"))
	verify_signals(game)

	var seen := {}
	var seen_signals := {}
	seen[target_id] = true
	game.state.party[0].moves.append("ice_beam")
	game.state.party[0].pp.ice_beam = 10
	for floor_number in range(1,51):
		assert(int(game.state.glitch_dimension.floor) == floor_number)
		game.start_glitch_battle()
		for enemy in game.battle.enemies:
			assert(enemy.has("glitch_shape"))
			seen[enemy.species] = true
			if enemy.has("glitch_signal"): seen_signals[enemy.glitch_signal] = true
		game.debug_options.one_hit = true
		var move := "ice_beam" if MoveEffects.effectiveness("normal",game.battle.enemies[0]) == 0.0 else "tackle"
		game.state.party[0].pp[move] = 10
		game.battle.actions = [{"actor":0,"kind":"move","move":move,"target":0}]
		game.resolve_round()
		assert(game.battle_finished)
		game.finish_victory()
		assert(game.state.glitch_dimension.cleared)
		if floor_number % 5 == 0:
			var inventory: Dictionary = game.state.inventory.duplicate()
			var expected := Dimension.cache_loot(int(game.state.glitch_dimension.seed),floor_number)
			game.open_glitch_cache()
			for item_id in expected:
				assert(int(game.state.inventory[item_id]) == int(inventory.get(item_id,0)) + int(expected[item_id]))
				assert(game.item_definition(item_id).glitched)
			inventory = game.state.inventory.duplicate()
			game.continue_game()
			game.open_glitch_cache()
			assert(game.state.inventory == inventory)
		if floor_number < 50:
			game.leave_glitch()
			assert(game.in_glitch())
			game.advance_glitch()
	assert(seen.size() == Dimension.ROSTER.size())
	for featured in Signals.FEATURED: assert(seen_signals.has(featured))
	assert(game.state.glitch_dimension.floor == 50 and game.state.glitch_dimension.cleared)
	game.leave_glitch()
	game.continue_game()
	assert(not game.in_glitch() and game.state.glitch_completed and game.state.current_node == "airstrip")
	assert(game.state.cleared == ["airstrip","meadow"])
	verify_items(game)

	game.start_endless("eevee")
	game.state.run.depth = 5
	game.state.current_node = "run_5"
	game.show_map()
	assert(game.glitch_available())
	game.enter_glitch()
	game.start_glitch_battle()
	game.continue_endless()
	assert(game.battle.glitch and game.state.run.depth == 5 and not game.state.run.pending_upgrade)
	print("Glitch Dimension verified across all 50 floors, both saves, signal archive, capture, damage, cache odds, and item breakage.")
	game.queue_free()
	await process_frame
	quit()

func verify_signals(game) -> void:
	assert(Signals.find(1,"").size() == 137)
	assert(Signals.get_entry("rb_000").name == "'M (00)")
	assert(Signals.get_entry("y_255").name == "Q ◣")
	assert(Signals.find(1,"missingno").size() == 5)
	var matches := Signals.find(1,"0xC1")
	assert(matches.size() == 2 and matches[0].index == 193 and matches[1].index == 193)
	assert(Signals.find(6,"#65535")[0].id == "kalos:65535")
	assert(Signals.find(6,"65536").is_empty())
	assert(Signals.get_entry("hoenn:540").name == "?")
	assert(Signals.get_entry("sinnoh:33261").name == "Hybrid #33261")
	assert(Signals.get_entry("unova:667").name == "Glitch Unown P")
	assert(Signals.find(5,"Glitch Unown Q").size() == 2)
	assert(Signals.get_entry("unova_alt:708").name == "Glitch Unown W")
	game.show_glitch_archive()
	assert(game.screen == game.Screen.GLITCH_ARCHIVE)
	game.tune_glitch_signal("kalos:65536")
	assert(not game.state.glitch_dimension.has("signal"))
	var search: LineEdit = game.ui.find_children("*","LineEdit",true,false)[0]
	search.text = "#65535"
	search.text_changed.emit(search.text)
	var result: Button
	for button in game.ui.find_children("*","Button",true,false):
		if button.text.begins_with("Glitch #65535\n"):
			result = button
			break
	assert(result != null)
	var sprite := result.icon
	assert(sprite is ImageTexture and sprite.get_size() == Vector2(32,32))
	result.pressed.emit()
	assert(game.screen == game.Screen.GLITCH_PROFILE and game.glitch_profile.id == "kalos:65535")
	assert(game.glitch_pokedex_scan == null and not game.state.glitch_dimension.has("signal"))
	for button in game.ui.find_children("*","Button",true,false):
		if button.text == "Tune this encounter":
			button.pressed.emit()
			break
	game.continue_game()
	assert(game.state.glitch_dimension["signal"] == "kalos:65535")
	game.start_glitch_battle()
	var opponent: Dictionary = game.battle.enemies[0]
	assert(GameData.pokemon_name(opponent) == "Glitch #65535")
	assert(game.GlitchArt.encounter_sprite(opponent.glitch_shape,Signals.get_entry(opponent.glitch_signal)) == sprite)
	var other_sprite: Texture2D = game.GlitchArt.encounter_sprite(opponent.glitch_shape,Signals.get_entry("kalos:65534"))
	assert(other_sprite.get_image().get_data() != sprite.get_image().get_data())
	game.continue_game()
	assert(game.battle.enemies[0].glitch_signal == "kalos:65535")
	game.state.party[0].hp = 0
	game.handle_defeat()
	game.tune_glitch_signal("")
	assert(not game.state.glitch_dimension.has("signal"))
	verify_profiles(game)

func verify_profiles(game) -> void:
	var profiles := {
		"rb_000":["m","bird","normal"], "y_000":["trainer","glitch","normal"],
		"missingno":["signal","bird","normal"], "missingno_ghost":["ghost","bird","normal"],
		"missingno_wing":["wing","bird","normal"], "missingno_shell":["shell","bird","normal"],
		"missingno_yellow":["yellow","normal","999"],
	}
	for id in profiles:
		var record := Signals.get_entry(id)
		var expected: Array = profiles[id]
		assert(record.profile.portrait == expected[0] and record.profile.types == expected.slice(1))
		var opponents := Dimension.encounter({"floor":1,"seed":23,"signal":id},game.state.party)
		assert(opponents[0].glitch_signal == id and ItemMechanics.species(opponents[0]).types == expected.slice(1))
	assert(Signals.get_entry("rb_000").profile.category == "ゥ R p ゥ R h")
	assert(Signals.get_entry("y_000").profile.category == "P'v Aq")
	assert(Signals.get_entry("missingno_shell").index == 182)
	assert(Signals.get_entry("missingno_wing").index == 183)
	assert(Signals.get_entry("missingno_ghost").index == 184)
	assert(Signals.find(1,"Ketsuban").size() == 5)
	var normal_forms := Signals.find(1,"0x1F")
	assert(normal_forms.size() == 2 and normal_forms[0].id == "missingno" and normal_forms[1].id == "missingno_yellow")
	assert(Signals.find(1,"0xB8")[0].id == "missingno_ghost")
	verify_m_reference(game)
	verify_trainer_reference(game)
	verify_pointer_a_reference(game)
	verify_four_four_reference(game)
	verify_c0_references(game)
	verify_c1_references(game)
	verify_c2_c3_references(game)
	verify_imported_references(game)
	game.show_glitch_profile("missingno_yellow")
	assert(game.screen == game.Screen.GLITCH_PROFILE)
	profile_control(game,"Gen I data").pressed.emit()
	profile_control(game,"Cartridge").pressed.emit()
	assert(game.glitch_reference_section == 4)
	var labels: Array[Node] = game.ui.find_children("*","Label",true,false)
	assert(labels.any(func(label): return label.text == "Exp. at Lv. 100  16,136,684"))
	assert(labels.any(func(label): return label.text == "Catch rate  0  ·  Base Exp.  Unknown"))
	profile_control(game,"Back to Profile").pressed.emit()
	game.tune_glitch_signal("missingno_yellow")
	game.start_glitch_battle()
	game.continue_game()
	assert(ItemMechanics.species(game.battle.enemies[0]).types == ["normal","999"])
	game.state.party[0].hp = 0
	game.handle_defeat()
	game.tune_glitch_signal("")

func verify_m_reference(game) -> void:
	game.glitch_archive_query = "'m (00)"
	game.show_glitch_archive()
	var row := profile_control(game,"'M (00)")
	assert(row.icon.resource_path == "res://assets/glitch/m_menu.png")
	row.pressed.emit()
	assert(game.glitch_profile.id == "rb_000")
	profile_control(game,"Gen I data").pressed.emit()
	assert(game.glitch_reference_section == 0)
	var reference: Dictionary = game.glitch_profile.profile.reference
	var defense: Array = reference.stats[2]
	assert(defense[0] == "Defense" and int(defense[1]) == 0 and defense.slice(2) == ["5–51","5–98"])
	assert(reference.total == 205 and reference.split_total == 234)
	profile_control(game,"Moves").pressed.emit()
	assert(game.glitch_reference_section == 1)
	assert(reference.level_moves[0] == reference.level_moves[1] and reference.machine_moves.size() == 24)
	profile_control(game,"Evolution").pressed.emit()
	assert(game.glitch_reference_section == 2 and reference.evolutions.size() == 6)
	profile_control(game,"Sprites").pressed.emit()
	assert(game.glitch_reference_section == 3)
	var front: TextureRect = game.ui.find_child("FrontReferenceSprite",true,false)
	var back: TextureRect = game.ui.find_child("BackReferenceSprite",true,false)
	var menu: TextureRect = game.ui.find_child("MenuReferenceSprite",true,false)
	assert(front != null and front.texture is AtlasTexture)
	assert(back != null and back.texture.resource_path == "res://assets/glitch/m_back.png")
	assert(menu != null and menu.texture.resource_path == "res://assets/glitch/m_menu.png")
	profile_control(game,"Cartridge").pressed.emit()
	assert(game.glitch_reference_section == 4)
	var labels: Array[Node] = game.ui.find_children("*","Label",true,false)
	assert(labels.any(func(label): return label.text == "Catch rate  3  ·  Base Exp.  Unknown"))
	assert(labels.any(func(label): return label.text == "Japanese name  ィ゙ゃゾ┛ · Iyazo"))
	assert(Signals.find(1,"Iyazo").size() == 2)
	profile_control(game,"3TrainerPoké " + Signals.POKEDOLLAR).pressed.emit()
	assert(game.glitch_reference_section == 4 and game.glitch_profile.id == "y_000")
	labels = game.ui.find_children("*","Label",true,false)
	assert(labels.any(func(label): return label.text == "Catch rate  4  ·  Base Exp.  Unknown"))
	profile_control(game,"'M (00)").pressed.emit()
	assert(game.glitch_profile.id == "rb_000")
	profile_control(game,"Back to Profile").pressed.emit()
	assert(game.glitch_reference_section == -1 and game.glitch_pokedex_scan != null)

func verify_trainer_reference(game) -> void:
	var name := "3TrainerPoké " + Signals.POKEDOLLAR
	game.glitch_archive_query = "3trainerpoké $"
	assert(Signals.get_entry("y_000").name == name)
	assert(Signals.find(1,name)[0].id == "y_000")
	assert(GameData.pokemon_name({"glitch_signal":"y_000"}) == name)
	game.show_glitch_archive()
	var row := profile_control(game,name)
	assert(row.icon.resource_path == "res://assets/glitch/trainer_menu.png")
	row.pressed.emit()
	assert(game.glitch_profile.id == "y_000")
	profile_control(game,"Gen I data").pressed.emit()
	var labels: Array[Node] = game.ui.find_children("*","Label",true,false)
	assert(labels.any(func(label): return label.text == "Type effectiveness · Glitch / Normal"))
	var reference: Dictionary = game.glitch_profile.profile.reference
	assert(reference.total == 725 and reference.split_total == 961)
	assert(reference.level_moves[3][1] == "Super Glitch" and int(reference.level_moves[4][0]) == 70)
	assert(reference.machine_moves.size() == 15 and reference.evolutions.size() == 5)
	profile_control(game,"Sprites").pressed.emit()
	var back: TextureRect = game.ui.find_child("BackReferenceSprite",true,false)
	var menu: TextureRect = game.ui.find_child("MenuReferenceSprite",true,false)
	assert(back != null and back.texture.resource_path == "res://assets/glitch/trainer_back.png")
	assert(menu != null and menu.texture.resource_path == "res://assets/glitch/trainer_menu.png")

func verify_pointer_a_reference(game) -> void:
	game.glitch_archive_query = "0xBF"
	game.show_glitch_archive()
	var row := profile_control(game,"▶ A")
	assert(row.icon.resource_path == "res://assets/glitch/pointer_a_menu.png")
	row.pressed.emit()
	assert(game.glitch_profile.id == "rb_191" and game.glitch_pokedex_scan.get_size() == Vector2(160,144))
	profile_control(game,"Gen I data").pressed.emit()
	var reference: Dictionary = game.glitch_profile.profile.reference
	assert(reference.total == 274 and reference.split_total == 293 and reference.catch_rate == 23)
	assert(reference.level_moves.size() == 52 and reference.machine_moves.size() == 17)
	assert(reference.level_moves[0][2] == "Cooltrainer♀" and int(reference.level_moves[-1][0]) == 254)
	profile_control(game,"Evolution").pressed.emit()
	var labels: Array[Node] = game.ui.find_children("*","Label",true,false)
	assert(labels.any(func(label): return label.text == "Does not evolve"))
	profile_control(game,"Back to Profile").pressed.emit()
	profile_control(game,"Tune this encounter").pressed.emit()
	var opponent: Dictionary = Dimension.encounter(game.state.glitch_dimension,game.state.party)[0]
	assert(opponent.glitch_signal == "rb_191" and GameData.pokemon_name(opponent) == "▶ A")
	assert(MoveEffects.effectiveness("ghost",opponent) == 0.0 and MoveEffects.effectiveness("fighting",opponent) == 2.0)
	game.tune_glitch_signal("")

func verify_four_four_reference(game) -> void:
	var aliases := Signals.find(1,"4A 4")
	assert(aliases.size() == 1 and aliases[0].id == "y_191")
	game.glitch_archive_query = "0xBF"
	game.show_glitch_archive()
	var row := profile_control(game,"4 4")
	assert(row.icon.resource_path == "res://assets/glitch/four_four_menu.png")
	row.pressed.emit()
	assert(game.glitch_profile.id == "y_191" and game.glitch_pokedex_scan.get_size() == Vector2(160,144))
	profile_control(game,"Gen I data").pressed.emit()
	var reference: Dictionary = game.glitch_profile.profile.reference
	assert(reference.total == 256 and reference.catch_rate == 20 and reference.level_moves.size() == 57)
	assert(reference.level_moves[1] == reference.level_moves[2] and reference.machine_moves.size() == 20)
	assert(reference.evolutions[0][2] == "PkMn pゥぁ ゥぇ")
	profile_control(game,"Sprites").pressed.emit()
	var back: TextureRect = game.ui.find_child("BackReferenceSprite",true,false)
	assert(back != null and back.texture.get_image().get_pixel(28,28) == Color.BLACK)
	profile_control(game,"Cartridge").pressed.emit()
	profile_control(game,"▶ A").pressed.emit()
	assert(game.glitch_profile.id == "rb_191" and game.glitch_reference_section == 4)
	profile_control(game,"4 4").pressed.emit()
	assert(game.glitch_profile.id == "y_191" and game.glitch_reference_section == 4)

func verify_c0_references(game) -> void:
	var records := Signals.find(1,"0xC0")
	assert(records.size() == 2 and records[0].id == "rb_192" and records[1].id == "y_192")
	game.glitch_archive_query = "0xC0"
	game.show_glitch_archive()
	profile_control(game,"a").pressed.emit()
	assert(game.glitch_profile.profile.types == ["water"] and game.glitch_pokedex_scan.get_size() == Vector2(160,144))
	profile_control(game,"Gen I data").pressed.emit()
	var red: Dictionary = game.glitch_profile.profile.reference
	assert(red.total == 335 and red.level_moves.size() == 57 and red.machine_moves.size() == 27 and red.evolutions.is_empty())
	profile_control(game,"Cartridge").pressed.emit()
	profile_control(game,"4 4Hy").pressed.emit()
	assert(game.glitch_profile.id == "y_192" and game.glitch_profile.profile.types == ["water","psychic"])
	profile_control(game,"Evolution").pressed.emit()
	var yellow: Dictionary = game.glitch_profile.profile.reference
	assert(yellow.total == 410 and yellow.level_moves.size() == 38 and yellow.machine_moves.size() == 36)
	assert(yellow.evolutions.size() == 3 and yellow.evolution_notes.size() == 2)
	profile_control(game,"Cartridge").pressed.emit()
	profile_control(game,"a").pressed.emit()
	assert(game.glitch_profile.id == "rb_192" and game.glitch_reference_section == 4)

func verify_c1_references(game) -> void:
	assert(Signals.find(1,"Fuiji").size() == 2)
	game.glitch_archive_query = "0xC1"
	game.show_glitch_archive()
	profile_control(game,"ゥ (C1)").pressed.emit()
	assert(game.glitch_profile.id == "rb_193" and game.glitch_pokedex_scan.get_size() == Vector2(160,144))
	profile_control(game,"Gen I data").pressed.emit()
	var red: Dictionary = game.glitch_profile.profile.reference
	assert(red.total == 788 and red.level_moves.size() == 35 and red.machine_moves.size() == 18)
	assert(red.evolutions[0][2] == "Spearow" and red.evolutions[1][2] == "Fearow")
	var opponent := {"species": Dimension.species_id(0), "glitch_signal": "rb_193"}
	assert(MoveEffects.effectiveness("fighting",opponent) == 1.0 and MoveEffects.effectiveness("ghost",opponent) == 1.0)
	profile_control(game,"Cartridge").pressed.emit()
	profile_control(game,"♀ .").pressed.emit()
	assert(game.glitch_profile.id == "y_193" and game.glitch_reference_section == 4)
	var yellow: Dictionary = game.glitch_profile.profile.reference
	assert(yellow.total == 630 and yellow.level_moves.size() == 112 and yellow.machine_moves.size() == 18)
	assert(yellow.evolutions.is_empty() and yellow.matchups[0] == ["Weak · 4×","Fighting"])
	opponent.glitch_signal = "y_193"
	assert(MoveEffects.effectiveness("fighting",opponent) == 4.0 and MoveEffects.effectiveness("ghost",opponent) == 0.0)
	profile_control(game,"ゥ (C1)").pressed.emit()
	assert(game.glitch_profile.id == "rb_193")

func verify_c2_c3_references(game) -> void:
	for code in ["0xC2","0xC3"]:
		var records := Signals.find(1,code)
		assert(records.size() == 2)
		game.glitch_archive_query = code
		game.show_glitch_archive()
		profile_control(game,str(records[0].name)).pressed.emit()
		profile_control(game,"Gen I data").pressed.emit()
		profile_control(game,"Cartridge").pressed.emit()
		profile_control(game,str(records[1].name)).pressed.emit()
		assert(game.glitch_profile.id == records[1].id and game.glitch_reference_section == 4)
		profile_control(game,str(records[0].name)).pressed.emit()
		assert(game.glitch_profile.id == records[0].id and game.glitch_reference_section == 4)
	for entry in [["rb_194",29,22,0],["y_194",34,16,1],["rb_195",10,23,2],["y_195",19,16,3]]:
		var reference: Dictionary = Signals.get_entry(entry[0]).profile.reference
		assert(reference.level_moves.size() == entry[1] and reference.machine_moves.size() == entry[2] and reference.evolutions.size() == entry[3])
	game.show_glitch_profile("rb_195",3)
	assert(game.ui.find_child("Front2ReferenceSprite",true,false).texture.get_size() == Vector2(48,48))
	game.show_glitch_profile("y_195",3)
	assert(game.ui.find_child("Front2ReferenceSprite",true,false).texture.get_size() == Vector2(56,56))
	assert(game.ui.find_child("Front3ReferenceSprite",true,false).texture.get_size() == Vector2(56,56))

func verify_imported_references(game) -> void:
	for index in range(196,256):
		for prefix in ["rb","y"]:
			var record := Signals.get_entry("%s_%03d" % [prefix,index])
			assert(record.has("profile") and record.profile.has("source"))
			assert(record.profile.reference.has("machine_moves"))
			if record.id != "rb_205": assert(record.profile.reference.has("level_moves"))
			assert(Signals.get_entry(str(record.profile.cartridge.counterpart)).index == record.index)
	for id in ["missingno","missingno_yellow","rb_196","y_255","gs_00","crystal_fc","hoenn:540","sinnoh:33261","unova:653","unova_alt:687","unova_egg:685","kalos:65535","later_egg"]:
		var record := Signals.get_entry(id)
		assert(record.has("profile"))
		game.show_glitch_profile(id)
		assert(game.glitch_profile.id == id)
		profile_control(game,"Gen %s data" % game.glitch_generation_name(record.generation)).pressed.emit()
		if record.profile.has("reference"):
			profile_control(game,"Sprites").pressed.emit()
			profile_control(game,"Cartridge").pressed.emit()
		assert(game.glitch_reference_section == 4)
	assert(Signals.find(9,"Egg")[0].id == "later_egg")
	assert(Signals.find(5,"UFO").is_empty())

func profile_control(game, label: String) -> Button:
	for button in game.ui.find_children("*","Button",true,false):
		if button.text.get_slice("\n",0) == label: return button
	return null

func verify_items(game) -> void:
	assert(game.item_definition("glitch_heal_scrambled").amount < GameData.ITEMS.potion.amount)
	assert(game.item_definition("glitch_heal_burst").amount > GameData.ITEMS.potion.amount)
	assert(Dimension.cache_odds(5) != Dimension.cache_odds(10))
	var random := RandomNumberGenerator.new()
	random.seed = 282
	var breaks := 0
	for roll in 20000:
		if Dimension.breaks_on_use(random): breaks += 1
	assert(absf(float(breaks) / 20000 - 0.2368) < 0.01)
	for should_break in [false,true]:
		for trial in 300:
			random.seed = trial
			if Dimension.breaks_on_use(random) != should_break: continue
			game.rng.seed = trial
			var item_id := "glitch_heal_scrambled"
			game.state.inventory[item_id] = 1
			var pokemon: Dictionary = game.state.party[0]
			pokemon.hp = 1
			game.use_heal_item(item_id,0)
			assert(pokemon.hp == 12)
			assert(int(game.state.inventory.get(item_id,0)) == (0 if should_break else 1))
			break
	var floor_five := [0,0,0,0,0]
	for seed_value in 1000:
		var rewards := Dimension.cache_loot(seed_value,5)
		for id in rewards:
			var tier := ItemCatalog.TIERS.find(game.item_definition(id).rarity)
			floor_five[tier] += int(rewards[id])
	for index in floor_five.size():
		assert(absf(float(floor_five[index]) / 3000 - Dimension.cache_odds(5)[index] / 100.0) < 0.04)
