"""Apply reviewed effects whose runtime handlers are present in this update."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def apply(catalog):
    items = {i['id']: i for i in catalog['items']}
    def put(name, kind, description, **fields):
        key = 'item_' + re.sub('[^a-z0-9]+','_',name.lower()).strip('_')
        item = items.setdefault(key, dict(id=key, name=name, category='Medicine', rarity='uncommon', amount=0, fraction=0.0, source='ITEM_VERSION_REVIEW.md'))
        item.update(name=name, kind=kind, description=description, status='implemented', requirement='', **fields)
        return item
    for name, element, amount in [('Sunglasses','dark',.2),('Black Glasses','dark',.1),('Spell Tag','ghost',.2),('Metal Coat','steel',.2),('Dragon Fang','dragon',.2),('Silk Scarf','normal',.2),('Sea Incense','water',.15)]:
        put(name,'held_power',f'When held, boosts {element}-type move power by {amount:.0%}.',boost_type=element,power_boost=amount)
    cures = {'Antidote':['poison','toxic'],'Awakening':['sleep'],'Burn Heal':['burn'],'Ice Heal':['freeze'],'Paralyze Heal':['paralysis'],'Full Heal':['all'],'Full Restore':['all'], 'Blue Flute':['sleep'],'Yellow Flute':['confusion'],'Red Flute':['attracted']}
    for name, conditions in cures.items():
        put(name,'medicine','Cures '+', '.join(conditions)+(' and fully restores HP.' if name=='Full Restore' else '.'),cures=conditions,full_hp=name=='Full Restore',reusable='Flute' in name)
    for name, conditions in [('Cheri',['paralysis']),('Chesto',['sleep']),('Pecha',['poison','toxic']),('Rawst',['burn']),('Aspear',['freeze']),('Persim',['confusion']),('Lum',['all'])]:
        put(name+' Berry','cure_berry','Cures '+', '.join(conditions)+' from the bag or automatically when held.',cures=conditions)
    for name, amount in [('Ether',10),('Max Ether',-1),('Elixir',10),('Max Elixir',-1),('Leppa Berry',10),('PP Up',1),('PP Max',3)]:
        upgrade = name in ['PP Up','PP Max']
        put(name,'pp_medicine','Restores move PP.' if not upgrade else 'Raises maximum PP, up to three shared upgrades.',pp_amount=amount,all_moves='Elixir' in name,pp_upgrade=upgrade)
    for name, amount, loss in [('Energy Powder',50,[5,10]),('Energy Root',120,[10,15]),('Lightning Powder',60,[5,10]),('Lightning Root',200,[10,15])]:
        put(name,'heal',f'Restores {amount} HP and lowers friendship.',amount=amount,friendship_loss=loss)
    put('Revival Herb','revive','Revives a fainted Pokémon with full HP and lowers friendship.',fraction=1.0,friendship_loss=[15,20])
    for name, amount in [('Oran Berry',10),('Ripe Oran Berry',20)]:
        put(name,'held_berry',f'Restores {amount} HP from the bag, or automatically at half HP when held.',amount=amount,fraction=0.0,threshold=.5,flavor='')
    # Consolidate both former Exp. Share variants through the existing migration path.
    put('Exp. Share','held_exp','Held: shares half the experience pool. In the bag when enabled: party-wide experience.',exp_mode='modern')
    items.pop('item_modern_exp_share',None)
    catalog.setdefault('item_aliases',{})['item_modern_exp_share']='item_exp_share'
    for name, description in {
        'Leftovers':'Restores 1/16 maximum HP at the end of each turn; Heal Block prevents recovery.',
        'Shell Bell':'Recovers 1/8 total move damage once after the final hit; Heal Block prevents recovery.',
        'Scope Lens':'Raises critical-hit stage by one.',
        'Razor Claw':'Raises critical-hit stage by one.',
        'Expert Belt':'Boosts super-effective attack damage by 20%.',
        'Muscle Band':'Boosts physical move power by 10%.',
        'Wise Glasses':'Boosts special move power by 10%.',
        'Wide Lens':'Multiplies move accuracy by 1.1.',
        'Zoom Lens':'Multiplies move accuracy by 1.2 after the target has acted.',
        'Bright Powder':'Multiplies incoming move accuracy by 0.9, excluding one-hit knockout moves.',
        'Lax Incense':'Multiplies incoming move accuracy by 0.9, excluding one-hit knockout moves.',
        'Black Sludge':'Heals Poison-type holders by 1/16 maximum HP; damages other holders by 1/8.',
        'Big Root':'Increases eligible draining recovery by 30%.',
        'Lucky Punch':'Adds two critical-hit stages for Chansey.',
        'Leek':'Adds two critical-hit stages for Farfetch’d and Sirfetch’d.',
        'Metal Powder':'Doubles Ditto’s Defense, including after transforming.',
        'Quick Powder':'Doubles Ditto’s Speed, including after transforming.',
    }.items(): put(name,'held_effect',description)
    effects = {
        'Dark Powder':'Additional 20/256 miss chance, including one-hit knockout moves.',
        'Quick Claw':'20% chance to move first within the move priority bracket.',
        'Focus Band':'30/256 survival chance, including confusion; protects subsequent hits of the same attack.',
        'Focus Sash':'Consumed at full HP to survive an otherwise fatal hit with 1 HP.',
        'King\'s Rock':'Adds 10% flinch per hit to moves without a built-in flinch chance.',
        'Razor Fang':'Adds 10% flinch per hit to moves without a built-in flinch chance.',
        'Life Orb':'Boosts eligible damage 30%; loses 10% maximum HP after a successful attack.',
        'Choice Band':'Attack x1.5; locks the first move until withdrawal.',
        'Choice Specs':'Special Attack x1.5; locks the first move until withdrawal.',
        'Choice Scarf':'Speed x1.5; locks the first move until withdrawal.',
        'Assault Vest':'Special Defense x1.5; cannot select status moves.',
        'Eviolite':'Defense and Special Defense x1.5 for a species that can evolve.',
        'Rocky Helmet':'Contact attackers lose 1/6 of their maximum HP per hit.',
        'White Herb':'Consumed to reset negative stat stages without removing positive stages.',
        'Power Herb':'Consumed to skip eligible charging turns, not recharging turns.',
        'Weakness Policy':'Consumed after a super-effective hit to raise Attack and Sp. Atk two stages.',
        'Throat Spray':'Consumed after a sound move to raise Sp. Atk one stage.',
        'Room Service':'Consumed during Trick Room to lower Speed one stage.',
        'Air Balloon':'Ungrounded and immune to Ground damage until struck by a damaging move.',
        'Heavy-Duty Boots':'Prevents entry hazards.',
        'Protective Pads':'Protects against contact-triggered effects.',
        'Safety Goggles':'Protects against powder moves and weather damage.',
        'Covert Cloak':'Prevents additional effects of incoming damaging moves.',
        'Clear Amulet':'Prevents other Pokémon from lowering stat stages.',
        'Ability Shield':'Protects the Ability from alteration or suppression.',
        'Mental Herb':'Consumed to cure infatuation, Taunt, Encore, Torment, Disable and Heal Block.',
        'Binding Band':'Binding damage from the holder is 1/6 target maximum HP per turn.',
        'Grip Claw':'Binding moves from the holder last seven turns.',
        'Soul Dew':'Latios/Latias: Sp. Atk and Sp. Def x1.5; Psychic and Dragon power +20%.',
        'Light Ball':'Pikachu: Attack x2, Sp. Atk x4 and move power x2 together.',
        'Metronome':'Repeated successful uses of the same move gain 10% per previous use, up to +100%.',
        'Destiny Knot':'Reflects eligible infatuation to its source.',
        'Everstone':'Prevents eligible evolution. Breeding is outside this update.',
        'Soothe Bell':'Boosts eligible friendship gains by 50%.',
        'Lagging Tail':'Acts last within the move priority bracket.',
        'Full Incense':'Acts last within the move priority bracket.',
    }
    for name, description in effects.items(): put(name,'held_effect',description)
    for name, stat in [('Liechi','attack'),('Ganlon','defense'),('Salac','speed'),('Petaya','special_attack'),('Apicot','special_defense'),('Lansat','critical'),('Starf','random'),('Micle','accuracy_next'),('Custap','priority_next')]:
        put(name+' Berry','held_effect','Consumed at 25% HP (50% with Gluttony): '+stat.replace('_',' ')+'.',low_stat=stat)
    resistance = dict(Occa='fire',Passho='water',Wacan='electric',Rindo='grass',Yache='ice',Chople='fighting',Kebia='poison',Shuca='ground',Coba='flying',Payapa='psychic',Tanga='bug',Charti='rock',Kasib='ghost',Haban='dragon',Colbur='dark',Babiri='steel',Roseli='fairy',Chilan='normal')
    for name, element in resistance.items(): put(name+' Berry','held_effect','Consumed to halve one matching '+('hit, including confusion and Struggle.' if name=='Chilan' else 'super-effective hit.'),resist_type=element)
    for name in ['Jaboca','Rowap','Kee','Maranga','Enigma']:
        put(name+' Berry','held_effect','Consumed after an eligible hit: '+{'Jaboca':'physical attacker loses 1/8 max HP.','Rowap':'special attacker loses 1/8 max HP.','Kee':'Defense +1.','Maranga':'Sp. Def +1.','Enigma':'heal 25% max HP after surviving a super-effective hit.'}[name])
    for element in ['normal','fire','water','electric','grass','ice','fighting','poison','ground','flying','psychic','bug','rock','ghost','dragon','dark','steel','fairy']:
        put(element.title()+' Gem','held_effect','Consumed to boost one successful matching damaging move by 50%.',gem_type=element)
    for name, stat in [('Power Weight','hp'),('Power Bracer','attack'),('Power Belt','defense'),('Power Lens','special_attack'),('Power Band','special_defense'),('Power Anklet','speed')]:
        put(name,'held_effect','Adds 4 '+stat+' EVs per eligible defeated Pokémon; halves battle Speed.',power_stat=stat)
    for name, stat in [('HP Up','hp'),('Protein','attack'),('Iron','defense'),('Calcium','special_attack'),('Zinc','special_defense'),('Carbos','speed')]:
        put(name,'ev_medicine','Adds up to 10 '+stat+' EVs (252 per stat, 510 total).',ev_stat=stat,ev_amount=10)
    for name, stat in [('Pomeg','hp'),('Kelpsy','attack'),('Qualot','defense'),('Hondew','special_attack'),('Grepa','special_defense'),('Tamato','speed')]:
        put(name+' Berry','ev_medicine','Removes 10 '+stat+' EVs and increases friendship.',ev_stat=stat,ev_amount=-10)
    put('Bottle Cap','hyper_train','At level 50+, train a chosen stat as IV 31, preserving inherited IVs.')
    put('Gold Bottle Cap','hyper_train','At level 50+, train all eligible stats as IV 31, preserving inherited IVs.',all_stats=True)
    put('Ability Patch','ability_medicine','Changes a standard Ability to the Hidden Ability, or the Hidden Ability to the first standard slot.')
    put('Pure Incense','held_effect','Prevents new status conditions, temporary effects and all stat-stage changes; does not remove existing effects.')
    put('Cleanse Tag','held_effect','Prevents harmful status effects from being applied; preserves beneficial effects and all stat stages.')
    put('Rare Candy','candy','Raises one level, up to 100; at level 100 can trigger an eligible level-up evolution.')
    for name, species in [('Griseous Core','giratina'),('Adamant Crystal','dialga'),('Lustrous Globe','palkia')]:
        put(name,'form_item','Reusable bag item: switches '+species+' between its normal and Origin Forme.',form_species=species,reusable=True)
    for name, old, species in [('Adamant Daimond','item_adamant_orb','dialga'),('Lustrous Pearl','item_lustrous_orb','palkia')]:
        new=put(name,'held_effect','Matching species: +20% to its two matching move types; +50% while the matching Core is active.',form_species=species)
        items.pop(old,None)
        catalog.setdefault('item_aliases',{})[old]=new['id']
    put('Griseous Orb','held_effect','Giratina: maintains Origin Forme; Dragon/Ghost power +20%, or +50% while Core activation is on.')
    for name in ['Red Orb','Blue Orb']:
        put(name,'boss_orb','Reusable boss trigger, with per-copy summon power and recharge; held by its matching Pokémon, activates Primal Reversion.')
    put('Escape Rope','escape_item','Single use: leave an eligible cave encounter; unsuccessful use consumes nothing.')
    for key in ['item_honey','item_black_flute','item_white_flute']:
        items[key].update(status='awaiting_mechanics',requirement='Deferred by user: field encounters, Honey Trees and economy specifications')
    items['item_sacred_ash_ketchum']['rarity']=items['item_sacred_ash']['rarity']
    put('Sacred Ash','party_revive','Outside battle, if anyone is fainted, fully restore party HP and PP.')
    put('Sacred Ash (Ketchum)','party_revive','Outside battle, fully revive fainted party members; leave other HP and all PP unchanged.')
    # Use punctuation-safe stable IDs for these two exact approved names.
    ash=items.pop('item_sacred_ash_ketchum')
    ash['id']='item_sacred_ash_ketchum'
    items[ash['id']]=ash
    for item in items.values():
        if item.get('kind') in ['held_effect','held_power','held_exp']: item['category']='Hold items'
        if item.get('kind') in ['cure_berry','held_berry'] or item['name'].endswith(' Berry'): item['category']='Berries'
    aliases=catalog.get('item_aliases',{})
    for key in ['source_rows','key_item_ids']:
        catalog[key]=[aliases.get(i,i) for i in catalog.get(key,[])]
    catalog['items']=sorted(items.values(),key=lambda i:i['name'].casefold())
    return catalog

if __name__ == '__main__':
    path=ROOT/'data/item_catalog.json'
    path.write_text(json.dumps(apply(json.loads(path.read_text(encoding='utf-8'))),indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
