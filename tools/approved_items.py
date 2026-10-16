"""Apply only the effects approved in ITEM_VERSION_REVIEW.md."""
import re
from number_tms import rows

def apply_approved(catalog):
    items = {i['id']: i for i in catalog['items']}
    def put(name, kind, description, item_id=None, **fields):
        item_id = item_id or 'item_' + re.sub('[^a-z0-9]+', '_', name.lower()).strip('_')
        category = {'heal':'Medicine','ball':'Pokeballs','held_berry':'Berries','battle_boost':'Battle items','machine':'Machines','held_exp':'Hold items','exp_mode':'Key items'}[kind]
        rarity = 'common' if kind in ['held_berry','machine'] else ('rare' if kind=='exp_mode' else 'uncommon')
        item = items.setdefault(item_id, dict(id=item_id, name=name, category=category,
            rarity=rarity, amount=0, fraction=0.0, source='Approved island variants'))
        item['category'] = category
        item.update(name=name, kind=kind, description=description, status='implemented', requirement='', **fields)
        return item
    balls = {
        'Quick Ball':'5× on turn one; 1× otherwise.', 'Dusk Ball':'3× at night or in caves; 1× otherwise.',
        'Timer Ball':'1× plus 0.3× per completed turn, capped at 4× after ten turns.',
        'Net Ball':'3× against Water or Bug types; 1× otherwise.',
        'Repeat Ball':'3× against a species registered as caught; 1× otherwise.',
        'Dream Ball':'4× against sleeping targets; 1× otherwise.',
        'Friend Ball':'1× capture power; sets a successful catch’s friendship to 200.',
        'Dive Ball':'3.5× against targets in/on water or Water types; bonuses do not stack.',
        'Fest Ball':'4× against Magnemite, Grimer or Tangela; 1× otherwise.',
        'Fast Ball':'4× against species with base Speed at least 100; 1× otherwise.',
        'Love Ball':'8× against the same species and opposite gender to the acting Pokémon; 1× otherwise.',
        'Moon Ball':'4× against any member of a Moon Stone evolution family; 1× otherwise.'}
    for name, description in balls.items(): put(name, 'ball', description, bonus=0.20)
    for name, fishing, water in [('Clean',5,4),('Worn',4,3.5),('Dirty',3,3.5)]:
        put(name+' Lure Ball', 'ball', f'{fishing}× when fishing, otherwise {water}× in/on water, otherwise 1×.',
            fishing_multiplier=fishing, water_multiplier=water, bonus=0.20)
    aliases = catalog.setdefault('item_aliases', {})
    if 'item_lure_ball' in items:
        del items['item_lure_ball']
        aliases['item_lure_ball'] = 'item_dirty_lure_ball'
    for berry, flavor in [('Sitrus',''),('Figy','spicy'),('Wiki','dry'),('Mago','sweet'),('Aguav','bitter'),('Iapapa','sour')]:
        for prefix, fraction, threshold in [('Expired ',0.125,0.5),('',1/3,0.25),('Ripe ',0.5,0.25)]:
            amount = 30 if berry == 'Sitrus' and prefix == 'Expired ' else 0
            if berry == 'Sitrus' and not prefix: fraction = 0.25
            if amount: fraction = 0
            healing = f'{amount} HP' if amount else f'{fraction:.2%} maximum HP'
            desc = f'When held, restores {healing} at {threshold:.0%} HP or lower. Consumed only when activated.'
            if flavor: desc += f' Causes confusion if the holder dislikes {flavor} flavor.'
            put(prefix+berry+' Berry', 'held_berry', desc, fraction=fraction, threshold=threshold, amount=amount, flavor=flavor)
    for name, stat in [('Attack','attack'),('Defense','defense'),('Sp. Atk','special_attack'),('Sp. Def','special_defense'),('Speed','speed'),('Accuracy','accuracy')]:
        for letter, stages in [('X',2),('Y',1)]:
            put(letter+' '+name, 'battle_boost', f'Raises {name} by {stages} stages during battle (maximum +6).',
                stat=stat, stages=stages)
    put('Z Accuracy','battle_boost','Bypasses accuracy checks for this battle; other failure and immunity rules still apply.',stat='accuracy',stages=0,bypass=True)
    put('Classic Exp. Share','held_exp','Held: splits experience evenly between living participants (half) and living holders (half).', item_id='item_exp_share')
    put('Modern Exp. Share','exp_mode','Toggle party-wide sharing: full experience for participants and half for nonparticipants. Does not stack with other sharing modes.',exp_mode='modern')
    put('Exp. All','exp_mode','Generation I sharing: half divided among participants; one participant’s share divided among all party slots, including lost fainted shares.',exp_mode='all')
    # Approved healing variants use the shared bag/battle healing handler.
    for name, amount in [('Classic Super Potion',50),('Super Potion',60),
                         ('Classic Hyper Potion',200),('Hyper Potion',120),
                         ('Fresh Water',30),('Freshest Water',50),
                         ('Dr. Pepper',200),('Coca Cola',60),('Pepsi',60),
                         ('Unbranded soda',50),('Lemonade',80)]:
        item = put(name, 'heal', f'Restores {amount} HP to a conscious Pokémon.', amount=amount, fraction=0.0)
        item['rarity'] = 'legendary' if name == 'Dr. Pepper' else 'uncommon'
    # Preserve the old 50-HP soda tier and every saved stack/layout through aliases.
    items.pop('item_soda_pop', None)
    aliases['item_soda_pop'] = 'item_unbranded_soda'
    # Machine numbering is independent within each family, using the existing TM snapshot.
    source_items = {int(r['id']):r['identifier'] for r in rows('items')}
    moves = {int(r['id']):r for r in rows('moves')}
    names = {int(r['move_id']):r['name'] for r in rows('move_names') if r['local_language_id']=='9'}
    for family in ['hm','tr']:
        taught = {int(r['move_id']) for r in rows('machines') if re.fullmatch(family+r'\d+', source_items[int(r['item_id'])])}
        ordered = sorted(taught, key=lambda m:(int(moves[m]['generation_id']),m))
        for item_id in list(items):
            if re.fullmatch('item_'+family+r'\d+', item_id):
                if 'machine_family' not in items[item_id]:
                    old = int(item_id[len('item_'+family):])
                    # Preserve the original machine's taught move, not its renamed number.
                    originals = [r for r in rows('machines') if source_items[int(r['item_id'])] == family+f'{old:02d}']
                    if originals:
                        move = int(max(originals,key=lambda r:int(r['version_group_id']))['move_id'])
                        aliases[item_id] = f'item_{family}{ordered.index(move)+1:03d}'
                del items[item_id]
        for n, mid in enumerate(ordered,1):
            put(f'{family.upper()}{n:03d} — {names[mid]}','machine',f'Teaches {names[mid]} to compatible Pokémon. '+('Reusable.' if family=='hm' else 'Consumed after successful teaching.'),
                item_id=f'item_{family}{n:03d}',machine_family=family, move_index=mid,
                move_id=moves[mid]['identifier'].replace('-','_'),consumable=family!='hm')
        catalog[family+'_count'] = len(ordered)
    for item in items.values():
        if 'tm_number' in item:
            item.update(kind='machine',status='implemented',requirement='',machine_family='tm',consumable=True,
                move_id=item['move_id'].replace('-','_'),description=f'Teaches {names[int(item["move_index"])]} to compatible Pokémon. Consumed after successful teaching.')
    catalog['items'] = sorted(items.values(), key=lambda i:i['name'].casefold())
    catalog['source_rows'] = [aliases.get(i,i) for i in catalog['source_rows']]
    catalog['key_item_ids'] = [aliases.get(i,i) for i in catalog['key_item_ids']]
    return catalog
