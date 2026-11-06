"""Reproducible offline data additions for the existing battle rules.

Berry values: PokeAPI berries.csv, checked 2026-11-06. Its original
60/70/80 table is retained; the resolver adds 20 for Unnatural Gift.
"""
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def main():
    items = {int(r['id']): r['identifier'] for r in csv.DictReader((ROOT/'data/tm_sources/items.csv').open(encoding='utf-8'))}
    types = {int(r['id']): r['identifier'] for r in json.loads((ROOT/'data/battle_sources/types.json').read_text(encoding='utf-8'))}
    type_ids = [10,11,13,12,15,2,4,5,3,14,7,6,8,16,17,9,10,11,13,12,15,2,4,5,3,14,7,6,8,16,17,9,10,11,13,10,11,13,12,15,2,4,5,3,14,7,6,8,16,17,9,1,12,15,2,4,5,3,14,7,6,8,16,17]
    berries = {}
    for index, type_id in enumerate(type_ids):
        number = index + 1
        power = 60 if number <= 16 or 36 <= number <= 52 else (70 if number <= 32 else 80)
        berries['item_'+items[126+index].replace('-','_')] = dict(type=types[type_id],power=power)
    berries['item_roseli_berry'] = dict(type='fairy',power=80)
    berries['item_kee_berry'] = dict(type='fairy',power=80)
    berries['item_maranga_berry'] = dict(type='dark',power=80)
    path = ROOT/'data/natural_gift.json'
    path.write_text(json.dumps(berries,indent=2)+'\n',encoding='utf-8')
    path = ROOT/'data/item_catalog.json'
    catalog = json.loads(path.read_text(encoding='utf-8'))
    for row in catalog['items']:
        if row['id'] in ['item_damp_rock','item_heat_rock','item_smooth_rock','item_icy_rock']:
            row.update(kind='held_effect',status='implemented',requirement='',description='When held by the weather setter, extends its matching ordinary weather from 5 to 8 turns. Reusable.')
    path.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

if __name__ == '__main__':
    main()
