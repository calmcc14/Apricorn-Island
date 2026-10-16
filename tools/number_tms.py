"""Apply chronological TM labels from the checked-in PokeAPI CSV snapshot."""
import csv
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def rows(name):
    with (ROOT / 'data/tm_sources' / (name + '.csv')).open(encoding='utf-8') as source:
        return list(csv.DictReader(source))

def apply_tms(catalog):
    items = {int(row['id']): row['identifier'] for row in rows('items')}
    moves = {int(row['id']): row for row in rows('moves')}
    names = {int(row['move_id']): row['name'] for row in rows('move_names')
             if row['local_language_id'] == '9'}
    taught = {int(row['move_id']) for row in rows('machines')
              if re.fullmatch(r'tm\d+', items[int(row['item_id'])])}
    ordered = sorted(taught, key=lambda move: (int(moves[move]['generation_id']), move))
    aliases = dict(catalog.get('tm_aliases', {}))
    for item in catalog['items']:
        if 'tm_number' not in item and re.fullmatch(r'item_tm\d+', item['id']):
            number = int(item['id'][7:])
            # TM00 becomes TM001; padded/unpadded duplicates share one stack.
            aliases[item['id']] = f'item_tm{max(1, number):03d}'
    catalog['items'] = [item for item in catalog['items']
                        if not re.fullmatch(r'item_tm\d+', item['id'])]
    for number, move in enumerate(ordered, 1):
        catalog['items'].append(dict(
            id=f'item_tm{number:03d}', name=f'TM{number:03d} — {names[move]}',
            category='Machines', description=f'Teaches {names[move]}. Move introduced in generation {moves[move]["generation_id"]}. Move teaching is awaiting implementation.',
            rarity='common', status='awaiting_mechanics',
            requirement='Move teaching and compatibility; consumption rule still undecided',
            kind='collectible', amount=0, fraction=0.0,
            source='PokeAPI CSV snapshot; chronological island TM numbering',
            move_id=moves[move]['identifier'], move_index=move,
            debut_generation=int(moves[move]['generation_id']), tm_number=number))
    catalog['tm_aliases'] = aliases
    catalog['tm_count'] = len(ordered)
    catalog['source_rows'] = [aliases.get(item, item) for item in catalog['source_rows']]
    catalog['items'].sort(key=lambda item: item['name'].casefold())
    return catalog

def write(catalog):

    from held_power_items import apply_held_power
    catalog = apply_held_power(catalog)
    from approved_items import apply_approved
    catalog = apply_approved(catalog)
    from implement_pending_items import apply as apply_pending
    catalog = apply_pending(catalog)
    (ROOT / 'data/item_catalog.json').write_text(json.dumps(catalog, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    checklist = ['# Item effect coverage', '', 'Generated from the offline catalog. All rows are obtainable from chests.', '',
                 '| Item | ID | Status | Required system / decision |', '|---|---|---|---|']
    for item in catalog['items']:
        checklist.append('| {name} | {id} | {status} | {requirement} |'.format(**item).replace('\n', ' '))
    (ROOT / 'data/ITEM_COVERAGE.md').write_text('\n'.join(checklist)+'\n', encoding='utf-8')

if __name__ == '__main__':
    catalog = apply_tms(json.loads((ROOT / 'data/item_catalog.json').read_text(encoding='utf-8')))
    write(catalog)
    print(f'{catalog["tm_count"]} chronological TMs; {len(catalog["items"])} catalog items')
