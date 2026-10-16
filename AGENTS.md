# Game release policy

- Keep exactly one main Windows game executable in the project root: `ApricornIsland.exe`.
- Update that executable in place for every game change. Do not create feature-named, numbered, dated, backup, or alternate playable executables.
- The ABS engine game is the user's explicit exception. Keep its files and distribution separate and preserve them during main-game cleanup.
- Export with the Windows Desktop preset in `export_presets.cfg`, which targets `ApricornIsland.exe` and disables the extra console wrapper.
- Keep README play instructions pointing to `ApricornIsland.exe`. Tests and source files are not separate game releases.
