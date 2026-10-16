"""Add only the evolution families and species required by approved item mechanics."""
import csv, io, json, urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from number_tms import rows
ROOT=Path(__file__).resolve().parents[1]
DEST=ROOT/'data/battle_sources'
def full(name):
    path=DEST/f'item_{name}.json'
    if not path.exists():
        raw=urllib.request.urlopen(f'https://raw.githubusercontent.com/PokeAPI/pokeapi/master/data/v2/csv/{name}.csv',timeout=40).read().decode()
        path.write_text(json.dumps(list(csv.DictReader(io.StringIO(raw))),indent=2)+'\n',encoding='utf-8')
    return json.loads(path.read_text(encoding='utf-8'))
def main():
    species=json.loads((DEST/'pokemon_species.json').read_text())
    by_id={r['id']:r for r in species}
    original=json.loads((ROOT/'data/battle_reference.json').read_text())
    families={r['evolution_chain_id'] for r in species if r['identifier'] in original['species']}
    special=['groudon','kyogre','giratina','dialga','palkia','latios','latias','ditto','chansey','farfetchd','sirfetchd']
    selected={r['id'] for r in species if r['evolution_chain_id'] in families or r['identifier'] in special}
    pokemon=full('pokemon'); stats=full('pokemon_stats'); ptypes=full('pokemon_types'); slots=full('pokemon_abilities')
    abilities={r['id']:r['identifier'] for r in full('abilities')}
    types={r['id']:r['identifier'] for r in json.loads((DEST/'types.json').read_text())}
    st_names={str(i+1):name for i,name in enumerate(['hp','attack','defense','special_attack','special_defense','speed'])}
    moves={r['id']:r['identifier'].replace('-','_') for r in rows('moves')}
    result={'species':{},'evolutions':[],'source':'https://github.com/PokeAPI/pokeapi/tree/master/data/v2/csv'}
    # Local learnsets are retained; new species are populated from the public API.
    selected_rows=[r for r in pokemon if r['species_id'] in selected and (r['is_default']=='1' or r['identifier'] in ['groudon-primal','kyogre-primal','giratina-origin','dialga-origin','palkia-origin','farfetchd-galar'])]
    def api(row):
        path=DEST/('item_pokemon_'+row['id']+'.json')
        if not path.exists():
            raw=urllib.request.urlopen('https://raw.githubusercontent.com/PokeAPI/api-data/master/data/api/v2/pokemon/'+row['id']+'/index.json',timeout=40).read()
            path.write_bytes(raw)
        return row,json.loads(path.read_text(encoding='utf-8'))
    for r,info in ThreadPoolExecutor(max_workers=6).map(api,selected_rows):
        key=r['identifier']; sp=by_id[r['species_id']]
        base={st_names[s['stat_id']]:int(s['base_stat']) for s in stats if s['pokemon_id']==r['id']}
        learn=[]; compatible=[]
        for move in info['moves']:
            details=[v for v in move['version_group_details'] if v['move_learn_method']['name']=='level-up']
            if details:
                latest=max(int(v['version_group']['url'].strip('/').split('/')[-1]) for v in details)
                for v in details:
                    if int(v['version_group']['url'].strip('/').split('/')[-1])==latest:
                        learn.append({'level':v['level_learned_at'],'move':move['move']['name'].replace('-','_')})
            if any(v['move_learn_method']['name']=='machine' for v in move['version_group_details']): compatible.append(int(move['move']['url'].strip('/').split('/')[-1]))
        entry=dict(stats=base,types=[types[t['type_id']] for t in ptypes if t['pokemon_id']==r['id']],base_speed=base['speed'],base_experience=int(r['base_experience'] or 50),weight=int(r['weight'])/10,gender_rate=int(sp['gender_rate']),growth_rate=int(sp['growth_rate_id']),base_friendship=int(sp['base_happiness']),capture_rate=int(sp['capture_rate']),ev_yield={st_names[s['stat_id']]:int(s['effort']) for s in stats if s['pokemon_id']==r['id'] and int(s['effort'])},compatible_moves=compatible,learnset=sorted(learn,key=lambda v:(v['level'],v['move'])),abilities={('hidden' if a['is_hidden']=='1' else a['slot']):abilities[a['ability_id']] for a in slots if a['pokemon_id']==r['id']},can_evolve=any(t['evolves_from_species_id']==r['species_id'] for t in species),dex_id=int(r['id']))
        result['species'][key]=entry
    evo=json.loads((DEST/'pokemon_evolution.json').read_text())
    for r in evo:
        if r['evolved_species_id'] in selected:
            row=dict(r); row['from']=by_id[r['evolved_species_id']]['evolves_from_species_id']; row['to']=by_id[r['evolved_species_id']]['identifier']
            row['from']=by_id[row['from']]['identifier'] if row['from'] else ''
            result['evolutions'].append(row)
    (ROOT/'data/item_species.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    def sprite(row):
        name=row['identifier']
        if name in original['species']: return
        for suffix,prefix in [('front',''),('back','back/')]:
            path=ROOT/'assets/sprites'/f'{name}_{suffix}.png'
            if not path.exists():
                try: path.write_bytes(urllib.request.urlopen(f'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/{prefix}{row["id"]}.png',timeout=30).read())
                except Exception: pass # Existing vector creature renderer remains available.
    list(ThreadPoolExecutor(max_workers=6).map(sprite,selected_rows))
    print(f'{len(result["species"])} item-dependent species and forms prepared.')
if __name__=='__main__': main()
