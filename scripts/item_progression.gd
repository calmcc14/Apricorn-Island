class_name ItemProgression
extends RefCounted

static var reference: Dictionary = {}
const FORMS := {"giratina":"giratina-origin","dialga":"dialga-origin","palkia":"palkia-origin","groudon":"groudon-primal","kyogre":"kyogre-primal"}
const CORES := {"item_griseous_core":"giratina","item_adamant_crystal":"dialga","item_lustrous_globe":"palkia"}

static func data() -> Dictionary:
	if reference.is_empty(): reference = JSON.parse_string(FileAccess.get_file_as_string("res://data/item_species.json"))
	return reference

static func info(name: String) -> Dictionary:
	var key := "giratina-altered" if name == "giratina" else name
	return data().species.get(key,{})

static func extend_species(original: Dictionary) -> Dictionary:
	var result := original.duplicate(true)
	for key in data().species:
		var name: String = "giratina" if key == "giratina-altered" else str(key)
		if result.has(name) or str(key).ends_with("-origin") or str(key).ends_with("-primal"): continue
		var row: Dictionary = data().species[key]
		var moves: Array = []
		for entry in row.learnset:
			if int(entry.level) <= 5 and GameData.MOVES.has(entry.move) and entry.move not in moves: moves.append(entry.move)
		if moves.is_empty(): moves = ["tackle"]
		while moves.size() > 4: moves.pop_front()
		result[name] = {"name":name.replace("-"," ").capitalize(),"type":str(row.types[0]),"max_hp":40+int(row.stats.hp)/2,"attack":8+int(row.stats.attack)/8,"defense":8+int(row.stats.defense)/8,"color":"#869dc2","accent":"#e3ddc2","moves":moves}
	return result

static func form(pokemon: Dictionary, in_battle: bool) -> void:
	var name := str(pokemon.species)
	var id := PendingItems.held(pokemon)
	var active: bool = pokemon.get("core_active",false) and name in ["giratina","dialga","palkia"]
	if name == "giratina" and str(pokemon.get("held_item","")) == "item_griseous_orb": active = true
	if in_battle and ((name == "groudon" and id == "item_red_orb") or (name == "kyogre" and id == "item_blue_orb")): active = true
	var next := str(FORMS.get(name,name)) if active else name
	var previous: Dictionary = pokemon.get("form_bonuses",{})
	var base: Dictionary = info(name).get("stats",{})
	var target: Dictionary = info(next).get("stats",base)
	for stat in ItemMechanics.IV_STATS:
		var stat_key: String = "max_hp" if stat == "hp" else str(stat)
		var current := int(pokemon.get(stat_key,10))-int(previous.get(stat,0))
		var ratio := float(target.get(stat,1))/maxf(1,float(base.get(stat,1))) if active else 1.0
		var bonus := int(current*(ratio-1.0))
		pokemon[stat_key] = maxi(1,current+bonus)
		if stat == "hp" and int(pokemon.hp) > 0: pokemon.hp = clampi(int(pokemon.hp)+bonus-int(previous.get(stat,0)),1,int(pokemon.max_hp))
		previous[stat] = bonus
	pokemon.form_bonuses = previous
	pokemon.form = next

static func use_core(item_id: String, pokemon: Dictionary) -> bool:
	if CORES.get(item_id,"") != pokemon.species: return false
	pokemon.core_active = not pokemon.get("core_active",false)
	form(pokemon,false)
	return true

static func orb_power(pokemon: Dictionary, move_type: String) -> float:
	var id := PendingItems.held(pokemon)
	var eligible: bool = (id == "item_griseous_orb" and pokemon.species == "giratina" and move_type in ["dragon","ghost"]) or (id == "item_adamant_daimond" and pokemon.species == "dialga" and move_type in ["dragon","steel"]) or (id == "item_lustrous_pearl" and pokemon.species == "palkia" and move_type in ["dragon","water"])
	return (1.5 if pokemon.get("core_active",false) else 1.2) if eligible else 1.0

static func evolution(pokemon: Dictionary, context: Dictionary = {}) -> String:
	if PendingItems.held(pokemon) == "item_everstone": return ""
	var hour := int(context.get("hour",Time.get_time_dict_from_system().hour))
	for row in data().evolutions:
		if row.from != pokemon.species or int(row.evolution_trigger_id) != 1 or not GameData.SPECIES.has(row.to): continue
		# Do not silently replace location, item, affection or special-action requirements.
		var unsupported := false
		for key in ["location_id","trigger_item_id","held_item_id","minimum_beauty","minimum_affection","party_species_id","party_type_id","trade_species_id","known_move_type_id","used_move_id","minimum_steps","minimum_damage_taken","nature_bitmask","condition_expression","required_pokemon_form_id"]:
			if str(row.get(key,"")) != "": unsupported = true
		for key in ["needs_overworld_rain","turn_upside_down","needs_multiplayer","near_special_rock"]:
			if int(row.get(key,0)) != 0: unsupported = true
		if unsupported: continue
		if str(row.minimum_level) != "" and int(pokemon.level) < int(row.minimum_level): continue
		if str(row.minimum_happiness) != "" and int(pokemon.get("friendship",70)) < int(row.minimum_happiness): continue
		if row.time_of_day == "day" and (hour < 6 or hour >= 18): continue
		if row.time_of_day == "night" and hour >= 6 and hour < 18: continue
		if str(row.gender_id) != "" and pokemon.get("gender","") != ("female" if int(row.gender_id) == 1 else "male"): continue
		if str(row.known_move_id) != "": continue
		return str(row.to)
	return ""

static func evolve(pokemon: Dictionary, target: String) -> bool:
	if target == "" or not GameData.SPECIES.has(target): return false
	var old: Dictionary = info(str(pokemon.species)).get("stats",{})
	var next: Dictionary = info(target).get("stats",{})
	for stat in ItemMechanics.IV_STATS:
		var key: String = "max_hp" if stat == "hp" else str(stat)
		var before := int(pokemon.get(key,10))
		var after := maxi(1,int(before*float(next.get(stat,1))/maxf(1,float(old.get(stat,1)))))
		pokemon[key] = after
		if stat == "hp" and int(pokemon.hp) > 0: pokemon.hp = maxi(1,int(pokemon.hp)+after-before)
	pokemon.species = target
	pokemon.erase("pending_evolution")
	var abilities: Dictionary = info(target).get("abilities",{})
	pokemon.ability = str(abilities.get(str(pokemon.get("ability_slot","1")),abilities.get("1","")))
	return true

static func candy(pokemon: Dictionary, apply_effect: bool) -> bool:
	var target := evolution(pokemon)
	if int(pokemon.level) >= 100:
		if target == "": return false
		return evolve(pokemon,target) if apply_effect else true
	if apply_effect:
		var growth := int(ItemMechanics.species(pokemon).get("growth_rate",2))
		ItemMechanics.grant_experience(pokemon,ItemMechanics.experience_at(int(pokemon.level)+1,growth)-int(pokemon.experience))
		evolve(pokemon,evolution(pokemon))
	return true

static func level_moves(pokemon: Dictionary, old_level: int, new_level: int) -> void:
	if not pokemon.has("pending_moves"): pokemon.pending_moves = []
	for entry in info(str(pokemon.species)).get("learnset",[]):
		var move := str(entry.move)
		if int(entry.level) <= old_level or int(entry.level) > new_level or not GameData.MOVES.has(move) or move in pokemon.moves or move in pokemon.pending_moves: continue
		if pokemon.moves.size() < 4:
			pokemon.moves.append(move)
			pokemon.pp[move] = int(GameData.MOVES[move].get("pp",35))
		else: pokemon.pending_moves.append(move)
