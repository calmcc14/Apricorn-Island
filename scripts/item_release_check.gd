class_name ItemReleaseCheck
extends RefCounted

static func run(game: Control) -> void:
	var results := {"packed":not OS.has_feature("editor"),"catalog":ItemCatalog.data().items.size() == 1859,"compiled_scripts":FileAccess.file_exists("res://scripts/main.gd.remap") and FileAccess.file_exists("res://scripts/pending_items.gd.remap")}
	if not game.cartridge_profile.has("active"):
		results.first_cartridge_picker = game.screen == game.Screen.CARTRIDGE and not Cartridge.version_available(game.cartridge_profile, Cartridge.YELLOW)
		game.choose_first_cartridge(Cartridge.RED)
		results.first_cartridge_picker = results.first_cartridge_picker and game.screen == game.Screen.TITLE
	results.national_dex = GameData.DEX_SPECIES.size() == 1025 and RogueRules.encounter_species().has("pecharunt")
	results.cartridges = Cartridge.has_species(Cartridge.RED,"groudon") and not Cartridge.has_species(Cartridge.BLUE,"groudon") and RogueRules.encounter_species(Cartridge.YELLOW).size() == 1026
	results.cartridge_loot = ItemCatalog.item_probability("item_blue_orb",14,Cartridge.RED) == 0.0 and ItemCatalog.item_probability("item_dreamy_ball",14,Cartridge.YELLOW) > 0.0
	results.roster_sprites = true
	results.shiny_roster_sprites = true
	results.shiny_sprite = true
	for species_id in ["pikachu", "gengar", "charizard", "pecharunt"]:
		for side in ["front", "back"]:
			var art: Image = game.load_sprite_image("shiny/%s_%s" % [species_id, side])
			var sprite: Texture2D = game.pokemon_sprite({"species":species_id,"shiny":true}, side == "back")
			results.shiny_sprite = results.shiny_sprite and art != null and sprite.get_image().get_data() == art.get_data()
	for species_id in GameData.DEX_SPECIES + ItemProgression.FORMS.values() + ["farfetchd-galar"]:
		var art_id: String = "giratina-altered" if species_id == "giratina" else species_id
		for side in ["front", "back"]:
			var path := "res://assets/sprites/%s_%s.png" % [art_id, side]
			if not ResourceLoader.exists(path) or game.pokemon_sprite({"species": species_id}, side == "back") == null:
				results.roster_sprites = false
				push_error("Missing packaged Pokémon sprite at " + path)
			var shiny_path := "res://assets/sprites/shiny/%s_%s.png" % [art_id, side]
			if not ResourceLoader.exists(shiny_path):
				results.shiny_roster_sprites = false
				push_error("Missing packaged shiny Pokémon sprite at " + shiny_path)
	if game.cartridge == Cartridge.YELLOW:
		results.yellow_sprites = game.species_sprite("pikachu").get_image().get_data() != game.load_sprite_image("pikachu_front").get_data()
	var is_blue: bool = game.cartridge == Cartridge.BLUE
	var orb := "item_blue_orb" if is_blue else "item_red_orb"
	var primal := "kyogre-primal" if is_blue else "groudon-primal"
	game.start_endless("bulbasaur")
	game.state.inventory[orb] = 1
	game.state.inventory.item_master_ball = 1
	game.start_orb_boss(orb,0)
	results.boss_started = game.battle.has("orb_item")
	if results.boss_started:
		var boss: Dictionary = game.battle.enemies[0]
		results.form = boss.form == primal
		results.artwork = ResourceLoader.exists("res://assets/sprites/%s_front.png" % primal) and game.pokemon_sprite(boss) == game.species_sprite(primal, false, bool(boss.get("shiny", false)))
		var hp := int(boss.boss_normal_hp)
		var messages: Array[String] = []
		game.resolve_ball_action({"actor":0,"target":0,"ball":"item_master_ball"},messages)
		results.capture_hp = game.state.party[-1].max_hp == hp
		results.no_duplicate_orb = game.state.party[-1].held_item == ""
		game.finish_victory()
		game.continue_endless()
		results.saved_orb = game.state.orb_instances[orb][0].held_only
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
	results.glitch_audio = true
	var track_lengths := {"glitch_ambient":48,"glitch_interference":48,"glitch_battle":40}
	for track in track_lengths:
		var stream := game.sfx.loop_wav(track) as AudioStreamWAV
		results.glitch_audio = results.glitch_audio and stream.loop_end == int(track_lengths[track]) * stream.mix_rate
	var ocean := load(RetroAudio.OCEAN_TRACK) as AudioStreamOggVorbis
	var ambient := game.sfx.load_ocean() as AudioStream
	results.glitch_ocean = ocean != null and ocean.get_length() > 0.0 and ambient != null and bool(ambient.get("loop"))
	game.state.run.depth = 5
	game.state.current_node = "run_5"
	game.show_map()
	game.enter_glitch()
	game.tune_glitch_signal("kalos:65535")
	game.start_glitch_battle()
	results.glitch_dimension = game.battle.get("glitch",false) and game.battle.enemies[0].has("glitch_shape")
	results.glitch_signals = GameData.pokemon_name(game.battle.enemies[0]) == "Glitch #65535" and game.GlitchDimension.Signals.find(1,"").size() == 137
	results.glitch_loot = game.item_definition("glitch_heal_overflow").amount > GameData.ITEMS.super_potion.amount
	game.open_debug()
	game.leave_glitch(true)
	results.glitch_debug_exit = not game.in_glitch() and game.state.current_node == "run_5" and not game.state.has("battle_checkpoint") and not game.state.get("glitch_completed",false)
	game.open_debug()
	game.enter_glitch(true)
	results.glitch_debug_travel = game.in_glitch() and int(game.state.glitch_dimension.floor) == 1
	var reference_checks := {"rb_000":"glitch_m_reference","y_000":"glitch_trainer_reference","rb_191":"glitch_pointer_a_reference","y_191":"glitch_four_four_reference","rb_192":"glitch_a_reference","y_192":"glitch_four_four_hy_reference","rb_193":"glitch_u_c1_reference","y_193":"glitch_female_dot_reference"}
	var pokedollar: String = game.GlitchDimension.Signals.POKEDOLLAR
	results.glitch_pokedollar = game.theme.default_font.has_char(pokedollar.unicode_at(0)) and GameData.pokemon_name({"glitch_signal":"y_000"}).ends_with(pokedollar)
	game.show_glitch_profile("rb_000",4)
	var cart_labels: Array[Node] = game.ui.find_children("*","Label",true,false)
	results.glitch_cartridge_details = cart_labels.any(func(label): return label.text == "Catch rate  3  ·  Base Exp.  Unknown")
	game.show_glitch_profile("y_000",4)
	cart_labels = game.ui.find_children("*","Label",true,false)
	results.glitch_cartridge_details = results.glitch_cartridge_details and cart_labels.any(func(label): return label.text == "Catch rate  4  ·  Base Exp.  Unknown")
	for id in reference_checks:
		game.show_glitch_profile(id,3)
		var back: TextureRect = game.ui.find_child("BackReferenceSprite",true,false)
		var menu: TextureRect = game.ui.find_child("MenuReferenceSprite",true,false)
		var back_size := Vector2(56,63) if id == "rb_192" else Vector2(56,56)
		results[reference_checks[id]] = back != null and menu != null and back.texture.get_size() == back_size and menu.texture.get_size() == Vector2(16,16)
	results.glitch_c2_c3_references = true
	var alternate_counts := {"rb_194":0,"y_194":0,"rb_195":1,"y_195":2}
	for id in alternate_counts:
		game.show_glitch_profile(id,3)
		var sprites: Array[Node] = game.ui.find_children("*ReferenceSprite","TextureRect",true,false)
		results.glitch_c2_c3_references = results.glitch_c2_c3_references and sprites.size() == 3 + int(alternate_counts[id]) and sprites.all(func(sprite): return sprite.texture != null)
	for code in ["0xC2","0xC3"]:
		results.glitch_c2_c3_references = results.glitch_c2_c3_references and game.GlitchDimension.Signals.find(1,code).size() == 2
	var archive = game.GlitchDimension.Signals
	results.glitch_imported_references = true
	for index in range(196,256):
		for prefix in ["rb","y"]:
			var imported_record: Dictionary = archive.get_entry("%s_%03d" % [prefix,index])
			var imported_profile: Dictionary = imported_record.get("profile",{})
			var art_root: String = game.GlitchArt.ASSET_DIR
			results.glitch_imported_references = results.glitch_imported_references and imported_profile.has("reference") and ResourceLoader.exists(art_root + str(imported_profile.get("sprite",""))) and ResourceLoader.exists(art_root + str(imported_profile.get("dex_image","")))
	for id in ["gs_00","crystal_ff","hoenn:540","sinnoh:33261","unova:653","unova_alt:687","kalos:65535","later_egg"]:
		results.glitch_imported_references = results.glitch_imported_references and archive.get_entry(id).has("profile")
	results.glitch_imported_references = results.glitch_imported_references and archive.find(5,"UFO").is_empty()
	game.show_glitch_profile("missingno_yellow")
	results.glitch_profiles = game.screen == game.Screen.GLITCH_PROFILE and game.GlitchDimension.Signals.find(1,"missingno").size() == 5
	game.show_glitch_profile("missingno_yellow",4)
	var missingno_labels: Array[Node] = game.ui.find_children("*","Label",true,false)
	results.glitch_missingno_reference = missingno_labels.any(func(label): return label.text == "Exp. at Lv. 100  16,136,684") and game.GlitchDimension.Signals.find(1,"0x1F").size() == 2
	game.tune_glitch_signal("missingno_yellow")
	game.start_glitch_battle()
	results.glitch_profiles = results.glitch_profiles and ItemMechanics.species(game.battle.enemies[0]).types == ["normal","999"]
	results.glitch_attachment_art = true
	var profile_art = game.GlitchArt
	var catalog = game.GlitchDimension.Signals
	var name_strip_heights := {"y_191":12,"rb_194":9}
	for id in ["rb_000","y_000","rb_191","y_191","rb_192","y_192","rb_193","y_193","rb_194","y_194","rb_195","y_195","missingno","missingno_ghost","missingno_wing","missingno_shell","missingno_yellow"]:
		var profile: Dictionary = catalog.get_entry(id).profile
		var sprite := profile_art.profile_sprite(profile) as AtlasTexture
		var scan := load(profile_art.ASSET_DIR + str(profile.dex_image)) as Texture2D
		var atlas_rect := Rect2(Vector2.ZERO,sprite.atlas.get_size())
		results.glitch_attachment_art = results.glitch_attachment_art and atlas_rect.encloses(sprite.region) and scan.get_size() == Vector2(160,144)
		if profile.has("name_image"):
			var strip := load(profile_art.ASSET_DIR + str(profile.name_image)) as Texture2D
			results.glitch_attachment_art = results.glitch_attachment_art and strip.get_height() == int(name_strip_heights.get(id,8))
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
