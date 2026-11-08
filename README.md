# leproc

Leproc is a World of Warcraft: Forever addon for every class. It glows an
ability's action button when the ability is ready, **whatever stance or form
you're in**. Block an attack in Battle Stance and Revenge glows, so you know
it's worth switching to Defensive Stance.

The game only shows reactive abilities as usable in the stance they need, so
other addons (and the game's own highlight) stay dark otherwise. Leproc watches
for the trigger itself (your block, dodge or parry, or your target's dodge) and
lights the button for the 5 s the ability is up.

Status: **0.9.0-beta** (2026-11-08), the first beta: `release/Leproc-0.9.0-beta.zip`.
Tried in game on a warrior; the rest is tested against a fake client. It covers the abilities
that follow a block, dodge or parry:

- **Warrior:** Revenge (after you block, dodge or parry; needs Defensive Stance)
  and Overpower (after your target dodges; needs Battle Stance).
- **Rogue:** Riposte (after you parry).
- **Hunter:** Counterattack (after you parry) and Mongoose Bite (after you
  dodge).

And the Forever procs that make an ability usable, whatever your stance:

- **Bloodthrill** (warrior talent): Overpower.
- **Victorious** (after a kill): Victory Rush.
- **Expose Prey** (hunter talent): Mongoose Bite.

The game hides your buffs from addons in combat, so for these Leproc doesn't
read the buff: it places its glow on one of Blizzard's aura containers, and the
game shows it while you have the buff, in combat too. That glow has no sound or
countdown, and ignores "Only in its stance". It's placed over your buttons out
of combat, so in combat it stays on the button it was on, even if a stance
change flips that bar's page.

Other classes' procs work the same way, lighting the ability they speed up or
make free:

- **Druid:** Eclipse → Starfire (in Bear and Cat Form too).
- **Rogue:** Cutthroat → Ambush (without Stealth).
- **Warlock:** Shadow Trance → Shadow Bolt; Decimation → Soul Fire.
- **Mage:** Heating Up or Hot Streak → Pyroblast; Missile Barrage → Arcane
  Missiles; Fingers of Frost → Ice Lance.
- **Shaman:** Maelstrom Weapon → Lightning Bolt.
- **Paladin:** Infusion of Light → Holy Light.

Except Shadow Trance, these proc buffs' IDs come from Forever's spell data and
haven't been seen in game yet; their tooltips say so.

Health-based abilities (Execute) are next: see [ROADMAP.md](ROADMAP.md).

## Getting started

Copy the `Leproc` folder into `<WoW>\_forever_\Interface\AddOns\` and start the
game. To install straight from this repo on Windows, see
[DEPLOY.md](DEPLOY.md) (`tools\install_forever.cmd`).

**Put the abilities on a bar that doesn't change with stance.** A button can
only glow while it's on screen. A warrior's main bar swaps with stance, so
Revenge kept only on the Defensive Stance page has no button to light in Battle
Stance. Bars 2 to 8 stay the same in every stance. The Abilities tab ("not on
screen") and `/leproc list` say when an ability isn't on a bar you can see.

**Bar addons work too:** Leproc finds action buttons from any addon, not only
Blizzard's: every bar ProcGlow knows (Blizzard's, EllesmereUI, Bartender,
Dominos, ElvUI, the gamepad bars) and any other. Bars built a while after login
are picked up too.

**Macros count by their text.** A macro that names a tracked ability on a
`/cast`, `/castsequence`, `/use` or `#showtooltip` line is that ability's
button, in any clause. So a stance-dance macro like
`/cast [nostance:2] Defensive Stance; Revenge` glows for Revenge in Battle
Stance, even though pressing it there would switch stance first.

## Usage

**The options window** opens with `/leproc` (or `/lpr`), the minimap button,
the game's addon menu by the minimap, or Options > AddOns > Leproc. It has four tabs:

- **Abilities:** your class's abilities, each set to:
  - **Any stance** (the default): lights after its trigger in any stance or
    form.
  - **Only in its stance:** lights only when you're in the stance the game
    needs, like other addons do.
  - **Off.**

  An ability that isn't on a bar you can see says so.

  Under each one, **Also glow** can pick a stance. While the ability is lit and
  you're not in that stance, the stance's button glows too, on the stance bar
  and on any action button holding it. For example, Revenge → Defensive Stance
  points you at the stance to switch to. Off ("Nothing else") by default.
- **Glow:** the glow style (Pixel, Action button, Auto-cast, GCD, Modern,
  Classic, Pulse), its colour, an optional countdown (the seconds left, in the
  middle of a lit button; off by default), and a sound for when an ability
  lights up (off by default). **Test** lights your abilities' buttons for 5 s.
- **General:** the minimap button, and how Leproc works.
- **Profiles:** each character starts with its own profile (by first and last
  name); share, copy, rename, delete or reset them.

**How long it lights:**

- **In the ability's own stance** (Revenge in Defensive Stance, Overpower in
  Battle Stance), the game decides: it lights the moment the game says it's
  usable and goes dark the moment the game says it isn't. "Short of rage"
  still glows.
- **In other stances** the game says no regardless, so Leproc keeps its own
  window: about 5 s from the trigger. The game reports blocks, dodges and
  parries to addons a little late (your logs: 0.2-0.9 s), so Leproc measures
  that delay while you're in the stance and ends its window that much sooner.
  `/leproc why` shows the delay.
- After you use it, it stays dark for its cooldown (Revenge 5 s) even if you
  block again. Dying or leaving combat ends every window.
- A guess that the game contradicts (a dodge from someone else's attack) goes
  out when you switch into the stance and the game says no.

**Chat commands:**

- `/leproc help` lists them.
- `/leproc list` shows your abilities, their modes and whether they're on
  screen.
- `/leproc <ability> any|stance|off|default`, for example `/leproc revenge
  stance`.
- `/leproc test` lights the buttons for 5 s.
- `/leproc bars` lists the action buttons Leproc found and which of them hold
  your abilities; `/leproc macros` shows what it read from each macro;
  `/leproc why revenge` explains why Revenge is or isn't glowing right now
  (its window, cooldown, stance and buttons).
- `/leproc log` logs, with timestamps (the clock, then the game's timer to a
  tenth), every trigger (who dodged, blocked or parried), every glow turning
  on or off, every spell you cast, stance and target changes, deaths, and what
  the game itself says about your abilities being usable ("no (short of
  power)" when rage is the only reason).
  `/leproc log show` opens it in a window to copy (Ctrl+C), `/leproc log off`
  stops it, `/leproc log clear` empties it. It keeps the last 2000 lines (a
  dungeon's worth). It also logs when the game opens or closes a window and
  each measured delay.
- `/leproc minimap`, `/leproc profile`, `/leproc reset`.

**Minimap button:** click for the window, right-click for the test, drag to move
it.

## Docs

- [CHANGELOG.md](CHANGELOG.md): what changed in each version
- [DEPLOY.md](DEPLOY.md): how it's deployed
- [TESTING.md](TESTING.md): what to check in game
- [LISTING.md](LISTING.md): the CurseForge / Wago page text, and the release notes
- [SECURITY.md](SECURITY.md): secrets, access, reporting problems
- [ROADMAP.md](ROADMAP.md): what's done and what's next
- [CLAUDE.md](CLAUDE.md): notes for Claude working on it
