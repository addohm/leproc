-- Leproc: a draggable minimap button (no libraries), and the game's addon compartment entry. A
-- click opens or closes the options window (profiles are managed on their tab). The icon greys out
-- while Leproc is turned off.
local _, ns = ...

local M = {}
ns.Minimap = M

local button

local function UpdatePosition()
	local angle = math.rad(ns.db.minimap.angle)
	local x, y = math.cos(angle), math.sin(angle)
	-- On a square minimap the button follows the square's edge.
	local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
	if shape ~= "ROUND" then
		local m = math.max(math.abs(x), math.abs(y))
		if m > 0 then x, y = x / m, y / m end
	end
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", x * (Minimap:GetWidth() / 2 + 5), y * (Minimap:GetHeight() / 2 + 5))
end

local function FollowCursor()
	local mx, my = Minimap:GetCenter()
	local cx, cy = GetCursorPosition()
	local scale = Minimap:GetEffectiveScale()
	ns.db.minimap.angle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
	UpdatePosition()
end

local function OnClick()
	ns.Window.Toggle()
end

local function Build()
	button = CreateFrame("Button", "LeprocMinimapButton", Minimap)
	button:SetSize(31, 31)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(8)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:RegisterForDrag("LeftButton")
	button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	local background = button:CreateTexture(nil, "BACKGROUND")
	background:SetSize(20, 20)
	background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	background:SetPoint("TOPLEFT", 7, -5)

	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetSize(17, 17)
	icon:SetTexture(ns.ICON)
	icon:SetTexCoord(0.04, 0.96, 0.04, 0.96)
	icon:SetPoint("TOPLEFT", 7, -6)
	button.icon = icon

	local border = button:CreateTexture(nil, "OVERLAY")
	border:SetSize(53, 53)
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetPoint("TOPLEFT")

	button:SetScript("OnClick", OnClick)
	button:SetScript("OnDragStart", function(self)
		self.dragging = true
		GameTooltip:Hide()
		self:SetScript("OnUpdate", FollowCursor)
	end)
	button:SetScript("OnDragStop", function(self)
		self.dragging = nil
		self:SetScript("OnUpdate", nil)
	end)
	button:SetScript("OnEnter", function(self)
		if self.dragging then return end
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:AddLine("Leproc" .. (ns.Enabled() and "" or " |cff999999(off)|r"))
		GameTooltip:AddLine("Click for options.", 1, 1, 1)
		GameTooltip:AddLine("Profile: " .. ns.Profiles.Current(), 1, 0.82, 0)
		GameTooltip:AddLine("Drag to move this button.", 0.7, 0.7, 0.7)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", GameTooltip_Hide)
end

-- The game's addon menu by the minimap (AddonCompartmentFunc in the .toc).
function Leproc_OnAddonCompartmentClick()
	OnClick()
end

function M.SetShown(shown)
	ns.db.minimap.hide = not shown
	M.Apply()
	if ns.Window then ns.Window.Refresh() end
end

-- Shows the button where the current profile has it, grey while Leproc is off (at login, and
-- whenever settings or the profile change).
function M.Apply()
	if not button then return end
	UpdatePosition()
	button:SetShown(not ns.db.minimap.hide)
	button.icon:SetDesaturated(not ns.Enabled())
end

function M.Button()
	return button
end

function M.Init()
	if not button then Build() end
	M.Apply()
end
