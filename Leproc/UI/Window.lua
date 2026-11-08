-- Leproc: the options window, in the same style as Nothing Wasted's: tabs across the top, a
-- Defaults button for the page shown, a resize grip. Pages register with Window.AddPage.
local _, ns = ...

local Window = {}
ns.Window = Window

local WIDTH, HEIGHT = 600, 500
local MIN_W, MIN_H, MAX_W, MAX_H = 560, 340, 1200, 1000
local TABS_Y = -36
local TAB_HEIGHT = 24
local GOLD = { 1, 0.82, 0 }
local GREY = { 0.62, 0.62, 0.62 }
local RULE = { 0.6, 0.45, 0.15, 0.6 }

local frame, content, defaultsButton
local tabButtons = {}
local pages, pageOrder = {}, {}
local current

-- def: { id, label, build(panel), refresh(panel), defaults() (optional) }; tabs follow the order added.
function Window.AddPage(def)
	pages[def.id] = def
	pageOrder[#pageOrder + 1] = def
end

local function StyleTab(b, selected)
	local color = selected and GOLD or GREY
	b.text:SetTextColor(color[1], color[2], color[3])
	b.underline:SetShown(selected)
end

local function TabButton(parent, label)
	local b = CreateFrame("Button", nil, parent)
	b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	b.text:SetPoint("CENTER", 0, 1)
	b.text:SetText(label)
	b:SetSize(math.max(40, (b.text:GetStringWidth() or 60) + 24), TAB_HEIGHT)
	b.underline = b:CreateTexture(nil, "ARTWORK")
	b.underline:SetPoint("BOTTOMLEFT", 8, 0)
	b.underline:SetPoint("BOTTOMRIGHT", -8, 0)
	b.underline:SetHeight(2)
	b.underline:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.9)
	b.underline:Hide()
	b:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")
	return b
end

function Window.Select(id)
	if not pages[id] then id = pageOrder[1].id end
	current = id
	ns.db.window.tab = id
	for _, def in ipairs(pageOrder) do
		StyleTab(tabButtons[def.id], def.id == id)
		if def.id == id then
			if not def.panel.built then
				def.build(def.panel)
				def.panel.built = true
			end
			def.panel:Show()
		else
			def.panel:Hide()
		end
	end
	defaultsButton:SetShown(pages[id].defaults ~= nil)
	Window.Refresh()
end

function Window.Refresh()
	if not frame or not frame:IsShown() or not current then return end
	local def = pages[current]
	if def.refresh and def.panel.built then def.refresh(def.panel) end
end

local function SavePosition()
	local point, _, relPoint, x, y = frame:GetPoint()
	ns.db.window.pos = { point, relPoint, x, y }
end

local function SaveSize()
	ns.db.window.size = { math.floor(frame:GetWidth() + 0.5), math.floor(frame:GetHeight() + 0.5) }
end

-- The resize grip in the bottom-right corner, like the chat windows'.
local function AddResizeGrip()
	frame:SetResizable(true)
	frame:SetResizeBounds(MIN_W, MIN_H, MAX_W, MAX_H)
	local grip = CreateFrame("Button", nil, frame)
	grip:SetSize(16, 16)
	grip:SetPoint("BOTTOMRIGHT", -4, 4)
	grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
	grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	grip:SetScript("OnMouseDown", function() frame:StartSizing("BOTTOMRIGHT") end)
	grip:SetScript("OnMouseUp", function()
		frame:StopMovingOrSizing()
		SaveSize()
		SavePosition()
	end)
end

local function Build()
	frame = CreateFrame("Frame", "LeprocFrame", UIParent, "BackdropTemplate")
	local size = ns.db.window.size
	if size then
		frame:SetSize(math.max(MIN_W, math.min(MAX_W, size[1])), math.max(MIN_H, math.min(MAX_H, size[2])))
	else
		frame:SetSize(WIDTH, HEIGHT)
	end
	frame:SetFrameStrata("HIGH")
	frame:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	frame:SetBackdropColor(0.05, 0.06, 0.09, 0.94)
	frame:SetBackdropBorderColor(0.6, 0.45, 0.15, 1)
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		SavePosition()
	end)
	local pos = ns.db.window.pos
	if pos then
		frame:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
	else
		frame:SetPoint("CENTER")
	end
	frame:Hide()
	tinsert(UISpecialFrames, "LeprocFrame") -- Escape closes the window

	-- Title bar: icon, name, build and close.
	local icon = frame:CreateTexture(nil, "ARTWORK")
	icon:SetSize(18, 18)
	icon:SetPoint("TOPLEFT", 14, -10)
	icon:SetTexture(ns.ICON)
	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("LEFT", icon, "RIGHT", 6, 0)
	title:SetText("Leproc")
	local version = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	version:SetPoint("LEFT", title, "RIGHT", 8, 0)
	version:SetText(ns.Version())

	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -2, -2)

	-- Tabs, then a rule under them, with the Defaults button at the right of the tab row.
	local x = 12
	for _, def in ipairs(pageOrder) do
		local b = TabButton(frame, def.label)
		b:SetPoint("TOPLEFT", x, TABS_Y)
		b:SetScript("OnClick", function() Window.Select(def.id) end)
		tabButtons[def.id] = b
		x = x + b:GetWidth() + 2
	end
	local rule = frame:CreateTexture(nil, "BORDER")
	rule:SetPoint("TOPLEFT", 12, TABS_Y - TAB_HEIGHT - 2)
	rule:SetPoint("TOPRIGHT", -12, TABS_Y - TAB_HEIGHT - 2)
	rule:SetHeight(1)
	rule:SetColorTexture(RULE[1], RULE[2], RULE[3], RULE[4])

	defaultsButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	defaultsButton:SetSize(90, 20)
	defaultsButton:SetPoint("TOPRIGHT", -16, TABS_Y - 2)
	defaultsButton:SetText("Defaults")
	defaultsButton:SetScript("OnClick", function()
		local def = pages[current]
		if def and def.defaults then
			def.defaults()
			ns.Refresh()
			Window.Refresh()
		end
	end)

	content = CreateFrame("Frame", nil, frame)
	content:SetPoint("TOPLEFT", 14, TABS_Y - TAB_HEIGHT - 10)
	content:SetPoint("BOTTOMRIGHT", -14, 14)
	for _, def in ipairs(pageOrder) do
		local panel = CreateFrame("Frame", nil, content)
		panel:SetAllPoints()
		panel:Hide()
		def.panel = panel
	end

	AddResizeGrip()

	frame:SetScript("OnShow", function() Window.Select(current or ns.db.window.tab) end)
end

-- An entry in the game's Options > AddOns list: a short page with a button that opens Leproc's
-- own window (the options live there).
function Window.Register()
	if Window.category or not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
	local panel = CreateFrame("Frame")
	panel.name = "Leproc"
	local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText("Leproc " .. ns.Version())
	local text = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
	text:SetPoint("RIGHT", -16, 0)
	text:SetJustifyH("LEFT")
	text:SetText("Glows Revenge, Overpower and other reactive abilities when they're ready, in any stance or form. The options have their own window: /leproc, or the minimap button.")
	local open = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	open:SetSize(200, 26)
	open:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -14)
	open:SetText("Open Leproc's options")
	open:SetScript("OnClick", function()
		if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
		Window.Show()
	end)
	panel.open = open
	Window.category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
	Settings.RegisterAddOnCategory(Window.category)
end

-- The panel of the page being shown (used by the tests).
function Window.CurrentPanel()
	return current and pages[current] and pages[current].panel
end

function Window.Show(page)
	if not frame then Build() end
	frame:Show()
	if page then Window.Select(page) end
end

function Window.Hide()
	if frame then frame:Hide() end
end

function Window.IsShown()
	return frame and frame:IsShown()
end

function Window.Toggle(page)
	if Window.IsShown() and (not page or page == current) then
		Window.Hide()
	else
		Window.Show(page)
	end
end
