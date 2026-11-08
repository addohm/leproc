# Roadmap

What's done for leproc, and what's next. Update it in the same commit as the
change.

## Done

- Standard docs (2026-11-08).
- Install and release tools from Leboof (2026-11-08).
- 0.1.0: block, dodge and parry abilities glow in any stance (Revenge, Overpower,
  Riposte, Counterattack, Mongoose Bite) on the action bars, with the
  options window, profiles, glow styles, a sound and the minimap button
  (2026-11-08). Tried in game: the window opens; abilities on EllesmereUI's
  bars weren't found.
- Buttons from any bar addon, found by scanning (2026-11-08).
- Diagnostics: `/leproc bars`, `/leproc macros`, `/leproc why` (2026-11-08).
- Every bar on ProcGlow's list tested; late bar addons noticed; macros count
  for every tracked ability their text names, so stance-dance macros glow
  (2026-11-08).

## Next

Picked on 2026-11-08 from the ProcGlow comparison, in this order:

1. Check 0.1.0 in game (TESTING.md).
2. A countdown (seconds left) on the glowing button, optional; Leproc in the
   game's Options > AddOns list.
3. Also glow another button: the stance button an ability needs (stance bar,
   or an action button holding the stance), while you're not in it.
4. Buff procs: Forever's Bloodthrill (Overpower), Expose Prey (Mongoose Bite)
   and Victorious (Victory Rush), then class procs (Clearcasting, Eclipse ->
   Starfire, Shadow Trance and others). Readable out of combat in any form; in
   combat through Blizzard's aura containers, as ProcGlow does: a slot per proc
   buff, the glow attached to it over the action button, so the game shows it
   with the buff and Leproc never reads it.
5. Execute and Hammer of Wrath: target health is secret in Forever. Probe
   whether the game can fade a glow by health percent (`UnitHealthPercent` with
   a curve); if not, they stay tied to their stance.

## Ideas

- A glow on the stance button too, pointing to the stance an ability needs.
- A per-ability glow, colour or sound.
