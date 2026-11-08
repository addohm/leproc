-- Leproc: the glows on action buttons, from any bar addon (Blizzard's, EllesmereUI's, Bartender's,
-- Dominos', ElvUI's...). Bars.Scan walks every frame (EnumerateFrames) for buttons that hold an
-- action slot, out of combat, and gives each Leproc's own overlay frame; the glow is drawn on
-- that, never on the button itself. Which ability a button holds comes from GetActionInfo(slot):
-- a spell, or a macro that casts one. A button only glows while it's on screen, so bars an addon
-- hides (Blizzard's, under EllesmereUI) never do, and an ability on a bar page that changes with
-- stance (a warrior's main bar) can't light in the other stances.
local _, ns = ...

local Bars = {}
ns.Bars = Bars

local buttons = {}   -- action buttons found, in the order found
local overlays = {}  -- button -> Leproc's overlay frame
local pending = false -- a scan was asked for in combat

local function Secret(v)
	return issecretvalue and issecretvalue(v)
end

local function Number(v)
	if type(v) == "number" and not Secret(v) and v > 0 then return v end
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

-- The ability (catalogue entry) on a button, if any.
local function EntryOn(button)
	local slot = Slot(button)
	if not slot then return nil end
	local ok, kind, id, sub = pcall(GetActionInfo, slot)
	if not ok or Secret(kind) or Secret(id) then return nil end
	if kind == "spell" or (kind == "macro" and sub == "spell") then
		return ns.bySpell[id]
	end
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

function Bars.Init()
	Bars.Scan()
end

function Bars.Update()
	for _, button in ipairs(buttons) do
		local e = EntryOn(button)
		local on = e and button:IsVisible() and ns.Track.IsLit(e)
		local size = math.floor((button:GetWidth() or 0) + 0.5)
		if size <= 0 then size = 36 end
		ns.Glow.Show(overlays[button], on and ns.db.glow or "none", ns.db.color, size)
	end
end

-- True if the ability is on a button you can see right now.
function Bars.OnScreen(e)
	for _, button in ipairs(buttons) do
		if button:IsVisible() and EntryOn(button) == e then return true end
	end
	return false
end

local function Changed()
	ns.Track.Update()
	if ns.Window then ns.Window.Refresh() end
end

-- A stance change or a page flip changes what the buttons hold. Bar addons update their buttons
-- in their own handlers for these events, so look once they've run. Buttons themselves only
-- appear when a bar addon builds them, which may be after login: scan again when the world is
-- entered and a few seconds later, and after combat if a scan had to wait.
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
		C_Timer.After(3, function()
			Bars.Scan()
			Changed()
		end)
	end
	C_Timer.After(0, Changed)
end)
