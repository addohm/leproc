local _, NS = ...
local ApplyAll, ApplyTimerStyle, CLASS_LIST, CLASS_SPELLS, ClassItems, ClassLabel = NS.ApplyAll, NS.ApplyTimerStyle, NS.CLASS_LIST, NS.CLASS_SPELLS, NS.ClassItems, NS.ClassLabel
local NewForm, PreviewIcon, SSget, SSset, SetStack, SetTimer = NS.NewForm, NS.PreviewIcon, NS.SSget, NS.SSset, NS.SetStack, NS.SetTimer
local ShowPicker, TA, TPOS_NAMES, Title, UI, cur = NS.ShowPicker, NS.TA, NS.TPOS_NAMES, NS.Title, NS.UI, NS.cur
local pageRefresh, pages = NS.pageRefresh, NS.pages

---------------------------------------------------------------------------
-- Page: Text Alerts (look and position of the on-screen text popups)
---------------------------------------------------------------------------
local function BuildTextPage(page)
    local head = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    TA.Acc(head, "fs")
    head:SetPoint("TOPLEFT", 16, -12)
    head:SetText("Text Alerts")
    local hint = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", 16, -36)
    hint:SetWidth(508)
    hint:SetJustifyH("LEFT")
    hint:SetText("These settings are the default look for every text popup. Anything you customise on an individual ability (Class Procs, then Customise) takes priority and is never changed from here.")

    -- live preview
    local box = page:CreateTexture(nil, "BACKGROUND")
    box:SetColorTexture(0, 0, 0, 0.4)
    box:SetPoint("TOPLEFT", page, "TOPLEFT", 16, -72)
    box:SetSize(508, 62)
    -- the preview sits in a holder that shrinks it to fit the box (long text, big sizes, countdown above/below)
    local pc = CreateFrame("Frame", nil, page)
    pc:SetSize(1, 1)
    pc:SetPoint("CENTER", box, "CENTER", 0, 0)
    local pf = TA.Build(pc)
    pf:SetClampedToScreen(false)
    pf:SetPoint("CENTER", pc, "CENTER", 0, 0)
    pf.baseX, pf.baseY, pf.shakeRel = 0, 0, box
    TA.previews[#TA.previews + 1] = pf
    TA.Style(pf)
    local demoT = 0
    pf:HookScript("OnUpdate", function(self, dt)
        demoT = (demoT + dt) % 12
        local str = "Example Text"
        if TA.TimerOn(nil) then
            str = TA.WithTimer(str, tostring(math.ceil(12 - demoT)), NS.DB.textStyle.tpos or "right")
        end
        if self.lastStr ~= str then self.lastStr = str; TA.Fit(self, str) end
        local w, h = self:GetWidth(), self:GetHeight()
        if w > 0 and h > 0 then pc:SetScale(math.max(0.2, math.min(1, 496 / w, 54 / h))) end
    end)

    local F = NewForm(page, 508, 16, 142)
    local function G(key) return function() return NS.DB.textStyle[key] end end
    local function S(key)
        return function(v) NS.DB.textStyle[key] = v; TA.RefreshStyle(); TA.PlayPreview() end
    end

    F:Section("Position")
    F:Tick("Unlock to move the text (drag it, then untick to lock)",
        function() return TA.unlocked end,
        function(v) TA.SetUnlocked(v) end, 0,
        "While unlocked, every text popup you've switched on is shown on screen and can be dragged. Untick to lock it again.")
    F:Button("Test popups", 100, function() TA.TestAll() end, 300, true)
    F:Button("Reset positions", 104, function() TA.ResetPositions() end, 404, true)
    F:Row()
    F:Button("Centre horizontally", 150, function() TA.Centre("x") end, 0, true)
    F:Button("Centre vertically", 150, function() TA.Centre("y") end, 156, true)
    F:Note("(applies to all popups)", 318)
    F:Row(26)

    F:Section("Text")
    local fontBtn
    local function FontLabel() return "Font: " .. Title(NS.DB.textStyle.font) end
    fontBtn = F:Button("", 250, function(self)
        ShowPicker(self, TA.FontNames(), function(name)
            NS.DB.textStyle.font = name
            TA.FitBtn(fontBtn, "Font: ", Title(NS.DB.textStyle.font))
            TA.RefreshStyle()
        end, true)
    end, 0, true)
    F.refreshers[#F.refreshers + 1] = function() TA.FitBtn(fontBtn, "Font: ", Title(NS.DB.textStyle.font)) end
    F:Mini("Size", 12, 72, 1, "%d", G("size"), S("size"), 262, "Text size.", 100)
    F:Row()
    F:ColorTbl("Colour", 0, NS.DB.textStyle, function() TA.RefreshStyle() end)
    F:Tick("Outline", G("outline"), S("outline"), 130)
    F:Tick("Thick outline", G("thick"), S("thick"), 230)
    F:Tick("Shadow", G("shadow"), S("shadow"), 360)
    F:Row()
    F:ColorTbl("Outline", 0, NS.DB.textStyle.outlineCol, function() TA.RefreshStyle() end)
    F:Row()
    F:Tick("Show a countdown with the text", G("timer"), S("timer"), 0,
        "Adds the seconds left to the popup, for procs and buffs that have a timer. Each ability can override this in its Customise menu.")
    local tposBtn
    local function TposLabel() return "Position: " .. TPOS_NAMES[NS.DB.textStyle.tpos or "right"] end
    tposBtn = F:Button("", 150, function(self)
        local order, names = { "right", "left", "below", "above" }, {}
        local curp = NS.DB.textStyle.tpos or "right"
        for _, k in ipairs(order) do if k ~= curp then names[#names + 1] = TPOS_NAMES[k] end end
        ShowPicker(self, names, function(name)
            for _, k in ipairs(order) do
                if TPOS_NAMES[k] == name then NS.DB.textStyle.tpos = k end
            end
            tposBtn:SetText(TposLabel())
            TA.PlayPreview()
        end, true, true)
    end, 250, true)
    F.refreshers[#F.refreshers + 1] = function() tposBtn:SetText(TposLabel()) end
    F:Row()
    F:Gap(6)

    F:Section("Box")
    local tBorder = F:Tick("Border", G("border"), S("border"), 0, "A frame round the text.")
    local tBg = F:Tick("Background", G("bg"), S("bg"), 130, "A solid box behind the text.")
    local sBg = F:Mini("Opacity", 0.1, 1, 0.05, "%.2f", G("bgAlpha"), S("bgAlpha"), 260, "How solid the background is.", 90)
    F:Row()
    F:ColorTbl("Border", 0, NS.DB.textStyle.borderCol, function() TA.RefreshStyle() end)
    F:ColorTbl("Background", 130, NS.DB.textStyle.bgCol, function() TA.RefreshStyle() end, 74)
    local function bgDim()
        local on = NS.DB.textStyle.bg
        local al = on and 1 or 0.35
        if on then sBg:Enable() else sBg:Disable() end
        sBg:SetAlpha(al); sBg.lab:SetAlpha(al); sBg.val:SetAlpha(al)
    end
    tBg:HookScript("OnClick", bgDim)
    F.refreshers[#F.refreshers + 1] = bgDim
    F:Row()
    F:Gap(6)

    F:Section("Animation - runs the whole time the text is showing")
    F.barW = 66
    local A, B = 118, 322
    local function Dep(tick, key, ctrls)
        local function apply()
            local on = NS.DB.textStyle[key]
            local al = on and 1 or 0.35
            for _, c in ipairs(ctrls) do
                if on then c:Enable() else c:Disable() end
                c:SetAlpha(al); c.lab:SetAlpha(al); c.val:SetAlpha(al)
            end
        end
        tick:HookScript("OnClick", apply)
        F.refreshers[#F.refreshers + 1] = apply
    end
    local function SPDg(key) return function() return 1 / (NS.DB.textStyle[key] or 1) end end
    local function SPDs(key) return function(v) S(key)(1 / v) end end
    local tThrob = F:Tick("Throb", G("throb"), S("throb"), 0, "Grows and shrinks steadily, border and background included.")
    local s1 = F:Mini("Speed", 0.5, 5, 0.1, "%.1fx", SPDg("throbPeriod"), SPDs("throbPeriod"), A, "How fast it throbs. Higher is faster.")
    local s2 = F:Mini("Size", 1.05, 1.6, 0.05, "%.2f", G("throbSize"), S("throbSize"), B, "How big it gets at its largest (1 = normal size).")
    Dep(tThrob, "throb", { s1, s2 })
    F:Row()
    local tPulse = F:Tick("Pulse", G("pulse"), S("pulse"), 0, "Fades in and out steadily.")
    local s3 = F:Mini("Speed", 0.5, 5, 0.1, "%.1fx", SPDg("pulsePeriod"), SPDs("pulsePeriod"), A, "How fast it fades. Higher is faster.")
    local s4 = F:Mini("Dimmest", 0, 0.9, 0.05, "%.2f", G("pulseMin"), S("pulseMin"), B, "How faint it gets. 0 fades right out.")
    Dep(tPulse, "pulse", { s3, s4 })
    F:Row()
    local tShake = F:Tick("Shake", G("shake"), S("shake"), 0, "A steady side-to-side sway.")
    local s5 = F:Mini("Speed", 1, 10, 0.2, "%.1fx", SPDg("shakePeriod"), SPDs("shakePeriod"), A, "How fast it sways. Higher is faster.")
    local s6 = F:Mini("Distance", 1, 30, 1, "%d", G("shakeDist"), S("shakeDist"), B, "How far it sways, in pixels.")
    Dep(tShake, "shake", { s5, s6 })
    F:Row()

    page:SetScript("OnShow", function() TA.PlayPreview() end)
    return function() F:Refresh(); TA.RefreshStyle() end
end
NS.BuildTextPage = BuildTextPage

---------------------------------------------------------------------------
-- Page: Timer & Stacks (the numbers drawn on a glowing button)
---------------------------------------------------------------------------
local function BuildCountersPage(page)
    local head = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    TA.Acc(head, "fs")
    head:SetPoint("TOPLEFT", 16, -12)
    head:SetText("Timer & Stacks")
    local hint = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", 16, -36)
    hint:SetWidth(490)
    hint:SetJustifyH("LEFT")
    hint:SetText("The numbers drawn on a glowing button: a countdown of the seconds left, and a stack count for procs that stack. Place each one where you like and use the icon on the right to preview. Stack numbers only appear for procs that stack.")

    -- live preview (loops a countdown, shows a stack of 3)
    local pv = CreateFrame("Frame", nil, page)
    pv:SetSize(52, 52)
    pv:SetPoint("TOPLEFT", page, "TOPLEFT", 16 + 520, -14)
    local ico = pv:CreateTexture(nil, "ARTWORK")
    ico:SetAllPoints()
    ico:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    ico:SetTexture(PreviewIcon())
    local demoT = 0
    pv:SetScript("OnUpdate", function(self, dt)
        demoT = (demoT + dt) % 12
        SetTimer(self, "__pgTimer", 12 - demoT)
        SetStack(self, "__pgStack", 3)
        if self.__pgTimer then ApplyTimerStyle(self.__pgTimer) end
        if self.__pgStack then ApplyTimerStyle(self.__pgStack) end
    end)

    local F = NewForm(page, 588, 16, 92)
    local PRESETS = { { "topleft", "Top left" }, { "topright", "Top right" }, { "center", "Middle" },
                      { "bottomleft", "Bottom left" }, { "bottomright", "Bottom right" } }

    local function Placement(kind)
        F:Note("Position", 0)
        local btns = {}
        local function mark()
            for key, b in pairs(btns) do
                if NS.DB.style[kind .. "Pos"] == key then b:Disable() else b:Enable() end
            end
        end
        for i, pr in ipairs(PRESETS) do
            btns[pr[1]] = F:Button(pr[2], 100, function()
                NS.DB.style[kind .. "Pos"] = pr[1]
                NS.DB.style[kind .. "X"], NS.DB.style[kind .. "Y"] = 0, 0
                ApplyAll()
                F:Refresh()
            end, 56 + (i - 1) * 106, true)
            local fs = btns[pr[1]]:GetFontString()
            if fs then fs:SetWordWrap(false); fs:SetWidth(0) end
        end
        F.refreshers[#F.refreshers + 1] = mark
        F:Row(30)
        local function axis(label, key, x, tip, what)
            F:Mini(label, -24, 24, 1, "%d", SSget(key), SSset(key), x, tip, 96)
            F:Button("Reset", 44, function()
                NS.DB.style[key] = 0
                ApplyAll()
                F:Refresh()
            end, x + 222, true)
        end
        axis("Left/Right", kind .. "X", 0, "Nudge it sideways, in pixels. Pick a position above first, then fine-tune here.")
        axis("Up/Down", kind .. "Y", 300, "Nudge it up or down, in pixels.")
        F:Row()
    end

    F:Section("Countdown timer")
    F:Tick("Show a countdown on glowing buttons",
        SSget("timerOn"), SSset("timerOn"), 0,
        "Counts down the seconds left to use a proc, on the button that glows.")
    F:Row()
    F:Mini("Text size", 8, 30, 1, "%d", SSget("timerSize"), SSset("timerSize"), 0,
        "Size of the countdown number.", 190)
    F:Note("Red at 5 s or less", 300)
    F:Row()
    Placement("timer")
    F:Gap(10)

    F:Section("Stack count")
    F:Tick("Show how many stacks you have (Fingers of Frost, Maelstrom Weapon...)",
        SSget("stackOn"), SSset("stackOn"), 0,
        "Shows a number on the glowing button for procs that build up in stacks. It only appears while you have the proc.")
    F:Row()
    F:Mini("Text size", 8, 30, 1, "%d", SSget("stackSize"), SSset("stackSize"), 0,
        "Size of the stack number.", 190)
    F:Row()
    Placement("stack")

    return function() F:Refresh() end
end
NS.BuildCountersPage = BuildCountersPage

---------------------------------------------------------------------------
-- Page: Class Procs (landing page listing every class)
---------------------------------------------------------------------------
local function BuildClassesPage(page)
    local head = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    TA.Acc(head, "fs")
    head:SetPoint("TOPLEFT", 16, -12)
    head:SetText("Class Procs / Buffs")
    local sub = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", 16, -36)
    sub:SetWidth(500)
    sub:SetJustifyH("LEFT")
    sub:SetText("Pick a class to choose which of its procs glow, pop up as text or show as an icon, to track its buffs, and to add buffs of your own. Your own class is marked (you).")

    local _, pc = UnitClass("player")
    -- your own class first, the rest in their usual order
    local ordered = {}
    for _, c in ipairs(CLASS_LIST) do if c == pc then ordered[#ordered + 1] = c end end
    for _, c in ipairs(CLASS_LIST) do if c ~= pc then ordered[#ordered + 1] = c end end
    local customBtn
    for idx, c in ipairs(ordered) do
        local col, rowN = (idx - 1) % 3, math.floor((idx - 1) / 3)
        local b = UI.Button(page, ClassLabel(c) .. (c == pc and " (you)" or ""), 164, 44, function() NS.ShowPage("class", c) end)
        b:SetPoint("TOPLEFT", page, "TOPLEFT", 16 + col * 172, -(70 + rowN * 52))
        if c == "OTHER" then customBtn = b end
        local fs = b:GetFontString()
        if fs then
            fs:SetFontObject("GameFontNormal")
            fs:ClearAllPoints()
            fs:SetPoint("LEFT", b, "LEFT", 44, 0)
            local rc = RAID_CLASS_COLORS and RAID_CLASS_COLORS[c]
            if rc then fs:SetTextColor(rc.r, rc.g, rc.b) end
        end
        b:HookScript("OnLeave", function() if fs then local rc = RAID_CLASS_COLORS and RAID_CLASS_COLORS[c]; if rc then fs:SetTextColor(rc.r, rc.g, rc.b) end end end)
        if c == pc then       -- your own class carries the accent bar
            local bar = b:CreateTexture(nil, "OVERLAY")
            bar:SetWidth(3)
            bar:SetPoint("TOPLEFT", 1, -1); bar:SetPoint("BOTTOMLEFT", 1, 1)
            UI.Tint(bar)
        end
        if CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[c] then
            local t = b:CreateTexture(nil, "OVERLAY")
            t:SetSize(30, 30)
            t:SetPoint("LEFT", 8, 0)
            t:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
            t:SetTexCoord(unpack(CLASS_ICON_TCOORDS[c]))
        end
    end
    -- "Custom / other" only appears when you have added an ability that isn't tied to a class
    local function RefreshCustom()
        if customBtn then customBtn:SetShown(#ClassItems("OTHER") > 0) end
    end
    RefreshCustom()
    return RefreshCustom
end
NS.BuildClassesPage = BuildClassesPage

---------------------------------------------------------------------------
-- Window, left-hand list and page switching
---------------------------------------------------------------------------
function NS.ShowPage(page, class)
    cur.page = page
    if class then cur.class = class end
    if page == "class" and not cur.class then
        local _, pc = UnitClass("player")
        cur.class = (pc and CLASS_SPELLS[pc]) and pc or "WARRIOR"
    end
    for key, p in pairs(pages) do
        if key == page then p:Show() else p:Hide() end
    end
    if pageRefresh[page] then pageRefresh[page]() end
    if NS.NavRefresh then NS.NavRefresh() end
end

local function MakeNavRow(parent, label, level, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(22)
    b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

    b.sel = b:CreateTexture(nil, "BACKGROUND")
    b.sel:SetAllPoints()
    b.sel:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    b.sel:SetBlendMode("ADD")
    b.sel:SetAlpha(0.75)
    TA.Acc(b.sel, "tex", 1, 1, 1)
    b.sel:Hide()

    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(14, 14)
    b.icon:SetPoint("LEFT", 4, 0)
    b.icon:Hide()

    b.text = b:CreateFontString(nil, "OVERLAY", level == 0 and "GameFontNormal" or "GameFontHighlight")
    b.text:SetPoint("LEFT", 8 + level * 16 + (level == 0 and 14 or 0), 0)
    b.text:SetJustifyH("LEFT")
    b.text:SetText(label)
    if level == 0 then TA.Acc(b.text, "fs") end

    b.level = level
    b:SetScript("OnClick", onClick)
    return b
end
NS.MakeNavRow = MakeNavRow
