# Approved item update — October 15, 2026

Windows release: `ApricornIsland.exe`, updated in place with the Windows Desktop preset. The separate ABS engine distribution is unchanged.

## Scope

Implemented the explicitly reviewed non-breeding item groups. Breeding is excluded at the user's request. Honey, Black Flute and White Flute remain pending at the user's request because field encounters, Honey Trees and economy specifications are not yet established. Unreviewed catalog/version/custom-effect decisions are unchanged. Enigma's e-Reader compatibility remains reserved for the DLC.

Latest Cleanse Tag correction: **prevent harmful statuses from being applied**, rather than waiting to cure them. Beneficial effects and both positive and negative stat stages are preserved. Pure Incense separately prevents new conditions, temporary effects and all stat-stage changes without clearing existing conditions or blocking HP damage/recovery.

## Implemented groups

| Group | Gameplay |
|---|---|
| Remaining type boosters | Sunglasses, Black Glasses, Spell Tag, Metal Coat, Dragon Fang, Silk Scarf and Sea Incense; Silk Scarf also boosts confusion self-damage. |
| Medicines and PP | Major-status cures, Full Heal/Restore, bitter Energy/Lightning medicines, Revival Herb, curing berries, Oran/Ripe Oran, reusable curing flutes, Ether/Elixir families, Leppa, PP Up/Max. Bag PP use selects the move; failed uses consume nothing; PP upgrades share the three-use cap and are field-only. |
| Experience | One Exp. Share, with held sharing or an enabled bag mode. Old Modern stacks, held IDs and stored layouts migrate to the single ID. Exp. All remains distinct. |
| Held battle items | Healing, critical stages, accuracy, Quick Claw, Focus Band/Sash, flinch items, Life Orb, Expert Belt, physical/special boosters, Choice locks, Assault Vest, Eviolite, Rocky Helmet and Big Root. |
| Berries and Herbs | Approved low-HP stat/accuracy/order berries, all 17 resistance berries plus the custom Chilan coverage, reactive berries, Enigma, White/Power/Mental Herbs, Weakness Policy, Throat Spray and Room Service. |
| Protections | Air Balloon, Heavy-Duty Boots, Protective Pads, Safety Goggles, Covert Cloak, Clear Amulet, Ability Shield, Pure Incense and the corrected Cleanse Tag. |
| Other held effects | Binding Band/Grip Claw, all type Gems at +50%, combined Soul Dew and Light Ball, Metronome's +10% streak capped at +100%, Lucky Punch/Leek, Ditto's custom Powders, Lagging Tail/Full Incense, Soothe Bell, Everstone and Destiny Knot's battle effect. |
| Progression | Six Power items (+4 EVs and half Speed), six vitamins and six EV-reducing berries with 252/510 caps, level-50 Hyper Training preserving inherited IVs, Ability Patch's reversible slots, Rare Candy and supported level-up evolutions/learning. Pending move replacement and evolution choices are accessible from Party. |
| Sacred Ash | Separate regular and Ketchum effects. Ketchum is excluded from ordinary loot pools and replaces a regular Ash award with exactly a 1-in-100 roll; the reward receipt and chest transfer use the resulting item. |
| Forms | Reusable Griseous Core/Adamant Crystal/Lustrous Globe; held Griseous Orb; Adamant Daimond/Lustrous Pearl with old Orb ID migration. Matching +50% Core-active boosts replace +20%. Red/Blue Orb Primal forms are battle-only. |
| Boss orbs | Per-copy persistent state, Primal Groudon/Kyogre encounters, distinct boss music and backgrounds, encounter-only 1.5x HP, normal caught HP, capture during battle, five-island-level KO recharge, retry after loss, and held-only state after capture. Additional copies start at 10%, gain +1 point per cleared island level, get recurring 45% chances for +10 after each five unused levels, lose 1 point per failed summon and 5 after losing a battle, clamp to 0–100%, and preserve the 100%-summon retry exception. |
| Escape Rope | Single-use escape from an eligible cave encounter; unavailable outside caves and in item-triggered boss battles. |

An orb use attempt resets its unused-level counter. New additional copies start their counter at acquisition; loading never resets it. Orb states remain separate from stack counts, with held copies assigned persistent IDs; bag access excludes held copies and copies beyond the bag quantity. Existing chest storage snapshots are not counted twice.

The battle loop now sorts both teams together by priority, held-item ordering and Speed, including Trick Room. Quick Claw is rolled once per actor per round; priority brackets remain intact. Existing encounter rosters and difficulty settings are retained. Added species, form data and sprites support the approved dependent mechanics; the original random encounter pool is unchanged.

The game continues to use its established simplified battle damage scale and permanent expedition upgrades. Item mechanics operate against supported moves, conditions, abilities and evolution requirements; this does not claim a complete recreation of every original-game ability or special evolution subsystem. Unsupported location, special-action, trade, affection and other evolution gates are not silently waived. No breeding system was built.

## Validation

- `run_pending_items.gd`: cures, PP limits, failed uses, held stats, berries, survival, EV caps, Hyper Training, Ash variants, ability slots, migration and ordering.
- `run_item_systems.gd`: forms, replacement boosts, Rare Candy/Everstone, successful/failed Gems, Power Herb, hazards, real boss capture, normal caught HP, per-copy meters, recharge and save round trips.
- `run_approved_items.gd`: existing approved balls, berries, boosts, experience, machines, save rollback, DLC isolation and every imported move runtime path. Its old three-Pokémon fixture now explicitly creates the three Pokémon after choosing a starter.
- `run_items.gd`: complete catalog coverage, probability totals, seeded loot, chest paths, migration, item use and full inventory. Counts updated for the new catalog and the fixture explicitly selects a starter.
- Existing healing, battle, held-power, IV and level checks are run against the current source.
- Visual screenshots cover orb inventory and both Primal boss encounters. Packed release verification uses the `--verify-items` diagnostic startup mode, with explicit checks that remain active in release builds and a JSON result report.

Known older-test issue: `run_balance.gd` fails its basic-attacks-only summit win-rate threshold. A comparison using the old player-first ordering also fails that same threshold (1/100 wins); difficulty was not silently retuned. Older integration/endless fixtures that call the starter-selection entry point without selecting a starter are stale; the focused current-startup integration checks above cover this release's affected systems.

## References

Approved exact effects: `ITEM_VERSION_REVIEW.md`. Offline move flags, species eligibility, evolution and form data: [PokeAPI CSV reference](https://github.com/PokeAPI/pokeapi/tree/master/data/v2/csv), [API data mirror](https://github.com/PokeAPI/api-data). Sprites: [PokeAPI sprites](https://github.com/PokeAPI/sprites). Runtime references are checked in and need no network connection.


Final release verification: nine source suites passed, and all packed executable checks passed (boss startup/form/artwork, capture HP, item/PP use and saved orb state). Exactly one main root executable is present. Windows Desktop export keeps its console wrapper disabled and excludes the ABS distributions. The exporter logged an editor safe-save warning; the packed game was independently verified.

Release SHA-256: `30010D274C143449F3AE918096E3545DD5D26F06ECEF38BBFD186E51C7C6190A`.

