-- Leproc: the options window, in the style of Leboof's and Nothing Wasted's: tabs across the top, a
-- Defaults button for the page shown, a resize grip. Pages register with Window.AddPage (or
-- Window.Page, for a page of option rows); `order` sets their place.
local _, ns = ...
local UI = ns.UI

local Window = {}
ns.Window = Window

local WIDTH, HEIGHT = 700, 520
local MIN_W, MIN_H, MAX_W, MAX_H = 680, 360, 1300, 1000 -- six tabs and Defaults fit at 680
local TABS_Y = -36
local TAB_HEIGHT = 24

local frame, content, defaultsButton
local tabButtons = {}
local pages, pageOrder = {}, {}
local current

-- def: { id, label, order, build(panel), refresh(panel), defaults() (optional) }.
function Window.AddPage(def)
	pages[def.id] = def
	pageOrder[#pageOrder + 1] = def
	table.sort(pageOrder, function(a, b) return (a.order or 99) < (b.order or 99) end)
end

-- A page of option rows: def = { id, label, order, note, fill(stack, panel), refresh(panel)
-- (default: sync the rows), defaults }.
function Window.Page(def)
	Window.AddPage({
		id = def.id,
		label = def.label,
		order = def.order,
		build = function(panel)
			local top = 0
			if def.note then
				local note = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
				note:SetPoint("TOPLEFT", 4, -2)
				note:SetPoint("TOPRIGHT", -28, -2)
				note:SetJustifyH("LEFT")
				note:SetText(def.note)
				top = -36
			end
			local holder = CreateFrame("Frame", nil, panel)
			holder:SetPoint("TOPLEFT", 0, top)
			holder:SetPoint("BOTTOMRIGHT")
			panel.stack = UI.Stack(holder)
			def.fill(panel.stack, panel)
		end,
		refresh = def.refresh or function(panel) panel.stack:Sync() end,
		defaults = def.defaults,
	})
end

local function StyleTab(b, selected)
	if selected then
		b.text:SetTextColor(ns.Theme.Accent())
	else
		local g = ns.Theme.GREY
		b.text:SetTextColor(g[1], g[2], g[3])
	end
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
	b.underline:Hide()
	b:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")
	return b
end

local function PaintTabs()
	for _, def in ipairs(pageOrder) do
		local b = tabButtons[def.id]
		if b then
			local r, g, bl = ns.Theme.Accent()
			b.underline:SetColorTexture(r, g, bl, 0.9)
			StyleTab(b, def.id == current)
		end
	end
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

-- Size and place from the profile (when it's built, and when the profile changes).
local function Place()
	local w = ns.db.window
	local size = w.size
	if size then
		frame:SetSize(math.max(MIN_W, math.min(MAX_W, size[1])), math.max(MIN_H, math.min(MAX_H, size[2])))
	else
		frame:SetSize(WIDTH, HEIGHT)
	end
	frame:ClearAllPoints()
	local pos = w.pos
	if pos then
		frame:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
	else
		frame:SetPoint("CENTER")
	end
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
	frame:SetFrameStrata("HIGH")
	frame:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	local bg = ns.Theme.BACKGROUND
	frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		SavePosition()
	end)
	Place()
	frame:Hide()
	tinsert(UISpecialFrames, "LeprocFrame") -- Escape closes the window

	-- Title bar: icon, name, version and close.
	local icon = frame:CreateTexture(nil, "ARTWORK")
	icon:SetSize(18, 18)
	icon:SetPoint("TOPLEFT", 14, -10)
	icon:SetTexture(ns.ICON)
	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("LEFT", icon, "RIGHT", 6, 0)
	title:SetText("Leproc")
	local version = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	version:SetPoint("LEFT", title, "RIGHT", 8, 0)
	version:SetText(ns.Version()) -- no build: that's for chat
	frame.version = version

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

	defaultsButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	defaultsButton:SetSize(90, 20)
	defaultsButton:SetPoint("TOPRIGHT", -16, TABS_Y - 2)
	defaultsButton:SetText("Defaults")
	defaultsButton:SetScript("OnClick", function() Window.RunDefaults() end)

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

	ns.Theme.Paint(function(T)
		frame:SetBackdropBorderColor(T.Edge())
		local r, g, b = T.Edge()
		rule:SetColorTexture(r, g, b, 0.6)
		PaintTabs()
	end)

	frame:SetScript("OnShow", function() Window.Select(current or ns.db.window.tab) end)
end

-- When the profile changes: the window takes that profile's size, place and tab.
function Window.Apply()
	if not frame then return end
	Place()
	if frame:IsShown() then
		Window.Select(ns.db.window.tab or current)
	end
end

-- An entry in the game's Options > AddOns list: an Enable box, and a button that opens Leproc's own
-- window (the options live there).
function Window.Register()
	if Window.category or not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
	local panel = CreateFrame("Frame")
	panel.name = "Leproc"
	local icon = panel:CreateTexture(nil, "ARTWORK")
	icon:SetSize(36, 36)
	icon:SetPoint("TOPLEFT", 16, -12)
	icon:SetTexture(ns.ICON)
	local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("LEFT", icon, "RIGHT", 10, 0)
	title:SetText("Leproc " .. ns.Version())
	panel.title = title
	local text = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	text:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -12)
	text:SetPoint("RIGHT", -16, 0)
	text:SetJustifyH("LEFT")
	text:SetText("Glows your action buttons when a proc or a reactive ability is ready, in any stance or form. The options have their own window: /leproc, or the minimap button.")
	local enable = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
	enable:SetPoint("TOPLEFT", text, "BOTTOMLEFT", -4, -14)
	enable.label = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	enable.label:SetPoint("LEFT", enable, "RIGHT", 4, 0)
	enable.label:SetText("Enable Leproc")
	enable:SetScript("OnClick", function(self) ns.SetEnabled(self:GetChecked()) end)
	local open = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	open:SetSize(200, 26)
	open:SetPoint("TOPLEFT", enable, "BOTTOMLEFT", 4, -12)
	open:SetText("Open Leproc's options")
	open:SetScript("OnClick", function()
		if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
		if GameMenuFrame and GameMenuFrame:IsShown() then HideUIPanel(GameMenuFrame) end
		Window.Show()
	end)
	panel:SetScript("OnShow", function() enable:SetChecked(ns.Enabled()) end)
	panel.open, panel.enable = open, enable
	Window.category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
	Settings.RegisterAddOnCategory(Window.category)
end

-- The Defaults button: the page shown back to its defaults.
function Window.RunDefaults()
	local def = pages[current]
	if def and def.defaults then
		def.defaults()
		ns.Refresh()
		Window.Refresh()
	end
end

-- The pages' ids, in tab order.
function Window.PageIds()
	local ids = {}
	for i, def in ipairs(pageOrder) do ids[i] = def.id end
	return ids
end

-- The panel of the page being shown (used by the tests).
function Window.CurrentPanel()
	return current and pages[current] and pages[current].panel
end

function Window.Frame()
	return frame
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
