local _, NS = ...
local BUFFS, CapWords, EnsurePos, IC, NewForm, PlaceAlert = NS.BUFFS, NS.CapWords, NS.EnsurePos, NS.IC, NS.NewForm, NS.PlaceAlert
local StyleAlertFrame, TA, TPOS_NAMES, UI, alertFrames = NS.StyleAlertFrame, NS.TA, NS.TPOS_NAMES, NS.UI, NS.alertFrames

---------------------------------------------------------------------------
-- Customise window for one text popup: a stationary, movable window (not attached to the text)
-- with every option from the Text Alerts page. Anything left alone follows the global setting.
---------------------------------------------------------------------------
local custMenu
-- a "Scale" button that opens a small slider to resize a whole window (remembered per window)
function TA.ScalePop(target, key, from)
    local pop = TA.scalePop
    if not pop then
        pop = CreateFrame("Frame", "ProcGlowScalePop", UIParent, "BackdropTemplate")
        pop:SetSize(250, 78)
        pop:SetFrameStrata("FULLSCREEN_DIALOG")
        pop:SetClampedToScreen(true)
        pop:EnableMouse(true)
        pop:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 20,
            insets = { left = 5, right = 5, top = 5, bottom = 5 } })
        tinsert(UISpecialFrames, "ProcGlowScalePop")
        pop:Hide()
        local t = pop:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        t:SetPoint("TOPLEFT", 14, -12)
        t:SetText("Window scale")
        TA.Acc(t, "fs")
        local x = CreateFrame("Button", nil, pop, "UIPanelCloseButton")
        x:SetPoint("TOPRIGHT", 2, 2)
        x:Hide()            -- it closes by itself when the mouse leaves, so no X
        pop.cur = 1
        local g = UI.Number(pop, 70, 140, 5, "%", function() return pop.cur * 100 end, function(v)
            pop.cur = v / 100
            if not pop.target then return end
            NS.DB.winScale = NS.DB.winScale or {}
            NS.DB.winScale[pop.key] = pop.cur
            pop.target:SetScale(pop.cur * TA.BASE); UI.Repixel()
        end, 90)
        g:SetPoint("TOPLEFT", 16, -40)
        local r = UI.Button(pop, "Reset", 46, 22, function()
            pop.cur = 1; g:Sync()
            if pop.target then NS.DB.winScale = NS.DB.winScale or {}; NS.DB.winScale[pop.key] = 1; pop.target:SetScale(TA.BASE); UI.Repixel() end
        end)
        r:SetPoint("TOPRIGHT", -14, -40)
        pop.load = function(v) pop.cur = v; g:Sync() end
        TA.AutoClose(pop, function() return TA.Over(pop.from) end)
        TA.scalePop = pop
    end
    if pop:IsShown() and pop.target == target then pop:Hide(); return end
    pop.target, pop.key, pop.from = target, key, from
    pop.load((NS.DB.winScale and NS.DB.winScale[key]) or 1)
    local cx, cy = from:GetCenter()
    local k = from:GetEffectiveScale() / UIParent:GetEffectiveScale()
    pop:ClearAllPoints()
    pop:SetPoint("TOP", UIParent, "BOTTOMLEFT", cx * k, cy * k - 14)
    pop:Show()
    pop:Raise()
end

-- windows are drawn at 90% of the game's UI scale; the 100% shown on the Scale control means that size
TA.BASE = 0.9
function TA.AddScale(f, key, anchor, point, rel, x, y, flat)
    local b
    if flat then
        b = UI.Button(f, "Scale", 64, 22)
    else
        b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        TA.Acc(b, "btn")
        b:SetSize(64, 22)
        b:SetText("Scale")
    end
    b:SetPoint(point, anchor, rel, x, y)
    b:SetScript("OnClick", function() TA.ScalePop(f, key, b) end)
    local hook = flat and b.HookScript or b.SetScript
    hook(b, "OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Window scale", 1, 1, 1)
        GameTooltip:AddLine("Make this window bigger or smaller. Remembered between sessions.", nil, nil, nil, true)
        GameTooltip:Show()
    end)
    hook(b, "OnLeave", function() GameTooltip:Hide() end)
    local v = NS.DB and NS.DB.winScale and NS.DB.winScale[key]
    f:SetScale((v or 1) * TA.BASE)
    if UI.Repixel then UI.Repixel() end
    return b
end

-- a "-" button next to a window's X: collapses it to its title bar (and "+" restores it)
function TA.AddMin(f, close, hideList, bw, bh, slot, flat)
    local b
    if flat then
        b = UI.Button(f, "-", close:GetWidth() or 22, close:GetHeight() or 22)
        b:SetPoint("RIGHT", close, "LEFT", -4, 0)
    else
        b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        TA.Acc(b, "btn")
        b:SetSize(close:GetWidth() or 32, close:GetHeight() or 32)
        b:SetPoint("RIGHT", close, "LEFT", 4, 0)
        b:SetText("-")
        pcall(function()
            b:SetNormalFontObject(GameFontNormalLarge)
            b:SetHighlightFontObject(GameFontHighlightLarge)
        end)
    end
    local was, w0, h0, pt
    f.minimised = false
    function f.Restore()
        if not f.minimised then return end
        f.minimised = false
        f:SetSize(w0, h0)
        if pt then f:ClearAllPoints(); f:SetPoint(pt[1], pt[2], pt[3], pt[4], pt[5]) end
        for i, o in ipairs(hideList) do if was[i] then o:Show() end end
        b:SetText("-")
    end
    b:SetScript("OnClick", function()
        if f.minimised then f.Restore(); return end
        w0, h0 = f:GetSize()
        local p1, rel, p2, px, py = f:GetPoint(1)
        pt = { p1, rel or UIParent, p2, px, py }
        was = {}
        for i, o in ipairs(hideList) do was[i] = o:IsShown() and true or false; o:Hide() end
        f.minimised = true
        f:SetSize(bw, bh)
        f:ClearAllPoints()
        f:SetPoint("LEFT", UIParent, "LEFT", 12, slot or 0)
        b:SetText("+")
        GameTooltip:Hide()
    end)
    local hook = flat and b.HookScript or b.SetScript
    hook(b, "OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(f.minimised and "Restore window" or "Minimise window", 1, 1, 1)
        GameTooltip:AddLine(f.minimised and "Bring the full window back." or "Shrinks this window to its title bar so you can see the screen.", nil, nil, nil, true)
        GameTooltip:Show()
    end)
    hook(b, "OnLeave", function() GameTooltip:Hide() end)
    return b
end

local function BuildCustomiseMenu()
    local cs                                  -- spell being edited
    local function cfg() return TA.Cfg(cs, true) end
    local function Eff(k)
        local a = cs and NS.DB.alerts[cs]
        if a and a[k] ~= nil then return a[k] end
        return NS.DB.textStyle[k]
    end

    local m = CreateFrame("Frame", "ProcGlowCustomise", UIParent, "BackdropTemplate")
    m:SetSize(450, math.min(640, math.max(540, (UIParent:GetHeight() or 768) - 60)))
    m:SetPoint("RIGHT", UIParent, "RIGHT", -30, 0)
    m:SetFrameStrata("DIALOG")
    m:SetToplevel(true)
    m:SetClampedToScreen(true)
    m:SetMovable(true)
    m:EnableMouse(true)
    m:RegisterForDrag("LeftButton")
    m:SetScript("OnDragStart", m.StartMoving)
    m:SetScript("OnDragStop", m.StopMovingOrSizing)
    -- the same dialog look and tint as the main window, so the two match
    m:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    m:SetBackdropBorderColor(1, 1, 1, 1)
    TA.Acc(m, "border", 1, 1, 1, 1)
    TA.Acc(m, "wbg", 1, 1, 1, 1)
    tinsert(UISpecialFrames, "ProcGlowCustomise")
    m:Hide()

    local title = m:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 18, -16)
    TA.Acc(title, "fs")
    local close = UI.Button(m, "x", 22, 22, function() m:Hide() end)
    close:SetPoint("TOPRIGHT", -10, -10)
    local hint = m:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", 18, -70)
    hint:SetWidth(400)
    hint:SetJustifyH("LEFT")
    hint:SetText("Drag the text on screen to move it; the centre buttons follow it. This window can be moved too. Anything marked Global follows the Text Alerts page.")
    -- the two centring buttons ride along with the text itself
    local cm = CreateFrame("Frame", nil, UIParent)
    cm:SetSize(316, 24)
    cm:SetFrameStrata("TOOLTIP")
    cm:Hide()
    local cH = UI.Button(cm, "Centre horizontally", 154, 22, function() if cs then TA.Centre("x", cs) end end)
    cH:SetPoint("LEFT", 0, 0)
    local cV = UI.Button(cm, "Centre vertically", 154, 22, function() if cs then TA.Centre("y", cs) end end)
    cV:SetPoint("LEFT", 162, 0)
    -- follows the text's resting position, ignoring its throb / shake so the buttons stay still
    local function PlaceCentre()
        if cs and TA.menuTab == "icon" then cm:Hide(); return end
        local f = cs and alertFrames[cs]
        if not f then cm:Hide(); return end
        local x, y
        if f.baseX and (f.throbOn or f.shakeOn) and not (f.dragging or TA.unlocked) then
            x, y = f.baseX, f.baseY
        else
            local cx, cy = f:GetCenter()
            local ux, uy = UIParent:GetCenter()
            if not (cx and ux) then return end
            local k = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
            x, y = cx * k - ux, cy * k - uy
        end
        y = y - (f:GetHeight() or 30) / 2 - 22
        cm:ClearAllPoints()
        cm:SetPoint("CENTER", UIParent, "CENTER", x, y)
        if not cm:IsShown() then cm:Show() end
    end
    cm:SetScript("OnUpdate", PlaceCentre)
    local function AttachCentre()
        if cs and TA.menuTab ~= "icon" and alertFrames[cs] then PlaceCentre() else cm:Hide() end
    end

    local sf = CreateFrame("ScrollFrame", "ProcGlowCustomiseScroll", m, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 14, -100)
    sf:SetPoint("BOTTOMRIGHT", -34, 16)
    local child = CreateFrame("Frame", nil, sf)
    child:SetSize(396, 800)
    sf:SetScrollChild(child)
    -- tabs: Text / Icon (greyed out when that kind of popup isn't switched on for this proc)
    local tabText = UI.Tab(m, "Text", 100, 24, function() m.SetTab("text") end)
    local tabIcon = UI.Tab(m, "Icon", 100, 24, function() m.SetTab("icon") end)
    for i, tb in ipairs({ tabText, tabIcon }) do
        tb:SetPoint("TOPLEFT", 18 + (i - 1) * 104, -42)
    end
    UI.Tip(tabText, "Text popup settings", "Edit the on-screen text for this proc. Greyed out when Text popup isn't ticked for it.")
    UI.Tip(tabIcon, "Icon settings", "Edit the on-screen icon for this proc. Greyed out when Show icon isn't ticked for it.")
    local ip = CreateFrame("Frame", nil, m)
    ip:SetPoint("TOPLEFT", 14, -72)
    ip:SetPoint("BOTTOMRIGHT", -14, 16)
    ip:Hide()
    local hideL = { hint, sf, tabText, tabIcon, ip }
    local minB = TA.AddMin(m, close, hideL, 330, 44, -34, true)
    local scB = TA.AddScale(m, "customise", minB, "RIGHT", "LEFT", -6, 0, true)
    hideL[#hideL + 1] = scB
    scB:SetFrameLevel(m:GetFrameLevel() + 2)
    local F = NewForm(child, 396, 4, 4)

    local function changed()
        local f = cs and alertFrames[cs]
        if f then
            StyleAlertFrame(f)
            f.lastStr = nil
            if f:IsShown() then TA.Anim(f) end
        end
        F:Refresh()
    end

    local pend
    local function Section(label, keys)
        pend = { label = label, keys = keys, y = F.y }
        F:Section(label)
    end
    -- closes a section with a "Use global" button inside it
    local function Done()
        local lab, keys = pend.label, pend.keys
        -- it sits on the section's heading line, out of the way of the controls below
        local keepY = F.y
        F.y = pend.y
        local b = F:Button("Use global", 96, function()
            local a = cfg()
            for _, k in ipairs(keys) do a[k] = nil end
            changed()
        end, 296, true)
        F:Pos(b, 296, -5)
        F.y = keepY
        UI.Tip(b, "Use the global setting", "Clears this ability's own " .. lab:lower() .. " choices (everything in this section) so it follows the Text Alerts page again.")
        F.refreshers[#F.refreshers + 1] = function()
            local a = cs and NS.DB.alerts[cs]
            local over = false
            if a then for _, k in ipairs(keys) do if a[k] ~= nil then over = true end end end
            b:SetShown(over)
        end
    end
    local function T(label, key, x, tip)
        return F:Tick(label, function() return Eff(key) and true or false end,
            function(v) cfg()[key] = v and true or false; changed() end, x, tip)
    end
    local function SL(label, key, lo, hi, step, fmt, x, tip, w)
        return F:Mini(label, lo, hi, step, fmt, function() return Eff(key) end,
            function(v) cfg()[key] = v; changed() end, x, tip, w)
    end
    local function SPD(label, key, lo, hi, x, tip)
        return F:Mini(label, lo, hi, 0.1, "%.1fx", function() return 1 / (Eff(key) or 1) end,
            function(v) cfg()[key] = 1 / v; changed() end, x, tip, 120)
    end
    -- colours: reading gives the effective colour; the first change creates this ability's own copy
    local function Proxy(key, base)
        return setmetatable({}, {
            __index = function(_, k)
                local a = cs and NS.DB.alerts[cs]
                local c = a and a[key]
                if type(c) ~= "table" then c = base() end
                return c[k]
            end,
            __newindex = function(_, k, v)
                local a = cfg()
                if type(a[key]) ~= "table" then
                    local g = base()
                    a[key] = { r = g.r, g = g.g, b = g.b }
                end
                a[key][k] = v
            end,
        })
    end
    local colP = Proxy("col", function() return NS.DB.textStyle end)
    local olP = Proxy("outlineCol", function() return NS.DB.textStyle.outlineCol end)
    local bdP = Proxy("borderCol", function() return NS.DB.textStyle.borderCol end)
    local bgP = Proxy("bgCol", function() return NS.DB.textStyle.bgCol end)

    -- position (typed numbers; dragging on screen updates them too)
    F:Section("Position")
    local function TPos(k) local a = cs and NS.DB.alerts[cs]; return (a and a[k]) or 0 end
    local function SetTPos(k, v)
        local a = cfg()
        EnsurePos(a)
        a[k] = v
        local f = cs and alertFrames[cs]
        if f then PlaceAlert(f, cs) end
    end
    F:Field("Across", -2000, 2000, 1, function() return TPos("x") end, function(v) SetTPos("x", v) end, 0,
        "How far the text sits left or right of the middle of the screen, in pixels. Negative is left.")
    F:Field("Up/down", -2000, 2000, 1, function() return TPos("y") end, function(v) SetTPos("y", v) end, 160,
        "How far the text sits above or below the middle of the screen, in pixels. Negative is down.")
    F:Row()
    F:Gap(6)

    if TA.COUNTDOWN then
    -- countdown
    Section("Countdown", { "timer", "tpos" })
    F:Tick("Show a countdown",
        function() return TA.TimerOn(cs and NS.DB.alerts[cs]) end,
        function(v) cfg().timer = v and true or false; changed() end, 0,
        "Adds the seconds left to the popup, for procs and buffs that have a timer.")
    local tposBtn
    local function TposLabel() return TPOS_NAMES[TA.Tpos(cs and NS.DB.alerts[cs])] end
    tposBtn = F:Button("", 150, function(self)
        local order, names = { "right", "left", "below", "above" }, {}
        local curp = TA.Tpos(cs and NS.DB.alerts[cs])
        for _, k in ipairs(order) do if k ~= curp then names[#names + 1] = TPOS_NAMES[k] end end
        TA.ShowPickerFn(self, names, function(name)
            for _, k in ipairs(order) do
                if TPOS_NAMES[k] == name then cfg().tpos = k end
            end
            changed()
        end, true, true)
    end, 135, true)
    UI.Arrowise(tposBtn)
    F.refreshers[#F.refreshers + 1] = function() tposBtn:SetText("Position: " .. TposLabel()) end
    Done()
    F:Row()
    F:Gap(6)
    end

    -- text
    Section("Text", { "font", "size", "col", "outline", "thick", "shadow", "outlineCol" })
    local fontBtn
    fontBtn = F:Button("", 260, function(self)
        TA.ShowPickerFn(self, TA.FontNames(), function(name) cfg().font = name; changed() end, true)
    end, 0, true)
    UI.Arrowise(fontBtn)
    F.refreshers[#F.refreshers + 1] = function()
        local a = cs and NS.DB.alerts[cs]
        TA.FitBtn(fontBtn, "Font: ", CapWords((a and a.font) or NS.DB.textStyle.font), (a and a.font) and "" or " (global)")
    end
    F:Row()
    SL("Size", "size", 12, 72, 1, "%d", 0, "Text size.", 150)
    F:Row()
    F:ColorTbl("Colour", 0, colP, changed)
    T("Outline", "outline", 130)
    T("Thick", "thick", 220)
    T("Shadow", "shadow", 300)
    F:Row()
    F:ColorTbl("Outline", 0, olP, changed)
    Done()
    F:Row()
    F:Gap(6)

    -- box
    Section("Box", { "border", "bg", "bgAlpha", "borderCol", "bgCol" })
    T("Border", "border", 0, "A frame round the text.")
    T("Background", "bg", 130, "A solid box behind the text.")
    F:Row()
    F:ColorTbl("Border", 0, bdP, changed)
    F:ColorTbl("Background", 130, bgP, changed, 74)
    F:Row()
    SL("Opacity", "bgAlpha", 0.1, 1, 0.05, "%.2f", 0, "How solid the background is.", 120)
    Done()
    F:Row()
    F:Gap(6)

    -- animation
    Section("Animation", { "throb", "pulse", "shake", "throbPeriod", "throbSize", "pulsePeriod", "pulseMin", "shakePeriod", "shakeDist" })
    T("Throb", "throb", 0, "Grows and shrinks steadily, border and background included.")
    SPD("Speed", "throbPeriod", 0.5, 5, 100, "How fast it throbs. Higher is faster.")
    F:Row()
    SL("Size", "throbSize", 1.05, 1.6, 0.05, "%.2f", 100, "How big it gets at its largest (1 = normal size).", 120)
    F:Row()
    T("Pulse", "pulse", 0, "Fades in and out steadily.")
    SPD("Speed", "pulsePeriod", 0.5, 5, 100, "How fast it fades. Higher is faster.")
    F:Row()
    SL("Dimmest", "pulseMin", 0, 0.9, 0.05, "%.2f", 100, "How faint it gets. 0 fades right out.", 120)
    F:Row()
    T("Shake", "shake", 0, "A steady side-to-side sway.")
    SPD("Speed", "shakePeriod", 1, 10, 100, "How fast it sways. Higher is faster.")
    F:Row()
    SL("Distance", "shakeDist", 1, 30, 1, "%d", 100, "How far it sways, in pixels.", 120)
    Done()
    F:Row()
    child:SetHeight(F.y + 12)

    -- ---- Icon tab ------------------------------------------------------
    local IF = NewForm(ip, 396, 4, 4)
    local function icfg() return IC.Cfg(cs, true) end
    local function iconChanged()
        local f = cs and IC.frames[cs]
        if f then IC.Place(f) end
        IF:Refresh()
    end
    IF:Section("Icon")
    local function SetDim(which, v)
        local c = icfg()
        local w, h = IC.Dims(c)
        if which == "w" then w = v else h = v end
        c.sw, c.sh, c.size = w, h, math.max(w, h)
        iconChanged()
    end
    -- scale: 100% is the standard 48 pixel icon; this sets width and height together, so the icon stays square
    IF:Mini("Scale", 20, 500, 5, "%d%", function() local c = cs and NS.DB.icons[cs]; return c and math.max(IC.Dims(c)) / 48 * 100 or 100 end,
        function(v)
            local px = math.max(8, math.min(256, math.floor(48 * v / 100 + 0.5)))
            local c = icfg()
            c.sw, c.sh, c.size = px, px, px
            iconChanged()
        end, 0, "Makes the icon bigger or smaller, keeping it square. 100% is the standard size. Use Width and Height below to stretch it instead.", 150, 50)
    IF:Button("Reset", 60, function() local c = icfg(); c.size, c.sw, c.sh = 48, nil, nil; iconChanged() end, 326, true)
    IF:Row()
    IF:Mini("Width", 8, 256, 1, "%d", function() local c = cs and NS.DB.icons[cs]; return c and (IC.Dims(c)) or 48 end,
        function(v) SetDim("w", v) end, 0, "How wide the icon is, in pixels.", 150, 50)
    IF:Row()
    IF:Mini("Height", 8, 256, 1, "%d", function() local c = cs and NS.DB.icons[cs]; return c and select(2, IC.Dims(c)) or 48 end,
        function(v) SetDim("h", v) end, 0, "How tall the icon is, in pixels.", 150, 50)
    IF:Row()
    IF:Tick("Show countdown", function() local c = cs and NS.DB.icons[cs]; return not (c and c.timer == false) end,
        function(v) icfg().timer = v and true or false end, 0, "Shows the seconds left on the icon, when the time left is known.")
    IF:Tick("Show stack count", function() local c = cs and NS.DB.icons[cs]; return not (c and c.stacks == false) end,
        function(v) icfg().stacks = v and true or false end, 170, "Shows how many stacks you have, for procs that stack.")
    IF:Row()
    IF:Tick("Glow around the icon", function() local c = cs and NS.DB.icons[cs]; return (c and c.glow) and true or false end,
        function(v) icfg().glow = v and true or false end, 0,
        "Gives the icon on screen the same glow your action buttons get, in the colours and animation from the Glow Style page.")
    IF:Row()
    -- only for buffs you track (not procs): the icon stays up after the buff ends, with the cooldown left on the ability
    local cdTick = IF:Tick("Track the cooldown after the buff ends", function() local c = cs and NS.DB.icons[cs]; return (c and c.cdkeep) and true or false end,
        function(v) icfg().cdkeep = v and true or false end, 0,
        "When the buff runs out, the icon stays on screen, greyed out, counting down the ability's cooldown until it is ready again. Only for abilities that have a cooldown.")
    IF.refreshers[#IF.refreshers + 1] = function()
        local show = (cs and NS.DB.watch and NS.DB.watch[cs] and NS.BUFFS.CanCD(cs)) and true or false
        cdTick.pgLabel:SetText((cs == "first aid") and "Track the debuff after the bandage ends" or "Track the cooldown after the buff ends")
        cdTick:SetShown(show); cdTick.pgLabel:SetShown(show); cdTick.pgHit:SetShown(show)
    end
    IF:Row()
    IF:Gap(6)

    IF:Section("Position")
    IF:Text("Drag the icon on screen to move it. For small adjustments, hover the bottom edge of the icon for left and right arrows, or either side for up and down arrows.")
    local function IPos(k) local c = cs and NS.DB.icons[cs]; return (c and c[k]) or 0 end
    local function SetIPos(k, v) local c = icfg(); c[k] = v; iconChanged() end
    IF:Field("Across", -2000, 2000, 1, function() return IPos("x") end, function(v) SetIPos("x", v) end, 0,
        "How far the icon sits left or right of the middle of the screen, in pixels. Negative is left.")
    IF:Field("Up/down", -2000, 2000, 1, function() return IPos("y") end, function(v) SetIPos("y", v) end, 160,
        "How far the icon sits above or below the middle of the screen, in pixels. Negative is down.")
    IF:Button("Reset", 60, function() local c = icfg(); c.x, c.y = 0, 140; iconChanged() end, 326, true)
    IF:Row(30)
    IF:Button("Centre horizontally", 150, function() if cs then IC.Centre("x", cs) end end, 0, true)
    IF:Button("Centre vertically", 150, function() if cs then IC.Centre("y", cs) end end, 156)
    IF:Gap(2)

    IF:Section("Line up icons")
    IF:Text("Drag one icon close to another and it clicks into place beside it. Or line every icon you have switched on up against this one:")
    IF:Tick("Drag snapped icons together", function() return NS.DB.iconGroup ~= false end,
        function(v) NS.DB.iconGroup = v and true or false end, 0,
        "Icons that are touching move as one when you drag any of them. Hold Shift while dragging to move just one, which also detaches it from the rest.")
    IF:Row()
    IF:Mini("Gap", 0, 30, 1, "%d px",
        function() return NS.DB.iconGap or 2 end,
        function(v) NS.DB.iconGap = v end, 0, "Space left between icons when they snap together.", 220, 50)
    IF:Button("Reset", 60, function() NS.DB.iconGap = 2; IF:Refresh() end, 326, true)
    IF:Row()
    IF:Button("Line up in a row", 150, function() if cs then IC.LineUp(cs, false) end end, 0, true)
    IF:Button("Line up in a column", 150, function() if cs then IC.LineUp(cs, true) end end, 156)
    IF:Button("Reset this icon", 150, function()
        local c = icfg()
        c.size, c.sw, c.sh, c.timer, c.stacks, c.glow, c.x, c.y = 48, nil, nil, true, true, false, 0, 140
        iconChanged()
    end, 0)
    IC.onMove = function() if m:IsShown() then IF:Refresh() end end
    TA.onMove = function() if m:IsShown() then F:Refresh() end end

    -- ---- tabs ----------------------------------------------------------
    local function Avail(tab)
        if not cs then return false end
        if tab == "text" then local a = NS.DB.alerts[cs]; return (a and a.on) and true or false end
        local c = NS.DB.icons[cs]
        return (c and c.on) and true or false
    end
    m.SetTab = function(tab)
        if not Avail(tab) then tab = (tab == "text") and "icon" or "text" end
        if not Avail(tab) then
            TA.moveSpell = nil
            TA.ApplyLock()          -- nothing left to edit: close
            return
        end
        m.curTab = tab
        TA.menuTab = tab
        UI.TabLook(tabText, Avail("text"), tab == "text")
        UI.TabLook(tabIcon, Avail("icon"), tab == "icon")
        if not m.minimised then
            hint:SetShown(tab == "text"); sf:SetShown(tab == "text"); ip:SetShown(tab == "icon")
        end
        AttachCentre()
        F:Refresh(); IF:Refresh()
        TA.ApplyLock()
    end

    -- Escape: while this window is open it closes only this window (the same as Done); the next Escape closes the settings
    local function MainEsc(on)
        for i = #UISpecialFrames, 1, -1 do if UISpecialFrames[i] == "ProcGlowFrame" then table.remove(UISpecialFrames, i) end end
        if on then tinsert(UISpecialFrames, "ProcGlowFrame") end
    end
    m:SetScript("OnShow", function() MainEsc(false) end)
    m:SetScript("OnHide", function()
        -- put the settings window back on the Escape list only after this key press has finished: the game is
        -- still walking that list right now, and an entry added mid-walk would be closed by the same press
        if C_Timer and C_Timer.After then C_Timer.After(0.2, function() if not m:IsShown() then MainEsc(true) end end) else MainEsc(true) end
        GameTooltip:Hide()
        cm:Hide()
        local mf = _G.ProcGlowFrame
        if m.shiftDx and mf then          -- put the settings window back where it was
            local pt, rel, rp, x, y = mf:GetPoint(1)
            if pt then mf:SetPoint(pt, rel, rp, x + m.shiftDx, y) end
        end
        m.shiftDx = nil
        if TA.moveSpell then TA.moveSpell = nil; TA.ApplyLock() end
    end)
    -- opens snapped to the right of the settings window, the same height, with the settings window nudged
    -- left to make room; the two can still be moved separately afterwards
    local function Dock()
        m.shiftDx = nil
        local mf = _G.ProcGlowFrame
        if not (mf and mf:IsShown()) then return end
        local ku = UIParent:GetEffectiveScale()
        local kMain, kMenu = mf:GetEffectiveScale() / ku, m:GetEffectiveScale() / ku
        local gap = 4
        local dxUI = (m:GetWidth() * kMenu + gap) / 2
        dxUI = math.max(0, math.min(dxUI, (mf:GetLeft() or 0) * kMain))
        local dx = dxUI / kMain
        local pt, rel, rp, x, y = mf:GetPoint(1)
        if pt then mf:SetPoint(pt, rel, rp, x - dx, y); m.shiftDx = dx end
        m:SetHeight(mf:GetHeight() * kMain / kMenu)
        m:ClearAllPoints()
        m:SetPoint("TOPLEFT", mf, "TOPRIGHT", gap, 0)
    end
    -- drop it back next to the settings window (close enough to the right edge) and it snaps on again
    m:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local mf = _G.ProcGlowFrame
        if self.minimised or not (mf and mf:IsShown()) then return end
        local ku = UIParent:GetEffectiveScale()
        local kMain, kMenu = mf:GetEffectiveScale() / ku, self:GetEffectiveScale() / ku
        local mL, mT = self:GetLeft(), self:GetTop()
        local fR, fT = mf:GetRight(), mf:GetTop()
        if not (mL and mT and fR and fT) then return end
        if math.abs(mL * kMenu - (fR * kMain + 4)) < 40 and math.abs(mT * kMenu - fT * kMain) < 80 then
            self:ClearAllPoints()
            self:SetPoint("TOPLEFT", mf, "TOPRIGHT", 4, 0)
            self:SetHeight(mf:GetHeight() * kMain / kMenu)
        end
    end)
    m.Open = function(spell)
        cs = spell
        if m.Restore then m.Restore() end
        local wasShown = m:IsShown()
        local gi = BUFFS.groups[spell]
        UI.cls = UI.cls or select(2, UnitClass("player"))
        UI.Retheme()
        title:SetText("Customise: " .. (gi and gi.label or CapWords(spell)))
        m:Show()
        m:Raise()
        if not wasShown then Dock() end
        m.curTab = nil
        m.SetTab(TA.menuTab or "text")
    end
    return m
end

function TA.ShowMenu(spell)
    if not custMenu then custMenu = BuildCustomiseMenu() end
    if not custMenu:IsShown() or custMenu.spell ~= spell then
        custMenu.spell = spell
        custMenu.Open(spell)
    elseif custMenu.curTab ~= TA.menuTab then
        custMenu.SetTab(TA.menuTab or "text")
    end
end
-- a Text popup / Show icon tick changed: keep the tabs of an open Customise window up to date
function TA.RefreshMenuTabs()
    if custMenu and custMenu:IsShown() and custMenu.curTab then custMenu.SetTab(custMenu.curTab) end
end
function TA.HideMenu()
    if custMenu and custMenu:IsShown() then custMenu:Hide() end
    if custMenu then custMenu.spell = nil end
end
