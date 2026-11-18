# Testing in game

What to check after installing a build (`tools\install_forever.cmd`, then
`/reload`). Note the build `/leproc help` shows. Results go in Confirmed or
Problems below.

## To check: rebuild step 1 (1.0.0-dev)

The window, profiles, the minimap button and Options > AddOns. Nothing glows
in this build (step 2). The file list changed: **restart the game** after the
install script, don't just `/reload`.

1. No Lua errors at login. The first login says "thanks for installing!";
   after that, "v1.0.0-dev build <commit> loaded" once per login, not at each
   loading screen.
2. `/leproc` opens the window; its title says "Leproc v1.0.0-dev" with no
   build number (Options > AddOns too; `/leproc help` gives the build). Six tabs (General, Procs & Buffs, Glow, Timer &
   Stacks, Text Alerts, Profiles), each opens; the four not built yet say so.
   Drag it by the title bar, resize from the corner, Escape closes it; it
   opens again where you left it, on the tab you left it on.
3. No Scale or minimise buttons in the title bar: just the icon, the name,
   the version and the close button.
4. General: "Use my class colour" turns the edge, the rules under the
   headings and the selected tab from gold to your class colour; Defaults
   puts gold back. "Enable Leproc" off greys the minimap button (and its
   tooltip says off).
5. Options > AddOns > Leproc: the icon, the Enable box (it matches General's),
   and the button closes the game's options and opens Leproc's window.
6. The minimap button: either click opens and closes the window (no menu).
   Drag moves it around the minimap. The addon compartment does the same.
7. Profiles tab, the only place they're managed: new, switch, copy, rename,
   delete and reset as before. Each profile keeps its own window size, place
   and tab.
8. **Switching by talents**: `/leproc spec` lists your three talent trees with
   their points and says which has the most (Forever's talent trees: this is
   the first test of reading them). Do the names and points match your talent
   window? With dual spec, after switching spec?
9. On the Profiles tab, tick "Switch profile by my talents or group role",
    make a second profile and pick it for the tree with your most points: it
    switches at once, with a line in chat. Respec or switch spec: it follows.
10. **Switching by role**: in a group, set your role (or have the leader set
    it) with a rule for that role: it switches, and back to the talent rule
    when you leave the group. Change role in combat: nothing until combat ends.
11. Reset all settings (General): asks first, then reloads with everything
    back to the defaults (the welcome shows again).

## To check: rebuild step 2a (1.0.0-dev)

The glows are back for reactive abilities. The file list changed again:
**restart the game** after the install script. Every reactive ability of your
class is on, in any stance (the tab to choose is 2b). Put them on a bar that
doesn't change with stance (bar 2, say), and keep `/leproc log` on while
testing (the session section below).

1. Revenge: block, dodge or parry in Battle Stance: it glows for about 4.5 s
   (5 s less the measured delay). In Defensive Stance it follows the game
   exactly. Use it: dark for its 5 s cooldown, even if you block again.
2. Overpower: your target dodges your attack: it glows in Battle Stance (the
   game) and in Defensive and Berserker Stance (Leproc's window). In a group,
   a target's dodge while you're out of combat doesn't light it.
3. **Execute** (new, ProcGlow's rule, first time in game): put it on a bar,
   fight something down past 20% in Battle Stance, then Berserker Stance. Does
   it stay dark above 20% and light below (the game's usable answer)? In
   Defensive Stance it can't light (expected). Short of rage it still glows.
4. **Victory Rush** (new): after a kill that gives experience or honour it
   glows, in any stance, until you use it or it runs out.
5. Blizzard's own highlight: does Forever ever highlight any of these itself?
   The log says "game: button highlight ON for ...". Where it does, the glow
   follows it.
6. A paladin, if you have one: **Hammer of Wrath** below 20%; **Exorcism** on
   undead and demons in the open world, not on anything else, and dark for 15 s
   after you use it. In a dungeon it can't light (the game hides what your
   target is): check that it stays dark there rather than lighting wrongly.
7. A rogue's Riposte after a parry; a hunter's Counterattack (parry) and
   Mongoose Bite (your own dodge).
8. EllesmereUI's bars: glows on its buttons, never on Blizzard's hidden ones,
   right after login and after `/reload`.
8a. **Your macros, as they are** (the fix for the screenshot): `/leproc test`
   lights MKR (shows Revenge), MKOP (Overpower) and Victory Rush, and **not**
   either MKSB, MKSS or MKH. `/leproc macros` says what each shows, e.g.
   `macro "MKR" shows Revenge, counts for Revenge` and `macro "MKSB" shows
   Shield Block, no tracked ability`. After a block in Battle Stance, MKR glows
   wherever it's on screen.
8b. **When Revenge has no button on screen** (it's only on the Defensive Stance
   page): after a block in Battle Stance the Defensive Stance button glows
   instead (the stance bar's, if yours is shown, and any button showing
   Defensive Stance), and `/leproc why revenge` says "so the buttons for
   Defensive Stance glow instead". Switch: Revenge's own button glows. Does
   `/leproc bars` count your stance bar buttons ("... stance bar buttons
   found")? If it says 0 with EllesmereUI's stance bar showing, tell me.
9. `/leproc test` lights your abilities for 5 s. `/leproc why revenge` right
   after a block: lit, the window's seconds, the stance, Blizzard's highlight,
   the buttons. `/leproc bars`, `macros`, `rescan`.
10. General > Enable Leproc off: nothing glows, and `/leproc test` says it's off.
11. The glow is 0.x's gold pixel glow until the Glow tab (step 3).

## Capturing a session for comparison (the log is back since step 2a)

Leproc's log says what Leproc saw and did; the game's combat log says what
really happened (whose attack was dodged). Together, `tools/compare_logs.py`
shows every false glow and miss and which signals came with each dodge.

1. Install the latest build; `/leproc help` shows it.
2. `/console enableFloatingCombatText 1` and
   `/console floatingCombatTextReactives 1` (for the reactive-alert probe).
3. `/leproc log clear`, `/leproc log`.
4. `/combatlog` (chat confirms; again after a logout or `/reload` if it
   doesn't). Advanced combat logging isn't needed.
5. Play. Then `/combatlog` to stop, `/reload` (saves Leproc's log).
6. Send `WTF\Account\<account>\SavedVariables\Leproc.lua` and the newest
   `Logs\WoWCombatLog...txt` (zipped). Leproc keeps 10000 lines: several
   dungeons.

## To check (0.9.0-beta; superseded by the rebuild)

0. First install: fully restart the game. The AddOns list and the addon
   compartment show Leproc's icon: a glowing gold square with a lightning bolt,
   on dark red.
1. No Lua errors on login. `/leproc help` prints the commands with a build
   number.
2. **The main point**, on a warrior with Revenge on a bar that doesn't change
   with stance (bar 2, say):
   - 2a. In Battle Stance, fight something until you block, dodge or parry.
     Revenge's button glows for about 5 s. Most blocks are partial (some damage
     still gets through): those should light it too.
   - 2b. Switch to Defensive Stance while it glows and use Revenge: the glow goes.
   - 2c. Block again right after using it: it stays dark until its 5 s
     cooldown ends.
   - 2d. Overpower: when your target dodges, Overpower glows in Defensive and
     Berserker Stance too.
   - 2e. In a group, does Overpower also light when your target dodges someone
     else's attack? (Expected: yes. The game only says that the target dodged.)
   - 2f. All of this inside a dungeon, in combat.
3. Revenge on the main bar's Defensive Stance page only: in Battle Stance it
   can't glow, and the Abilities tab says "(not on screen)" on one line.
4. Abilities tab: Revenge and Overpower with icons. The arrows switch Any
   stance / Only in Defensive Stance / Off, and changed ones say "(changed)".
   With "Only in Defensive Stance", a block in Battle Stance doesn't light it,
   and switching to Defensive inside the 5 s does.
5. Glow tab: each style shows on the sample and on the buttons (Test). Do Modern
   and Classic line up with the button? Pick a sound, block: it plays once per
   lighting, in combat too.
6. Macros: a macro that casts Revenge glows like the spell does. A
   stance-dance macro (`/cast [nostance:2] Defensive Stance; Revenge`) glows in
   Battle Stance after a block. A macro naming both
   (`/cast [stance:1] Overpower; [stance:2] Revenge`) glows for either.
7. Minimap button: click opens the window, right-click runs the test, drag
   moves it, clear of Nothing Wasted's, Ticky's and Leboof's buttons.
8. Profiles tab: as Leboof's. Each character's own profile is named by first and
   last name, and a second character can share it.
9. Other classes: a rogue's Riposte after a parry; a hunter's Counterattack
   (parry) and Mongoose Bite (your dodge).
10. With EllesmereUI's action bars: the Abilities tab no longer says "not on
    screen" for abilities on its bars, and they glow there (2a to 2f again),
    right after login and after a `/reload`. Also with no bar addon.
    Bartender, Dominos or ElvUI, if you have one.
11. Diagnostics: `/leproc bars` lists your EllesmereUI buttons holding Revenge
    and Overpower (by name and slot) and counts Blizzard's hidden ones;
    `/leproc macros` shows each macro and what it counts for; `/leproc why
    revenge` right after a block says lit, the window's seconds left, and the
    buttons. Send the output if anything looks off.
12. Countdown (Glow tab, "Show the seconds left on the button"): a lit button
    shows 5, 4, 3... in its middle, readable at your button size, and it goes
    when the glow goes. Off by default.
13. Options > AddOns lists Leproc; its button closes the game's options and
    opens Leproc's window.
14. Also glow (Abilities tab, under Revenge): pick Defensive Stance. Block in
    Battle Stance: Revenge glows, and so does Defensive Stance on the stance
    bar (EllesmereUI's stance bar too? `/leproc bars` says how many stance
    buttons it found) and on any action button holding it. Switch to
    Defensive: only Revenge still glows.
15. Proc buffs, the game showing the glow:
    - Victory Rush glows after a kill (Victorious) and stops when you use it
      or it runs out, in and out of combat.
    - With Bloodthrill talented, keep Rend up and hit: when it procs,
      Overpower glows, also in Defensive Stance, in combat, inside a dungeon.
    - Does the glow move (Pixel's dashes march) or sit still? Only the game
      runs it in combat, so motion is the thing to watch.
    - `/leproc why overpower` has a "buff:" line; if it says "unavailable",
      send the text.
    - Hunters: Expose Prey lights Mongoose Bite.
16. Class procs (any of your characters): the ability glows while the proc is
    up, in combat too. Druid: Eclipse lights Starfire in Bear and Cat Form.
    Rogue: Cutthroat lights Ambush out of Stealth. Warlock: Shadow Trance and
    Decimation. Mage, shaman, paladin as in the README. Note which never
    light: their buff IDs are guesses from Forever's data.
17. `/leproc log`, for the Overpower problem below: turn it on, fight in
    Battle Stance until Overpower glows after a dodge, then `/leproc log show`,
    Ctrl+C, and paste it to me. What to look for: after "your target dodged",
    the line where the game says Overpower is no longer usable, whether it says
    "no (short of power)" or a plain "no", and what you cast just before.
18. Death and combat end: after dying, or once combat ends, nothing glows
    (the log says "windows cleared").
19. The new timing (the build after the second log, 2026-11-08):
    - Defensive Stance: Revenge glows the instant you block (before, it came
      about half a second late) and goes dark exactly when the game says, never
      after.
    - Battle Stance: Overpower glows when the game says, and stops when the
      game stops it (the PvP case).
    - Revenge in Battle Stance (a guess): `/leproc why revenge` shows the
      measured delay; the glow ends that much before 5 s.
    - A false Overpower glow in Defensive Stance goes out when you switch to
      Battle Stance (the log says "no longer usable -> its window closes").
    - With `/leproc log` on, "the block/dodge/parry report came 0.x s after the
      game" lines show the delay being measured.
20. The proc-highlight probe (log only): `/leproc log clear`, `/leproc log`,
    then fight with Overpower procs in Battle Stance and in Defensive Stance,
    in a group if you can, with the combat log saved too. In the log, look
    for "game: button highlight ON for Overpower" or "screen proc alert ON":
    does it come with your own dodged attacks, in which stances, and does it
    ever come for a party member's? Also "highlighted: yes/no" on each
    "your target dodged" line. Send both logs.
21. Out of combat, your target's dodges are ignored: with `/leproc log` on,
    target someone a party member is fighting before you pull: "-> ignored:
    you're not in combat", and no Overpower glow.
22. The reactive-alert probe (log only), the owner's rule: "if something dodges
    MY attack, light Overpower". First make sure the game sends the alerts:
    `/console enableFloatingCombatText 1` and
    `/console floatingCombatTextReactives 1` (or the "Reactive spells" combat
    text option); `/leproc log` prints both settings when it starts. Then
    fight with Overpower procs in Battle Stance and in Defensive Stance, in a
    group, with the game's combat log saved. In the log: does "game: reactive
    alert (SPELL_ACTIVE)" come right after "your target dodged" when it was
    your attack (combat log: "Kam's ... was dodged"), never after a party
    member's, and in Defensive Stance too? Send both logs.

## Confirmed

- 9f623d4: loads, `/leproc` opens the window with the build and icon, and the
  Abilities tab lists Revenge and Overpower for a warrior.

## Problems

- 2026-11-18 group session (24d56e2, Kam Pf, 53 min open world in a party,
  nearly all in Defensive Stance; `tools/compare_logs.py` after its fix for
  Forever's 19-field advanced block):
  - **Revenge: right.** 160 windows; the one "miss" was the out-of-stance
    report delay (lit 0.9 s after a dodge in Berserker Stance), and the 20
    "false" were 0.3-0.5 s overlaps in Defensive Stance where the game
    decides (clock noise between the two logs). Its cooldown is honoured: the
    game says usable during it, Leproc stays dark until it ends.
  - **Overpower in Defensive Stance: half wrong in a group.** Your target
    dodged 50 times: 25 your attacks, 25 Noraz's (a party druid). Neither
    probe tells them apart: the reactive alert came with 8 of yours and 6 of
    his (its spell is secret, and it fires for Revenge too), Blizzard's
    highlight with none. So 24 false Overpower glows. The 17 "misses" were the
    report's lateness (0.4 s) or the target dying right after your dodged
    swing. Decision pending (ROADMAP).
  - The log is spammed with "screen proc alert off for everything" lines
    (`SPELL_ACTIVATION_OVERLAY_HIDE` with no spell).

- 0ddf9ba / 118bbe5: Overpower glows when it isn't usable, on the spell and on
  a macro. No Bloodthrill talent, so it's the "your target dodged" window.
  The e4280bc log (party PvP, open world) showed: target dodged, the game said
  Overpower usable 0.1 s later (so it was the owner's own attack), then not
  usable 1.2 s after that, with no cast of it; Leproc kept glowing to 5 s.
  Either rage ran short or Forever ends the window early: the next log says
  which (item 17). Same log: Revenge lit after a death (fixed: windows clear
  on death and at the end of combat); once, the game said Revenge was usable
  on switching to Defensive Stance with no block, dodge or parry logged
  before it (watch for this again).
- e4280bc+a89b890 second log (party, Defensive Stance tanking): Leproc's rules
  matched the game's (5 s windows, cast closes, cooldown), but the game made
  Revenge usable 0.2-0.9 s before the block/dodge/parry report arrived (e.g.
  t939.4 vs t940.1), and ended it 5 s after its own start, so Leproc lit late
  and stayed lit ~0.5 s too long. That also explains the first log's
  "usable before any trigger". Fixed in the next build: the game decides in
  the stance, the delay is measured and taken off elsewhere (item 19).
- Fourth log (still the a89b890 build: the update hadn't been installed),
  Battle Stance: the game opened Overpower at t635.9 and t643.8 and ended it
  exactly 5.0 s later both times; the target-dodge reports came 0.5 s and
  0.3 s after the game. So Overpower's window isn't short (the PvP case stays
  unexplained), and target dodges are reported late too: their starting delay
  is 0.4 s now. Same log: t667.3-668.5 the old build lit Revenge (cooldown
  over) while the game said not usable, the false glow 0264c54 fixes; and
  t144.9-148.6 a block in Battle Stance lit Revenge, the owner switched and
  used it, as designed.
- Fifth log (2026-11-09; old build, then 0.9.0-beta from t3007): the new build
  lit Revenge the instant the game said (t3033.3), the parry report came 0.5 s
  later and the delay was learned; a cast turned it off. At t3153.8 Overpower
  lit in Defensive Stance from "your target dodged" 3.6 s after a Charge, in a
  group of five: the owner's own swing or a party member's, which Leproc can't
  tell apart. Next: the proc-highlight probe (item 20) and the game's combat
  log next to Leproc's.
- Sixth log (2026-11-09, 0.9.0-beta 0f8a000): t3498.1-3502.1 four "your
  target dodged" lit Overpower while the owner wasn't in combat (a party
  member fighting his target): now ignored. t3580.1 a target dodge 0.7 s after
  his Sunder lit Overpower in Defensive Stance; at t3581.9 he switched to
  Battle Stance, the game said not usable and Leproc closed it on the spot
  (as designed). That dodge wasn't one that enabled his Overpower: likely a
  party member's. Mid-fight ones like it still light; the probe (item 20)
  or "Only in its stance" are the answers so far.

- 9f623d4: with EllesmereUI's action bars, Revenge and Overpower said "not on a
  bar you can see" although both were on its bars: Leproc only looked at
  Blizzard's buttons, which EllesmereUI hides. The label also wrapped onto the
  next row. Fixed in the next build (any addon's buttons; shorter label): check
  item 10.
