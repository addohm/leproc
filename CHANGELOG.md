# Changelog

All notable changes to leproc. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- `/leproc log` (`off`, `show`, `clear`): every trigger, glow, cast, stance and target change, and what the game says about your abilities being usable (by spell and by button, "secret" when hidden), timestamped; the last 300 lines kept, copyable from a window (2026-11-08).
- Class procs, shown by the game the same way: Eclipse → Starfire (in any form), Cutthroat → Ambush, Shadow Trance → Shadow Bolt, Decimation → Soul Fire, Heating Up / Hot Streak → Pyroblast, Missile Barrage → Arcane Missiles, Fingers of Frost → Ice Lance, Maelstrom Weapon → Lightning Bolt, Infusion of Light → Holy Light. Only Shadow Trance's buff ID is confirmed (2026-11-08).
- Proc buffs: Bloodthrill lights Overpower, Victorious lights Victory Rush (new), Expose Prey lights Mongoose Bite, in any stance and in combat. The game shows these glows itself through Blizzard's aura containers (a slot per proc buff, the glow a child of its button, placed over the action buttons out of combat); Leproc never reads the buffs (2026-11-08).
- Also glow: per ability, a stance whose button also glows (on the stance bar, and any action button holding it) while the ability is lit and you're not in that stance, e.g. Revenge → Defensive Stance. Off by default (2026-11-08).
- Optional countdown: the seconds left in the window, in the middle of a lit button (Glow tab; off by default) (2026-11-08).
- Leproc in the game's Options > AddOns list, with a button that opens its window (2026-11-08).
- Diagnostics: `/leproc bars` (the action buttons found, and which hold your abilities), `/leproc macros` (what each macro on your bars counts for), `/leproc why <ability>` (its window, cooldown, stance and buttons right now) (2026-11-08).
- Macros count for every tracked ability their text names (`/cast`, `/castsequence`, `/use`, `#showtooltip`, any clause), so a stance-dance macro like `/cast [nostance:2] Defensive Stance; Revenge` glows for Revenge in Battle Stance (2026-11-08).
- Bar addons that build their buttons late (EllesmereUI, Bartender, Dominos, ElvUI, the gamepad bars) are noticed: Leproc watches for their first button for 30 s after entering the world, and on every update (2026-11-08).
- Glows on any bar addon's action buttons (EllesmereUI, Bartender, Dominos, ElvUI...), not only Blizzard's: Leproc scans for buttons that hold an action slot (2026-11-08).
- Leproc 0.1.0: glows the action buttons of Revenge, Overpower, Riposte, Counterattack and Mongoose Bite for 5 s after their trigger (your block, dodge or parry, or your target's dodge), in any stance or form. Partial blocks count. Using the ability turns the glow off until its cooldown ends. Per ability: Any stance (default), Only in its stance, or Off (2026-11-08).
- Options window (Abilities, Glow, General, Profiles), profiles, Leboof's glow styles and colours, a sound when an ability lights, a test (`/leproc test`), the minimap button and the addon compartment entry, and an icon (2026-11-08).
- Tests (`tests/run_tests.py`), `tools/gen_data.py` and TESTING.md (2026-11-08).
- `tools/forever_tooltips.py`: Wowhead's Forever tooltips for spells by name, to check one before adding it (2026-11-08).
- `tools/install_forever.cmd` and `tools/make_release.py`, copied from Leboof for a `Leproc` addon folder, plus `.gitattributes` and `.gitignore` (2026-11-08).
- Standard docs: README, CLAUDE, CHANGELOG, DEPLOY, SECURITY and ROADMAP (2026-11-08).

### Fixed

- A window lasted past your death: a cooldown ending afterwards lit Revenge while you were dead. Dying and the end of combat now close every window (2026-11-08).
- `/leproc log` timestamps mixed the clock's seconds with the game timer's tenths, putting lines out of order: it now shows the clock, then the game's timer (2026-11-08).

### Changed

- In an ability's own stance the game decides: Revenge in Defensive Stance and Overpower in Battle Stance light the moment the game says they're usable and go dark the moment it says they aren't ("short of power" still glows). This fixes Overpower glowing after the game had ended it (2026-11-08).
- The target's-dodge delay starts at 0.4 s, not 0: the owner's Battle Stance log showed those reports 0.3-0.5 s late too (2026-11-08).
- Elsewhere Leproc's window is 5 s minus the measured delay of the game's block/dodge/parry reports (the owner's logs: 0.2-0.9 s late), so it no longer glows about half a second past the real end. The delay is learned while the game can answer, per kind of trigger, and shown by `/leproc why` (2026-11-08).
- A guessed window the game contradicts closes when you switch into the ability's stance (2026-11-08).
- `/leproc log` keeps 2000 lines, and logs the game opening and closing windows and each measured delay (2026-11-08).
- `/leproc log`: "no (short of power)" when rage, energy or mana is the only reason; every spell you cast; deaths; only your class's abilities in a trigger's line (2026-11-08).
- Abilities tab: "(not on screen)" instead of "(not on a bar you can see)", which wrapped onto the next row (2026-11-08).
- `ProcGlow/` (the design example, someone else's addon) is no longer tracked, and is git-ignored (2026-11-08).
- Docs filled in with what's known so far; open questions left as TODOs (2026-11-08).
