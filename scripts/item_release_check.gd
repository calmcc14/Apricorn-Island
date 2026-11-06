class_name ItemReleaseCheck
extends RefCounted

static func run(game: Control) -> void:
	var results := {"packed":not OS.has_feature("editor"),"catalog":ItemCatalog.data().items.size() == 1859,"compiled_scripts":FileAccess.file_exists("res://scripts/main.gd.remap") and FileAccess.file_exists("res://scripts/pending_items.gd.remap")}
	game.start_endless("bulbasaur")
	game.state.inventory.item_red_orb = 1
	game.state.inventory.item_master_ball = 1
	game.start_orb_boss("item_red_orb",0)
	results.boss_started = game.battle.has("orb_item")
	if results.boss_started:
		var boss: Dictionary = game.battle.enemies[0]
		results.form = boss.form == "groudon-primal"
		results.artwork = game.sprites.has("groudon-primal_front")
		var hp := int(boss.boss_normal_hp)
		var messages: Array[String] = []
		game.resolve_ball_action({"actor":0,"target":0,"ball":"item_master_ball"},messages)
		results.capture_hp = game.state.party[-1].max_hp == hp
		results.no_duplicate_orb = game.state.party[-1].held_item == ""
		game.finish_victory()
		game.continue_endless()
		results.saved_orb = game.state.orb_instances.item_red_orb[0].held_only
	game.state.party[0].status_condition = "poison"
	results.medicine = ItemCatalog.apply(GameData.ITEMS.item_antidote,game.state.party[0])
	game.state.party[0].pp.tackle = 0
	results.pp = PendingItems.pp_use(GameData.ITEMS.item_leppa_berry,game.state.party[0],"tackle",true)
	results.standard_moves = GameData.MOVES.quick_attack.priority == 1 and GameData.MOVES.vine_whip.pp == 25
	var weather_check := {}
	var setter: Dictionary = game.state.party[0].duplicate(true)
	setter.held_item = "item_icy_rock"
	for attempt in 3: MoveEffects.set_weather(weather_check,"snow",setter)
	results.combined_weather = weather_check.weather == "hail_snow" and weather_check.weather_turns == 8
	results.gift_data = FileAccess.file_exists("res://data/natural_gift.json")
	results.weather_rocks = ItemMechanics.held_kind(GameData.ITEMS.item_icy_rock)
	setter.encore_move = ""
	results.empty_encore = PendingItems.move_allowed(setter,"tackle")
	setter.pp.struggle = 0
	var fallback_messages: Array[String] = []
	results.struggle = MoveEffects.can_act(setter,"struggle",game.rng,fallback_messages)
	var passed := true
	for value in results.values():
		if not value: passed = false
	results.passed = passed
	var report_path := OS.get_environment("APRICORN_ITEM_TEST_REPORT")
	if report_path == "": report_path = "user://item_release_check.json"
	var file := FileAccess.open(report_path,FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(results,"  "))
		file.close()
	print("PACKED ITEM CHECK: "+JSON.stringify(results))
	game.get_tree().quit(0 if passed else 1)
