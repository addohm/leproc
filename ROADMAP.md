# Roadmap

What's done for leproc, and what's next. Update it in the same commit as the
change.

## Done

- **0.9.0-beta released** (2026-11-08): `release/Leproc-0.9.0-beta.zip`, tag
  `v0.9.0-beta`, with LISTING.md (the pitch page), the icon and the banner.
- Standard docs (2026-11-08).
- Install and release tools from Leboof (2026-11-08).
- 0.1.0: block, dodge and parry abilities glow in any stance (Revenge, Overpower,
  Riposte, Counterattack, Mongoose Bite) on the action bars, with the
  options window, profiles, glow styles, a sound and the minimap button
  (2026-11-08). Tried in game: the window opens; abilities on EllesmereUI's
  bars weren't found.
- Buttons from any bar addon, found by scanning (2026-11-08).
- Diagnostics: `/leproc bars`, `/leproc macros`, `/leproc why` (2026-11-08).
- Optional countdown on lit buttons; Leproc in Options > AddOns (2026-11-08).
- The game decides in an ability's own stance; elsewhere a window shortened by
  the measured report delay (from the owner's logs) (2026-11-08).
- Proc buffs through Blizzard's aura containers: Bloodthrill (Overpower),
  Victorious (Victory Rush), Expose Prey (Mongoose Bite) (2026-11-08).
- Class procs on the same mechanism: Eclipse, Cutthroat, Shadow Trance,
  Decimation, Heating Up / Hot Streak, Missile Barrage, Fingers of Frost,
  Maelstrom Weapon, Infusion of Light (2026-11-08).
- Also glow: a stance's button (stance bar, or an action button holding it)
  while an ability is lit and you're not in that stance (2026-11-08).
- Every bar on ProcGlow's list tested; late bar addons noticed; macros count
  for every tracked ability their text names, so stance-dance macros glow
  (2026-11-08).

## The rebuild (planned 2026-11-18)

The owner, 2026-11-18: Leproc's current form isn't a place to start from.
Leproc starts over with ProcGlow 2.0.6 (by Troy) as its base: everything
ProcGlow does, rebuilt in our own code, in Leproc's look, within Blizzard's
rules for addons. That's the base; from there we work towards the perfect proc
addon.

### Decided

- Rebuild, not a fork: ProcGlow is read for what it does, the code is ours
  (ProcGlow has no licence).
- All of ProcGlow, including what 0.x left out: buff reminders, text popups
  with their animations, floating icons and "Track a buff or cooldown",
  redirects, the glow designer, timer and stack numbers, profiles that switch
  by spec or group role, the class-coloured window. (Window scale, minimise
  and the minimap's profile menu were built, then dropped at the owner's word
  on 2026-11-18: the window resizes, and profiles are managed on their tab.)
- Leproc's any-stance glow stays: in an ability's own stance the game decides
  (as in ProcGlow); outside it, the block, dodge and parry windows.
- Our look: Leboof's options window, widgets and colours, with ProcGlow's
  pages in it.
- Nothing is released until the base is complete; then 1.0.0 with the
  release kit.

### Blizzard's rules it keeps to

- Secret values are never compared or used in sums: `issecretvalue` first,
  and calls that can meet one run in `pcall`.
- Your own auras are read only while the game allows it (out of combat, and
  outside battlegrounds and arenas: `C_Secrets.ShouldAurasBeSecret`). In
  combat, proc buffs show through Blizzard's aura containers, which the game
  fills itself; those frames are set up out of combat only.
- The combat log is blocked for addons: triggers come from `UNIT_COMBAT`,
  casts from `UNIT_SPELLCAST_*`.
- Glows go on our own frames over the buttons: no protected calls, nothing set
  on Blizzard's or other addons' buttons. Display only: nothing is automated.
- Our frames never catch the mouse, except while being moved.

### What carries over from 0.x

- Kept: the tools (install, release, `gen_data.py`, `compare_logs.py`,
  `forever_tooltips.py`), the test harness (`tests/wowmock.lua` grows with each
  step), the art, the docs, the generated spell IDs (`Data.lua`: every client
  language works by ID), Leboof's window and widgets, the log
  (`/leproc log`), and what the owner's logs taught us (the report delay, a
  target's dodges out of combat aren't yours, partial blocks count).
- Rewritten: the rest of the addon, file by file, in the steps below.
- Not taken from ProcGlow: its own notices (the thank-you box with its
  CurseForge link, the language notices), `/pg scanids` (`tools/gen_data.py`
  does this), Commanding Shout (not in Forever), and two bugs: `/pg profile
  <name>` calls a function that doesn't exist, and the spell ID from
  `UNIT_SPELLCAST_SENT` is dropped, so "was this buff cast on me" always falls
  back to judging by your target.

### Steps

Each step is a commit or a few, installed and checked in game, with its list
in TESTING.md.

1. **Skeleton and look.** Done 2026-11-18. The new file layout; settings and
   profiles, switching by talents or group role; the options window in our
   theme with ProcGlow's pages as tabs (General, Procs & Buffs, Glow, Timer &
   Stacks, Text Alerts, Profiles; the middle four are placeholders until their
   steps); class colour; the minimap button; Options > AddOns with an Enable
   box; the login message. Profiles are managed on their tab only. Profiles stay Leproc's: account-wide and shareable
   between characters, with no limit, rather than ProcGlow's 8 per character;
   the switching rules are per character, as in ProcGlow. Talents are read
   from Forever's talent trees (the group with the most points spent); not
   seen in game yet (TESTING.md). 0.x's glow code is gone until step 2
   (`Abilities.lua`, `Data.lua` and `Glow.lua` stay, unused, for step 2).
2. **Buttons and the glow rule.** Every bar ProcGlow knows (Blizzard's,
   Bartender, Dominos, ElvUI, EllesmereUI, the gamepad bars, the stance bars)
   plus our scan for any other; slots and macros. Per button, ProcGlow's
   order: Blizzard's proc highlight; the target's type (Exorcism); the game's
   usable answer and the cooldown; short of rage inside the window; dark once
   used, until the next trigger; and outside the ability's stance, the trigger
   windows. Abilities: Overpower, Revenge, Riposte, Counterattack, Mongoose
   Bite, Execute, Victory Rush, Hammer of Wrath, Exorcism. The class pages: a
   grid of classes, a page per class with a row per ability (Glow, Text, Icon,
   More), Test, adding and removing abilities.
3. **Glow designer, timer and stacks.** Blizzard's glow or the layers (halo,
   highlight, outline, fill, burst, ants; pulse, pop, flash) with every
   setting and a live preview, next to 0.x's styles; the countdown and stack
   count on lit buttons, their size and place; a preview on every button.
4. **Proc buffs.** Shadow Trance, Hot Streak, Heating Up, Missile Barrage,
   Fingers of Frost, Maelstrom Weapon, Infusion of Light, Searing Light,
   Decimation, Eclipse, Cutthroat, Thousand Cuts, Expose Prey, Bloodthrill,
   Victorious; Clearcasting for each class that has it; the popup-only ones
   (Remorseless Attacks, Rapid Killing, Arcane Blast stacks). Read out of
   combat, through the aura containers in combat, with no gap or blink when
   combat ends; stacks; a faint glow below full stacks; Arcane Blast counted
   from your casts; adding a buff that lights an ability.
5. **Text popups.** Font, size, colours, outline, shadow, border, background;
   throb, pulse and shake; each ability's own text and overrides; Unlock to
   move, Test, reset and centre.
6. **Floating icons and the Customise window.** An icon per ability: size,
   timer, stacks, glow; snapping, moving together, the nudge pad, lining up,
   centring. The Customise window, docked beside the options window, with Text
   and Icon tabs.
7. **Buff reminders.** Battle Shout; each class's buffs and groups (blessings,
   armors, aspects, auras, shields), seals, weapon imbues, Find Minerals and
   the like when missing, Righteous Fury only when tanking, none while resting
   or flying; "Track a buff or cooldown" with suggestions, racials, cooldown
   icons, First Aid's Recently Bandaged, Slice and Dice by combo points. In
   combat and battlegrounds: your casts, learned durations and whatever the
   game still answers (as ProcGlow does), or Leboof's container method where
   that works better.
8. **Redirects.** A proc shown on another button or slot, only in the stances
   you pick; replaces 0.x's Also glow.
9. **Diagnostics.** `/leproc why`, `bars`, `macros`, `auras`, `procs`, `bg`,
   `icon`, `mouse`, `debug`, and the log.
10. **1.0.0** with the release kit (DEPLOY.md).

### 0.x's next steps

Folded into the rebuild: checking the beta's timing (step 2 puts the game's
answer first), confirming the proc buff IDs (step 4), and Execute and Hammer
of Wrath (step 2: the game's usable answer in their stance).

## Ideas

- A per-ability glow, colour or sound.
