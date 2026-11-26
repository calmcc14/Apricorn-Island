class_name ItemCatalog
extends RefCounted

const VERSION := 1
const TIERS := ["common", "uncommon", "rare", "epic", "legendary"]
static var catalog: Dictionary = {}
static var pools: Dictionary = {}
static var cartridge_pools: Dictionary = {}

static func data() -> Dictionary:
	if catalog.is_empty():
		catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/item_catalog.json"))
	return catalog

static func build(legacy: Dictionary) -> Dictionary:
	var result := legacy.duplicate(true)
	for id in result:
		result[id].merge({"id":id,"category":"Island supplies","rarity":"common","status":"implemented","requirement":"","fraction":0.0}, false)
	for item in data().items:
		result[str(item.id)] = item
	return result

static func tier_odds(depth: int) -> Array:
	var first := [0.60, 0.25, 0.10, 0.04, 0.01]
	var middle := [0.40, 0.30, 0.18, 0.09, 0.03]
	var last := [0.25, 0.30, 0.25, 0.15, 0.05]
	var d := clampi(depth, 0, 100)
	var from: Array = first if d <= 50 else middle
	var to: Array = middle if d <= 50 else last
	var t := float(d if d <= 50 else d - 50) / 50.0
	var result: Array = []
	for i in TIERS.size(): result.append(lerpf(from[i], to[i], t))
	return result

static func tier_pools(version := "") -> Dictionary:
	if pools.is_empty():
		for tier in TIERS: pools[tier] = []
		for item in data().items:
			if item.id != "item_sacred_ash_ketchum": pools[str(item.rarity)].append(str(item.id))
		for tier in TIERS: pools[tier].sort()
	if version == "": return pools
	if not cartridge_pools.has(version):
		var available := {}
		for tier in TIERS:
			available[tier] = pools[tier].filter(func(id): return Cartridge.has_item(version, id))
		if version == Cartridge.YELLOW:
			available.common.append("star_berry")
			var extras := Cartridge.read_dictionary("res://data/spinoff_dlc_items.json")
			for item in extras.items.values(): available[item.rarity].append(item.id)
		cartridge_pools[version] = available
	return cartridge_pools[version]

static func item_probability(id: String, depth: int, version := "") -> float:
	if id == "item_sacred_ash_ketchum": return item_probability("item_sacred_ash",depth,version)/99.0
	for i in TIERS.size():
		var pool: Array = tier_pools(version)[TIERS[i]]
		if id in pool: return float(tier_odds(depth)[i]) / pool.size() * (0.99 if id == "item_sacred_ash" else 1.0)
	return 0.0

static func chest_rewards(seed_value: int, chest_id: String, depth: int, supplies: Dictionary, version := "") -> Dictionary:
	# Stable hash independent of Godot's Dictionary ordering and global battle RNG.
	var stable_seed := seed_value
	for c in chest_id.to_utf8_buffer(): stable_seed = (stable_seed * 31 + c) & 0x7fffffff
	var random := RandomNumberGenerator.new()
	random.seed = stable_seed
	var rewards := supplies.duplicate(true)
	var odds := tier_odds(depth)
	for roll in 3:
		var value := random.randf()
		var index := TIERS.size() - 1
		var total := 0.0
		for i in TIERS.size():
			total += float(odds[i])
			if value < total:
				index = i
				break
		var pool: Array = tier_pools(version)[TIERS[index]]
		var id := str(pool[random.randi_range(0, pool.size() - 1)])
		rewards[id] = int(rewards.get(id, 0)) + 1
	return rewards

static func migrate(save: Dictionary) -> void:
	save.catalog_version = VERSION
	BossOrbs.initialize(save)
	var aliases: Dictionary = data().get("tm_aliases", {})
	aliases = aliases.duplicate()
	aliases.merge(data().get("item_aliases",{}),true)
	var inventory := {}
	for id in save.get("inventory", {}):
		var target: String = str(aliases.get(id, id))
		if str(id).begins_with("item_tm") and str(id).substr(7).is_valid_int():
			var number := maxi(1, int(str(id).substr(7)))
			if number <= int(data().get("tm_count", 0)): target = "item_tm%03d" % number
		inventory[target] = int(inventory.get(target, 0)) + int(save.inventory[id])
	save.inventory = inventory
	# JSON decodes numbers as floats; keep stack counts as integers on every load.
	for id in save.get("inventory", {}): save.inventory[id] = int(save.inventory[id])
	if not save.has("opened_chests"): save.opened_chests = []
	if not save.has("loot_seed"): save.loot_seed = 173689
	if not save.has("chest_rewards"): save.chest_rewards = {}
	for rewards in save.chest_rewards.values():
		var migrated := {}
		for id in rewards:
			var target := str(aliases.get(id,id))
			migrated[target] = int(migrated.get(target,0))+int(rewards[id])
		rewards.clear()
		rewards.merge(migrated)
	if not save.has("caught_species"):
		save.caught_species = []
		for pokemon in save.get("reserve",[]):
			if pokemon.species not in save.caught_species: save.caught_species.append(pokemon.species)
	if not save.has("exp_mode"): save.exp_mode = "classic"
	for pokemon in save.get("party", []) + save.get("reserve", []):
		ItemMechanics.initialize(pokemon)
		pokemon.held_item = str(aliases.get(str(pokemon.held_item),str(pokemon.held_item)))
		if pokemon.get("species","") != "" and pokemon.species not in save.caught_species: save.caught_species.append(pokemon.species)
	for key in ["chest_storage"]:
		if save.has(key): save[key] = migrate_counts(save[key],aliases)
	for id in save.get("chest_stores",{}): save.chest_stores[id] = migrate_counts(save.chest_stores[id],aliases)
	for key in ["inventory_slots","chest_slots"]:
		for stack in save.get(key,[]):
			if not stack.is_empty(): stack.id = str(aliases.get(str(stack.id),str(stack.id)))
	for layout in save.get("chest_layouts",{}).values():
		for stack in layout:
			if not stack.is_empty(): stack.id = str(aliases.get(str(stack.id),str(stack.id)))

static func migrate_counts(counts: Dictionary, aliases: Dictionary) -> Dictionary:
	var result := {}
	for id in counts:
		var target := str(aliases.get(str(id),str(id)))
		result[target] = int(result.get(target,0))+int(counts[id])
	return result

static func can_apply(item: Dictionary, pokemon: Dictionary) -> bool:
	if item.get("status", "") != "implemented": return false
	if item.kind in ["medicine","cure_berry"]: return PendingItems.cure(item,pokemon,false)
	if item.kind == "pp_medicine":
		for move in pokemon.get("moves",[]):
			if PendingItems.pp_use(item,pokemon,move,false): return true
		return false
	if item.kind == "held_berry": return int(pokemon.hp) > 0 and int(pokemon.hp) < int(pokemon.max_hp) and str(item.id) in ["item_oran_berry","item_ripe_oran_berry"]
	if item.kind == "heal": return int(pokemon.hp) > 0 and int(pokemon.hp) < int(pokemon.max_hp)
	if item.kind == "revive": return int(pokemon.hp) == 0
	if item.kind == "battle_boost": return ItemMechanics.can_boost(item,pokemon)
	return false

static func move_power_multiplier(pokemon: Dictionary, move_type: String) -> float:
	if int(pokemon.get("embargo",0)) > 0 or pokemon.get("held_suppressed",false): return 1.0
	var id := str(pokemon.get("held_item", ""))
	if id == "": return 1.0
	for item in data().items:
		if str(item.id) == id and item.get("kind", "") == "held_power" and item.get("boost_type", "") == move_type:
			return (1.0 + float(item.get("power_boost", 0.0)))*ItemProgression.orb_power(pokemon,move_type)
	return ItemProgression.orb_power(pokemon,move_type)

static func apply(item: Dictionary, pokemon: Dictionary) -> bool:
	if not can_apply(item, pokemon): return false
	if item.kind in ["medicine","cure_berry"]: return PendingItems.cure(item,pokemon,true)
	if item.kind == "pp_medicine": return false # A move must be explicitly selected by the caller.
	if item.kind == "battle_boost": return ItemMechanics.boost(item,pokemon)
	PendingItems.friendship_loss(item,pokemon)
	if item.kind == "revive":
		pokemon.hp = maxi(1, int(float(pokemon.max_hp) * float(item.fraction)))
		pokemon.status_condition = ""
		for key in ["confusion_turns","sleep_turns","toxic_turns"]: pokemon.erase(key)
	else:
		pokemon.hp = int(pokemon.max_hp) if int(item.amount) < 0 else mini(int(pokemon.max_hp), int(pokemon.hp) + int(item.amount))
	return true

static func status_text(item: Dictionary) -> String:
	match str(item.get("status", "")):
		"implemented": return "Usable now" if item.kind != "treasure" else "Island keepsake"
		"awaiting_version_choice": return "Awaiting your game-version choice"
		"originally_without_effect": return "Awaiting your custom effect"
	return "Awaiting system: " + str(item.get("requirement", "Original effect research"))
