# Apricorn Island

A private, offline Godot 4 prototype about exploring a branching pixel-art island with a team of three creatures. It includes battles, catches, treasure, party swapping, inventory healing, map zoom/panning, defeat recovery, and one autosave slot.

## Play in Godot

For a source checkout from GitHub, follow the steps below. Windows release downloads use `ApricornIsland.exe`; place it in this folder to play. To export it yourself, use the **Windows Desktop** preset in `export_presets.cfg`, which writes `ApricornIsland.exe` without a console wrapper. Generated builds and the separate ABS engine project/distribution are excluded from this source repository.

1. Install Godot 4.3 or newer.
2. Import this folder using `project.godot`.
3. Press **F6/F5** to run the project.

The latest Windows game is available as `ApricornIsland.exe` in this folder. It includes visible level progression, individual IV spreads, and a Pokémon details menu alongside the original island adventure, Hard difficulty, and the Gaster movement/sprite fix. This is the single main Windows build; future updates replace this file. The ABS engine version is maintained separately. Existing adventure and endless saves use the same locations.

## Controls

- Pokémon details: choose a party slot and **View selected Pokémon**, or use **Details** beside a reserve Pokémon. In the PC Box, switch **Stored Pokémon: Swap** to **Stored Pokémon: Details** to inspect stored Pokémon. Battle POKÉMON buttons open details without using a turn. Overview, Stats, IV Judge and Moves tabs show the Pokémon's profile, six-stat chart, IV spread, judge ratings, EVs, held item, friendship and moves. Arrows browse the current party or reserve collection; Escape or Back returns to the previous screen.
- Every new Pokémon rolls six independent IVs from 0–31, ordered HP / Attack / Defense / Special Attack / Special Defense / Speed. IVs add `floor(IV × level / 100)` to each corresponding stat alongside the existing prototype growth and expedition upgrades. HP bonuses preserve damage and do not revive fainted Pokémon. Existing Pokémon receive deterministic spreads on migration; IVs and applied bonuses save with the Pokémon, avoiding rerolls or repeated bonuses. Seeded endless encounters use separate IV randomness. Run `tests/run_ivs.gd` with isolated APPDATA to validate generation, migration, growth, saving, swaps and details navigation.

The level-system update is available in `ApricornIsland.exe`. Pokémon earn battle EXP up to level 100. Each level gives +2 maximum HP and +1 to Attack, Defense, Special Attack, Special Defense and Speed. Battle cards show blue EXP bars and EXP remaining; party and storage screens show levels and progression. Existing saves retain their levels and EXP. Validate progression with `tests/run_levels.gd`.

- Box: the red PC button on the map opens Pokémon storage. Choose a party slot and click a stored Pokémon to swap; changes save immediately. Each Box page shows 30 slots. Arrow buttons browse pages, and Escape returns to the map. The updated Windows build is `ApricornIsland.exe`.

- Mouse: choose menu and battle actions, travel directly to any unlocked map location regardless of distance.
- Mouse wheel or map buttons: zoom the island.
- Left-drag: pan the island map while zoomed in.
- E: open inventory from the map or party; E or Escape closes inventory and chests.
- Inventory: 27 slots plus a nine-slot hotbar. Drag stacks to move, swap, or merge them. Shift-click transfers between the chest and bag. Hover shows pixel-font names colored by rarity. Extra owned items remain available in overflow slots. Chest contents and slot order save with your game.
- Konami code **↑ ↑ ↓ ↓ ← → ← → B A** (no Start/Select): open/close Debug mode from the title, map, party, inventory, settings or battle. Heal/revive the party, add 25 potions and capture balls, win the current battle, toggle battle animations, and inspect FPS/location/run seed. Party/supply changes save immediately; tools wait until battle animations finish. Escape closes the menu.
- Escape: open settings from the map or return from party/inventory.

## Game flow

### Endless expedition

- Choose **New Endless Run** for a seeded procedural route with no final area. **Continue Endless Run** resumes it; the original island adventure has its own separate save.
- HP, items, catches, and upgrades persist through a run. Winning a fight grants supplies and one choice: team attack, maximum HP plus recovery, or a supply pack.
- All route areas are battles. Supply chests appear after clearing levels 10, 20, 30, and so on without increasing depth. Every tenth area is a regular battle. Other areas have randomized enemies. Chest sprites and supply chests appear only at multiples of ten in endless runs.
- The route keeps only a small visible window of destinations and generates later areas on demand. Enemy strength grows with depth. Full-party defeat ends the run; a new run resets the team and supplies with a new seed while retaining best depth.
- Saves include battle checkpoints and unclaimed upgrades. Retreat preserves damage and spent supplies. Cleared areas cannot be farmed for repeated rewards.
- Original synthesized pulse/triangle/noise effects accompany menus, travel, elemental attacks, healing, captures, victories, and defeats. They are inspired by handheld-era RPG audio; no Generation 3 recordings are included. Master Volume controls them.
- Battles also feature three original looping handheld-style music tracks. Wild and Rival alternate randomly between regular encounters; Guardian plays at the summit. Music stops when combat ends or you leave, and Master Volume controls both music and effects. See `assets/music/CREDITS.md`.
- Battles play action-by-action with lunges, projectiles, hit movement, healing sparkles, and capture throws. Input waits until the round animation finishes. The trainer animates while traveling on the map.

### Original island adventure

- Choose Bulbasaur, Charmander, Squirtle, Pikachu, or Eevee in either mode, then catch more Pokémon to build your team.
- Stop 3 is Palm Trail; the island chest appears at stop 10.
- Reach a node, then choose its action from the right-hand panel.
- In battle, use FIGHT for moves, BAG for balls and potions, POKÉMON to check the team, and RUN to leave. Choose one action for each conscious teammate. Your team acts first, followed by surviving opponents.
- Caught creatures go to the reserve box. Swap them into the three-member party between encounters.
- Victories and defeats restore the whole team's HP. The airstrip provides free rest, and the team also rests before the volcano challenge.
- Settings offers Easy, Normal, and Hard difficulty. Hard enemies deal full damage (about 54% more than Normal); Easy and Normal reduce enemy damage. All modes retain the summit adjustment to avoid a sudden difficulty spike.
- The illustrated introduction explains travel, type matchups, recovery, and catching, and can be skipped.

## Validation

### Complete item catalog (stage one)

- The offline catalog includes all 1,473 supplied item rows and 217 key-item names, plus the six existing island supplies. Every catalog item can appear from the first chest.
- Island chests, endless caches and milestone chests retain their supplies and add three item rolls. Rarity odds interpolate from 60/25/10/4/1 percent at depth zero to 40/30/18/9/3 at 50 and 25/30/25/15/5 at 100; they stay capped thereafter. Each item is equally likely within its tier.
- The bag supports name/effect search, categories, owned-only filtering, counts, item details and exact current loot chances. Battle BAG lists owned, implemented battle items and supports choosing a healing/revival target.
- Catalog Berry Juice, Max Potion, Revive, Max Revive and Master Ball work now. Other original effects are explicitly pending, including version choices and missing systems. Existing island healing/capture items retain their behavior. Normal healing does not revive fainted Pokémon.
- Old saves retain inventory and chest collection flags. Seeded loot is independent of combat randomness, and chest inventory/collection are written together through a temporary save file. Failed chest saves roll back rewards.
- See `data/ITEM_COVERAGE.md` for the complete per-item checklist and `data/ITEM_VERSION_REVIEW.md` for your next effect decisions. Key-item effects and blank supplied descriptions still need per-item research in their later stage.
- Catalog IDs are separate from legacy save IDs. Source and rarity/status assignments live in `data/item_catalog.json`; `tools/build_item_catalog.py` regenerates the catalog and checklist from the supplied text.
- TMs now use one chronological sequence, TM001–TM348, with the taught move in each label. Moves are ordered by debut generation and original move index. Duplicate old numbered stacks merge on load. `tools/number_tms.py` refreshes this catalog from the offline PokeAPI reference tables; teaching and species compatibility are implemented.

Run `godot --headless --path . --script res://tests/run_items.gd` for catalog, loot, migration, UI and implemented-effect tests. `tests/capture_items.gd` captures the new screens with a rendering-capable Godot run. Use isolated APPDATA for both.

With Godot available, run the lightweight rules tests from a terminal:

```text
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --script res://tests/run_integration.gd
godot --headless --path . --script res://tests/run_balance.gd
godot --headless --path . --script res://tests/run_endless.gd
godot --headless --path . --script res://tests/run_endless_balance.gd
```

Export using **Project → Export → Windows Desktop**. The included preset targets `ApricornIsland.exe`; an export template must be installed in Godot.

The integration suite covers real map and battle-menu clicks, distant travel, sprite loading, healing, recovery, and difficulty preferences. The balance suite simulates 2,400 battles with effective-move and novice basic-attack strategies, including all three difficulty modes. Visual QA captures are in `build/` (generated by `tests/capture_polish.gd` with a rendering-capable Godot run). Run tests with an isolated APPDATA directory to keep play saves separate.

## Content notes

- The island background is original generated artwork saved at `assets/island_bg.png`.
- Pokémon front/back sprites are cached from PokéAPI for offline play; see `assets/sprites/CREDITS.md` for sources and attribution.
- This project is intended only as a private, noncommercial fan prototype.

Debug testing switches: invincible party, one-hit attacks, guaranteed catches, unlimited owned items, perfect player accuracy, enemy turns, unlocked island travel, and battle animations. Switches are session-only and can be reset together. Scroll the debug menu to reach all options. Debug rewards and party/inventory changes still use normal saves.

## Hidden FUN events

Each island adventure and endless run gets a hidden FUN value from 1–99. It stays fixed across reloads; existing saves receive a value when loaded. Most values keep the island ordinary. Four original encounters can appear as an optional mysterious button at their location, and each is remembered after you finish it. FUN uses separate randomness and does not change combat, loot or route generation.

For testing, open Debug with the Konami code and use **Set FUN value**. Seen events stay completed. Event ranges and locations: 2–9 at Sparkle Brook / endless area 3; 41–45 at Whisper Forest / area 7; 66 at Misty Hollow (island); the playable secret replaces endless area 66; 90–95 at Champion Lookout / area 25. New adventures reset seen events.

Run `godot --headless --path . --script res://tests/run_fun.gd` for range, save persistence, location and one-time-event checks.

### Level 66 secret hallway

In endless mode, entering area 66 with FUN 66 replaces its battle with a playable secret hallway. The gray door is guaranteed. Arrow keys move Frisk; Z/Enter interacts or confirms; X/Shift cancels; C/Ctrl opens or closes the ITEM/STAT/CELL menu. Approach the door and walk up or confirm to enter. Approach the figure and confirm to make it vanish. Walk down through the room exit to return to the hall; its door disappears. Either end of the hall returns to the expedition and completes area 66 without combat rewards or upgrades. The Pokémon party and bag are preserved. Room transitions and interaction are saved; Continue resumes an unfinished secret.

The attached Gaster sprites preserve their proportions and render in front of or behind Frisk according to their feet. Footprint collision keeps Frisk inside the T-shaped room and blocks Gaster until he vanishes; movement slides along walls without snapping at corners. Sprite-sheet background removal applies only to Frisk. Frisk uses the supplied sprite sheet with directional walking frames. The hallway uses texture regions from the supplied reference, and the gray T-shaped room matches the room reference. The menu is recreated in code. The Frisk profile is separate from the expedition save inventory. The secret menu shows CHARA, LV 1, 20/20 HP, 69 gold, Ballet Shoes, Old Tutu, and an empty inventory.

Validation: `tests/run_secret.gd` checks trigger boundaries, keyboard menu controls, doorway entry, interaction, room return, save/resume and expedition completion. `tests/capture_secret.gd` captures the hall, room and menu for visual review.

Debug includes **WD GASTER**, which opens a fresh playable hallway immediately from the title or an active game, regardless of FUN or level. Leaving either end returns to Debug. This preview does not change adventure progress, FUN, seen-event flags or saves.

Debug also includes **Open Chest** during an active adventure outside battle. It opens a saved testing chest with two potions, three capture balls and normal catalog loot on first use. Later uses reopen its remaining contents without adding duplicate rewards or changing map progress. Close the chest with E or Esc to return to the map.


Approved type-power items now include all 24 variants for Fire, Water, Grass, Electric, Ice, Fighting, Poison, Ground, Flying, Psychic, Bug and Rock. The catalog Potion restores 20 HP. Legacy island Potion retains its 25-HP effect. Current source catalog: 1,859 items plus six legacy supplies. Approved capture balls, held berries, battle boosts, experience sharing and machine teaching are implemented. See `data/APPROVED_IMPLEMENTATION.md` for details and validation.


Battle update: all damaging moves use a 1.5x same-type attack bonus (STAB) and the complete dual-type chart, including immunities. Original moves now share taught-move secondary effects. Burn, poison, toxic poison, paralysis, sleep, freeze and confusion use the existing condition rules; battle HP cards display active conditions. Ember and Flame Tail can burn; Thunder Shock can paralyze. Run tests/run_battle_mechanics.gd for focused verification. Updated playable build: ApricornIsland.exe.

Approved healing variants and custom sodas are implemented. See `data/APPROVED_IMPLEMENTATION.md`. Run `tests/run_healing_variants.gd` for healing and soda save migration checks.



## Approved item update — October 15, 2026

Play **ApricornIsland.exe**. The approved non-breeding item update adds medicines and PP upgrades, held battle effects, berries, progression/Hyper Training, form items and persistent Red/Blue Orb bosses. Select an owned item in the inventory for its use/equip controls. Battle PP items first select a Pokémon, then a move. Level-up move and evolution choices are in Party. Red/Blue Orbs expose a summon control for each available copy; their meters, recharge and capture restrictions save automatically.

Cleanse Tag prevents harmful statuses while preserving beneficial effects and every stat stage. Breeding, Honey, Black Flute and White Flute remain excluded/deferred as requested. Unreviewed catalog effects remain pending. See `data/PENDING_ITEM_IMPLEMENTATION.md` for exact scope, save behavior, validation and remaining prototype limits. The ABS engine version remains separate.
