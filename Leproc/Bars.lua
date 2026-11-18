-- Leproc: the glows on action buttons, from any bar addon. Bars.Scan walks every frame
-- (EnumerateFrames) for buttons that hold an action slot, out of combat, and gives each Leproc's
-- own overlay frame; the glow is drawn on that, never on the button itself (no fields or scripts
-- set on a button, nothing protected called). That finds every bar on ProcGlow's list
-- (Blizzard's, Bartender's, Dominos', ElvUI's, EllesmereUI's, the gamepad bars) and any other, and
-- the stance bars (by name: StanceButton1, BT4StanceButton1...). A button only glows while it's on
-- screen, so bars an addon hides (Blizzard's, under EllesmereUI) never do.
--
-- What a button holds is the spell it shows (Macros.lua): a spell, or the spell the game reports
-- for a macro (its icon), plus, for a macro showing a stance, the abilities it's a stance-dance for.
--
-- The player keeps their bars as they are. When an ability is lit but no button you can see holds
-- it (it's on a bar page of another stance: a warrior's main bar swaps with stance), the buttons
-- that take you to its stance glow instead: the stance bar's, and any button showing the stance.
local _, ns = ...

local Bars = {}
ns.Bars = Bars

local buttons = {}   -- action buttons found, in the order found
local stances = {}   -- stance bar buttons found: { button, the stance's number }
local overlays = {}  -- button -> Leproc's overlay frame
local pointing = {}  -- key -> the stances whose buttons glow for it (at the last Update)
local pending = false -- a scan was asked for in combat

-- The first button of each bar addon that may build its bars after login (ProcGlow's list):
-- when one turns up without an overlay, scan again.
Bars.LATE = {
	"EABButton1",                       -- EllesmereUI (EABButton1-180)
	"BT4Button1",                       -- Bartender (BT4Button1-120)
	"DominosActionButton1",             -- Dominos (DominosActionButton1-120)
	"ElvUI_Bar1Button1",                -- ElvUI (ElvUI_Bar1Button1 to ElvUI_Bar15Button12)
	"GamepadMainActionBarFramePageUnitBottomCenteredAnchorBottomBarActionButton1", -- the gamepad UI
}

local Secret = ns.Secret

local function Number(v)
	if type(v) == "number" and not Secret(v) and v > 0 then return v end
end

local function Text(v)
	if type(v) == "string" and v ~= "" and not Secret(v) then return v end
end

-- The action slot a button holds now. Blizzard's buttons keep it in `action`; buttons built on
-- the secure action template keep it in their "action" attribute, and paging ones (stance pages)
-- in `_state_action`.
local function Slot(button)
	local slot = Number(button._state_action) or Number(button.action)
	if slot then return slot end
	local ok, attr = pcall(button.GetAttribute, button, "action")
	return ok and Number(attr) or nil
end

-- The spell a button shows, and what kind of action it is: a spell, or a macro's icon (the game
-- reports it for the slot).
local function Shown(button)
	local slot = Slot(button)
	if not slot then return nil end
	local ok, kind, id, sub = pcall(GetActionInfo, slot)
	if not ok or Secret(kind) or Secret(id) or Secret(sub) then return nil end
	if kind == "spell" or (kind == "macro" and sub == "spell") then return Number(id), kind, slot end
	return nil, kind, slot
end

-- The tracked abilities (catalogue entries) a button holds: the one it shows, or the ones a macro
-- showing a stance dances to.
local NONE = {}
local function EntriesOn(button)
	local id, kind, slot = Shown(button)
	if not id then return NONE end
	local e = ns.bySpell[id]
	if e then return { e } end
	if kind == "macro" then
		local list = ns.Macros.Dance(slot, id)
		if #list > 0 then return list end
	end
	return NONE
end

local function IsActionButton(f)
	local ok, yes = pcall(function()
		if f:IsForbidden() then return false end
		if not (f:IsObjectType("CheckButton") or f:IsObjectType("Button")) then return false end
		return Slot(f) ~= nil
	end)
	return ok and yes
end

local function SpellName(id)
	if not Number(id) then return nil end
	local ok, name = pcall(C_Spell.GetSpellName, id)
	return ok and Text(name) or nil
end

-- A stance bar button's stance number, or nil: a button holding no action slot, named
-- "...Stance...Button<n>".
local function StanceIndex(f)
	local ok, index = pcall(function()
		if f:IsForbidden() then return nil end
		if not (f:IsObjectType("CheckButton") or f:IsObjectType("Button")) or Slot(f) then return nil end
		local name = Text(f:GetName())
		return name and tonumber(name:match("Stance.-Button(%d+)$"))
	end)
	return ok and index or nil
end

-- The spell of stance number i.
local function FormSpell(i)
	local ok, _, _, _, id = pcall(GetShapeshiftFormInfo, i)
	return ok and Number(id) or nil
end

-- The stance you're in, by name (for the log and /leproc why).
function Bars.CurrentForm()
	local ok, i = pcall(GetShapeshiftForm)
	if not (ok and Number(i)) then return nil end
	local okInfo, _, _, _, id = pcall(GetShapeshiftFormInfo, i)
	return okInfo and SpellName(id) or nil
end

-- Finds action buttons not seen before and gives each an overlay. Out of combat only: a bar
-- addon's buttons are protected, so their children are made while nothing is locked.
function Bars.Scan()
	if InCombatLockdown() then
		pending = true
		return
	end
	pending = false
	local f = EnumerateFrames()
	while f do
		if not overlays[f] then
			local index = not IsActionButton(f) and StanceIndex(f)
			if index or IsActionButton(f) then
				local overlay = CreateFrame("Frame", nil, f)
				overlay:SetAllPoints(f)
				overlay:SetFrameLevel(f:GetFrameLevel() + 10)
				overlays[f] = overlay
				if index then
					stances[#stances + 1] = { f, index }
				else
					buttons[#buttons + 1] = f
				end
			end
		end
		f = EnumerateFrames(f)
	end
end

-- Scans again if a bar addon's first button has turned up since the last scan. Returns true if
-- it scanned.
function Bars.CheckLate()
	if InCombatLockdown() then return false end
	for _, name in ipairs(Bars.LATE) do
		local b = _G[name]
		if b and not overlays[b] and IsActionButton(b) then
			Bars.Scan()
			return true
		end
	end
	return false
end

function Bars.Init()
	ns.Macros.Names()
	Bars.Scan()
end

local function Size(button)
	local size = math.floor((button:GetWidth() or 0) + 0.5)
	return size > 0 and size or 36
end

-- Glows every button you can see that holds a lit ability (lit: key -> true, from Track.Update).
-- A lit ability that no button you can see holds, while you're not in its stance, glows the
-- buttons that switch to its stance instead.
function Bars.Update(lit)
	Bars.CheckLate()
	local glow, held = {}, {}
	for _, button in ipairs(buttons) do
		if button:IsVisible() then
			for _, e in ipairs(EntriesOn(button)) do
				held[e.key] = true
				if lit[e.key] then glow[button] = true end
			end
		end
	end
	wipe(pointing)
	local want = {}
	for _, e in ipairs(ns.Catalogue) do
		if lit[e.key] and not held[e.key] and e.stanceIds and not ns.Track.InStance(e) then
			for id in pairs(e.stanceIds) do want[id] = e end
		end
	end
	if next(want) then
		local function Point(id)
			local e = want[id]
			local name = SpellName(id) or "its stance"
			pointing[e.key] = pointing[e.key] or {}
			for _, n in ipairs(pointing[e.key]) do
				if n == name then return end
			end
			table.insert(pointing[e.key], name)
		end
		for _, s in ipairs(stances) do
			local id = s[1]:IsVisible() and FormSpell(s[2])
			if id and want[id] then
				glow[s[1]] = true
				Point(id)
			end
		end
		for _, button in ipairs(buttons) do
			local id = button:IsVisible() and Shown(button)
			if id and want[id] then
				glow[button] = true
				Point(id)
			end
		end
	end
	for _, button in ipairs(buttons) do
		ns.Glow.Show(overlays[button], glow[button] and ns.db.glow or "none", ns.db.color, Size(button))
	end
	for _, s in ipairs(stances) do
		ns.Glow.Show(overlays[s[1]], glow[s[1]] and ns.db.glow or "none", ns.db.color, Size(s[1]))
	end
end

-- The stances whose buttons glow for an ability now (it's lit, but on no button you can see).
function Bars.Pointing(e)
	return pointing[e.key] or NONE
end

-- True if the ability is on a button you can see right now.
function Bars.OnScreen(e)
	Bars.CheckLate()
	for _, button in ipairs(buttons) do
		if button:IsVisible() then
			for _, held in ipairs(EntriesOn(button)) do
				if held == e then return true end
			end
		end
	end
	return false
end

-- Diagnostics (/leproc bars, /leproc macros, /leproc why) ----------------------------------

local function Name(button)
	local ok, name = pcall(button.GetName, button)
	return (ok and Text(name)) or "an unnamed button"
end

local function Labels(list)
	local names = {}
	for _, e in ipairs(list) do names[#names + 1] = e.label end
	return table.concat(names, ", ")
end

-- The buttons you can see that hold the ability, as "EABButton12 (slot 61)".
function Bars.Where(e)
	local where = {}
	for _, button in ipairs(buttons) do
		if button:IsVisible() then
			for _, held in ipairs(EntriesOn(button)) do
				if held == e then where[#where + 1] = Name(button) .. " (slot " .. Slot(button) .. ")" end
			end
		end
	end
	return where
end

-- The action slots of the buttons you can see holding the ability (each once), for /leproc log.
function Bars.Slots(e)
	local slots, seen = {}, {}
	for _, button in ipairs(buttons) do
		local slot = Slot(button)
		if slot and not seen[slot] and button:IsVisible() then
			for _, held in ipairs(EntriesOn(button)) do
				if held == e then
					seen[slot] = true
					slots[#slots + 1] = slot
				end
			end
		end
	end
	return slots
end

-- Every button found: how many, how many on screen, the ones on screen holding a tracked
-- ability, and how many hidden ones hold one (Blizzard's, under a bar addon).
function Bars.Report()
	Bars.CheckLate()
	local shown, hidden, lines = 0, 0, {}
	for _, button in ipairs(buttons) do
		local held = EntriesOn(button)
		if button:IsVisible() then
			shown = shown + 1
			if #held > 0 then lines[#lines + 1] = Name(button) .. " (slot " .. Slot(button) .. "): " .. Labels(held) end
		elseif #held > 0 then
			hidden = hidden + 1
		end
	end
	table.insert(lines, 1, #buttons .. " action buttons and " .. #stances .. " stance bar buttons found, " .. shown
		.. " action buttons on screen. On screen holding a tracked ability:"
		.. (#lines == 0 and " none." or ""))
	if hidden > 0 then lines[#lines + 1] = "and " .. hidden .. " hidden buttons hold one (they can't glow)." end
	return lines
end

-- Every macro on a button you can see: its name, the spell it shows (the game's answer), and the
-- tracked abilities it counts for.
function Bars.MacroReport()
	local lines, seen = {}, {}
	for _, button in ipairs(buttons) do
		local id, kind, slot = Shown(button)
		if button:IsVisible() and kind == "macro" and slot and not seen[slot] then
			seen[slot] = true
			local getText = (C_ActionBar and C_ActionBar.GetActionText) or GetActionText
			local okName, name = pcall(getText, slot)
			local held = EntriesOn(button)
			local dance = id and not ns.bySpell[id] and #held > 0
			lines[#lines + 1] = Name(button) .. " (slot " .. slot .. "): macro \"" .. tostring(okName and Text(name) or "?")
				.. "\" shows " .. (SpellName(id) or "nothing the game names")
				.. ", " .. (#held == 0 and "no tracked ability"
					or ((dance and "a stance-dance for " or "counts for ") .. Labels(held)))
		end
	end
	table.insert(lines, 1, #lines .. " macros on buttons you can see" .. (#lines > 0 and ":" or "."))
	return lines
end

local function Changed()
	ns.Track.Update()
	if ns.Window then ns.Window.Refresh() end
end

-- A stance change or a page flip changes what the buttons hold. Bar addons update their buttons
-- in their own handlers for these events, so look once they've run. Buttons themselves only
-- appear when a bar addon builds them, which may be after login: scan when the world is entered,
-- watch for a late bar addon (Bars.LATE) every 2 s for 30 s after that and on every update, and
-- scan after combat if a scan had to wait.
local events = CreateFrame("Frame")
for _, event in ipairs({ "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR",
	"UPDATE_SHAPESHIFT_FORM", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED" }) do
	events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_REGEN_ENABLED" then
		if not pending then return end
		Bars.Scan()
	elseif event == "PLAYER_ENTERING_WORLD" then
		Bars.Scan()
		C_Timer.NewTicker(2, function()
			if Bars.CheckLate() then Changed() end
		end, 15)
	end
	C_Timer.After(0, Changed)
end)
