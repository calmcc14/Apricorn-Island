# TM reference snapshot

Downloaded 2026-10-10 from https://github.com/PokeAPI/pokeapi/tree/master/data/v2/csv.
Files: machines.csv, moves.csv, move_names.csv, items.csv.

Only machine rows whose item identifier matches tm followed by digits contribute moves. HMs and TR-only moves are excluded. Distinct TM moves are sorted by debut generation, then move index. This provides a deterministic order for moves released together. This snapshot defines the current 348 entries; additions require an explicit reference refresh, retaining published numbering if older data is corrected.
