"""Build offline catalog and effect coverage from the user's supplied item table.

Usage: python tools/build_item_catalog.py PATH_TO_PASTED_TEXT
Key-item names are a checked-in snapshot of pokemondb.net/item/type/key.
"""
import json
import re
import sys
import unicodedata
from number_tms import apply_tms, write
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def slug(name):
    name = unicodedata.normalize('NFKD', name).encode('ascii', 'ignore').decode()
    return re.sub(r'[^a-z0-9]+', '_', name.lower()).strip('_')

def classify(name, category, description):
    text = (name + ' ' + description).lower()
    if category == 'Key items':
        return 'Key-item interactions'
    if 'material obtained' in text or 'craft' in text or 'apricorn' in text:
        return 'Crafting and economy'
    if any(s in text for s in ['sandwich', 'ingredient', 'picnic', 'cooking', 'contest', 'breeding', 'egg']):
        return 'Breeding, cooking and contests'
    if any(s in text for s in ['evol', 'form', 'nature', 'evs', 'exp.', 'level', 'teach', 'tm', 'hm']):
        return 'Progression, evolution, forms and move teaching'
    if category == 'Hold items' or any(s in text for s in ['held', 'holder', 'ability']):
        return 'Held items and abilities'
    if category in ['Medicine', 'Battle items', 'Berries', 'Pokeballs']:
        return 'Status conditions and battle stats'
    return 'Crafting and economy'

def entry(name, category, description, source):
    stage = classify(name, category, description)
    status = 'awaiting_mechanics'
    kind, amount, fraction = 'collectible', 0, 0.0
    # Only implement effects with an unambiguous, supported action.
    if name in ['Potion', 'Super Potion', 'Hyper Potion', 'Fresh Water', 'Soda Pop', 'Lemonade']:
        status, stage = 'awaiting_version_choice', 'Healing values differ between games'
    elif name in ['Revive', 'Max Revive']:
        status, kind, fraction = 'implemented', 'revive', (0.5 if name == 'Revive' else 1.0)
        stage = ''
    elif name in ['Berry Juice', 'Max Potion']:
        status, kind, amount = 'implemented', 'heal', (20 if name == 'Berry Juice' else -1)
        stage = ''
    elif name == 'Master Ball':
        status, kind, stage = 'implemented', 'ball', ''
    elif category == 'Pokeballs':
        stage = 'Capture formula, species conditions and version review'
    # Explicitly effectless entries only; blank descriptions are unknown, not effectless.
    if re.search(r'^(this item |it )?(has no effect|does nothing|has no use)[.!]?$', description, re.I):
        status, stage = 'originally_without_effect', 'Awaiting your custom effect'
    if name == 'Master Ball' or name.endswith('ium Z') or name in ['Sacred Ash', 'Gold Bottle Cap']:
        rarity = 'legendary'
    elif 'mega evolve' in description.lower() or name.endswith('ite') and category == 'Hold items' or 'Herba Mystica' in name:
        rarity = 'epic'
    elif category == 'Key items' or name in ['Max Revive', 'Max Potion', 'Ability Patch', 'Ability Capsule']:
        rarity = 'rare'
    elif category in ['Hold items', 'Battle items', 'Pokeballs'] or 'evol' in description.lower():
        rarity = 'uncommon'
    else:
        rarity = 'common'
    return dict(id='item_' + slug(name), name=name, category=category or 'Other items',
                description=description or 'Original effect needs research before implementation.',
                rarity=rarity, status=status, requirement=stage, kind=kind, amount=amount,
                fraction=fraction, source=source)

def main(path):
    items, rows = {}, []
    for line in Path(path).read_text(encoding='utf-8-sig').splitlines():
        if ' icon ' not in line:
            continue
        fields = line.split(' icon ', 1)[1].split('\t')
        assert len(fields) >= 2, line
        name, category = fields[:2]
        description = '\t'.join(fields[2:]).strip()
        row = entry(name.strip(), category.strip(), description, 'user_pasted_item_list')
        if row['id'] in items:
            assert items[row['id']]['name'] == row['name'], 'ID collision: ' + name
        else:
            items[row['id']] = row
        rows.append(row['id'])
    assert len(rows) == 1473, f'Expected 1473 source rows, got {len(rows)}'
    keys = json.loads((ROOT / 'data/key_item_names.json').read_text(encoding='utf-8'))
    key_ids = []
    for name in keys:
        row = entry(name, 'Key items', '', 'https://pokemondb.net/item/type/key')
        # Names identify the original items; per-item research remains explicitly tracked.
        row['description'] = 'Key item from the original games. Its original interaction awaits the key-item system and effect research.'
        key_ids.append(row['id'])
        if row['id'] not in items:
            items[row['id']] = row
        else:
            items[row['id']]['key_item'] = True
    result = dict(version=1, source_rows=rows, key_item_ids=key_ids,
                  items=sorted(items.values(), key=lambda x: x['name'].casefold()))
    result = apply_tms(result)
    (ROOT / 'data/item_catalog.json').write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    checklist = ['# Item effect coverage', '', 'Generated from the offline catalog. All rows are obtainable from chests.', '',
                 '| Item | ID | Status | Required system / decision |', '|---|---|---|---|']
    for item in result['items']:
        checklist.append('| {name} | {id} | {status} | {requirement} |'.format(**item).replace('\n', ' '))
    (ROOT / 'data/ITEM_COVERAGE.md').write_text('\n'.join(checklist)+'\n', encoding='utf-8')
    write(result)
    print(f'{len(rows)} source rows + {len(keys)} key rows = {len(items)} unique catalog items')

if __name__ == '__main__':
    main(sys.argv[1])
