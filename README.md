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

**Step 1 is in:** the options window, profiles (with switching by talents or
group role), the minimap button and the Options > AddOns entry. **Nothing
glows yet**: that's step 2. For the glows as they were, play the last release,
`release/Leproc-0.9.0-beta.zip` (its README is at the tag `v0.9.0-beta`).

## Getting started

Copy the `Leproc` folder into `<WoW>\_forever_\Interface\AddOns\` and start the
game. To install straight from this repo on Windows, see
[DEPLOY.md](DEPLOY.md) (`tools\install_forever.cmd`).

## Usage

**The options window** opens with `/leproc` (or `/lpr`), the minimap button,
the game's addon menu by the minimap, or Options > AddOns > Leproc. It's
dragged by its title bar and resized from its corner; **Scale** in the title
bar makes it bigger or smaller (70% to 140%), **-** folds it to its title bar
(and **+** brings it back), and Escape closes it. The Defaults button resets
the tab shown. The tabs:

- **General:** turn Leproc on or off (the minimap button greys out while it's
  off), show or hide the minimap button, a reminder in chat at login, the
  window in your class colour, and **Reset all settings** (every profile and
  every character, after asking; the interface reloads).
- **Procs & Buffs**, **Glow**, **Timer & Stacks**, **Text Alerts:** not built
  yet; each says which step brings it.
- **Profiles:** each character starts with its own profile (by first and last
  name). Pick another to share it between characters; new, copy, rename,
  delete, reset.
  - **Switch automatically:** pick a profile for each of your talent trees
    (the one with the most points counts) and for each group role (tank,
    healer, damage dealer). A role rule wins while you're in a group with that
    role. It switches when your talents or role change, waiting for the end of
    combat; the rules are each character's own. The tab shows your trees'
    points and your role as Leproc sees them.

**The minimap button:** click for the window, right-click for a menu of your
profiles (click one to switch, or "New profile..."), drag to move it around the
minimap (square minimaps too). The addon compartment by the minimap does the
same.

**Options > AddOns > Leproc:** an Enable box and a button that opens the
window.

**Chat commands** (`/leproc help` lists them):

- `/leproc`: open or close the window.
- `/leproc general`, `abilities`, `glow`, `timer`, `text`, `profiles`: open
  that tab.
- `/leproc profile`: list the profiles; `/leproc profile <name>` switches.
- `/leproc spec`: your talent trees, their points and your group role, as
  profile switching sees them.
- `/leproc minimap`: show or hide the minimap button.
- `/leproc on`, `/leproc off`: turn every glow on or off.

## Docs

- [CHANGELOG.md](CHANGELOG.md): what changed in each version
- [DEPLOY.md](DEPLOY.md): how it's deployed
- [TESTING.md](TESTING.md): what to check in game
- [LISTING.md](LISTING.md): the CurseForge / Wago page text, and the release notes
  (still 0.9.0-beta's; rewritten for 1.0.0)
- [SECURITY.md](SECURITY.md): secrets, access, reporting problems
- [ROADMAP.md](ROADMAP.md): what's done and what's next
- [CLAUDE.md](CLAUDE.md): notes for Claude working on it
