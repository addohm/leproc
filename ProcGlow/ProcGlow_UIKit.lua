local _, NS = ...
local ApplyAll, CLASS_ORDER, CLASS_SPELLS, LOC, STYLE_DEFAULTS, TA = NS.ApplyAll, NS.CLASS_ORDER, NS.CLASS_SPELLS, NS.LOC, NS.STYLE_DEFAULTS, NS.TA

---------------------------------------------------------------------------
-- Settings window: a list on the left (Settings, Glow Style, Classes > each
-- class) and the matching page on the right.
---------------------------------------------------------------------------

local pages, pageRefresh = {}, {}
NS.pageRefresh, NS.pages = pageRefresh, pages
local cur = { page = "settings", class = nil }
NS.cur = cur
local navRows = {}
NS.navRows = navRows
   -- defined further down


   -- defined with the minimap button further down
local ICON_PATH = "Interface\\AddOns\\ProcGlow\\icon.tga"
NS.ICON_PATH = ICON_PATH
local MINIMAP_ICON_PATH = "Interface\\AddOns\\ProcGlow\\minimap.tga"
NS.MINIMAP_ICON_PATH = MINIMAP_ICON_PATH   -- round, full-bleed version

local uid = 0
local function NextName(prefix)
    uid = uid + 1
    return prefix .. uid
end
NS.NextName = NextName

local function Title(s)
    local l = LOC.Local(s)
    if l then return l end          -- the client's own spelling (accented letters would trip the pattern below)
    return (s:gsub("(%a)([%w']*)", function(a, b) return a:upper() .. b end))
end
NS.Title = Title

local function ClassLabel(c)
    if c == "OTHER" then return "Custom / other" end
    return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[c]) or Title(c:lower())
end
NS.ClassLabel = ClassLabel

local CLASS_LIST = {}
NS.CLASS_LIST = CLASS_LIST
for _, c in ipairs(CLASS_ORDER) do CLASS_LIST[#CLASS_LIST + 1] = c end
CLASS_LIST[#CLASS_LIST + 1] = "OTHER"

local builtinSet = {}
NS.builtinSet = builtinSet
for _, list in pairs(CLASS_SPELLS) do
    for _, n in ipairs(list) do builtinSet[n:lower()] = true end
end

local function CopyDefaults()
    for k, v in pairs(STYLE_DEFAULTS) do NS.DB.style[k] = v end
end
NS.CopyDefaults = CopyDefaults

local function MakePanel(parent)
    local p = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    p:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    p:SetBackdropColor(0, 0, 0, 0.8)
    p:SetBackdropBorderColor(0.75, 0.75, 0.75, 1)
    TA.Acc(p, "border", 0.75, 0.75, 0.75, 1)
    TA.Acc(p, "bg", 0, 0, 0, 0.8)
    return p
end
NS.MakePanel = MakePanel

local function Tip(frame, title, text)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, 1, 1, 1)
        if text then GameTooltip:AddLine(text, nil, nil, nil, true) end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end
NS.Tip = Tip

-- is the mouse over this frame (with a little margin)? Worked out from the cursor position directly, which
-- does not depend on the frame's own mouse handling
function TA.Over(f)
    if not f or not f.GetLeft then return false end
    local l, r, bt, tp = f:GetLeft(), f:GetRight(), f:GetBottom(), f:GetTop()
    if not (l and r and bt and tp and GetCursorPosition) then return false end
    local x, y = GetCursorPosition()
    local s = f:GetEffectiveScale()
    if not (s and s > 0) then return false end
    x, y = x / s, y / s
    local pad = 8
    return x >= l - pad and x <= r + pad and y >= bt - pad and y <= tp + pad
end
-- a pop-up that closes itself after the mouse has been away for a couple of seconds, or at once on a click elsewhere
function TA.AutoClose(f, keep)
    if f.pgAuto then return end
    f.pgAuto = true
    local idle = 0
    local oldShow, oldUpd = f:GetScript("OnShow"), f:GetScript("OnUpdate")
    f:SetScript("OnShow", function(self, ...) idle = 0; if oldShow then oldShow(self, ...) end end)
    f:SetScript("OnUpdate", function(self, el, ...)
        if oldUpd then oldUpd(self, el, ...) end
        if not self:IsShown() then return end
        if TA.Over(self) or (keep and keep()) then idle = 0; return end
        idle = idle + el
        if idle >= 2 or (IsMouseButtonDown and IsMouseButtonDown("LeftButton")) then idle = 0; self:Hide() end
    end)
end

-- (the big "do" block that used to start here was removed when the file was split up)
local function PickColor(onDone, tbl)
    local c = tbl or NS.DB.style
    local function onChange()
        c.r, c.g, c.b = ColorPickerFrame:GetColorRGB()
        onDone()
    end
    local function onCancel(prev)
        if type(prev) == "table" then c.r, c.g, c.b = prev.r, prev.g, prev.b end
        onDone()
    end
    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({
            r = c.r, g = c.g, b = c.b, hasOpacity = false,
            swatchFunc = onChange, cancelFunc = onCancel,
        })
    else
        ColorPickerFrame.func = onChange
        ColorPickerFrame.cancelFunc = onCancel
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.previousValues = { r = c.r, g = c.g, b = c.b }
        ColorPickerFrame:SetColorRGB(c.r, c.g, c.b)
        ColorPickerFrame:Hide()
        ColorPickerFrame:Show()
    end
end

-- Small layout helper: stacks headers, text, checkboxes, sliders and buttons
-- down a frame, and remembers how to refresh them from the saved settings.
local PRESET_COLOURS = {
    {"White",1,1,1},{"Light grey",0.75,0.75,0.75},{"Grey",0.5,0.5,0.5},{"Dark grey",0.25,0.25,0.25},{"Black",0,0,0},
    {"Red",1,0.1,0.1},{"Dark red",0.65,0,0},{"Crimson",0.86,0.08,0.24},{"Orange",1,0.5,0},{"Amber",1,0.7,0},
    {"Gold",1,0.82,0},{"Yellow",1,1,0.1},{"Cream",1,0.95,0.7},{"Lime",0.6,1,0.1},{"Green",0.1,0.9,0.1},
    {"Dark green",0,0.5,0.15},{"Forest",0.13,0.4,0.2},{"Mint",0.6,1,0.8},{"Teal",0.1,0.85,0.75},{"Cyan",0.2,1,1},
    {"Sky blue",0.4,0.7,1},{"Blue",0.15,0.3,1},{"Navy",0.05,0.1,0.45},{"Indigo",0.3,0.2,0.7},{"Purple",0.65,0.25,1},
    {"Lavender",0.78,0.65,1},{"Magenta",1,0.2,0.85},{"Pink",1,0.55,0.75},{"Brown",0.6,0.38,0.18},{"Tan",0.82,0.7,0.5},
}
local CLASS_COLOURS = {
    {"Druid",1,0.49,0.04},{"Hunter",0.67,0.83,0.45},{"Mage",0.41,0.8,0.94},{"Paladin",0.96,0.55,0.73},{"Priest",1,1,1},
    {"Rogue",1,0.96,0.41},{"Shaman",0,0.44,0.87},{"Warlock",0.58,0.51,0.79},{"Warrior",0.78,0.61,0.43},
}
local colourChooser
local function ShowColourChooser(anchor, tbl, onDone)
    if not colourChooser then
        local c = CreateFrame("Frame", "ProcGlowColourChooser", UIParent, "BackdropTemplate")
        c:SetFrameStrata("TOOLTIP")
        c:SetFrameLevel(30)
        tinsert(UISpecialFrames, "ProcGlowColourChooser")
        c:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 24,
            insets = { left = 6, right = 6, top = 6, bottom = 6 } })
        c:SetSize(218, 280)
        c:EnableMouse(true)
        local cx = CreateFrame("Button", nil, c, "UIPanelCloseButton")
        cx:SetSize(24, 24)
        cx:SetPoint("TOPRIGHT", c, "TOPRIGHT", -2, -2)
        cx:SetScript("OnClick", function() c:Hide() end)
        cx:Hide()           -- closes on a click away, Escape, or after the mouse has been away a moment
        c.cus = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
        TA.Acc(c.cus, "btn")
        c.cus:SetSize(168, 22); c.cus:SetPoint("BOTTOM", 0, 14); c.cus:SetText("Custom...")
        local hdr = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hdr:SetPoint("TOPLEFT", 16, -14 - 6 * 25 - 2)
        hdr:SetText("Class colours")
        local all = {}
        for i, col in ipairs(PRESET_COLOURS) do all[#all + 1] = { col, 14 + ((i - 1) % 5) * 34, -14 - math.floor((i - 1) / 5) * 25 } end
        for i, col in ipairs(CLASS_COLOURS) do all[#all + 1] = { col, 14 + ((i - 1) % 5) * 34, -14 - 6 * 25 - 18 - math.floor((i - 1) / 5) * 25 } end
        for _, it in ipairs(all) do
            local col = it[1]
            local b = CreateFrame("Button", nil, c)
            b:SetSize(24, 20)
            b:SetPoint("TOPLEFT", it[2], it[3])
            local bd = b:CreateTexture(nil, "BACKGROUND"); bd:SetAllPoints(); bd:SetColorTexture(1, 1, 1, 1)
            local t = b:CreateTexture(nil, "ARTWORK")
            t:SetPoint("TOPLEFT", 2, -2); t:SetPoint("BOTTOMRIGHT", -2, 2)
            t:SetColorTexture(col[2], col[3], col[4], 1)
            b:SetScript("OnClick", function()
                local tb = c.tbl
                tb.r, tb.g, tb.b = col[2], col[3], col[4]
                c:Hide()
                if c.done then c.done() end
            end)
            b:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:SetText(col[1]); GameTooltip:Show()
            end)
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end
        c.cus:SetScript("OnClick", function()
            c:Hide()
            PickColor(c.done, c.tbl)
        end)
        local catcher = CreateFrame("Button", nil, UIParent)
        catcher:SetAllPoints(UIParent)
        catcher:SetFrameStrata("TOOLTIP")
        catcher:SetFrameLevel(10)
        catcher:Hide()
        catcher:SetScript("OnClick", function() c:Hide() end)
        c:SetScript("OnShow", function() catcher:Show() end)
        c:SetScript("OnHide", function() catcher:Hide(); GameTooltip:Hide() end)
        TA.AutoClose(c, function() return TA.Over(c.anchorW) end)
        colourChooser = c
    end
    local c = colourChooser
    c.tbl, c.done, c.anchorW = tbl, onDone, anchor
    c:ClearAllPoints()
    c:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
    c:Show()
end


---------------------------------------------------------------------------
-- A calmer layout for the class pages (Paladin first): one row pattern for everything
-- (name | Glow | Text | Icon | More), one Test and one Customise for the whole page, flat controls
-- in a neutral theme, and a box you can type a number into next to every slider.
-- It reads and writes the very same settings as the classic page, so nothing is lost by switching.
---------------------------------------------------------------------------
local UI = {
    simple = setmetatable({}, { __index = function() return true end }),      -- every class uses the calmer layout
    fill = { 0.13, 0.15, 0.19 }, hover = { 0.20, 0.23, 0.30 }, edge = { 0.32, 0.36, 0.45 },
    panel = { 0.10, 0.11, 0.15 }, dim = { 0.62, 0.66, 0.74 }, gold = { 1, 0.82, 0 },
}
NS.UI = UI
function UI.Paint(tex, c, a) tex:SetColorTexture(c[1], c[2], c[3], a or 1) end
-- Colours. Default is the dark blue-grey with gold. With the class-colour option on, the gold becomes the
-- class colour and every dark shade takes a faint tint of it.
UI.reg = {}
function UI.Class()
    local cc = RAID_CLASS_COLORS and RAID_CLASS_COLORS[UI.cls or ""]
    if cc and NS.DB and NS.DB.classUI then return cc end
end
function UI.Col(k)
    local base = UI[k]
    local cc = UI.Class()
    if not cc then return base end
    if k == "gold" then return { cc.r, cc.g, cc.b } end
    local m = (k == "edge") and 0.35 or (k == "dim") and 0.2 or 0.16
    return { base[1] + (cc.r * 0.7 - base[1]) * m, base[2] + (cc.g * 0.7 - base[2]) * m, base[3] + (cc.b * 0.7 - base[3]) * m }
end
-- a tooltip that adds to (never replaces) the hover scripts a widget already has
function UI.Tip(frame, title, text)
    frame:HookScript("OnEnter", function(self)
        local ti, tx = title, text
        if type(ti) == "function" then ti = ti() end
        if type(tx) == "function" then tx = tx() end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(ti, 1, 1, 1)
        if tx then GameTooltip:AddLine(tx, nil, nil, nil, true) end
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
end
-- run fn now and again whenever the look changes
function UI.Reg(fn) UI.reg[#UI.reg + 1] = fn; fn() end
function UI.Retheme() for _, fn in ipairs(UI.reg) do fn() end end
TA.UIRetheme = UI.Retheme
function UI.Tint(tex, k)       -- vertex colour in the accent
    UI.Reg(function() local c = UI.Col(k or "gold"); tex:SetVertexColor(c[1], c[2], c[3]) end)
end
-- a flat bordered box: the border is the frame's own colour, the fill sits one pixel inside it
-- one physical screen pixel, in the units of frame f. The window runs at a fractional scale, so a "1" border can
-- land between two screen pixels and be rounded away on some sides; sizing borders in real pixels stops that.
function UI.Px(f)
    local es = f.GetEffectiveScale and f:GetEffectiveScale()
    if not es or es <= 0 then return 1 end
    local ph
    if GetPhysicalScreenSize then local _, h = GetPhysicalScreenSize(); ph = h end
    if not ph or ph <= 0 then return 1 end
    return (768 / ph) / es
end
UI.fits = setmetatable({}, { __mode = "k" })
-- fn() lays out something that depends on UI.Px(owner); it runs now, whenever the owner is shown, and on every rescale
function UI.Fit(owner, fn)
    UI.fits[owner] = fn
    pcall(fn)
    local h = owner.HookScript and owner or (owner.GetParent and owner:GetParent())
    if h and h.HookScript then pcall(h.HookScript, h, "OnShow", function() pcall(fn) end) end
end
function UI.Repixel()
    for _, fn in pairs(UI.fits) do pcall(fn) end
end
function UI.Skin(f, fillKind, alpha)
    f.fillKind = fillKind or "fill"
    f.fillAlpha = alpha or 1
    f.edgeTex = f:CreateTexture(nil, "BACKGROUND")
    f.edgeTex:SetAllPoints()
    UI.Reg(function() UI.Paint(f.edgeTex, UI.Col("edge")) end)
    f.fillTex = f:CreateTexture(nil, "BORDER")
    UI.Fit(f, function()
        local px = UI.Px(f)
        f.fillTex:ClearAllPoints()
        f.fillTex:SetPoint("TOPLEFT", px, -px)
        f.fillTex:SetPoint("BOTTOMRIGHT", -px, px)
    end)
    UI.Reg(function() UI.Paint(f.fillTex, UI.Col(f.fillKind), f.fillAlpha) end)
end
function UI.Button(parent, text, w, h, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w, h or 22)
    UI.Skin(b)
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.label:SetPoint("CENTER", 0, 0)
    b.label:SetText(text)
    b:SetFontString(b.label)          -- so b:SetText / b:GetFontString work like on any other button
    b:SetScript("OnEnter", function(s) if not s.greyed then UI.Paint(s.fillTex, UI.Col("hover")) end end)
    b:SetScript("OnLeave", function(s) UI.Paint(s.fillTex, UI.Col(s.fillKind), s.fillAlpha) end)
    b:SetScript("OnClick", function(s, ...) if not s.greyed then onClick(s, ...) end end)
    return b
end
-- a tab: highlighted while it is the one showing, greyed when there is nothing behind it
function UI.Tab(parent, text, w, h, onClick)
    local b = UI.Button(parent, text, w, h, onClick)
    b.bar = b:CreateTexture(nil, "OVERLAY")
    b.bar:SetHeight(2)
    b.bar:SetPoint("BOTTOMLEFT", 1, 1); b.bar:SetPoint("BOTTOMRIGHT", -1, 1)
    UI.Tint(b.bar)
    b.bar:Hide()
    return b
end
function UI.TabLook(b, enabled, selected)
    b.greyed = not enabled
    b.fillKind = selected and "hover" or "fill"
    UI.Paint(b.fillTex, UI.Col(b.fillKind), b.fillAlpha)
    if enabled then b.label:SetTextColor(1, 1, 1) else b.label:SetTextColor(0.4, 0.42, 0.48) end
    b.bar:SetShown(selected and true or false)
end
-- a button that is there for symmetry but has nothing to do right now
function UI.Grey(b, on)
    b.greyed = on and true or false
    if on then b.label:SetTextColor(0.4, 0.42, 0.48) else b.label:SetTextColor(1, 1, 1) end
    UI.Paint(b.fillTex, UI.Col(b.fillKind))
end
-- the current choice in a flat bar with a small arrow; clicking it opens the list
function UI.Arrowise(b)
    b.label:ClearAllPoints()
    b.label:SetPoint("LEFT", 8, 0)
    b.label:SetPoint("RIGHT", -22, 0)
    b.label:SetJustifyH("LEFT")
    b.arrow = b:CreateTexture(nil, "OVERLAY")
    b.arrow:SetSize(20, 20)
    b.arrow:SetPoint("RIGHT", -3, -3)
    b.arrow:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
    UI.Tint(b.arrow)
end
function UI.Dropdown(parent, w, onClick)
    local b = UI.Button(parent, "", w, 22, onClick)
    UI.Arrowise(b)
    return b
end
-- turn a standard game button into the flat look in place (hides its template art, adds the flat box)
function UI.FlatButton(b)
    if b.pgFlat or not b.GetRegions then return end
    b.pgFlat = true
    pcall(function()
        for _, r in ipairs({ b:GetRegions() }) do
            if r.GetObjectType and r:GetObjectType() == "Texture" then r:Hide() end
        end
        b:SetNormalTexture(nil); b:SetPushedTexture(nil); b:SetDisabledTexture(nil); b:SetHighlightTexture(nil)
    end)
    UI.Skin(b)
    b:HookScript("OnEnter", function(s) if s:IsEnabled() then UI.Paint(s.fillTex, UI.Col("hover")) end end)
    b:HookScript("OnLeave", function(s) UI.Paint(s.fillTex, UI.Col(s.fillKind), s.fillAlpha) end)
    local fs = b:GetFontString()
    if fs then fs:SetDrawLayer("OVERLAY") end
end
TA.FlatButton = UI.FlatButton
-- the same for a standard edit box
function UI.FlatEdit(e)
    if e.pgFlat then return e end
    e.pgFlat = true
    pcall(function()
        for _, r in ipairs({ e:GetRegions() }) do
            if r.GetObjectType and r:GetObjectType() == "Texture" then r:Hide() end
        end
    end)
    UI.Skin(e)
    e:SetTextInsets(6, 6, 0, 0)
    return e
end
-- the small flat X used to close a window
function UI.Close(parent, onClick)
    return UI.Button(parent, "x", 22, 22, onClick)
end
function UI.Check(parent, get, set)
    local cb = CreateFrame("CheckButton", nil, parent)
    cb:SetSize(20, 20)
    UI.Skin(cb)
    cb.tick = cb:CreateTexture(nil, "OVERLAY")
    cb.tick:SetPoint("TOPLEFT", 1, -1)
    cb.tick:SetPoint("BOTTOMRIGHT", -1, 1)
    cb.tick:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    UI.Tint(cb.tick)
    cb.tick:Hide()
    cb:SetScript("OnEnter", function(s) UI.Paint(s.fillTex, UI.Col("hover")) end)
    cb:SetScript("OnLeave", function(s) UI.Paint(s.fillTex, UI.Col("fill")) end)
    cb:SetScript("OnClick", function(s)
        local v = s:GetChecked() and true or false
        s.tick:SetShown(v)
        set(v)
    end)
    function cb:Sync()
        local v = get() and true or false
        self:SetChecked(v)
        self.tick:SetShown(v)
    end
    return cb
end
function UI.Edit(parent, w, h)
    local e = CreateFrame("EditBox", nil, parent)
    e:SetSize(w, h or 22)
    UI.Skin(e)
    e:SetAutoFocus(false)
    e:SetFontObject("GameFontHighlightSmall")
    e:SetTextInsets(6, 6, 0, 0)
    e:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
    return e
end
-- a slider with a box beside it: drag, or click the box and type the exact number (it is kept within range and step)
function UI.Number(parent, minV, maxV, step, unit, get, set, barW)
    local g = CreateFrame("Frame", nil, parent)
    barW = barW or 120
    g:SetSize(barW + 62 + ((unit and unit ~= "") and 50 or 0), 22)
    local s = CreateFrame("Slider", nil, g)
    s:SetOrientation("HORIZONTAL")
    s:SetSize(barW, 16)
    s:SetPoint("LEFT", 0, 0)
    local tr = s:CreateTexture(nil, "BACKGROUND")
    tr:SetPoint("LEFT", 0, 0); tr:SetPoint("RIGHT", 0, 0); tr:SetHeight(4)
    UI.Reg(function() UI.Paint(tr, UI.Col("edge")) end)
    s:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
    local th = s:GetThumbTexture()
    th:SetSize(8, 16)
    UI.Tint(th)
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
    local box = UI.Edit(g, 46, 22)
    box:SetPoint("LEFT", s, "RIGHT", 10, 0)
    box:SetJustifyH("CENTER")
    local un = g:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    un:SetPoint("LEFT", box, "RIGHT", 6, 0)
    un:SetText(unit or "")
    local places = (step < 1) and #((tostring(step):match("%.(%d+)")) or "1") or 0
    local fmt = "%." .. places .. "f"
    local loading = false
    local function Snap(v)
        v = math.floor(v / step + 0.5) * step
        return math.max(minV, math.min(maxV, v))
    end
    s:SetScript("OnValueChanged", function(_, v)
        v = Snap(v)
        box:SetText(string.format(fmt, v))
        if not loading then set(v) end
    end)
    local function Commit()
        local n = tonumber((box:GetText() or ""):match("%d+%.?%d*"))
        if n then s:SetValue(Snap(n)) end
        box:SetText(string.format(fmt, Snap(s:GetValue())))
    end
    box:SetScript("OnEnterPressed", function(self) Commit(); self:ClearFocus() end)
    box:SetScript("OnEditFocusLost", Commit)
    function g:Tip(title, text) UI.Tip(s, title, text); UI.Tip(box, title, text) end
    g.unitFs = un
    function g:Enable() s:Enable(); box:EnableMouse(true) end
    function g:Disable() s:Disable(); box:ClearFocus(); box:EnableMouse(false) end
    function g:Sync()
        loading = true
        local v = Snap(get() or minV)
        s:SetValue(v)
        box:SetText(string.format(fmt, v))
        loading = false
    end
    return g
end


-- a box you type a number into (no slider): used for positions
function UI.Box(parent, minV, maxV, step, get, set, w)
    local e = UI.Edit(parent, w or 60, 22)
    e:SetJustifyH("CENTER")
    local function Snap(v) v = math.floor(v / step + 0.5) * step; return math.max(minV, math.min(maxV, v)) end
    local function Commit()
        local n = tonumber((e:GetText() or ""):match("^%s*(%-?%d+%.?%d*)"))
        if n then set(Snap(n)) end
        e:SetText(tostring(Snap(get() or 0)))
    end
    e:SetScript("OnEnterPressed", function(self) Commit(); self:ClearFocus() end)
    e:SetScript("OnEditFocusLost", Commit)
    function e:Sync() if not self:HasFocus() then self:SetText(tostring(Snap(get() or 0))) end end
    function e:Tip(title, text) UI.Tip(self, title, text) end
    return e
end

-- the form helper: flat boxes and typeable numbers
local function NewForm(parent, width, ox, oy)
    local F = { parent = parent, width = width, ox = ox or 0, oy = oy or 0, y = 0, ind = 0, refreshers = {} }

    function F:Pos(frame, x, dy)
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", self.parent, "TOPLEFT",
            self.ox + self.ind + (x or 0), -(self.oy + self.y + (dy or 0)))
    end

    function F:Gap(n) self.y = self.y + n end

    function F:Refresh()
        for _, fn in ipairs(self.refreshers) do fn() end
    end

    function F:Text(text)
        local fs = self.parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetWidth(self.width - self.ind - 6)
        fs:SetJustifyH("LEFT")
        fs:SetText(text)
        self:Pos(fs, 0)
        self.y = self.y + math.max(14, fs:GetStringHeight()) + 6
        return fs
    end

    -- keepRow = true leaves y alone so a second button can sit beside it
    function F:Button(label, w, onClick, x, keepRow)
        local b = UI.Button(self.parent, label, w, 22, onClick)
        self:Pos(b, x or 0)
        if not keepRow then self.y = self.y + 30 end
        return b
    end

    -- ---- compact layout helpers: several controls share one row ----------
    function F:Row(h) self.y = self.y + (h or 26) end

    function F:Section(text)
        local fs = self.parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        self:Pos(fs, 0, 2)
        fs:SetText(text)
        UI.Reg(function() local c = UI.Col("gold"); fs:SetTextColor(c[1], c[2], c[3]) end)
        local line = self.parent:CreateTexture(nil, "ARTWORK")
        UI.Fit(line, function() line:SetHeight(UI.Px(self.parent)) end)
        line:SetWidth(self.width)
        line:SetPoint("TOPLEFT", self.parent, "TOPLEFT", self.ox, -(self.oy + self.y + 19))
        UI.Reg(function() UI.Paint(line, UI.Col("gold"), 0.5) end)
        self.y = self.y + 25
        return
    end

    function F:Note(text, x)
        local fs = self.parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        self:Pos(fs, x or 0, 8)
        fs:SetText(text)
        return fs
    end

    -- tick box at column x; does not move to the next row
    function F:Tick(label, get, set, x, tip)
        local cb = UI.Check(self.parent, get, set)
        self:Pos(cb, x or 0, 1)
        local fs = self.parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("LEFT", cb, "RIGHT", 6, 0)
        fs:SetText(label)
        -- the words are part of the tick: clicking them ticks it too
        local hit = CreateFrame("Button", nil, self.parent)
        hit:SetPoint("LEFT", cb, "RIGHT", 0, 0)
        hit:SetSize(math.ceil(fs:GetStringWidth() or 40) + 10, 20)
        hit:SetScript("OnClick", function() cb:Click() end)
        if tip then UI.Tip(cb, label, tip); UI.Tip(hit, label, tip) end
        self.refreshers[#self.refreshers + 1] = function() cb:Sync() end
        cb.pgLabel, cb.pgHit = fs, hit
        return cb
    end

    -- label + slider + value on a single line. fmt formats the value, e.g. "%.2f"
    function F:Mini(label, minV, maxV, step, fmt, get, set, x, tip, barW, labW)
        local lab = self.parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        lab:SetJustifyH("LEFT")
        lab:SetText(label)
        lab:SetWordWrap(false)
        local lw = math.max(labW or 58, math.ceil(lab:GetStringWidth() or 0) + 6)
        lab:SetWidth(lw)
        local unit = (fmt:match("%%[%d%.]*[dfg](.*)$") or ""):gsub("^%s+", "")
        local g = UI.Number(self.parent, minV, maxV, step, unit, get, set, math.min(barW or self.barW or 120, 140))
        self:Pos(lab, x, 5)
        self:Pos(g, x + lw + 2, 1)
        if tip then g:Tip(label, tip) end
        self.refreshers[#self.refreshers + 1] = function() g:Sync() end
        g.lab, g.val = lab, g.unitFs
        return g
    end

    function F:ColorAt(label, x)
        local fs = self.parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        self:Pos(fs, x + 4, 5)
        fs:SetText(label)
        local btn = CreateFrame("Button", nil, self.parent)
        btn:SetSize(26, 18)
        self:Pos(btn, x + 80, 3)
        local border = btn:CreateTexture(nil, "BACKGROUND")
        border:SetAllPoints()
        UI.Reg(function() UI.Paint(border, UI.Col("edge")) end)
        local sw = btn:CreateTexture(nil, "ARTWORK")
        UI.Fit(btn, function() local px = UI.Px(btn); sw:ClearAllPoints(); sw:SetPoint("TOPLEFT", px, -px); sw:SetPoint("BOTTOMRIGHT", -px, px) end)
        local function paint() sw:SetColorTexture(NS.DB.style.r, NS.DB.style.g, NS.DB.style.b, 1) end
        btn:SetScript("OnClick", function() PickColor(function() paint(); ApplyAll() end) end)
        UI.Tip(btn, "Glow colour", "Click to pick the colour.")
        self.refreshers[#self.refreshers + 1] = paint
        return btn
    end

    -- colour swatch for any table with r, g, b
    -- label and a typed number box on one line (flat forms only)
    function F:Field(label, minV, maxV, step, get, set, x, tip, lw)
        local fs = self.parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetText(label)
        self:Pos(fs, x, 5)
        local box = UI.Box(self.parent, minV, maxV, step, get, set, 64)
        self:Pos(box, x + (lw or 62), 1)
        if tip then box:Tip(label, tip) end
        self.refreshers[#self.refreshers + 1] = function() box:Sync() end
        return box
    end

    function F:ColorTbl(label, x, tbl, onDone, lw)
        local fs = self.parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        self:Pos(fs, x + 4, 5)
        fs:SetText(label)
        local btn = CreateFrame("Button", nil, self.parent)
        btn:SetSize(26, 18)
        self:Pos(btn, x + (lw or 56), 3)
        local border = btn:CreateTexture(nil, "BACKGROUND")
        border:SetAllPoints()
        UI.Reg(function() UI.Paint(border, UI.Col("edge")) end)
        local sw = btn:CreateTexture(nil, "ARTWORK")
        UI.Fit(btn, function() local px = UI.Px(btn); sw:ClearAllPoints(); sw:SetPoint("TOPLEFT", px, -px); sw:SetPoint("BOTTOMRIGHT", -px, px) end)
        local function paint() sw:SetColorTexture(tbl.r, tbl.g, tbl.b, 1) end
        btn:SetScript("OnClick", function() ShowColourChooser(btn, tbl, function() paint(); onDone() end) end)
        UI.Tip(btn, label, "Click to choose a preset colour or a custom one.")
        self.refreshers[#self.refreshers + 1] = paint
        return btn
    end

    return F
end
NS.NewForm = NewForm

-- shorthand for DB.style settings: returns getter, setter
local function SSget(key) return function() return NS.DB.style[key] end end
NS.SSget = SSget
local function SSset(key) return function(v) NS.DB.style[key] = v; ApplyAll() end end
NS.SSset = SSset
local function SS(key) return SSget(key), SSset(key) end
NS.SS = SS
