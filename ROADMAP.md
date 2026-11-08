# Roadmap

What's done for leproc, and what's next. Update it in the same commit as the
change.

## Done

- Standard docs (2026-11-08).
- Install and release tools from Leboof (2026-11-08).
- 0.1.0: block, dodge and parry abilities glow in any stance (Revenge, Overpower,
  Riposte, Counterattack, Mongoose Bite) on Blizzard's action bars, with the
  options window, profiles, glow styles, a sound and the minimap button
  (2026-11-08). Not yet tried in game.

## Next

1. Check 0.1.0 in game (TESTING.md).
2. Buff procs (Clearcasting, Eclipse -> Starfire and others): readable out of
   combat in any form; in combat, light the glow through Leboof's aura
   container trick (the game sizes the glow frame, Leproc never reads the
   buff). Needs a probe first.
3. Execute and Hammer of Wrath: target health is secret in Forever. Probe
   whether the game can fade a glow by health percent (`UnitHealthPercent` with
   a curve); if not, they stay tied to their stance.
4. Other bar addons: Bartender, Dominos, ElvUI.

## Ideas

- A glow on the stance button too, pointing to the stance an ability needs.
- A per-ability glow, colour or sound.
