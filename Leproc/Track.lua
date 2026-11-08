-- Leproc: when each ability is lit. The game reports blocks, dodges and parries (UNIT_COMBAT) to
-- addons even in combat: only the damage number is secret. So an ability's window opens on its
-- trigger whatever stance you're in, and the game's own "usable" (which says no outside the right
-- stance) is never asked. Using the ability closes the window and starts its cooldown (timed from
-- your cast: UNIT_SPELLCAST_SUCCEEDED). Mode "stance" also needs the stance the ability requires.
local _, ns = ...

local Track = {}
ns.Track = Track

local open = {}    -- key -> when its window closes
local ready = {}   -- key -> when its cooldown ends
local test = 0     -- /leproc test: everything tracked is lit until then
local lit = {}     -- key -> lit at the last Update (for the sound)

local function Secret(v)
	return issecretvalue and issecretvalue(v)
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

function Track.IsLit(e)
	local mode = ns.Mode(e)
	if mode == "off" then return false end
	local now = GetTime()
	if test > now then return true end
	if not (open[e.key] and open[e.key] > now) then return false end
	if ready[e.key] and ready[e.key] > now then return false end
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
	local now, opened = GetTime(), {}
	for _, e in ipairs(ns.Catalogue) do
		if e.triggers[trigger] then
			open[e.key] = now + ns.WINDOW
			opened[#opened + 1] = e
		end
	end
	if #opened > 0 then
		ns.Log.Trigger(trigger, unit, event, flags, opened)
		Track.Update()
		UpdateAt(ns.WINDOW)
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
		trigger = "targetdodge"
	end
	if trigger then Open(trigger, unit, event, flags) end
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

-- Seconds left on a lit ability (its window, or the test's), for the countdown; nil if not lit.
function Track.Left(e)
	if not Track.IsLit(e) then return nil end
	local now = GetTime()
	if test > now then return test - now end
	return open[e.key] - now
end

-- What Leproc knows about an ability right now, for /leproc why: seconds left in its window and
-- on its cooldown (nil if none), whether you're in its stance, whether the test is on.
function Track.State(e)
	local now = GetTime()
	local function Left(t) return (t and t > now) and (t - now) or nil end
	return { window = Left(open[e.key]), cooldown = Left(ready[e.key]), inStance = InStance(e), test = test > now }
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
-- (A stance change is handled in Bars.lua, once the bars have changed too.)
events:SetScript("OnEvent", function(_, event, a, b, c)
	if event == "UNIT_COMBAT" then
		Track.OnUnitCombat(a, b, c)
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		Track.OnCast(c)
	elseif event == "PLAYER_DEAD" then
		Track.Clear("you died")
	elseif event == "PLAYER_REGEN_ENABLED" then
		Track.Clear("combat ended")
	end
end)
