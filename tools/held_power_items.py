"""Apply approved type-power held item variants without changing existing IDs."""
import json
from pathlib import Path

VARIANTS = [('Coal', 'fire', .1), ('Charcoal', 'fire', .2),
            ('Magic Water', 'water', .1), ('Mystic Water', 'water', .2),
            ('Miracle Seed', 'grass', .1), ('Miraculous Seed', 'grass', .2),
            ('Magnet', 'electric', .1), ('Magnetite', 'electric', .2),
            ('Ice', 'ice', .1), ('Never-Melt Ice', 'ice', .2),
            ('White Belt', 'fighting', .1), ('Black Belt', 'fighting', .2),
            ('Poison Spike', 'poison', .1), ('Poison Barb', 'poison', .2),
            ('Hard Sand', 'ground', .1), ('Soft Sand', 'ground', .2),
            ('Dull Beak', 'flying', .1), ('Sharp Beak', 'flying', .2),
            ('Bent Fork', 'psychic', .1), ('Twisted Spoon', 'psychic', .2),
            ('White Powder', 'bug', .1), ('Silver Powder', 'bug', .2),
            ('Soft Stone', 'rock', .1), ('Hard Stone', 'rock', .2)]

def apply_held_power(catalog):
    potion = next(i for i in catalog['items'] if i['id'] == 'item_potion')
    potion.update(status='implemented', requirement='', kind='heal', amount=20,
                  description='Restores 20 HP to a conscious Pokémon.')
    for name, move_type, boost in VARIANTS:
        item_id = 'item_' + name.lower().replace('-', '_').replace(' ', '_')
        item = next((i for i in catalog['items'] if i['id'] == item_id), None)
        if item is None:
            item = dict(id=item_id, name=name, category='Hold items', rarity='uncommon',
                        amount=0, fraction=0.0, source='Approved island item variants')
            catalog['items'].append(item)
        item.update(description=f'When held, boosts {move_type.capitalize()}-type move power by {boost:.0%}.',
                    status='implemented', requirement='', kind='held_power',
                    boost_type=move_type, power_boost=boost)
    catalog['items'].sort(key=lambda i: i['name'].casefold())
    return catalog

if __name__ == '__main__':
    from number_tms import write
    path = Path(__file__).resolve().parents[1] / 'data/item_catalog.json'
    write(apply_held_power(json.loads(path.read_text(encoding='utf-8'))))
