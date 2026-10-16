"""Update completed implementation notes without changing approval decisions."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
path = ROOT/'data/ITEM_VERSION_REVIEW.md'
text = path.read_text(encoding='utf-8')
replacements = {
    '## Review when their systems are added':'## Approved effects — implemented',
    'Capture implementation remains pending; Master Ball\'s guaranteed capture is already supported.':'Capture implementation is complete; Master Ball retains guaranteed capture.',
    'Capture implementation remains pending.':'Capture implementation is complete.',
    'Friendship and capture implementation remain pending.':'Friendship and capture implementation are complete.',
    'Catalog variants, inventory migration, fishing and capture implementation remain pending.':'Catalog variants, inventory migration, fishing and capture implementation are complete.',
    'Catalog addition and capture implementation remain pending.':'Catalog addition and capture implementation are complete.',
    'Capture, gender data and relevant edge-case implementation remain pending.':'Capture, gender data and edge-case implementation are complete.',
    'Evolution-family data and capture implementation remain pending.':'Evolution-family data and capture implementation are complete.',
    'Move teaching and species compatibility remain pending.':'Move teaching and species compatibility are implemented.',
    'HM/TR catalog renumbering and migration remain pending.':'HM/TR catalog renumbering and migration are implemented.',
    'Progression, exact formula verification and gameplay implementation remain pending.':'Progression and sharing are implemented, with separate selectable generation formulas.',
    'Catalog variants, save migration and healing implementation remain pending.':'Catalog variants, save migration and held healing are implemented.',
    'Catalog variants, save migration, held activation, flavor/nature and confusion implementation remain pending.':'Catalog variants, save migration, held activation, nature/flavor and confusion are implemented.',
    'Catalog additions, held effects and save migration remain pending; bag-use rules remain separate.':'Catalog additions, held effects and save migration are implemented; bag-use rules remain separate.',
    'Catalog variants, save migration and battle stat implementation remain pending.':'Catalog variants, save migration and battle stats are implemented.',
    'exact original-game edge cases remain to be verified before implementation':'independent original-game failure and immunity conditions have been checked',
    'Catalog variants, save migration and battle accuracy implementation remain pending.':'Catalog variants, save migration and battle accuracy are implemented.',
    'Windows executable rebuild remains pending.':'Windows build: ApricornIslandItems.exe.',
    'reserved for the planned spinoff DLC list (not created yet)':'reserved in the separate spinoff DLC manifest',
    'DLC list creation, Entree Forest encounters and capture effects remain pending.':'The DLC manifest and conditional capture handler are implemented. The playable Entree Forest DLC remains reserved.'
}
for old, new in replacements.items(): text = text.replace(old,new)
if '[Approved implementation report]' not in text:
    text = text.replace('# Item version choices', '# Item version choices\n\n[Approved implementation report](APPROVED_IMPLEMENTATION.md) — updated Windows build, save migration and validation.',1)
path.write_text(text,encoding='utf-8')
path = ROOT/'README.md'
text = path.read_text(encoding='utf-8')
text = text.replace('The latest Windows game is available as `ApricornIslandInventory.exe`', 'The latest Windows game is available as `ApricornIslandItems.exe`')
text = text.replace('Current source catalog: 1,820 items plus six legacy supplies.', 'Current source catalog: 1,847 items plus six legacy supplies. Approved capture balls, held berries, battle boosts, experience sharing and machine teaching are implemented. See `data/APPROVED_IMPLEMENTATION.md` for details and validation.')
path.write_text(text,encoding='utf-8')
