# Testing in game

What to check after installing a build (`tools\install_forever.cmd`, then
`/reload`). Note the build `/leproc help` shows. Results go in Confirmed or
Problems below.

## To check (0.1.0)

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

## Confirmed

- 9f623d4: loads, `/leproc` opens the window with the build and icon, and the
  Abilities tab lists Revenge and Overpower for a warrior.

## Problems

- 9f623d4: with EllesmereUI's action bars, Revenge and Overpower said "not on a
  bar you can see" although both were on its bars: Leproc only looked at
  Blizzard's buttons, which EllesmereUI hides. The label also wrapped onto the
  next row. Fixed in the next build (any addon's buttons; shorter label): check
  item 10.
