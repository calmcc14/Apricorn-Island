"""Compile the checked-in machine moves and their effect metadata for offline use."""
import json
from pathlib import Path
from number_tms import rows

ROOT = Path(__file__).resolve().parents[1]

def main():
    catalog = json.loads((ROOT/'data/item_catalog.json').read_text(encoding='utf-8'))
    wanted = {int(i['move_index']) for i in catalog['items'] if i['kind']=='machine'}
    dependent = {'transform','struggle','gastro-acid','worry-seed','simple-beam','entrainment','role-play','geomancy','disable','heal-block','rapid-spin','leech-seed'}
    wanted.update(int(r['id']) for r in rows('moves') if r['identifier'] in dependent)
    species = json.loads((ROOT/'data/item_species.json').read_text())['species']
    learned = {m['move'] for s in species.values() for m in s['learnset']}
    learned.update(['tackle','scratch','ember','vine_whip','razor_leaf','growl','bubble','gust','absorb','rock_throw','thunder_shock','quick_attack','water_gun','bite'])
    wanted.update(int(r['id']) for r in rows('moves') if r['identifier'].replace('-','_') in learned)
    def source(name): return json.loads((ROOT/f'data/battle_sources/{name}.json').read_text())
    meta = {int(r['move_id']):r for r in source('move_meta')}
    prose = {int(r['move_effect_id']):r['short_effect'] for r in source('move_effect_prose') if r['local_language_id']=='9'}
    types = {int(r['id']):r['identifier'] for r in source('types')}
    names = {int(r['move_id']):r['name'] for r in rows('move_names') if r['local_language_id']=='9'}
    changes = source('move_meta_stat_changes')
    stat_names = {2:'attack',3:'defense',4:'special_attack',5:'special_defense',6:'speed',7:'accuracy',8:'evasion'}
    result = {}
    for r in rows('moves'):
        mid = int(r['id'])
        if mid not in wanted: continue
        effect = int(r['effect_id'] or 0)
        m = meta.get(mid,{})
        fields = {k:int(m.get(k) or 0) for k in ['meta_category_id','meta_ailment_id','min_hits','max_hits','min_turns','max_turns','drain','healing','crit_rate','ailment_chance','flinch_chance','stat_chance']}
        result[r['identifier'].replace('-','_')] = dict(name=names[mid],type=types[int(r['type_id'])],
            power=int(r['power'] or 0),accuracy=int(r['accuracy'] or 100)/100,
            always_hit=not r['accuracy'], pp=int(r['pp'] or 5), priority=int(r['priority']),
            kind='damage' if int(r['damage_class_id']) != 1 else 'status',
            damage_class=int(r['damage_class_id']), target=int(r['target_id']),effect_id=effect,
            effect=prose.get(effect,'Effect requires additional reference.'),
            effect_chance=int(r['effect_chance'] or 100), move_index=mid, **fields,
            stat_changes=[dict(stat=stat_names[int(s['stat_id'])],change=int(s['change'])) for s in changes if int(s['move_id'])==mid and int(s['stat_id']) in stat_names])
    (ROOT/'data/machine_moves.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(f'{len(result)} distinct machine move definitions compiled')

if __name__=='__main__': main()
