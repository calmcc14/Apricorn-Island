class_name Cartridge
extends RefCounted

const RED := "red"
const BLUE := "blue"
const YELLOW := "yellow"
const VERSIONS := [RED, BLUE, YELLOW]
const COLORS := {RED: Color("#a83f42"), BLUE: Color("#28649a"), YELLOW: Color("#805b13")}
const PROFILE_PATH := "user://apricorn_cartridge.json"
const ISLAND_PATH := "user://apricorn_island_save.json"
const ENDLESS_PATH := "user://apricorn_endless_save.json"
const STORY_ALTERNATES := {
	"caterpie":"weedle", "oddish":"bellsprout", "growlithe":"vulpix",
	"sandshrew":"ekans", "psyduck":"slowpoke",
}

static var species_sides: Dictionary = {}
static var item_sides: Dictionary = {}

static func load_exclusives() -> void:
	if not species_sides.is_empty(): return
	var data: Dictionary = read_dictionary("res://data/cartridge_exclusives.json")
	# Original pairings take precedence over later games that swapped sides.
	for pair in data.species:
		for side in [RED, BLUE]:
			for id in pair[side]:
				if not species_sides.has(id): species_sides[id] = side
	for side in [RED, BLUE]:
		for id in data.items[side]: item_sides[id] = side

static func has_species(version: String, id: String) -> bool:
	if version not in [RED, BLUE]: return true
	load_exclusives()
	return species_sides.get(id, version) == version

static func has_item(version: String, id: String) -> bool:
	if version not in [RED, BLUE]: return true
	load_exclusives()
	return item_sides.get(id, version) == version

static func story_species(version: String, species: Array) -> Array:
	var result: Array = []
	for id in species:
		if has_species(version, id): result.append(id)
		else: result.append(STORY_ALTERNATES[id])
	return result

static func version_name(version: String) -> String:
	return version.capitalize() + " Version"

static func initial_profile() -> Dictionary:
	var profile := read_dictionary(PROFILE_PATH)
	if profile.get("original") not in VERSIONS: return {}
	if not profile.get("yellow_unlocked", false):
		for version in VERSIONS:
			if read_dictionary(save_path(version, str(profile.original), false)).get("finished", false):
				unlock_yellow(profile)
				break
	if not version_available(profile, str(profile.get("active", ""))): profile.erase("active")
	return profile

static func version_available(profile: Dictionary, version: String) -> bool:
	if version in [RED, BLUE]: return true
	if version != YELLOW: return false
	if profile.get("yellow_unlocked", false): return true
	# Keep access to expeditions started before Yellow became an unlock.
	var original := str(profile.get("original", ""))
	return original in VERSIONS and (
		FileAccess.file_exists(save_path(YELLOW, original, false))
		or FileAccess.file_exists(save_path(YELLOW, original, true))
	)

static func unlock_yellow(profile: Dictionary) -> bool:
	if profile.get("yellow_unlocked", false): return true
	var updated := profile.duplicate()
	updated.yellow_unlocked = true
	if not write_dictionary(PROFILE_PATH, updated): return false
	profile.yellow_unlocked = true
	return true

static func save_path(version: String, original: String, endless: bool) -> String:
	var path := ENDLESS_PATH if endless else ISLAND_PATH
	if version == original: return path
	return path.get_basename() + "_" + version + ".json"

static func read_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file: return {}
	var value: Variant = JSON.parse_string(file.get_as_text())
	return value if value is Dictionary else {}

static func write_dictionary(path: String, value: Dictionary) -> bool:
	var temporary := "%s.%d.%d.tmp" % [path, OS.get_process_id(), Time.get_ticks_usec()]
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if not file: return false
	file.store_string(JSON.stringify(value, "  "))
	file.flush()
	var error := file.get_error()
	file.close()
	if error == OK and DirAccess.rename_absolute(temporary, path) == OK: return true
	DirAccess.remove_absolute(temporary)
	return false
