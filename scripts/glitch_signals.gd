extends RefCounted

const DATA_PATH := "res://data/glitch_signals.json"
const REFERENCE_PATH := "res://data/glitch_reference.json"
const POKEDOLLAR := "\uE000"
const FEATURED := [
	"missingno", "rb_000", "y_000", "gs_unown", "gs_egg", "hoenn_bad_egg",
	"sinnoh:32768", "unova:653", "unova_alt:708", "kalos:724", "alola_egg",
	"missingno_ghost", "missingno_wing", "missingno_shell", "missingno_yellow",
]
static var named: Dictionary = {}
static var ranges: Dictionary = {}
static var family_profiles: Dictionary = {}

static func load_catalog() -> void:
	if not named.is_empty(): return
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	for row in source.named:
		named[row[0]] = entry(str(row[0]),int(row[1]),int(row[2]),str(row[3]),str(row[4]))
	for row in source.red_blue_yellow:
		var index := int(row[0])
		var red_id := "rb_%03d" % index
		var yellow_id := "y_%03d" % index
		named[red_id] = entry(red_id,1,int(row[1]),str(row[3]),"Red / Blue",index)
		named[yellow_id] = entry(yellow_id,1,int(row[2]),str(row[4]),"Yellow",index)
	for row in source.ranges:
		ranges[row[0]] = row
	var imported: Variant = JSON.parse_string(FileAccess.get_file_as_string(REFERENCE_PATH))
	var additions: Dictionary = {}
	if imported is Dictionary:
		additions = imported.profiles
		for id in imported.profiles:
			if not named.has(id) or source.profiles.has(id): continue
			var profile: Dictionary = imported.profiles[id]
			named[id].profile = profile
			if profile.has("index"): named[id].index = int(profile.index)
		family_profiles = imported.families
	for id in source.profiles:
		var profile: Dictionary = source.profiles[id]
		profile.merge(additions.get(id,{}))
		if str(id).begins_with("missingno"):
			var cartridge: Dictionary = source.missingno_cartridge.duplicate()
			cartridge.merge(profile.cartridge,true)
			var special_form := profile.has("index")
			cartridge.indices = [int(profile.index)] if special_form else cartridge.normal_indices.map(func(index): return int(index))
			if not special_form: cartridge.time_capsule_equivalent = cartridge.normal_time_capsule
			profile.cartridge = cartridge
		named[id].profile = profile
		if profile.has("index"): named[id].index = int(profile.index)

static func entry(id: String, generation: int, number: int, label: String, version: String, index := -1) -> Dictionary:
	return {"id":id,"generation":generation,"number":number,"name":label,"version":version,"index":index}

static func get_entry(id: String) -> Dictionary:
	if id.is_empty(): return {}
	load_catalog()
	if named.has(id): return named[id]
	var parts := id.split(":",false,1)
	if parts.size() != 2 or not ranges.has(parts[0]) or not parts[1].is_valid_int(): return {}
	var group: Array = ranges[parts[0]]
	var number := int(parts[1])
	if number < int(group[2]) or number > int(group[3]): return {}
	var label := str(group[4])
	if group.size() > 5: label += " " + str(group[5])[number - int(group[2])]
	elif parts[0] in ["sinnoh","kalos"]: label = ("Hybrid" if parts[0] == "sinnoh" else "Glitch") + " #%d" % number
	var record := entry("%s:%d" % [parts[0],number],int(group[1]),number,label,"")
	if family_profiles.has(parts[0]): record.profile = family_profiles[parts[0]]
	return record

static func find(generation: int, query: String) -> Array:
	load_catalog()
	var results: Array = []
	var search := query.strip_edges().to_lower()
	var name_search := search.replace(POKEDOLLAR,"$").replace("₽","$")
	var digits := search.trim_prefix("#")
	var hexadecimal := digits.begins_with("0x") and digits.is_valid_hex_number(true)
	var number := -1
	if digits.is_valid_int(): number = int(digits)
	elif hexadecimal: number = digits.hex_to_int()
	for record in named.values():
		if generation > 0 and record.generation != generation: continue
		var name := str(record.name).to_lower().replace(POKEDOLLAR,"$")
		var name_match: bool = search.is_empty() or name.contains(name_search) or str(record.version).to_lower().contains(search)
		if record.has("profile") and not name_match:
			var aliases: Array = record.profile.get("aliases",[])
			name_match = aliases.any(func(alias): return str(alias).to_lower() == name_search)
			if record.profile.has("cartridge"):
				var cartridge: Dictionary = record.profile.cartridge
				name_match = name_match or str(cartridge.get("romanized_name","")).to_lower() == search or str(cartridge.get("japanese_name","")) == search
		var listed_index := false
		if number >= 0 and record.has("profile"):
			var cartridge: Dictionary = record.profile.get("cartridge",{})
			listed_index = number in cartridge.get("indices",[])
		if name_match or (number >= 0 and (record.index == number or listed_index or (not hexadecimal and record.number == number))):
			results.append(record)
	for key in ranges:
		var group: Array = ranges[key]
		if generation > 0 and int(group[1]) != generation: continue
		var first := int(group[2])
		var last := int(group[3])
		if number >= first and number <= last:
			results.append(get_entry("%s:%d" % [key,number]))
		elif number < 0 and last - first < 32:
			for variant in range(first,last + 1):
				var record := get_entry("%s:%d" % [key,variant])
				if search.is_empty() or str(record.name).to_lower().contains(search): results.append(record)
		elif number < 0 and (search.is_empty() or str(group[4]).to_lower().contains(search)):
			var preview := get_entry("%s:%d" % [key,first])
			preview.name = group[4]
			preview.version = "#%d–#%d · enter a number" % [first,last]
			results.append(preview)
	return results

static func details(record: Dictionary, compact := false) -> String:
	var generation := int(record.generation)
	var parts := PackedStringArray(["Gen %d" % generation if generation > 0 else "Unnumbered entry"])
	if int(record.number) >= 0: parts.append("Dex #%03d" % int(record.number))
	if int(record.index) >= 0:
		parts.append("0x%02X" % record.index if compact else "Index %03d / %02X" % [record.index,record.index])
	if not str(record.version).is_empty(): parts.append(record.version)
	return " · ".join(parts)

static func for_floor(floor_number: int, slot: int, random: RandomNumberGenerator) -> String:
	load_catalog()
	var featured_index := int(floor_number / 2.0) - 1
	if slot == 0 and featured_index >= 0 and featured_index < FEATURED.size():
		return FEATURED[featured_index]
	if random.randi_range(0,5) == 0:
		var keys := ranges.keys()
		var key: String = keys[random.randi_range(0,keys.size() - 1)]
		var group: Array = ranges[key]
		return "%s:%d" % [key,random.randi_range(int(group[2]),int(group[3]))]
	var ids := named.keys()
	return ids[random.randi_range(0,ids.size() - 1)]
