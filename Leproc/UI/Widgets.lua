-- Leproc: building blocks for the options window, in the same style as Nothing Wasted's.
-- Rows are laid out like the game's Settings: the label on the left, the control on the right.
-- Each row has :Sync() to show the current value. Place rows top to bottom with UI.Stack.
local _, ns = ...

local UI = {}
ns.UI = UI

local LABEL_X, CONTROL_X, ROW_HEIGHT = 16, 300, 32

local function Tooltip(frame, lines)
	if not lines then return end
	frame:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		for i, line in ipairs(type(lines) == "function" and lines() or lines) do
			if i == 1 then GameTooltip:AddLine(line) else GameTooltip:AddLine(line, 1, 1, 1, true) end
		end
		GameTooltip:Show()
	end)
	frame:SetScript("OnLeave", GameTooltip_Hide)
end

local function OptionRow(parent, label, font, tooltip, controlX)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(ROW_HEIGHT)
	row:EnableMouse(tooltip ~= nil)
	row.label = row:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
	row.label:SetPoint("LEFT", LABEL_X, 0)
	row.label:SetWidth((controlX or CONTROL_X) - LABEL_X - 12)
	row.label:SetJustifyH("LEFT")
	row.label:SetText(label)
	row.Sync = function() end
	Tooltip(row, tooltip)
	return row
end

function UI.OptionCheck(parent, label, get, set, tooltip)
	local row = OptionRow(parent, label, nil, tooltip)
	local cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
	cb:SetSize(30, 30)
	cb:SetPoint("LEFT", CONTROL_X, 0)
	cb:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
	row.check = cb
	row.Sync = function() cb:SetChecked(get()) end
	return row
end

-- A value picker with arrows on each side: values is a list of { value, label }, or a function
-- returning one (read each time, for lists that change). `opts` may give the label font, a tooltip
-- (a list of lines, or a function returning one), sync(row) run after each Sync, and controlX and
-- boxWidth to make room for more controls on the right (row.right is where the next one can go).
function UI.OptionSelect(parent, label, choices, get, set, opts)
	opts = opts or {}
	local cx, bw = opts.controlX or CONTROL_X, opts.boxWidth or 150
	local row = OptionRow(parent, label, opts.font, opts.tooltip, cx)
	local function Values()
		return type(choices) == "function" and choices() or choices
	end
	local function Step(dir)
		local values = Values()
		if #values == 0 then return end
		local cur, idx = get(), 1
		for i, v in ipairs(values) do
			if v[1] == cur then idx = i end
		end
		idx = (idx - 1 + dir) % #values + 1
		set(values[idx][1])
		row.Sync()
	end
	local function Arrow(dir, x)
		local b = CreateFrame("Button", nil, row)
		b:SetSize(26, 26)
		b:SetPoint("LEFT", x, 0)
		local base = dir < 0 and "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-" or "Interface\\Buttons\\UI-SpellbookIcon-NextPage-"
		b:SetNormalTexture(base .. "Up")
		b:SetPushedTexture(base .. "Down")
		b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
		b:SetScript("OnClick", function() Step(dir) end)
		return b
	end
	row.prev = Arrow(-1, cx)
	local box = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
	box:SetSize(bw, 24)
	box:SetPoint("LEFT", cx + 30, 0)
	box:SetScript("OnClick", function() Step(1) end)
	row.box = box
	row.next = Arrow(1, cx + 34 + bw)
	row.right = cx + 66 + bw
	row.Sync = function()
		local values = Values()
		local cur = get()
		local text = #values == 0 and "|cff999999none|r" or tostring(cur)
		for _, v in ipairs(values) do
			if v[1] == cur then text = v[2] end
		end
		box:SetText(text)
		if opts.sync then opts.sync(row) end
	end
	return row
end

-- A text box; set(text) runs when you press Enter, and clears the box if it returns true.
function UI.OptionEdit(parent, label, get, set, tooltip)
	local row = OptionRow(parent, label, nil, tooltip)
	local box = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
	box:SetSize(174, 22)
	box:SetPoint("LEFT", CONTROL_X + 36, 0)
	box:SetAutoFocus(false)
	box:SetScript("OnEnterPressed", function(self)
		set(self:GetText() or "")
		self:ClearFocus()
		row.Sync()
	end)
	box:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
		row.Sync()
	end)
	row.box = box
	row.Sync = function()
		if not box:HasFocus() then box:SetText(get() or "") end
	end
	return row
end

-- A sound picker (ns.SOUNDS) with a Test button that plays the one chosen.
function UI.OptionSound(parent, label, get, set, tooltip)
	local row = UI.OptionSelect(parent, label, ns.SOUNDS, get, function(v)
		set(v)
		ns.Play(v)
	end, { tooltip = tooltip, boxWidth = 130 })
	local test = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
	test:SetSize(50, 22)
	test:SetPoint("LEFT", row.right + 4, 0)
	test:SetText("Test")
	test:SetScript("OnClick", function() ns.Play(get()) end)
	row.test = test
	return row
end

-- A sample action button showing the glow as it's set.
function UI.GlowPreview(parent)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(64)
	local function Sample(x, label, icon)
		local f = CreateFrame("Frame", nil, row)
		f:SetSize(36, 36)
		f:SetPoint("LEFT", x, 0)
		f.icon = f:CreateTexture(nil, "ARTWORK")
		f.icon:SetAllPoints()
		f.icon:SetTexture(icon)
		f.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		text:SetPoint("LEFT", f, "RIGHT", 14, 0)
		text:SetText(label)
		return f
	end
	local sample = Sample(LABEL_X + 14, "How a lit button looks", "Interface\\Icons\\Ability_Warrior_Revenge")
	row.Sync = function()
		ns.Glow.Show(sample, ns.db.glow, ns.db.color, 36)
	end
	return row
end

-- buttonText may be a function, read at each Sync.
function UI.OptionButton(parent, label, buttonText, onClick, tooltip)
	local row = OptionRow(parent, label, nil, tooltip)
	local b = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
	b:SetSize(150, 24)
	b:SetPoint("LEFT", CONTROL_X + 30, 0)
	b:SetScript("OnClick", function()
		onClick()
		row.Sync()
	end)
	row.button = b
	row.Sync = function()
		b:SetText(type(buttonText) == "function" and buttonText() or buttonText)
	end
	return row
end

-- A section heading inside a page, like "Mouse" in the game's Settings.
function UI.OptionHeading(parent, text)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(ROW_HEIGHT + 4)
	local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	fs:SetPoint("BOTTOMLEFT", 4, 6)
	fs:SetText(text)
	row.Sync = function() end
	return row
end

-- A paragraph of small text. `text` may be a function, read at each Sync.
function UI.OptionText(parent, text, height)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(height or 40)
	local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	fs:SetPoint("TOPLEFT", LABEL_X, -4)
	fs:SetPoint("BOTTOMRIGHT", -8, 4)
	fs:SetJustifyH("LEFT")
	fs:SetJustifyV("TOP")
	row.Sync = function() fs:SetText(type(text) == "function" and text() or text) end
	return row
end

-- A scrolling column of rows. Returns the stack; call stack:Add(row) for each row in order.
function UI.Stack(parent)
	local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT")
	scroll:SetPoint("BOTTOMRIGHT", -24, 0)
	local inner = CreateFrame("Frame", nil, scroll)
	inner:SetSize(500, 1)
	scroll:SetScrollChild(inner)
	scroll:SetScript("OnSizeChanged", function(_, width) inner:SetWidth(width) end)
	local stack = { rows = {}, inner = inner, height = 0 }
	function stack:Add(row)
		row:SetParent(inner)
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", 0, -self.height)
		row:SetPoint("RIGHT", inner, "RIGHT")
		self.height = self.height + row:GetHeight()
		inner:SetHeight(self.height)
		self.rows[#self.rows + 1] = row
		row:Show()
		return row
	end
	function stack:Sync()
		for _, row in ipairs(self.rows) do row:Sync() end
	end
	-- For pages that rebuild their list: Reset, Add the rows again in order, then Done hides the
	-- rows that weren't added back. Rows that stay are never hidden, so an open dropdown menu on
	-- one stays open.
	function stack:Reset()
		self.old, self.rows, self.height = self.rows, {}, 0
		inner:SetHeight(1)
	end
	function stack:Done()
		local kept = {}
		for _, row in ipairs(self.rows) do kept[row] = true end
		for _, row in ipairs(self.old or {}) do
			if not kept[row] then row:Hide() end
		end
		self.old = nil
	end
	return stack
end
