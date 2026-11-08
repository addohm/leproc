# Changelog

All notable changes to leproc. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Diagnostics: `/leproc bars` (the action buttons found, and which hold your abilities), `/leproc macros` (what each macro on your bars counts for), `/leproc why <ability>` (its window, cooldown, stance and buttons right now) (2026-11-08).
- Macros count for every tracked ability their text names (`/cast`, `/castsequence`, `/use`, `#showtooltip`, any clause), so a stance-dance macro like `/cast [nostance:2] Defensive Stance; Revenge` glows for Revenge in Battle Stance (2026-11-08).
- Bar addons that build their buttons late (EllesmereUI, Bartender, Dominos, ElvUI, the gamepad bars) are noticed: Leproc watches for their first button for 30 s after entering the world, and on every update (2026-11-08).
- Glows on any bar addon's action buttons (EllesmereUI, Bartender, Dominos, ElvUI...), not only Blizzard's: Leproc scans for buttons that hold an action slot (2026-11-08).
- Leproc 0.1.0: glows the action buttons of Revenge, Overpower, Riposte, Counterattack and Mongoose Bite for 5 s after their trigger (your block, dodge or parry, or your target's dodge), in any stance or form. Partial blocks count. Using the ability turns the glow off until its cooldown ends. Per ability: Any stance (default), Only in its stance, or Off (2026-11-08).
- Options window (Abilities, Glow, General, Profiles), profiles, Leboof's glow styles and colours, a sound when an ability lights, a test (`/leproc test`), the minimap button and the addon compartment entry, and an icon (2026-11-08).
- Tests (`tests/run_tests.py`), `tools/gen_data.py` and TESTING.md (2026-11-08).
- `tools/install_forever.cmd` and `tools/make_release.py`, copied from Leboof for a `Leproc` addon folder, plus `.gitattributes` and `.gitignore` (2026-11-08).
- Standard docs: README, CLAUDE, CHANGELOG, DEPLOY, SECURITY and ROADMAP (2026-11-08).

### Changed

- Abilities tab: "(not on screen)" instead of "(not on a bar you can see)", which wrapped onto the next row (2026-11-08).
- `ProcGlow/` (the design example, someone else's addon) is no longer tracked, and is git-ignored (2026-11-08).
- Docs filled in with what's known so far; open questions left as TODOs (2026-11-08).
