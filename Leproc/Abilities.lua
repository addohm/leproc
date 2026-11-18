-- Leproc: the catalogue of reactive abilities (ProcGlow's list). Each is usable only for a moment:
-- after a trigger (you block, dodge or parry, or your target dodges), at low target health
-- (Execute, Hammer of Wrath), after a kill (Victory Rush), or on the right target (Exorcism). The
-- game says when, in the ability's stance; for the trigger abilities Leproc also lights them in
-- any other stance, from the triggers (Track.lua). Spell IDs come from Data.lua, by name
-- (tools/gen_data.py).
--   key          short id, used in settings and /leproc why <key>
--   names        the ability's spell names (every rank shares the name)
--   class        the class it belongs to
--   after        what opens its window: "block", "dodge", "parry" (yours), "targetdodge" (your
--                target's). Empty: only the game knows (target health is secret to addons).
--   stances      the stances the game requires, if any ("Only in its stance" uses them)
--   cooldown     seconds after you use it before it can be used again
--   targetTypes  creature type IDs it works on (UnitCreatureType): 3 Demon, 6 Undead
--   note         shown in its tooltip
-- Proc buffs (Shadow Trance, Hot Streak...) come back in step 4 of the rebuild.
local _, ns = ...

-- How long an ability stays usable after its trigger (the game's reactive window).
ns.WINDOW = 5

ns.Catalogue = {
	{ key = "overpower", names = { "Overpower" }, class = "WARRIOR", after = { "targetdodge" },
		stances = { "Battle Stance" }, cooldown = 5,
		note = "In a group it may also light when your target dodges someone else's attack: the game only says that the target dodged." },
	{ key = "revenge", names = { "Revenge" }, class = "WARRIOR", after = { "block", "dodge", "parry" },
		stances = { "Defensive Stance" }, cooldown = 5 },
	{ key = "execute", names = { "Execute" }, class = "WARRIOR", after = {},
		stances = { "Battle Stance", "Berserker Stance" }, cooldown = 0,
		note = "Lights when the game says it's usable (your target below 20% health). Addons can't see the target's health, so it can't light in Defensive Stance." },
	{ key = "victoryrush", names = { "Victory Rush" }, class = "WARRIOR", after = {}, cooldown = 0,
		note = "Lights when the game says it's usable: for a while after you kill an enemy that gives experience or honour." },
	{ key = "riposte", names = { "Riposte" }, class = "ROGUE", after = { "parry" }, cooldown = 6 },
	{ key = "counterattack", names = { "Counterattack" }, class = "HUNTER", after = { "parry" }, cooldown = 5 },
	{ key = "mongoosebite", names = { "Mongoose Bite" }, class = "HUNTER", after = { "dodge" }, cooldown = 5 },
	{ key = "hammerofwrath", names = { "Hammer of Wrath" }, class = "PALADIN", after = {}, cooldown = 6,
		note = "Lights when the game says it's usable (your target below 20% health)." },
	{ key = "exorcism", names = { "Exorcism" }, class = "PALADIN", after = {}, cooldown = 15, targetTypes = { 3, 6 },
		note = "Lights while your target is undead or a demon and Exorcism is ready. In dungeons the game hides what your target is, so it can't light there." },
}
