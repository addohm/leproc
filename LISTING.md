# Leproc: CurseForge and Wago listing

Copy-paste material for the project pages. Placeholders are in [brackets]. Keep the feature list
in step with README.md.

---

## Basics

| Field | Value |
| --- | --- |
| Name | Leproc |
| Slug | `leproc` |
| Game version | WoW: Forever (Interface 16001) |
| Author | addohm |
| Release type | Beta (0.9.0-beta) |
| License | [choose: All Rights Reserved, MIT, ...] |
| Source | [https://github.com/addohm/leproc, if the repo is public] |
| Issues | [https://github.com/addohm/leproc/issues, if public] |

**Images**
- Avatar: `art/leproc-icon-400.png`
- Banner / header: `art/leproc-banner.png` (1600x500)

**Categories**
- CurseForge: Action Bars (main), Combat, Buffs & Debuffs
- Wago: Action Bars (main), Combat

**Summary** (the one-liner under the name; 138 characters)

> Revenge, Overpower and your procs light up on your action bars in any stance or form, so you
> know when it's worth switching. WoW: Forever.

**Short tagline** (for images or a Discord post)

> Reactive abilities glow, whatever your stance.

---

## Description

*(Paste as Markdown. Both sites accept it.)*

### Leproc

**Reactive abilities glow, whatever your stance. Built for WoW: Forever.**

Block an attack in Battle Stance and Revenge is up for a few seconds, but the game won't show it,
and neither will other proc addons: they ask the game whether the button is usable, and outside
Defensive Stance the game says no. Leproc lights the button anyway, so you know it's worth the
switch. The same goes for Overpower in Defensive Stance, and for every class's procs.

#### What lights up

- **Warrior:** Revenge (after you block, dodge or parry), Overpower (after your target dodges,
  or a Bloodthrill proc), Victory Rush (after a kill).
- **Rogue:** Riposte (after you parry), Ambush with Cutthroat (no Stealth needed).
- **Hunter:** Counterattack (after you parry), Mongoose Bite (after you dodge, or Expose Prey).
- **Druid:** Starfire with Eclipse, in Bear and Cat Form too.
- **Warlock:** Shadow Bolt with Shadow Trance, Soul Fire with Decimation.
- **Mage:** Pyroblast (Heating Up, Hot Streak), Arcane Missiles (Missile Barrage), Ice Lance
  (Fingers of Frost).
- **Shaman:** Lightning Bolt with Maelstrom Weapon.
- **Paladin:** Holy Light with Infusion of Light.

#### Exact where the game can tell

- **In the ability's own stance** (Revenge in Defensive, Overpower in Battle), Leproc follows
  the game's own answer: it lights the moment the ability is usable and goes dark the moment it
  isn't. "Short of rage" still glows.
- **In other stances** the game always says no, so Leproc watches the blocks, dodges and parries
  the game reports (in combat too) and keeps its own window. Those reports arrive a little late,
  so Leproc measures the delay while you're in the stance and allows for it everywhere else.
- **Proc buffs** light through Blizzard's own aura containers: the game shows the glow while you
  have the buff, in combat too, without Leproc reading it.
- Using the ability turns the glow off until its cooldown is over. Dying or leaving combat ends
  everything.

#### Works with your bars

- Any action bar addon: Blizzard's, EllesmereUI, Bartender, Dominos, ElvUI, the gamepad bars.
  Bars built late are picked up.
- **Macros count by their text**, so a stance-dance macro like
  `/cast [nostance:2] Defensive Stance; Revenge` glows for Revenge in Battle Stance.
- **Also glow:** point an ability at a stance, and that stance's button (on the stance bar, or
  any action button holding it) glows too while the ability is lit and you're not in it.
- Tip: keep reactive abilities on a bar that doesn't change with stance, so they have a button
  to light in every stance.

#### Glow, sound, countdown

- Seven glow styles (Pixel glow, Action button glow, Auto-cast shine, GCD, Modern WoW glow,
  Classic WoW glow, Pulse) in eleven colours or your class colour.
- An optional countdown on the lit button, and an optional sound when something lights up.
- **Per ability:** Any stance (the default), Only in its stance, or Off.

#### Profiles

- Every setting is in a profile, one per character by default ("First Last"). Share one between
  characters, or copy, rename, delete and reset.

#### Commands

| Command | |
| --- | --- |
| `/leproc` | Open or close the options window (also the minimap button and Options > AddOns) |
| `/leproc test` | Light your abilities' buttons for 5 s |
| `/leproc list` | Your abilities, their modes, and whether they're on screen |
| `/leproc why <ability>` | Why it is or isn't glowing right now |
| `/leproc bars`, `/leproc macros` | What Leproc found on your bars and in your macros |
| `/leproc log` | Log every trigger, glow and cast, to copy and report a problem |
| `/leproc help` | All commands |

#### Good to know

- **This is a beta.** Report odd glows with `/leproc log` (`/leproc log show` to copy it).
- **Outside the ability's stance the glow is Leproc's estimate.** The game can't say there.
  Overpower, for example, can light when your target dodges a party member's attack, since the
  game only reports that the target dodged (only while you're in combat yourself). Set
  Overpower to "Only in its stance" if you'd rather it lit only when the game confirms it.
- **Proc glows are placed out of combat.** In combat they stay on the buttons they were on, even
  if a stance change flips that bar's page.
- **Execute and Hammer of Wrath** aren't covered: Forever hides target health from addons.
- Most class procs' buff IDs come from Forever's data and haven't all been seen in game yet.
- No libraries, no automation: display and sound only.

---

## Screenshots to take

1. Battle Stance after a block: Revenge glowing on an action bar (Pixel glow), with the
   countdown on.
2. The same moment with Also glow on: Defensive Stance glowing on the stance bar too.
3. The Abilities tab: Revenge, Overpower and Victory Rush with their modes and Also glow pickers.
4. The Glow tab: the sample button, style and colour pickers, sound and Test.
5. A stance-dance macro glowing on EllesmereUI's (or another addon's) bar.
6. `/leproc why revenge` output in chat.

---

## Release notes

### 0.9.0-beta

The first beta. Revenge, Overpower, Riposte, Counterattack and Mongoose Bite glow on your action
buttons after their trigger in any stance or form: exact in the ability's own stance (the game's
answer), and Leproc's own window elsewhere, corrected for how late the game reports blocks,
dodges and parries. Proc buffs (Bloodthrill, Victorious, Expose Prey, and class procs such as
Eclipse, Cutthroat and Shadow Trance) light through Blizzard's aura containers. Any bar addon,
macros by their text, Also glow for stance buttons, seven glow styles, an optional countdown and
sound, profiles, the Options > AddOns entry, and diagnostics (`/leproc why`, `bars`, `macros`,
`log`).
