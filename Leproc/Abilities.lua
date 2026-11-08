-- Leproc: the catalogue. Each ability lights up after something happens in a fight (you block,
-- dodge or parry, or your target dodges), whatever stance or form you're in. Spell IDs come from
-- Data.lua, by name (tools/gen_data.py).
--   key        short id, used in settings and /leproc <key>
--   names      the ability's spell names (every rank shares the name)
--   class      the class it belongs to (the Abilities tab shows your class's)
--   after      what opens its window: "block", "dodge", "parry" (yours), "targetdodge" (your target's)
--   buff       a proc buff that also makes it usable, and buffIds its spell IDs (explicit: the talent
--              that grants it shares the name, and a talent's ID would match all the time). The game
--              shows the glow for these itself (Procs.lua), in combat too.
--   stance     the stance the game requires, if any ("Only in its stance" uses it)
--   cooldown   seconds after you use it before it can be used again
--   note       shown in its tooltip
local _, ns = ...

-- How long an ability stays usable after its trigger (the game's reactive window).
ns.WINDOW = 5

ns.Catalogue = {
	{ key = "revenge", names = { "Revenge" }, class = "WARRIOR", after = { "block", "dodge", "parry" },
		stance = "Defensive Stance", cooldown = 5 },
	{ key = "overpower", names = { "Overpower" }, class = "WARRIOR", after = { "targetdodge" },
		stance = "Battle Stance", cooldown = 5, buff = "Bloodthrill", buffIds = { 1289681 },
		note = "In a group it may also light when your target dodges someone else's attack: the game only says that the target dodged." },
	{ key = "victoryrush", names = { "Victory Rush" }, class = "WARRIOR", after = {}, cooldown = 0,
		buff = "Victorious", buffIds = { 402975 } },
	{ key = "riposte", names = { "Riposte" }, class = "ROGUE", after = { "parry" }, cooldown = 6 },
	{ key = "counterattack", names = { "Counterattack" }, class = "HUNTER", after = { "parry" }, cooldown = 5 },
	{ key = "mongoosebite", names = { "Mongoose Bite" }, class = "HUNTER", after = { "dodge" }, cooldown = 5,
		buff = "Expose Prey", buffIds = { 1310726 } },
}
