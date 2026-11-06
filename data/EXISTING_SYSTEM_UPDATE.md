# Existing-system update — November 6, 2026

Windows release: `ApricornIsland.exe`, updated in place with Windows Desktop. ABS files remain separate and unchanged.

## Implemented

- Standard attacks use imported power, accuracy, PP, priority, category and effect metadata instead of the old island overrides. Flame Tail, Focus and Shell Rest retain their custom definitions. The offline compiler now includes existing species' level-up moves: 506 imported definitions, previously 367. This enables existing teaching paths, without claiming bespoke execution for every move.
- Saved Pokémon keep their IVs, EVs, stats and upgrades. Remaining PP is capped to corrected maxima. Ability IDs migrate from hyphens to underscores without rerolling the Ability or slot. Existing supported species data already contains reviewed modern base stats and types; these are not added as fixed increases to individual stats.
- Critical hits use approved 2× damage and stage chances 1/16, 1/8, 1/4, 1/3, 1/2. Ordinary binding uses 1/16 maximum HP; Binding Band retains 1/6 and Grip Claw seven turns.
- Actual Snow-setting events follow Snow → Hail → Hail + Snow, then refresh the combined state. Rain/Sun/Sand replace both components. Weather lasts five turns, or eight with the matching reusable held rock. All four rocks can be equipped. Snow Warning starts with Snow. Snow boosts Ice Defense; Sand boosts Rock Special Defense. Combined cold applies one Hail chip and one Snow Defense bonus.
- Grounded matching Electric/Grassy/Psychic attacks gain 40% power. Misty prevents new major status and confusion and halves Dragon damage. Electric prevents new sleep. Grassy healing and Ground-move reduction check grounding. Flying, Levitate, Air Balloon, Telekinesis and Gravity participate. Existing conditions are preserved.
- Natural Gift uses berry typing and original power. Its 15% triggered Unnatural Gift uses newer power plus 15% final damage. One attack consumes one berry; Unnatural Gift has no separate learned slot. Normalize preserves its berry type.
- Knock Off boosts damage against eligible held items and removes them; matching form orbs stay protected. Rapid Spin clears the user's hazards, binding and Leech Seed and gains one Speed stage. Leech Seed drains actual HP and heals its source; saved references use indices rather than cyclic Pokémon objects. Defog clears both hazard sides and terrain, and only opposing screens.
- Existing Ability hooks now support Sturdy, Lightning Rod/Storm Drain redirection and absorption, all-opponent Frisk, opposite-Ability Plus/Minus partners, Normalize, 30% Aerilate/Pixilate/Refrigerate, Transistor, repeated Protean/Libero, Gale Wings at any HP, Prankster's Dark immunity, Skill Link, Weak Armor, Infiltrator, Keen Eye, Oblivious, Overcoat, Intimidate protections, Rattled's Intimidate trigger, Illuminate, entry Sword/Shield boosts, and Moody without accuracy/evasion. Entry weather triggers run once in Speed order. Existing immunity, stat protection and weather hooks are extended.
- Sleep resets to its assigned counter on the existing battle/switch reset, including Rest. Existing approved paralysis, burn and confusion rules remain.
- Both teams fall back to Struggle when no move is usable. Struggle needs no PP, uses typeless damage and maximum-HP recoil. The fight menu also permits completing a charging move after spending its last PP.

## Remaining mechanics

This extends the existing resolver; it does not implement every catalog item, Ability or special move interaction. Unreviewed items receive no invented effects. Absent species/forms are not added to encounters and saved Ability slots are not rerolled.

Additional systems or interfaces are still needed for crafting/economy, Kitchen activities, breeding, contests, Honey/field interactions, unique key-item flows, Meteorite's offline per-individual energy timers, general Mega/transformation lifecycles, Pickup item ownership tracking, Disguise state, Battle Bond and chosen reserve switching for Trainer Teleport. Special move paths requiring missing mechanics remain incomplete even when their definitions load.

## Validation

The new `run_existing_rules.gd` suite passes move metadata, supported species data, weather transitions/rocks, entry triggers, grounding, terrain prevention, Sturdy, absorption, Natural Gift consumption, Leech Seed recovery/save serialization, Rapid Spin, Gale Wings and saved Ability spelling checks.

Regression suites passed: approved items (including every imported move runtime path), pending items, forms/bosses, battle mechanics, IVs, levels, customization, Pokédex and polish. The previously documented basic-attacks-only summit balance assertion still fails; type-aware teams passed all difficulty/encounter thresholds. The old Endless balance fixture now explicitly selects a starter, restores its original three-partner baseline and respects move PP. All 30 runs reached the first camp and defeated the first guardian; the longest run reached floor 50.

The packed Windows release passed checks for compiled scripts, standard move values, combined weather, weather rocks, Natural Gift data, item/PP use, Primal boss artwork/form, capture HP and saved orb state. The project root contains exactly one game executable, `ApricornIsland.exe`.

References: [PokeAPI moves](https://github.com/PokeAPI/pokeapi/blob/master/data/v2/csv/moves.csv), [PokeAPI berries](https://github.com/PokeAPI/pokeapi/blob/master/data/v2/csv/berries.csv). Custom choices remain recorded in `ITEM_VERSION_REVIEW.md`.
