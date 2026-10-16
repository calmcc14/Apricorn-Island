"""Offline battle flags and current island evolution/ability reference, from PokeAPI."""
import csv, io, json, urllib.request, hashlib
from number_tms import rows
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def table(name):
    path=ROOT/'data/battle_sources'/f'{name}.json'
    if path.exists(): return json.loads(path.read_text(encoding='utf-8'))
    url=f'https://raw.githubusercontent.com/PokeAPI/pokeapi/master/data/v2/csv/{name}.csv'
    raw=urllib.request.urlopen(url,timeout=30).read()
    rows=list(csv.DictReader(io.StringIO(raw.decode())))
    path.write_text(json.dumps(rows,indent=2)+'\n',encoding='utf-8')
    return rows
def main():
    flags={r['id']:r['identifier'] for r in table('move_flags')}
    result={'move_flags':{},'move_ids':{r['identifier'].replace('-','_'):int(r['id']) for r in rows('moves')},'species':{},'source':'https://github.com/PokeAPI/pokeapi/tree/master/data/v2/csv'}
    for r in table('move_flag_map'): result['move_flags'].setdefault(r['move_id'],[]).append(flags[r['move_flag_id']])
    species=table('pokemon_species')
    by_id={r['id']:r for r in species}
    evolves={r['evolves_from_species_id'] for r in species if r['evolves_from_species_id']}
    abilities={r['id']:r['identifier'] for r in table('abilities')}
    pokes={r['identifier']:r for r in table('pokemon')}
    slots=table('pokemon_abilities')
    for name in json.loads((ROOT/'data/battle_reference.json').read_text())['species']:
        row=pokes[name]; sid=row['species_id']
        result['species'][name]={'can_evolve':sid in evolves,'abilities':{('hidden' if a['is_hidden']=='1' else a['slot']):abilities[a['ability_id']] for a in slots if a['pokemon_id']==row['id']}}
    (ROOT/'data/item_runtime_reference.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print('Item flags and species eligibility reference ready.')
if __name__=='__main__': main()
