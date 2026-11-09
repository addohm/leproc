-- Leproc: when each ability is lit. Two sources, the better one wins:
--
-- 1. The game, where it can answer: in the ability's own stance (always, for abilities without
--    one), C_Spell.IsSpellUsable says whether its reactive window is open. "Short of power" still
--    counts (the window is open, rage just hasn't caught up). It's exact at both ends: it changes
--    the moment the window opens or closes (ACTION_USABLE_CHANGED, SPELL_UPDATE_USABLE).
-- 2. Leproc's own window, everywhere else: the game reports blocks, dodges and parries to addons
--    even in combat (UNIT_COMBAT; only the damage number is secret), so a trigger opens a 5 s
--    window whatever stance you're in. Those reports come late: the owner's logs show the game
--    making Revenge usable 0.2-0.9 s before the report of the block arrives. Leproc measures that
--    delay while the game can answer (`LeprocDB.delay`, per kind of trigger) and ends its own
--    windows that much sooner.
--
-- While the game answers, its changes also set Leproc's window (so it's right when you then
-- switch stance), and its "no" closes it. Using the ability starts its cooldown (timed from your
-- cast: UNIT_SPELLCAST_SUCCEEDED; the game's "usable" ignores cooldowns). Death and the end of
-- combat close every window. Mode "stance" lights only in the ability's stance.
local _, ns = ...

local Track = {}
ns.Track = Track

local open = {}       -- key -> when its window closes
local ready = {}      -- key -> when its cooldown ends
local test = 0        -- /leproc test: everything tracked is lit until then
local lit = {}        -- key -> lit at the last Update (for the sound)
local game = {}       -- key -> "active" / "inactive": the game's last answer while it gave one
local activeAt = {}   -- key -> when the game last said its window opened (for measuring the delay)
local reportedAt = {} -- key -> { time, kind }: the last trigger report for it
local stanceAt = -10  -- when the stance last changed

-- The kinds of trigger, for the delay: your own block/dodge/parry, and your target's dodge. The
-- starting values are from the owner's logs: 0.2-0.9 s for your own (Defensive Stance tanking),
-- 0.3-0.5 s for the target's (Overpower in Battle Stance).
local KIND = { block = "player", dodge = "player", parry = "player", targetdodge = "target" }
local DELAY = { player = 0.5, target = 0.4 }
local MAX_DELAY = 1.5

local function Secret(v)
	return issecretvalue and issecretvalue(v)
end

-- The measured delay of a kind of trigger report.
function Track.Delay(kind)
	local saved = LeprocDB and LeprocDB.delay
	return (saved and saved[kind]) or DELAY[kind] or 0
end

local function Sample(kind, seconds)
	if not LeprocDB then return end
	LeprocDB.delay = LeprocDB.delay or {}
	local d = math.max(0, math.min(MAX_DELAY, seconds))
	LeprocDB.delay[kind] = Track.Delay(kind) * 0.7 + d * 0.3
	ns.Log.Delay(kind, d, LeprocDB.delay[kind])
end

-- True if you're in the stance the ability requires.
local function InStance(e)
	if not e.stanceIds then return true end
	local index = GetShapeshiftForm()
	if not index or index == 0 or Secret(index) then return false end
	local _, active, _, spellID = GetShapeshiftFormInfo(index)
	return active and not Secret(spellID) and e.stanceIds[spellID] == true
end
Track.InStance = InStance

-- The game's answer, where it can give one: "yes", "short" (only power is missing), "no", or
-- nil (not in the ability's stance, a hidden value, an error, or an ability lit by a buff).
local function GameSays(e)
	if #e.after == 0 or not InStance(e) then return nil end
	local ok, usable, short = pcall(C_Spell.IsSpellUsable, e.names[1])
	if not ok or Secret(usable) or Secret(short) then return nil end
	if usable then return "yes" end
	if short then return "short" end
	return "no"
end
Track.GameSays = GameSays

function Track.IsLit(e)
	local mode = ns.Mode(e)
	if mode == "off" then return false end
	local now = GetTime()
	if test > now then return true end
	if ready[e.key] and ready[e.key] > now then return false end
	local says = GameSays(e)
	if says then return says ~= "no" end
	if not (open[e.key] and open[e.key] > now) then return false end
	return mode ~= "stance" or InStance(e)
end

-- Works out what's lit, glows the buttons, and plays the sound for anything newly lit. Called on
-- every change, and by a timer when a window closes or a cooldown ends.
function Track.Update()
	if not ns.db then return end
	local newly = false
	for _, e in ipairs(ns.Catalogue) do
		local on = Track.IsLit(e)
		if on and not lit[e.key] and test <= GetTime() then newly = true end
		if on ~= (lit[e.key] or false) then ns.Log.Glow(e, on) end
		lit[e.key] = on
	end
	ns.Bars.Update()
	if newly then ns.Play(ns.db.sound) end
end

local function UpdateAt(seconds)
	C_Timer.NewTimer(seconds + 0.05, Track.Update)
end

local function Open(trigger, unit, event, flags)
	local now, opened, kind = GetTime(), {}, KIND[trigger]
	local ends = now + ns.WINDOW - Track.Delay(kind)
	for _, e in ipairs(ns.Catalogue) do
		if e.triggers[trigger] then
			-- The game said the window opened shortly before this report: that's the delay.
			if activeAt[e.key] and now - activeAt[e.key] < MAX_DELAY then
				Sample(kind, now - activeAt[e.key])
				activeAt[e.key] = nil
			end
			reportedAt[e.key] = { now, kind }
			if not open[e.key] or open[e.key] < ends then open[e.key] = ends end
			opened[#opened + 1] = e
		end
	end
	if #opened > 0 then
		ns.Log.Trigger(trigger, unit, event, flags, opened, ends - now)
		Track.Update()
		UpdateAt(ends - now)
	end
end

-- UNIT_COMBAT: (unit, event, flagText, amount, schoolMask). A partial block is a WOUND with
-- BLOCK_REDUCED (most Classic blocks are partial); a full block is BLOCK, or a WOUND flagged BLOCK.
function Track.OnUnitCombat(unit, event, flags)
	if Secret(unit) or Secret(event) or Secret(flags) then return end
	local trigger
	if unit == "player" then
		if event == "DODGE" then trigger = "dodge"
		elseif event == "PARRY" then trigger = "parry"
		elseif event == "BLOCK" or (event == "WOUND" and (flags == "BLOCK_REDUCED" or flags == "BLOCK")) then trigger = "block"
		end
	elseif unit == "target" and event == "DODGE" then
		-- The game doesn't say whose attack your target dodged. Out of combat it can't have been
		-- yours (the owner's log: four of them while a party member fought his target), and you
		-- can't use the ability anyway.
		local ok, fighting = pcall(UnitAffectingCombat, "player")
		if ok and not Secret(fighting) and not fighting then
			ns.Log.Ignored("your target dodged (target DODGE)", "you're not in combat, so it wasn't your attack")
			return
		end
		trigger = "targetdodge"
	end
	if trigger then Open(trigger, unit, event, flags) end
end

-- The game changed its mind about something being usable. For each ability it can answer for:
-- its window opening (not just because you switched into the stance) starts Leproc's window
-- now, and its window closing closes Leproc's. Switching into the stance while Leproc's guess is
-- open and the game says it's over closes the guess too.
function Track.OnGame()
	local now, changed = GetTime(), false
	for _, e in ipairs(ns.Catalogue) do
		-- Only abilities you track (other classes' are off): their answers mean nothing for you.
		if #e.after > 0 and ns.Mode(e) ~= "off" then
			local says = GameSays(e)
			local state = says and (says == "no" and "inactive" or "active") or nil
			local before = game[e.key]
			if state == "active" and before == "inactive" and now - stanceAt > 0.3 then
				local r = reportedAt[e.key]
				if r and now - r[1] < MAX_DELAY then
					-- The report came first (target dodges do): no delay, and its window stands.
					Sample(r[2], 0)
				else
					activeAt[e.key] = now
					open[e.key] = now + ns.WINDOW
					UpdateAt(ns.WINDOW)
				end
				ns.Log.GameOpened(e)
				changed = true
			elseif state == "inactive" and (before == "active" or before == nil) and open[e.key] and open[e.key] > now then
				open[e.key] = nil
				ns.Log.GameClosed(e)
				changed = true
			end
			game[e.key] = state
		end
	end
	if changed then Track.Update() end
end

function Track.OnCast(spellID)
	if Secret(spellID) then return end
	local e = ns.bySpell[spellID]
	if not e then return end
	ns.Log.Cast(e)
	open[e.key] = nil
	ready[e.key] = GetTime() + e.cooldown
	Track.Update()
	UpdateAt(e.cooldown)
end

-- Seconds left on a lit ability (its window, or the test's), for the countdown; nil if not lit,
-- 0 if lit but its end isn't known (the game says usable, with no window of Leproc's).
function Track.Left(e)
	if not Track.IsLit(e) then return nil end
	local now = GetTime()
	if test > now then return test - now end
	return (open[e.key] and open[e.key] > now) and (open[e.key] - now) or 0
end

-- What Leproc knows about an ability right now, for /leproc why: seconds left in its window and
-- on its cooldown (nil if none), whether you're in its stance, the game's answer, the test.
function Track.State(e)
	local now = GetTime()
	local function Left(t) return (t and t > now) and (t - now) or nil end
	return { window = Left(open[e.key]), cooldown = Left(ready[e.key]), inStance = InStance(e), test = test > now,
		game = GameSays(e) }
end

-- Lights every tracked ability's buttons for one window, to see the glow (no sound).
function Track.Test()
	test = GetTime() + ns.WINDOW
	Track.Update()
	UpdateAt(ns.WINDOW)
	local names = {}
	for _, e in ipairs(ns.ClassEntries()) do
		if ns.Mode(e) ~= "off" then names[#names + 1] = e.label end
	end
	if #names == 0 then
		ns.Print("test: nothing of your class is tracked, so no button lights.")
	else
		ns.Print("test: lighting " .. table.concat(names, ", ") .. " for " .. ns.WINDOW .. " s, wherever they're on a bar you can see.")
	end
end

-- Death and the end of combat close every window: nothing is left to use it on, and a cooldown
-- ending later mustn't light it (it did after a death).
function Track.Clear(why)
	if next(open) == nil then return end
	wipe(open)
	ns.Log.Cleared(why)
	Track.Update()
end

local events = CreateFrame("Frame")
events:RegisterUnitEvent("UNIT_COMBAT", "player", "target")
events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
events:RegisterEvent("PLAYER_DEAD")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("ACTION_USABLE_CHANGED")
events:RegisterEvent("SPELL_UPDATE_USABLE")
events:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
-- (Bars.lua redraws on a stance change, once the bars have changed too.)
events:SetScript("OnEvent", function(_, event, a, b, c)
	if event == "UNIT_COMBAT" then
		Track.OnUnitCombat(a, b, c)
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		Track.OnCast(c)
	elseif event == "PLAYER_DEAD" then
		Track.Clear("you died")
	elseif event == "PLAYER_REGEN_ENABLED" then
		Track.Clear("combat ended")
	elseif event == "UPDATE_SHAPESHIFT_FORM" then
		stanceAt = GetTime()
	elseif ns.db then
		Track.OnGame()
	end
end)
