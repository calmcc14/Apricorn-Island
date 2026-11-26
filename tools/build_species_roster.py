"""Build the playable National Dex from the data already in this project."""

import json
from collections import defaultdict
from pathlib import Path


DATA = Path(__file__).resolve().parents[1] / "data"
STAT_NAMES = ("hp", "attack", "defense", "special_attack", "special_defense", "speed")
DISPLAY_NAMES = {
    "nidoran-f": "Nidoran ♀", "nidoran-m": "Nidoran ♂", "farfetchd": "Farfetch’d",
    "sirfetchd": "Sirfetch’d", "mr-mime": "Mr. Mime", "mr-rime": "Mr. Rime",
    "mime-jr": "Mime Jr.", "ho-oh": "Ho-Oh", "porygon-z": "Porygon-Z",
    "type-null": "Type: Null", "flabebe": "Flabébé", "jangmo-o": "Jangmo-o",
    "hakamo-o": "Hakamo-o", "kommo-o": "Kommo-o", "wo-chien": "Wo-Chien",
    "chien-pao": "Chien-Pao", "ting-lu": "Ting-Lu", "chi-yu": "Chi-Yu",
}
TYPE_ATTACKS = {
    "normal": "tackle", "fighting": "rock_smash", "flying": "gust",
    "poison": "poison_sting", "ground": "mud_slap", "rock": "rock_throw",
    "bug": "bug_bite", "ghost": "shadow_sneak", "steel": "metal_claw", "fire": "ember",
    "water": "water_gun", "grass": "absorb", "electric": "thunder_shock",
    "psychic": "confusion", "ice": "ice_shard", "dragon": "dragon_breath",
    "dark": "bite", "fairy": "fairy_wind",
}


def load(path):
    return json.loads((DATA / path).read_text(encoding="utf-8-sig"))


def source(name):
    return load(f"battle_sources/{name}.json")


def group(rows, key):
    result = defaultdict(list)
    for row in rows:
        result[row[key]].append(row)
    return result


def level_evolutions(species_by_id):
    conditions = (
        "gender_id", "location_id", "trigger_item_id", "held_item_id", "time_of_day",
        "known_move_id", "known_move_type_id", "minimum_happiness", "minimum_beauty",
        "minimum_affection", "relative_physical_stats", "party_species_id", "party_type_id",
        "trade_species_id", "region_id", "required_pokemon_form_id", "evolved_pokemon_form_id",
        "used_move_id", "minimum_move_count", "minimum_steps", "minimum_damage_taken",
        "nature_bitmask", "condition_expression", "percentage_chance",
    )
    flags = ("needs_overworld_rain", "turn_upside_down", "needs_multiplayer", "near_special_rock")
    result = []
    for row in source("pokemon_evolution"):
        if row["is_default"] != "1" or row["evolution_trigger_id"] != "1" or not row["minimum_level"]:
            continue
        if any(row[key] for key in conditions) or any(row[key] == "1" for key in flags):
            continue
        target = species_by_id[row["evolved_species_id"]]
        parent = species_by_id[target["evolves_from_species_id"]]
        result.append({
            "from": parent["identifier"], "to": target["identifier"],
            "evolution_trigger_id": row["evolution_trigger_id"], "minimum_level": row["minimum_level"],
        })
    return result


def main():
    species = sorted(source("pokemon_species"), key=lambda row: int(row["id"]))
    defaults = {row["species_id"]: row for row in source("item_pokemon") if row["is_default"] == "1"}
    stats = group(source("item_pokemon_stats"), "pokemon_id")
    types = group(source("item_pokemon_types"), "pokemon_id")
    slots = group(source("item_pokemon_abilities"), "pokemon_id")
    type_ids = {row["id"]: row["identifier"] for row in source("types")}
    ability_ids = {row["id"]: row["identifier"] for row in source("abilities")}
    moves = load("machine_moves.json")
    learnsets = group(source("pokemon_moves"), "pokemon_id")
    move_ids = {str(row["move_index"]): key for key, row in moves.items()}
    evolution_parents = {row["evolves_from_species_id"] for row in species}
    assert [int(row["id"]) for row in species] == list(range(1, 1026))
    assert all(moves[move]["kind"] == "damage" for move in TYPE_ATTACKS.values())
    result = {}
    for row in species:
        pokemon = defaults[row["id"]]
        pokemon_id = pokemon["id"]
        identifier = row["identifier"]
        base_stats = {STAT_NAMES[int(stat["stat_id"]) - 1]: int(stat["base_stat"]) for stat in stats[pokemon_id]}
        ev_yield = {STAT_NAMES[int(stat["stat_id"]) - 1]: int(stat["effort"]) for stat in stats[pokemon_id] if int(stat["effort"])}
        pokemon_types = [type_ids[entry["type_id"]] for entry in sorted(types[pokemon_id], key=lambda entry: int(entry["slot"]))]
        attacks = list(dict.fromkeys(TYPE_ATTACKS[kind] for kind in pokemon_types))
        if len(attacks) == 1:
            attacks.append("bite" if attacks[0] == "tackle" else "tackle")
        level_up = [entry for entry in learnsets[pokemon_id] if entry["pokemon_move_method_id"] == "1" and entry["move_id"] in move_ids]
        if level_up:
            version = max(int(entry["version_group_id"]) for entry in level_up)
            learnset = [{"level": int(entry["level"]), "move": move_ids[entry["move_id"]]} for entry in level_up if int(entry["version_group_id"]) == version]
            learnset.sort(key=lambda entry: entry["level"])
        else:
            learnset = [{"level": 1, "move": move} for move in attacks]
        result[identifier] = {
            "name": DISPLAY_NAMES.get(identifier, identifier.replace("-", " ").title()),
            "dex_id": int(row["id"]), "stats": base_stats, "types": pokemon_types,
            "base_speed": base_stats["speed"], "base_experience": int(pokemon["base_experience"] or 50),
            "weight": int(pokemon["weight"]) / 10, "gender_rate": int(row["gender_rate"]),
            "growth_rate": int(row["growth_rate_id"]), "base_friendship": int(row["base_happiness"]),
            "capture_rate": int(row["capture_rate"]), "ev_yield": ev_yield, "learnset": learnset,
            "can_evolve": row["id"] in evolution_parents,
            "compatible_moves": sorted({int(entry["move_id"]) for entry in learnsets[pokemon_id] if entry["pokemon_move_method_id"] == "4"}),
            "abilities": {"hidden" if entry["is_hidden"] == "1" else entry["slot"]: ability_ids[entry["ability_id"]] for entry in slots[pokemon_id]},
        }
    evolutions = level_evolutions({row["id"]: row for row in species})
    def compact(value):
        return json.dumps(value, ensure_ascii=False, separators=(",", ":"))

    with (DATA / "species_roster.json").open("w", encoding="utf-8", newline="\n") as output:
        output.write('{\n  "species": {\n')
        output.write(",\n".join(f"    {compact(key)}: {compact(profile)}" for key, profile in result.items()))
        output.write('\n  },\n  "evolutions": [\n')
        output.write(",\n".join(f"    {compact(row)}" for row in evolutions))
        output.write('\n  ]\n}\n')
    print(f"Built {len(result)} species and {len(evolutions)} level evolutions from local data.")


if __name__ == "__main__":
    main()
