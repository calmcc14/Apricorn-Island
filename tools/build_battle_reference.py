"""Fetch public PokeAPI reference tables and build a small offline island snapshot."""
import csv
import hashlib
import io
import json
import re
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'data/battle_sources'
FILES = ['pokemon', 'pokemon_species', 'pokemon_stats', 'pokemon_types',
         'pokemon_moves', 'pokemon_evolution', 'types', 'type_efficacy',
         'move_meta', 'move_meta_stat_changes', 'move_effect_prose', 'natures']
SPECIES = ['bulbasaur', 'charmander', 'squirtle', 'caterpie', 'pidgey', 'rattata',
           'oddish', 'growlithe', 'psyduck', 'sandshrew', 'magnemite',
           'jigglypuff', 'meowth', 'onix', 'pikachu', 'eevee']

def fetch(name):
    url = f'https://raw.githubusercontent.com/PokeAPI/pokeapi/master/data/v2/csv/{name}.csv'
    raw = urllib.request.urlopen(url, timeout=60).read()
    return name, raw, list(csv.DictReader(io.StringIO(raw.decode('utf-8'))))

def main():
    DEST.mkdir(exist_ok=True)
    if all((DEST / f'{name}.json').exists() for name in FILES):
        fetched = [(name, (DEST / f'{name}.json').read_bytes(),
                    json.loads((DEST / f'{name}.json').read_text())) for name in FILES]
    else:
        with ThreadPoolExecutor(max_workers=6) as pool:
            fetched = list(pool.map(fetch, FILES))
    tables = {name: rows for name, _, rows in fetched}
    species_rows = {int(r['id']): r for r in tables['pokemon_species']}
    types = {int(r['id']): r['identifier'] for r in tables['types']}
    selected = [r for r in tables['pokemon'] if r['identifier'] in SPECIES]
    ids = {int(r['id']) for r in selected}
    manifest = {}
    for name, raw, rows in fetched:
        manifest[name] = hashlib.sha256(raw).hexdigest()
        if name in ['pokemon_moves', 'pokemon_stats', 'pokemon_types']:
            rows = [r for r in rows if int(r['pokemon_id']) in ids]
        elif name == 'pokemon':
            rows = selected
        (DEST / f'{name}.json').write_text(json.dumps(rows, indent=2)+'\n', encoding='utf-8')
    def chain(species_id):
        return int(species_rows[species_id]['evolution_chain_id'])
    moon_chains = {chain(int(r['evolved_species_id'])) for r in tables['pokemon_evolution']
                   if r['trigger_item_id'] == '81'}
    result = {'species': {}, 'type_chart': {}, 'natures': tables['natures']}
    stat_names = {1:'hp', 2:'attack', 3:'defense', 4:'special_attack', 5:'special_defense', 6:'speed'}
    for r in selected:
        pid = int(r['id'])
        sp = species_rows[int(r['species_id'])]
        stats = {stat_names[int(s['stat_id'])]: int(s['base_stat'])
                 for s in tables['pokemon_stats'] if int(s['pokemon_id']) == pid}
        compatible = sorted({int(m['move_id']) for m in tables['pokemon_moves']
                             if int(m['pokemon_id']) == pid and m['pokemon_move_method_id'] == '4'})
        result['species'][r['identifier']] = dict(stats=stats,
            types=[types[int(t['type_id'])] for t in tables['pokemon_types'] if int(t['pokemon_id']) == pid],
            base_speed=stats['speed'], base_experience=int(r['base_experience']),
            weight=int(r['weight'])/10,
            ev_yield={stat_names[int(s['stat_id'])]:int(s['effort']) for s in tables['pokemon_stats'] if int(s['pokemon_id'])==pid and int(s['effort'])>0},
            gender_rate=int(sp['gender_rate']), growth_rate=int(sp['growth_rate_id']),
            base_friendship=int(sp['base_happiness']), capture_rate=int(sp['capture_rate']),
            moon_family=chain(int(r['species_id'])) in moon_chains, compatible_moves=compatible)
    for r in tables['type_efficacy']:
        result['type_chart'].setdefault(types[int(r['damage_type_id'])], {})[types[int(r['target_type_id'])]] = int(r['damage_factor']) / 100
    (ROOT / 'data/battle_reference.json').write_text(json.dumps(result, indent=2)+'\n', encoding='utf-8')
    (DEST / 'MANIFEST.json').write_text(json.dumps(manifest, indent=2)+'\n', encoding='utf-8')
    print('Offline species, compatibility, nature and battle reference built')

if __name__ == '__main__': main()
