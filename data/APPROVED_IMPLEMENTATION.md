# Approved item implementation — 2026-10-12

Windows build: `ApricornIslandHealing.exe`.

| Approved group | Implemented behavior |
|---|---|
| Healing variants | Classic Super Potion 50 HP; Super Potion 60 HP; Classic Hyper Potion 200 HP; Hyper Potion 120 HP; Fresh Water 30 HP; Freshest Water 50 HP; Dr. Pepper 200 HP; Coca Cola and Pepsi 60 HP each; Unbranded soda 50 HP; Lemonade 80 HP. Dr. Pepper uses the existing legendary tier. Old Soda Pop counts and layouts migrate to Unbranded soda. |
| Potion | Catalog Potion restores 20 HP; the legacy island Potion retains 25 HP. |
| Capture balls | Quick, Dusk, Timer, Net, Repeat, Dream, Friend, Dive, Fest, Fast, Love and Moon use the approved conditions. Friend sets friendship to 200. |
| Lure balls | Clean, Worn and Dirty variants use their separate fishing/water multipliers without stacking. Fishing is available at uncleared water battle locations. |
| Held berries | Expired, normal and Ripe variants for Sitrus, Figy, Wiki, Mago, Aguav and Iapapa use the approved amounts and thresholds. Flavor-dislike confusion applies only to the flavor berries. Activation consumes the held berry. |
| Battle boosts | X/Y Attack, Defense, Sp. Atk, Sp. Def, Speed and Accuracy raise the requested stages, capped at +6. Z Accuracy bypasses accuracy without bypassing independent failure or immunity conditions. |
| Type-power held items | All 24 approved 10%/20% variants boost their matching move types. |
| Experience | Classic held sharing, Modern party sharing and generation-I Exp. All are mutually exclusive modes. Generation II–V and VI–VII formula choices are available from their item details. Fainted members receive no experience; Exp. All retains the original lost-share behavior. |
| Machines | 348 chronological TMs, 11 HMs and 100 TRs. Compatibility uses the checked-in species reference, taking machine compatibility across its version groups. Players select a move to replace when all four slots are filled. Successful TM/TR teaching consumes one item; HM teaching is reusable. Failed, cancelled, duplicate, incompatible or unsuccessfully saved teaching consumes nothing. |
| Dreamy Ball | Separate spinoff DLC manifest and capture handler. Guaranteed only when the DLC encounter is explicitly marked Entree Forest. Excluded from the base catalog and every base chest pool. The playable spinoff DLC remains reserved. |

Existing inventory counts, held items, chest stores and slot layouts migrate together. Legacy Lure Ball stacks become Dirty Lure Ball, preserving the earlier 3× fishing tier. Classic Exp. Share preserves the existing `item_exp_share` ID. Original HM/TR stacks map to the move taught by their latest version in the original snapshot; subsequent migration is idempotent.

New Pokémon receive gender and nature data. Old saves retain their existing team, stats and upgrades, with neutral Hardy nature where no nature was previously stored. Endless gender and nature generation use a separate seeded random stream. Repeat Ball records caught species independently of the current reserve box.

Machine moves run within the island prototype's simplified combat rules and damage scale. Imported definitions supply physical/special classification, accuracy, PP, priorities, targeting and effect metadata. Progression preserves the prototype's starting stats and permanent expedition upgrades. This implementation does not approve effects for unrelated pending catalog items.

Validated: approved item boundaries and variants; independent OHKO failure/immunity checks under Z Accuracy; teaching consumption and failed-save rollback; old-save migration; chest loot and transfers; party storage; integration, balance, debug and endless flows; visual inspection of inventory, teaching and battle bag; packed Windows export smoke test.

Reference snapshot: [PokeAPI data](https://github.com/PokeAPI/pokeapi/tree/master/data/v2/csv), stored offline in `battle_sources` and `battle_reference.json`. Experience-sharing differences were checked against [Exp. Share](https://bulbapedia.bulbagarden.net/wiki/Exp._Share), accuracy exceptions against [one-hit knockout moves](https://bulbapedia.bulbagarden.net/wiki/One-hit_knockout_move), and machine reuse against [HM](https://bulbapedia.bulbagarden.net/wiki/HM) and [TR](https://bulbapedia.bulbagarden.net/wiki/TR).

Healing update validation: `tests/run_healing_variants.gd` passes all exact amounts, HP caps, rejection for full/fainted targets, stack merging, chest/layout migration and idempotence. Existing approved-item and general-item suites have stale starter/catalog assumptions and did not complete in this update.

The healing Windows export was generated successfully. Export logged an editor-settings safe-save warning. Packed executable runtime smoke verification did not complete in the sandbox; source healing checks passed.
