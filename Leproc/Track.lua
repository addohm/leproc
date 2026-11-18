-- Leproc: when each ability is lit. ProcGlow's order, then Leproc's own window where the game
-- can't answer:
--
-- 1. Turned off, another class's, or Leproc off: never.
-- 2. Used: dark for its cooldown, timed from your cast (UNIT_SPELLCAST_SUCCEEDED), or the game's
--    own cooldown where it shows it (C_Spell.GetSpellCooldown, secret while cooldowns are
--    restricted; the global cooldown doesn't count).
-- 3. Blizzard's own proc highlight (C_SpellActivationOverlay.IsSpellOverlayed): lit.
-- 4. A target-type ability (Exorcism): lit only on the right target (UnitCreatureType; secret in
--    dungeons, so never there) and when the game says usable.
-- 5. The game, in the ability's own stance (always, for abilities without one):
--    C_Spell.IsSpellUsable decides, exact at both ends. "Short of power" still counts (it's up,
--    rage just hasn't caught up).
-- 6. Elsewhere, for the trigger abilities in "any stance" mode: Leproc's own window. The game
--    reports blocks, dodges and parries to addons even in combat (UNIT_COMBAT; only the amount is
--    secret), so a trigger opens a 5 s window whatever stance you're in. The reports come late
--    (the owner's logs: 0.2-0.9 s after the game's own change), so Leproc measures that delay
--    while the game can answer (LeprocDB.delay) and ends its windows that much sooner.
--
-- While the game answers, its changes also set Leproc's window (so it's right when you then
-- switch stance), and its "no" closes it. Death and the end of combat close every window.
local _, ns = ...

local Track = {}
ns.Track = Track

Track.TRIGGERS = { block = "you block", dodge = "you dodge", parry = "you parry", targetdodge = "your target dodges" }

local open = {}       -- key -> when its window closes
local ready = {}      -- key -> when its cooldown ends (from your cast)
local test = 0        -- /leproc test: your abilities are lit until then
local lit = {}        -- key -> lit at the last Update (for the log)
local game = {}       -- key -> "active" / "inactive": the game's last answer while it gave one
local activeAt = {}   -- key -> when the game last said its window opened (for measuring the delay)
local reportedAt = {} -- key -> { time, kind }: the last trigger report for it
local stanceAt = -10  -- when the stance last changed

-- The kinds of trigger, for the delay: your own block/dodge/parry, and your target's dodge. The
-- starting values are from the owner's logs: 0.2-0.9 s for your own (Defensive Stance tanking),
-- 0.3-0.5 s for the target's (Overpower in Battle Stance).
local KIND = { block = "player", dodge = "player", parry = "player", targetdodge = "target" }

-- Reports that don't say whose attack it was. In a group, half of your target's dodges are
-- someone else's (the owner's group session, 2026-11-18: 25 of 50 in Defensive Stance were a party
-- member's, and nothing the game gives addons tells them apart). So in a group they open no window
-- of Leproc's: Overpower lights where the game knows (Battle Stance), and a window the game opened
-- there carries on if you then switch stance. Solo, every dodge of your target is yours.
local AMBIGUOUS = { targetdodge = true }

local function Grouped()
	local ok, yes = pcall(IsInGroup)
	return ok and not ns.Secret(yes) and yes == true
end
Track.Grouped = Grouped
local DELAY = { player = 0.5, target = 0.4 }
local MAX_DELAY = 1.5
local GCD = 1.5

local Secret = ns.Secret

local function Number(v)
	if type(v) == "number" and not Secret(v) then return v end
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

-- True if you're in a stance the ability requires (always, for abilities without one).
local function InStance(e)
	if not e.stanceIds then return true end
	local ok, index = pcall(GetShapeshiftForm)
	if not ok or not Number(index) or index == 0 then return false end
	local _, active, _, spellID = GetShapeshiftFormInfo(index)
	return active and Number(spellID) ~= nil and e.stanceIds[spellID] == true
end
Track.InStance = InStance

-- The game's answer, where it can give one: "yes", "short" (only power is missing), "no", or
-- nil (not in the ability's stance, a hidden value, an error).
local function GameSays(e)
	if not InStance(e) then return nil end
	local ok, usable, short = pcall(C_Spell.IsSpellUsable, e.names[1])
	if not ok or Secret(usable) or Secret(short) then return nil end
	if usable then return "yes" end
	if short then return "short" end
	return "no"
end
Track.GameSays = GameSays

-- Seconds left on the game's own cooldown for it (not the global cooldown), 0 if none, or nil if
-- the game hides it right now.
local function GameCooldown(e)
	if not (C_Spell and C_Spell.GetSpellCooldown) then return nil end
	local ok, info = pcall(C_Spell.GetSpellCooldown, e.names[1])
	if not ok then return nil end
	if type(info) ~= "table" then return 0 end
	local start, duration = Number(info.startTime), Number(info.duration)
	if not (start and duration) then return nil end
	if start == 0 or duration <= GCD then return 0 end
	return math.max(0, start + duration - GetTime())
end

-- Seconds left on its cooldown: the longer of the game's (when shown) and the one timed from your
-- cast; 0 when ready.
local function Cooldown(e)
	local mine = ready[e.key] and math.max(0, ready[e.key] - GetTime()) or 0
	return math.max(mine, GameCooldown(e) or 0)
end

-- Whether Blizzard highlights it now (its own proc glow), any rank.
local function Overlay(e)
	local api = C_SpellActivationOverlay and C_SpellActivationOverlay.IsSpellOverlayed
	if not api then return false end
	for _, id in ipairs(e.idList) do
		local ok, on = pcall(api, id)
		if ok and on == true then return true end
	end
	return false
end

-- For a target-type ability: true if your target is one it works on, false if not, nil if the
-- game hides what it is (in dungeons) or there's no living enemy targeted.
local function TargetFits(e)
	local ok, yes = pcall(function()
		if not UnitExists("target") or UnitIsDead("target") or not UnitCanAttack("player", "target") then return nil end
		local _, id = UnitCreatureType("target")
		if not Number(id) then return nil end
		return e.types[id] == true
	end)
	if ok then return yes end
end

function Track.IsLit(e)
	if not ns.db or not ns.Enabled() then return false end
	local mode = ns.Mode(e)
	if mode == "off" then return false end
	local now = GetTime()
	if test > now then return true end
	if Cooldown(e) > 0 then return false end
	if Overlay(e) then return true end
	local says = GameSays(e)
	if e.types then return TargetFits(e) == true and says ~= nil and says ~= "no" end
	if says then return says ~= "no" end
	if #e.after == 0 or mode == "stance" then return false end
	return open[e.key] ~= nil and open[e.key] > now
end

-- Works out what's lit and glows the buttons. Called on every change, and by a timer when a
-- window closes or a cooldown ends.
function Track.Update()
	if not ns.db then return end
	for _, e in ipairs(ns.Catalogue) do
		local on = Track.IsLit(e)
		if on ~= (lit[e.key] or false) then ns.Log.Glow(e, on) end
		lit[e.key] = on
	end
	ns.Bars.Update(lit)
end

-- Several events in one frame (a fight sends many) make one Update, on the next frame.
local soon = false
function Track.Soon()
	if soon then return end
	soon = true
	C_Timer.After(0, function()
		soon = false
		Track.Update()
	end)
end

local function UpdateAt(seconds)
	C_Timer.NewTimer(seconds + 0.05, Track.Update)
end

local function Open(trigger, unit, event, flags)
	local now, opened, held, kind = GetTime(), {}, {}, KIND[trigger]
	local ends = now + ns.WINDOW - Track.Delay(kind)
	local guess = not (AMBIGUOUS[trigger] and Grouped())
	for _, e in ipairs(ns.Catalogue) do
		if e.triggers[trigger] then
			-- The game said the window opened shortly before this report: that's the delay.
			if activeAt[e.key] and now - activeAt[e.key] < MAX_DELAY then
				Sample(kind, now - activeAt[e.key])
				activeAt[e.key] = nil
			end
			reportedAt[e.key] = { now, kind }
			if guess then
				if not open[e.key] or open[e.key] < ends then open[e.key] = ends end
				opened[#opened + 1] = e
			else
				held[#held + 1] = e
			end
		end
	end
	if #held > 0 then
		ns.Log.Grouped(trigger, unit, event, held)
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

-- The game changed its mind about something being usable. For each trigger ability it can answer
-- for: its window opening (not just because you switched into the stance) starts Leproc's window
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
					-- The report came first (target dodges do): no delay. The game confirms the
					-- window (it was your attack), in a group too.
					Sample(r[2], 0)
					if not open[e.key] or open[e.key] < now + ns.WINDOW then
						open[e.key] = now + ns.WINDOW
						UpdateAt(ns.WINDOW)
					end
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
	if changed then Track.Update() else Track.Soon() end
end

function Track.OnCast(spellID)
	if Secret(spellID) then return end
	local e = ns.bySpell[spellID]
	if not e then return end
	ns.Log.Cast(e)
	open[e.key] = nil
	if e.cooldown > 0 then
		ready[e.key] = GetTime() + e.cooldown
		UpdateAt(e.cooldown)
	end
	Track.Update()
end

-- Seconds left on a lit ability (its window, or the test's), for the countdown; nil if not lit,
-- 0 if lit but its end isn't known (the game says usable, with no window of Leproc's).
function Track.Left(e)
	if not Track.IsLit(e) then return nil end
	local now = GetTime()
	if test > now then return test - now end
	return (open[e.key] and open[e.key] > now) and (open[e.key] - now) or 0
end

-- What Leproc knows about an ability right now, for /leproc why.
function Track.State(e)
	local now = GetTime()
	local function Left(t) return (t and t > now) and (t - now) or nil end
	local cd = Cooldown(e)
	return { window = Left(open[e.key]), cooldown = cd > 0 and cd or nil, gameCooldown = GameCooldown(e),
		inStance = InStance(e), test = test > now, game = GameSays(e), overlay = Overlay(e),
		target = e.types and TargetFits(e) or nil }
end

-- Lights your class's tracked abilities' buttons for one window, to see the glow.
function Track.Test()
	if not ns.Enabled() then
		ns.Print("test: Leproc is off (General tab), so nothing lights.")
		return
	end
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
for _, event in ipairs({ "PLAYER_DEAD", "PLAYER_REGEN_ENABLED", "ACTION_USABLE_CHANGED", "SPELL_UPDATE_USABLE",
	"UPDATE_SHAPESHIFT_FORM", "PLAYER_TARGET_CHANGED", "SPELL_UPDATE_COOLDOWN" }) do
	events:RegisterEvent(event)
end
-- Blizzard's proc highlights, one by one in case a client lacks them.
for _, event in ipairs({ "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" }) do
	pcall(events.RegisterEvent, events, event)
end
-- (Bars.lua redraws on a stance change, once the bars have changed too.)
events:SetScript("OnEvent", function(_, event, a, b, c)
	if not ns.db then return end
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
	elseif event == "ACTION_USABLE_CHANGED" or event == "SPELL_UPDATE_USABLE" then
		Track.OnGame()
	else
		Track.Soon()
	end
end)
