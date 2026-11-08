-- Leproc: the glows on action buttons, from any bar addon. Bars.Scan walks every frame
-- (EnumerateFrames) for buttons that hold an action slot, out of combat, and gives each Leproc's
-- own overlay frame; the glow is drawn on that, never on the button itself. That finds every bar
-- on ProcGlow's list (Blizzard's, Bartender's, Dominos', ElvUI's, EllesmereUI's, the gamepad
-- bars) and any other. A button only glows while it's on screen, so bars an addon hides
-- (Blizzard's, under EllesmereUI) never do, and an ability on a bar page that changes with stance
-- (a warrior's main bar) can't light in the other stances.
--
-- What a button holds: GetActionInfo(slot) gives a spell, or the spell a macro would cast right
-- now. A macro also counts for every tracked ability its text names, so a stance-dance macro
-- (/cast [nostance:2] Defensive Stance; Revenge) is Revenge's button even in Battle Stance, when
-- it would cast Defensive Stance.
local _, ns = ...

local Bars = {}
ns.Bars = Bars

local buttons = {}   -- action buttons found, in the order found
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
		if not overlays[f] and IsActionButton(f) then
			local overlay = CreateFrame("Frame", nil, f)
			overlay:SetAllPoints(f)
			overlay:SetFrameLevel(f:GetFrameLevel() + 10)
			buttons[#buttons + 1] = f
			overlays[f] = overlay
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

function Bars.Update()
	Bars.CheckLate()
	for _, button in ipairs(buttons) do
		local on = false
		if button:IsVisible() then
			for _, e in ipairs(EntriesOn(button)) do
				if ns.Track.IsLit(e) then on = true end
			end
		end
		local size = math.floor((button:GetWidth() or 0) + 0.5)
		if size <= 0 then size = 36 end
		ns.Glow.Show(overlays[button], on and ns.db.glow or "none", ns.db.color, size)
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
