-- Leproc: a draggable minimap button (no libraries), and the game's addon compartment entry.
-- Left-click opens the options window; right-click lights your abilities' buttons for a test.
local _, ns = ...

local M = {}
ns.Minimap = M

local button

local function UpdatePosition()
	local angle = math.rad(ns.db.minimap.angle)
	local radius = Minimap:GetWidth() / 2 + 5
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function FollowCursor()
	local mx, my = Minimap:GetCenter()
	local cx, cy = GetCursorPosition()
	local scale = Minimap:GetEffectiveScale()
	ns.db.minimap.angle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
	UpdatePosition()
end

local function OnClick(mouseButton)
	if mouseButton == "RightButton" then
		ns.Track.Test()
	else
		ns.Window.Toggle()
	end
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

	local border = button:CreateTexture(nil, "OVERLAY")
	border:SetSize(53, 53)
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetPoint("TOPLEFT")

	button:SetScript("OnClick", function(_, mouseButton) OnClick(mouseButton) end)
	button:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", FollowCursor) end)
	button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:AddLine("Leproc")
		GameTooltip:AddLine("Click for options.", 1, 1, 1)
		GameTooltip:AddLine("Right-click to light your abilities' buttons for " .. ns.WINDOW .. " s, as a test.", 1, 1, 1)
		GameTooltip:AddLine("Drag to move this button.", 0.7, 0.7, 0.7)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", GameTooltip_Hide)
end

-- The game's addon menu by the minimap (AddonCompartmentFunc in the .toc).
function Leproc_OnAddonCompartmentClick(_, mouseButton)
	OnClick(mouseButton)
end

function M.SetShown(shown)
	ns.db.minimap.hide = not shown
	if button then button:SetShown(shown) end
	if ns.Window then ns.Window.Refresh() end
end

-- Shows the button where the current profile has it (at login, and when the profile changes).
function M.Apply()
	if not button then return end
	UpdatePosition()
	button:SetShown(not ns.db.minimap.hide)
end

function M.Init()
	Build()
	M.Apply()
end
