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
- Optional countdown on lit buttons; Leproc in Options > AddOns (2026-11-08).
- Proc buffs through Blizzard's aura containers: Bloodthrill (Overpower),
  Victorious (Victory Rush), Expose Prey (Mongoose Bite) (2026-11-08).
- Also glow: a stance's button (stance bar, or an action button holding it)
  while an ability is lit and you're not in that stance (2026-11-08).
- Every bar on ProcGlow's list tested; late bar addons noticed; macros count
  for every tracked ability their text names, so stance-dance macros glow
  (2026-11-08).

## Next

Picked on 2026-11-08 from the ProcGlow comparison, in this order:

1. Check 0.1.0 in game (TESTING.md).
2. Class procs (Eclipse -> Starfire, Cutthroat -> Ambush, Shadow Trance ->
   Shadow Bolt, the mage procs...) on the same aura-container mechanism, each
   checked against Forever first (its data also holds Season of Discovery
   runes).
3. Execute and Hammer of Wrath: target health is secret in Forever. Probe
   whether the game can fade a glow by health percent (`UnitHealthPercent` with
   a curve); if not, they stay tied to their stance.

## Ideas

- A per-ability glow, colour or sound.
