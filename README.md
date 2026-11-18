# leproc

Leproc is a World of Warcraft: Forever addon for every class. It glows an
ability's action button when the ability is ready, **whatever stance or form
you're in**: block an attack in Battle Stance and Revenge glows, so you know
it's worth switching to Defensive Stance.

Status: **being rebuilt** (1.0.0-dev). Leproc is starting over with ProcGlow's
feature set as its base, in its own code and look: proc and reactive glows,
proc buffs, buff reminders, text popups, floating icons, redirects and a glow
designer, keeping Leproc's any-stance glow. The plan, in ten steps, is in
[ROADMAP.md](ROADMAP.md) ("The rebuild").

**In so far:** the options window, profiles (with switching by talents or
group role), the minimap button and the Options > AddOns entry (step 1), and
the glows for reactive abilities (step 2a). The tab to choose what glows is
next (2b); until then every reactive ability of your class glows, in any
stance. Proc buffs (Shadow Trance, Hot Streak...) come in step 4: for those,
play the last release, `release/Leproc-0.9.0-beta.zip` (its README is at the
tag `v0.9.0-beta`).

## What glows

ProcGlow's reactive abilities:

- **Warrior:** Overpower (after your target dodges), Revenge (after you block,
  dodge or parry), Execute (your target below 20% health), Victory Rush (after
  a kill).
- **Rogue:** Riposte (after you parry).
- **Hunter:** Counterattack (after you parry), Mongoose Bite (after you dodge).
- **Paladin:** Hammer of Wrath (your target below 20% health), Exorcism (while
  your target is undead or a demon and it's ready).

**When a button glows**, in ProcGlow's order:

1. Never while it's on cooldown after you use it (timed from your cast, or the
   game's own cooldown where it shows it).
2. Blizzard's own proc highlight on it: lit.
3. Exorcism: only on an undead or demon target. In dungeons the game hides
   what your target is, so it can't light there.
4. **In the ability's own stance** (Revenge in Defensive Stance, Overpower in
   Battle Stance, Execute in Battle or Berserker; always for abilities that
   need none), the game decides: lit the moment it says the ability is
   usable, dark the moment it says it isn't. "Short of rage" still glows.
5. **In other stances** the game says no regardless, so Leproc keeps its own
   window for the abilities that follow a block, dodge or parry: about 5 s
   from the trigger, ended a little early to allow for how late the game
   reports it to addons (measured while you're in the stance; `/leproc why`
   shows it). Execute can't do this: addons can't see the target's health.
   Your target's dodges only count while you're in combat (in a group, out of
   combat, it was someone else's attack). Dying or leaving combat ends every
   window.

**Put the abilities on a bar that doesn't change with stance**, to see them
light in every stance: a warrior's main bar swaps with stance. Bars 2 to 8 stay
put. **Bar addons work too:** every bar ProcGlow knows (Blizzard's,
EllesmereUI, Bartender, Dominos, ElvUI, the gamepad bars) and any other, also
when built a while after login. **Macros count by their text:** a macro naming
a tracked ability on a `/cast`, `/castsequence`, `/use` or `#showtooltip` line,
in any clause, is that ability's button, so a stance-dance macro
(`/cast [nostance:2] Defensive Stance; Revenge`) glows for Revenge in Battle
Stance.

## Getting started

Copy the `Leproc` folder into `<WoW>\_forever_\Interface\AddOns\` and start the
game. To install straight from this repo on Windows, see
[DEPLOY.md](DEPLOY.md) (`tools\install_forever.cmd`).

## Usage

**The options window** opens with `/leproc` (or `/lpr`), the minimap button,
the game's addon menu by the minimap, or Options > AddOns > Leproc. It's
dragged by its title bar and resized from its corner, and Escape closes it.
The Defaults button resets the tab shown. The tabs:

- **General:** turn Leproc on or off (the minimap button greys out while it's
  off), show or hide the minimap button, a reminder in chat at login, the
  window in your class colour, and **Reset all settings** (every profile and
  every character, after asking; the interface reloads).
- **Procs & Buffs**, **Glow**, **Timer & Stacks**, **Text Alerts:** not built
  yet; each says which step brings it.
- **Profiles:** where profiles are managed (nowhere else). Each character
  starts with its own profile (by first and last name), and that's all most
  players need. Pick another to share it between characters, or keep two
  setups on one (tank and damage, say); new, copy, rename, delete, reset.
  - **Switch automatically:** pick a profile for each of your talent trees
    (the one with the most points counts) and for each group role (tank,
    healer, damage dealer). A role rule wins while you're in a group with that
    role. It switches when your talents or role change, waiting for the end of
    combat; the rules are each character's own. The tab shows your trees'
    points and your role as Leproc sees them.

**The minimap button:** click (either button) to open or close the window,
drag to move it around the minimap (square minimaps too). The addon
compartment by the minimap does the same.

**Options > AddOns > Leproc:** an Enable box and a button that opens the
window.

**Chat commands** (`/leproc help` lists them):

- `/leproc`: open or close the window.
- `/leproc general`, `abilities`, `glow`, `timer`, `text`, `profiles`: open
  that tab.
- `/leproc profile`: says which profile you're using and opens the Profiles
  tab.
- `/leproc spec`: your talent trees, their points and your group role, as
  profile switching sees them.
- `/leproc minimap`: show or hide the minimap button.
- `/leproc on`, `/leproc off`: turn every glow on or off.
- `/leproc test`: light your abilities' buttons for 5 s.
- `/leproc why <ability>`: why it is or isn't glowing right now (its
  cooldown, Blizzard's highlight, the game's answer, its window, the stance,
  the buttons holding it).
- `/leproc bars`: the action buttons Leproc found and which hold your
  abilities; `/leproc rescan` looks for buttons again.
- `/leproc macros`: what Leproc read from each macro on your bars.
- `/leproc log`: logs, with timestamps, every trigger, glow and cast, stance
  and target changes, deaths, what the game says about your abilities being
  usable, Blizzard's proc highlights and the game's reactive alerts.
  `/leproc log show` opens it to copy (Ctrl+C), `/leproc log off` stops it,
  `/leproc log clear` empties it. It keeps the last 10000 lines; all are in
  `WTF\Account\<account>\SavedVariables\Leproc.lua` after a `/reload`.

## Docs

- [CHANGELOG.md](CHANGELOG.md): what changed in each version
- [DEPLOY.md](DEPLOY.md): how it's deployed
- [TESTING.md](TESTING.md): what to check in game
- [LISTING.md](LISTING.md): the CurseForge / Wago page text, and the release notes
  (still 0.9.0-beta's; rewritten for 1.0.0)
- [SECURITY.md](SECURITY.md): secrets, access, reporting problems
- [ROADMAP.md](ROADMAP.md): what's done and what's next
- [CLAUDE.md](CLAUDE.md): notes for Claude working on it
