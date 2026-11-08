-- Leproc: the glows on action buttons, from any bar addon. Bars.Scan walks every frame
-- (EnumerateFrames) for buttons that hold an action slot, out of combat, and gives each Leproc's
-- own overlay frame; the glow is drawn on that, never on the button itself. That finds every bar
-- on ProcGlow's list (Blizzard's, Bartender's, Dominos', ElvUI's, EllesmereUI's, the gamepad
-- bars) and any other. A button only glows while it's on screen, so bars an addon hides
-- (Blizzard's, under EllesmereUI) never do, and an ability on a bar page that changes with stance
-- (a warrior's main bar) can't light in the other stances.
--
-- An ability can also glow a stance's button while it's lit and you're not in that stance
-- (ns.db.also): the stance bar's button for it, and any action button holding the stance. Stance
-- bar buttons are found by name (StanceButton1, BT4StanceButton1, DominosStanceButton1,
-- ElvUI_StanceBarButton1...: "Stance", then "Button" and the stance's number).
--
-- What a button holds: GetActionInfo(slot) gives a spell, or the spell a macro would cast right
-- now. A macro also counts for every tracked ability its text names, so a stance-dance macro
-- (/cast [nostance:2] Defensive Stance; Revenge) is Revenge's button even in Battle Stance, when
-- it would cast Defensive Stance.
local _, ns = ...

local Bars = {}
ns.Bars = Bars

local buttons = {}   -- action buttons found, in the order found
local stances = {}   -- stance bar buttons found: { button, the stance's number }
local overlays = {}  -- button -> Leproc's overlay frame
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

local function Secret(v)
	return issecretvalue and issecretvalue(v)
end

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

-- Tracked abilities by lower-case name: the English names, and the game's own (localized).
local byName = {}
local function Names()
	for _, e in ipairs(ns.Catalogue) do
		for _, name in ipairs(e.names) do byName[name:lower()] = e end
		for _, id in ipairs(e.idList) do
			local ok, name = pcall(C_Spell.GetSpellName, id)
			if ok and Text(name) then byName[name:lower()] = e end
		end
	end
end

-- The tracked abilities a macro's text names, on #show(tooltip), /cast, /castsequence,
-- /castrandom and /use lines, in any clause: "[stance:1] Overpower; [stance:2] Revenge" names
-- both. Conditions, reset=, "!" and "(Rank 3)" are ignored. Cached by text.
local parsed = {}
local function MacroEntries(body)
	if parsed[body] then return parsed[body] end
	local list, seen = {}, {}
	for line in body:lower():gmatch("[^\n]+") do
		local args = line:match("^%s*#show%a*%s+(.+)") or line:match("^%s*/cast%a*%s+(.+)")
			or line:match("^%s*/use%s+(.+)")
		if args then
			args = args:gsub("%b[]", ""):gsub("reset=%S+", "")
			for part in args:gmatch("[^;,]+") do
				local name = part:gsub("%(.-%)", ""):gsub("^[%s!]+", ""):gsub("%s+$", "")
				local e = byName[name]
				if e and not seen[e] then
					seen[e] = true
					list[#list + 1] = e
				end
			end
		end
	end
	parsed[body] = list
	return list
end

-- A macro's text: by the name the button shows (when the slot reports the spell the macro
-- casts, its ID isn't the macro's), else by the macro's index.
local function MacroBody(slot, id, sub)
	local getText = (C_ActionBar and C_ActionBar.GetActionText) or GetActionText
	local ok, name = pcall(getText, slot)
	local body
	if ok and Text(name) then
		local okInfo, _, _, b = pcall(GetMacroInfo, name)
		if okInfo then body = Text(b) end
	end
	if not body and sub ~= "spell" and Number(id) then
		local okInfo, _, _, b = pcall(GetMacroInfo, id)
		if okInfo then body = Text(b) end
	end
	return body
end

-- The tracked abilities (catalogue entries) a button holds: none, one, or a macro's several.
local NONE = {}
local function EntriesOn(button)
	local slot = Slot(button)
	if not slot then return NONE end
	local ok, kind, id, sub = pcall(GetActionInfo, slot)
	if not ok or Secret(kind) or Secret(id) or Secret(sub) then return NONE end
	local direct = (kind == "spell" or (kind == "macro" and sub == "spell")) and ns.bySpell[id] or nil
	if kind ~= "macro" then return direct and { direct } or NONE end
	local body = MacroBody(slot, id, sub)
	local list = body and MacroEntries(body) or NONE
	if not direct then return list end
	for _, e in ipairs(list) do
		if e == direct then return list end
	end
	local all = { direct }
	for _, e in ipairs(list) do all[#all + 1] = e end
	return all
end

local function IsActionButton(f)
	local ok, yes = pcall(function()
		if f:IsForbidden() then return false end
		if not (f:IsObjectType("CheckButton") or f:IsObjectType("Button")) then return false end
		return Slot(f) ~= nil
	end)
	return ok and yes
end

-- A stance bar button's stance number, or nil.
local function StanceIndex(f)
	local ok, index = pcall(function()
		if f:IsForbidden() then return nil end
		if not (f:IsObjectType("CheckButton") or f:IsObjectType("Button")) or Slot(f) then return nil end
		local name = Text(f:GetName())
		return name and tonumber(name:match("Stance.-Button(%d+)$"))
	end)
	return ok and index or nil
end

local function SpellName(id)
	if not Number(id) then return nil end
	local ok, name = pcall(C_Spell.GetSpellName, id)
	return ok and Text(name) or nil
end

-- The name of stance number i (from the game), and the one you're in.
local function FormName(i)
	local ok, _, _, _, id = pcall(GetShapeshiftFormInfo, i)
	return ok and SpellName(id) or nil
end

local function CurrentForm()
	local ok, i = pcall(GetShapeshiftForm)
	if ok and Number(i) then return FormName(i) end
end
Bars.CurrentForm = CurrentForm

-- Your stances, by name, for the "Also glow" picker.
function Bars.Forms()
	local list = {}
	local ok, n = pcall(GetNumShapeshiftForms)
	for i = 1, (ok and Number(n)) or 0 do
		local name = FormName(i)
		if name then list[#list + 1] = name end
	end
	return list
end

-- The stances to glow now, with the seconds left on the ability lighting each.
local function Wanted()
	local wanted, current = {}, nil
	for _, e in ipairs(ns.Catalogue) do
		local target = ns.db.also[e.key]
		if target then
			local left = ns.Track.Left(e)
			if left then
				current = current or CurrentForm() or ""
				if target ~= current and (not wanted[target] or left > wanted[target]) then wanted[target] = left end
			end
		end
	end
	return wanted
end

-- The spell a button holds (a spell, or a macro casting one), by name.
local function SpellOn(button)
	local slot = Slot(button)
	if not slot then return nil end
	local ok, kind, id, sub = pcall(GetActionInfo, slot)
	if ok and (kind == "spell" or (kind == "macro" and sub == "spell")) then return SpellName(id) end
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
	Names()
	Bars.Scan()
end

-- The countdown: the seconds left, in the middle of a lit button (if switched on). While
-- anything is lit, a ticker redraws just those buttons' numbers.
local lit = {}       -- the buttons lit at the last Update: { overlay, entries, size }
local ticker

local function Left(entries)
	local left
	for _, e in ipairs(entries) do
		local l = ns.Track.Left(e)
		if l and (not left or l > left) then left = l end
	end
	return left
end

local function Count(overlay, size, left)
	if not overlay.count then
		overlay.count = overlay:CreateFontString(nil, "OVERLAY")
		overlay.count:SetPoint("CENTER")
		overlay.count:SetTextColor(1, 0.95, 0.6)
	end
	if left then
		overlay.count:SetFont(STANDARD_TEXT_FONT, math.max(10, math.floor(size * 0.42)), "THICKOUTLINE")
		overlay.count:SetText(left > 0.05 and tostring(math.max(1, math.ceil(left - 0.01))) or "")
	end
	overlay.count:SetShown(left ~= nil)
end

local function Tick()
	for _, l in ipairs(lit) do Count(l[1], l[3], Left(l[2])) end
end

local function Size(button)
	local size = math.floor((button:GetWidth() or 0) + 0.5)
	return size > 0 and size or 36
end

local function Show(button, left, entries)
	local size = Size(button)
	local overlay = overlays[button]
	ns.Glow.Show(overlay, left and ns.db.glow or "none", ns.db.color, size)
	if (ns.db.countdown and left) or overlay.count then Count(overlay, size, ns.db.countdown and left or nil) end
	if left then lit[#lit + 1] = { overlay, entries, size } end
end

-- A stance glow's entries, for the countdown: the lit abilities pointing at that stance.
local function Pointing(stance)
	local list = {}
	for _, e in ipairs(ns.Catalogue) do
		if ns.db.also[e.key] == stance then list[#list + 1] = e end
	end
	return list
end

function Bars.Update()
	Bars.CheckLate()
	wipe(lit)
	local wanted = Wanted()
	local anyWanted = next(wanted) ~= nil
	local holders = {} -- key -> { button, size } for abilities a proc buff lights (Procs.lua)
	for _, button in ipairs(buttons) do
		local visible = button:IsVisible()
		local entries = visible and EntriesOn(button) or NONE
		for _, e in ipairs(entries) do
			if e.buffSet then
				holders[e.key] = holders[e.key] or {}
				table.insert(holders[e.key], { button, Size(button) })
			end
		end
		local left = Left(entries)
		local stance = anyWanted and visible and SpellOn(button)
		if stance and wanted[stance] then
			if not left or wanted[stance] > left then left = wanted[stance] end
			entries = Pointing(stance)
		end
		Show(button, left, entries)
	end
	for _, s in ipairs(stances) do
		local stance = anyWanted and s[1]:IsVisible() and FormName(s[2])
		Show(s[1], stance and wanted[stance] or nil, stance and Pointing(stance) or NONE)
	end
	ns.Procs.Place(holders)
	local want = ns.db.countdown and #lit > 0
	if want and not ticker then
		ticker = C_Timer.NewTicker(0.1, Tick)
	elseif not want and ticker then
		ticker:Cancel()
		ticker = nil
	end
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

-- Every macro on a button you can see: its name, whether its text could be read, and the tracked
-- abilities it names.
function Bars.MacroReport()
	local lines, seen = {}, {}
	for _, button in ipairs(buttons) do
		local slot = Slot(button)
		if button:IsVisible() and slot and not seen[slot] then
			local ok, kind, id, sub = pcall(GetActionInfo, slot)
			if ok and kind == "macro" and not Secret(id) then
				seen[slot] = true
				local getText = (C_ActionBar and C_ActionBar.GetActionText) or GetActionText
				local okName, name = pcall(getText, slot)
				local body = MacroBody(slot, id, sub)
				local held = EntriesOn(button)
				lines[#lines + 1] = Name(button) .. " (slot " .. slot .. "): macro \"" .. tostring(okName and Text(name) or "?")
					.. "\", " .. (body and "text read" or "|cffff8040text not readable|r")
					.. ", " .. (#held > 0 and ("counts for " .. Labels(held)) or "no tracked ability")
			end
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
