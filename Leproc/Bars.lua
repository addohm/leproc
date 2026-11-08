-- Leproc: the glows on Blizzard's action buttons. Each button gets Leproc's own overlay frame
-- (made once at login, out of combat), and the glow is drawn on that, never on the button itself.
-- Which ability a button holds comes from GetActionInfo(button.action): a spell, or a macro that
-- casts one. A button only glows while it's on screen, so an ability on a bar page that changes
-- with stance (a warrior's main bar) can't light in the other stances.
local _, ns = ...

local Bars = {}
ns.Bars = Bars

local PREFIXES = {
	"ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarRightButton",
	"MultiBarLeftButton", "MultiBar5Button", "MultiBar6Button", "MultiBar7Button",
}

local buttons = {}   -- Blizzard's action buttons that exist
local overlays = {}  -- button -> Leproc's overlay frame

local function Secret(v)
	return issecretvalue and issecretvalue(v)
end

-- The ability (catalogue entry) on a button, if any.
local function EntryOn(button)
	local slot = button.action
	if type(slot) ~= "number" or Secret(slot) or slot <= 0 then return nil end
	local ok, kind, id, sub = pcall(GetActionInfo, slot)
	if not ok or Secret(kind) or Secret(id) then return nil end
	if kind == "spell" or (kind == "macro" and sub == "spell") then
		return ns.bySpell[id]
	end
end

function Bars.Init()
	for _, prefix in ipairs(PREFIXES) do
		for i = 1, 12 do
			local button = _G[prefix .. i]
			if button and not overlays[button] then
				local overlay = CreateFrame("Frame", nil, button)
				overlay:SetAllPoints(button)
				overlay:SetFrameLevel(button:GetFrameLevel() + 10)
				buttons[#buttons + 1] = button
				overlays[button] = overlay
			end
		end
	end
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

-- A stance change or a page flip changes what the buttons hold. Blizzard updates button.action
-- in its own handlers for these events, so look once they've run.
local events = CreateFrame("Frame")
for _, event in ipairs({ "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR",
	"UPDATE_SHAPESHIFT_FORM", "PLAYER_ENTERING_WORLD" }) do
	events:RegisterEvent(event)
end
events:SetScript("OnEvent", function()
	C_Timer.After(0, function()
		ns.Track.Update()
		if ns.Window then ns.Window.Refresh() end
	end)
end)
