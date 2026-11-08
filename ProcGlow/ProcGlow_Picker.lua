local _, NS = ...
local BUFFS, ClassItems, ClassLabel, IC, LOC, LoadLists = NS.BUFFS, NS.ClassItems, NS.ClassLabel, NS.IC, NS.LOC, NS.LoadLists
local NextName, Print, SHOUTS, ShortStance, SpellIcon, StanceList = NS.NextName, NS.Print, NS.SHOUTS, NS.ShortStance, NS.SpellIcon, NS.StanceList
local TA, Title, UI, buffProcs, cur = NS.TA, NS.Title, NS.UI, NS.buffProcs, NS.cur

---------------------------------------------------------------------------
-- Searchable ability picker (shared pop-up used by the class pages)
---------------------------------------------------------------------------
local pickerFrame, pickerCatcher
local PICK_ROWS = 11

-- every ability name we can offer for a class: the class's proc list plus,
-- for your own class, everything in your spellbook
local function AbilityChoices(class, items)
    local seen, out = {}, {}
    local function add(n)
        if type(n) ~= "string" or n == "" then return end
        local k = n:lower()
        if not seen[k] then seen[k] = true; out[#out + 1] = k end
    end
    for _, it in ipairs(items or {}) do add(it.spell) end
    local _, pc = UnitClass("player")
    if class == pc then
        pcall(function()
            local nameOf = GetSpellBookItemName or GetSpellName
            if GetNumSpellTabs and nameOf then
                for t = 1, GetNumSpellTabs() do
                    local _, _, offset, num = GetSpellTabInfo(t)
                    for i = (offset or 0) + 1, (offset or 0) + (num or 0) do
                        local passive = IsPassiveSpell and IsPassiveSpell(i, "spell")
                        if not passive then
                            local bn = nameOf(i, "spell")
                            if type(bn) == "string" then bn = LOC.Key(bn:lower()) end
                            add(bn)
                        end
                    end
                end
            end
        end)
    end
    table.sort(out)
    return out
end

local function HidePicker()
    if pickerFrame then pickerFrame:Hide() end
    if pickerCatcher then pickerCatcher:Hide() end
end

local function ShowPicker(anchor, choices, onPick, noIcons, plain, exact)
    if not pickerFrame then
        pickerCatcher = CreateFrame("Button", nil, UIParent)
        pickerCatcher:SetAllPoints(UIParent)
        pickerCatcher:SetFrameStrata("TOOLTIP")
        pickerCatcher:SetFrameLevel(10)
        pickerCatcher:EnableMouse(true)
        pickerCatcher:SetScript("OnClick", HidePicker)
        pickerCatcher:Hide()

        local f = CreateFrame("Frame", "ProcGlowPicker", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
        tinsert(UISpecialFrames, "ProcGlowPicker")
        f:SetSize(300, 42 + PICK_ROWS * 20 + 10)
        f:SetFrameStrata("TOOLTIP")
        f:SetFrameLevel(30)
        f:SetClampedToScreen(true)
        f:EnableMouse(true)
        f:EnableMouseWheel(true)
        f:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 14,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        f:Hide()
        f.offset = 0
        f.filtered = {}

        local lab = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lab:SetPoint("TOPLEFT", 12, -10)
        lab:SetText("Search:")
        f.lab = lab
        local px = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        px:SetSize(24, 24)
        px:SetPoint("TOPRIGHT", f, "TOPRIGHT", 8, 8)
        px:SetScript("OnClick", HidePicker)
        f.px = px
        px:Hide()

        local box = UI.FlatEdit(CreateFrame("EditBox", NextName("ProcGlowPickSearch"), f, "InputBoxTemplate"))
        box:SetSize(140, 20)
        box:SetPoint("TOPLEFT", 56, -6)
        box:SetAutoFocus(false)
        box:SetMaxLetters(40)
        f.box = box

        f.btns = {}
        local function Refill()
            local q = strtrim(box:GetText() or ""):lower()
            local list = {}
            for _, n in ipairs(f.choices or {}) do
                local ln = LOC.on and LOC.Local(n)
                if q == "" or n:find(q, 1, true) or (ln and LOC.Lower(ln):find(LOC.Lower(q), 1, true)) then list[#list + 1] = n end
            end
            -- allow free text (an ability on your bars, or an action slot number)
            if q ~= "" then
                local exact = false
                for _, n in ipairs(list) do if n == q then exact = true end end
                if not exact then list[#list + 1] = q end
            end
            f.filtered = list
            f.offset = math.max(0, math.min(f.offset, #list - PICK_ROWS))
            for i = 1, PICK_ROWS do
                local b = f.btns[i]
                local n = list[f.offset + i]
                if n then
                    b.value = n
                    local label = exact and n or (LOC.Disp(n) or Title(n))
                    if tonumber(n) then label = "Action slot " .. n end
                    b.text:SetText(label)
                    local tex = (not f.noIcons) and not tonumber(n) and SpellIcon(n) or nil
                    if f.noIcons then
                        b.icon:SetTexture(nil)
                    elseif tex then
                        b.icon:SetTexture(tex)
                    else
                        b.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                    end
                    b:Show()
                else
                    b.value = nil
                    b:Hide()
                end
            end
            f.count:SetText(#list == 0 and "No matches" or "")
        end
        f.Refill = Refill

        for i = 1, PICK_ROWS do
            local b = CreateFrame("Button", nil, f)
            b:SetSize(280, 20)
            b:SetPoint("TOPLEFT", 10, -34 - (i - 1) * 20)
            b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
            b.icon = b:CreateTexture(nil, "ARTWORK")
            b.icon:SetSize(16, 16)
            b.icon:SetPoint("LEFT", 2, 0)
            b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            b.text:SetPoint("LEFT", b.icon, "RIGHT", 5, 0)
            b.text:SetPoint("RIGHT", b, "RIGHT", -4, 0)
            b.text:SetWordWrap(false)
            b.text:SetJustifyH("LEFT")
            b:SetScript("OnClick", function(self)
                local v = self.value
                HidePicker()
                if v and LOC.on and not tonumber(v) then v = LOC.Key(v, true) end
                if v and f.onPick then f.onPick(v) end
            end)
            f.btns[i] = b
        end

        f.count = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        f.count:SetPoint("TOPLEFT", 14, -40)

        f:SetScript("OnMouseWheel", function(self, delta)
            self.offset = self.offset - delta * 3
            Refill()
        end)
        box:SetScript("OnTextChanged", function() f.offset = 0; Refill() end)
        box:SetScript("OnEscapePressed", HidePicker)
        box:SetScript("OnEnterPressed", function()
            local first = f.filtered[1]
            HidePicker()
            if first and LOC.on and not tonumber(first) then first = LOC.Key(first, true) end
            if first and f.onPick then f.onPick(first) end
        end)
        f:SetScript("OnHide", function() if pickerCatcher then pickerCatcher:Hide() end end)
        pickerFrame = f
        TA.AutoClose(f, function() return (f.box and f.box:HasFocus()) or TA.Over(f.anchorW) end)
    end

    local f = pickerFrame
    f.choices = choices
    f.anchorW = anchor
    f.noIcons = noIcons
    f.exact = exact
    f.onPick = onPick
    f.offset = 0
    f.box:SetText("")
    local top = plain and 8 or 34
    f.lab:SetShown(not plain); f.box:SetShown(not plain)
    f.px:Hide()    -- no dropdown list has an X: a click away or Escape closes it
    for i, b in ipairs(f.btns) do
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", 10, -top - (i - 1) * 20)
        b:SetWidth(plain and 130 or 190)
    end
    f.count:ClearAllPoints(); f.count:SetPoint("TOPLEFT", 14, -(top + 6))
    f:SetSize(plain and 150 or 210, plain and (top + #choices * 20 + 10) or (42 + PICK_ROWS * 20 + 10))
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
    pickerCatcher:Show()
    f:Show()
    f.Refill()
    if not plain then f.box:SetFocus() end
end
NS.ShowPicker = ShowPicker
TA.ShowPickerFn = ShowPicker

function UI.MakePage(parent, c)
    local P = {}
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -4)
    frame:SetSize(508, 10)
    P.frame = frame
    local COLS = { glow = 300, text = 350, icon = 400 }
    local ROWH, DET = 30, 28
    local rows, secs, syncs = {}, {}, {}
    local relayout
    P.altOpen = {}
    local _, playerClass = UnitClass("player")
    local curStances = (playerClass == "WARRIOR" or playerClass == "DRUID") and c == playerClass

    local function Fs(font, text, parentF)
        local fs = (parentF or frame):CreateFontString(nil, "OVERLAY", font)
        fs:SetText(text or "")
        return fs
    end

    -- the page's data: the same settings the classic page uses, just described as rows
    local function Defs()
        local list = {}
        local defs = BUFFS.class[c] or {}
        local function Warn(key, th)
            return { kind = "num", label = "Warn when", min = 0, max = 15, step = 0.5, unit = "min left",
                get = function() return (NS.DB.track.th[key] or th) / 60 end,
                set = function(v) NS.DB.track.th[key] = v * 60 end,
                tip = "Minutes left before the buff starts to glow. 0 means only when it is missing." }
        end
        if c == "WARRIOR" then
            list[#list + 1] = { section = 1, key = "battle shout", name = "Battle Shout", defText = "Battle Shout ending!",
                glow = { get = function() return not NS.DB.disabled["battle shout"] end, set = function(v) NS.DB.disabled["battle shout"] = (not v) or nil end },
                extras = {
                    { kind = "num", label = "Warn when", min = 1, max = 60, step = 1, unit = "sec left",
                      get = function() return NS.DB.shout.threshold end, set = function(v) NS.DB.shout.threshold = v end,
                      tip = "Seconds left on your own shout before it starts to glow." },
                    { kind = "tick", label = "Glow when missing", get = function() return NS.DB.shout.glowMissing end,
                      set = function(v) NS.DB.shout.glowMissing = v and true or false end, tip = "Glow Battle Shout when you have none of your own on you." },
                    { kind = "tick", label = "Glow with no rage", get = function() return NS.DB.shout.ignoreRage end,
                      set = function(v) NS.DB.shout.ignoreRage = v and true or false end, tip = "Keep the glow on even when you do not have the rage to cast it, so you still see the reminder." },
                } }
        end
        for _, d in ipairs(defs.singles or {}) do
            local key = d.spell:lower()
            local ex = { Warn(key, d.th) }
            if d.tankOnly then
                ex[#ex + 1] = { kind = "tick", label = "Only when tanking",
                    get = function() return NS.DB.track.rfTank end,
                    set = function(v) NS.DB.track.rfTank = v and true or false end,
                    tip = "Only tracked while you are in a party or raid and your group role is set to tank." }
            end
            list[#list + 1] = { section = 1, key = key, name = d.spell, defText = d.spell .. " needed!",
                glow = { get = function() return NS.DB.track.on[key] end, set = function(v) NS.DB.track.on[key] = v and true or false end },
                extras = ex }
        end
        for _, g in ipairs(defs.groups or {}) do
            local gi = BUFFS.groups[g.key]
            local ex = {}
            if g.th then ex[#ex + 1] = Warn(g.key, g.th) end
            ex[#ex + 1] = { kind = "num", label = "Back to choice after", min = 0.5, max = 10, step = 0.5, unit = "min",
                get = function() return (NS.DB.track.linger[g.key] or BUFFS.LINGER) / 60 end,
                set = function(v) NS.DB.track.linger[g.key] = v * 60 end,
                tip = "If you cast a different one on yourself it is tracked instead. After this long with none of yours on you, tracking returns to your choice." }
            list[#list + 1] = { section = 1, key = g.key, group = g.key, label = Title(gi.label), defText = gi.label .. " missing!",
                glow = { get = function() return NS.DB.track.groupOn[g.key] end, set = function(v) NS.DB.track.groupOn[g.key] = v and true or false end },
                extras = ex }
        end
        if c == "PALADIN" then
            list[#list + 1] = { section = 1, key = "seals", name = "Seals", note = "follows the seal you have up", iconOnly = true, extras = {} }
        end
        for _, it in ipairs(ClassItems(c)) do
            local sp = it.spell
            local row = { section = 2, key = sp, name = it.display, note = it.extra, defText = TA.DefaultText(sp), extras = {} }
            if it.watch then row.note = row.note or "tracked buff" elseif it.textOnly then row.note = row.note or "popup only" end
            if c == "WARRIOR" and not (it.watch or it.textOnly) then row.redirect = true end
            if it.watch then row.watch = true; row.cd = BUFFS.CanCD(sp) end
            if it.watch and BUFFS.missingOnly[sp] then
                -- gathering tracking: always a "missing" reminder, so only icon and text are offered
                row.note = "shows when missing"
                row.cd = nil
            elseif it.watch and not row.cd then
                -- a plain tracked buff (no cooldown): icon and text, either while it is on you or while it is missing
                row.extras[#row.extras + 1] = { kind = "tick", label = "Show when missing",
                    get = function() return NS.DB.missing and NS.DB.missing[sp] and true or false end,
                    set = function(v)
                        NS.DB.missing = NS.DB.missing or {}
                        NS.DB.missing[sp] = v and true or nil
                        local a = TA.Cfg(sp)
                        if a and (a.text == nil or a.text == "" or a.text == row.defText or a.text == row.defMissing) then
                            a.text = v and row.defMissing or row.defText
                        end
                    end,
                    tip = "Show the icon and text when this buff is NOT on you, instead of while it is. Only works while the game lets the addon read your buffs (not in combat or battlegrounds)." }
                row.defMissing = (it.display or sp) .. " missing!"
            elseif it.watch or it.iconOnly then
                row.iconOnly = true
            elseif not it.textOnly then
                row.glow = { get = function() return not NS.DB.disabled[sp] end,
                    set = function(v) if v then NS.DB.disabled[sp] = nil else NS.DB.disabled[sp] = true end end }
            end
            if it.watch or it.custom then
                row.del = function()
                    NS.DB.added[sp] = nil
                    if NS.DB.watch and NS.DB.watch[sp] then
                        NS.DB.watch[sp] = nil
                        NS.DB.icons[sp] = nil
                        local f = IC.frames[sp]
                        if f then f:Hide() end
                    end
                    if TA.moveSpell == sp then TA.moveSpell = nil; TA.ApplyLock() end
                    NS.DB.customClass[sp] = nil; NS.DB.disabled[sp] = nil; NS.DB.redirect[sp] = nil; NS.DB.redirectCond[sp] = nil
                    if LoadLists then LoadLists() end
                    if P.onChange then P.onChange() end
                end
            end
            list[#list + 1] = row
        end
        return list
    end

    local function BuildRow(r)
        local row = { spec = r, expanded = false, det = {} }
        local key = r.key
        if r.group then
            row.lab = Fs("GameFontHighlight", r.label)
            row.drop = UI.Dropdown(frame, 150, function(self)
                local cur = BUFFS.Selected(r.group)
                local choices, known = {}, {}
                for _, m in ipairs(BUFFS.members[r.group]) do
                    if m ~= cur then
                        choices[#choices + 1] = m
                        if BUFFS.Known(BUFFS.tracked[m].name) then known[#known + 1] = m end
                    end
                end
                if #known > 0 then choices = known end
                TA.ShowPickerFn(self, choices, function(name)
                    NS.DB.track.sel[r.group] = name
                    BUFFS.state[r.group] = nil
                    row.drop.label:SetText(Title(name))
                end, false, true)
            end)
            UI.Tip(row.drop, "Which " .. r.label:lower() .. " to track", "Click to choose. If you cast a different one it follows that instead.")
            syncs[#syncs + 1] = function() row.drop.label:SetText(Title(BUFFS.Selected(r.group))) end
        else
            row.name = Fs("GameFontHighlight", r.name)
            row.name:SetJustifyH("LEFT")
            row.name:SetWidth(270)
            row.name:SetWordWrap(false)
            if r.note then row.name:SetText(r.name .. " |cff8a93a6(" .. r.note .. ")|r") end
        end

        local function Needs()      -- text or an icon on an untracked buff would never show
            if r.glow and not r.glow.get() then r.glow.set(true); if row.cbGlow then row.cbGlow:Sync() end end
        end
        if r.glow then
            row.cbGlow = UI.Check(frame, r.glow.get, function(v) r.glow.set(v) end)
            UI.Tip(row.cbGlow, "Glow", "Glows the ability's button on your action bar.")
            syncs[#syncs + 1] = function() row.cbGlow:Sync() end
        end
        if not r.iconOnly then
            row.cbText = UI.Check(frame,
                function() local a = TA.Cfg(key); return a and a.on end,
                function(v)
                    local a = TA.Cfg(key, true)
                    a.on = v and true or false
                    if v and (a.text == nil or a.text == "") then a.text = r.defText end
                    if v then Needs() end
                    if row.textEdit then row.textEdit:SetText(a.text or "") end
                    relayout()
                end)
            UI.Tip(row.cbText, "Text", "Shows a line of text on screen. Open More to change the words.")
            syncs[#syncs + 1] = function() row.cbText:Sync() end
        end
        row.cbIcon = UI.Check(frame,
            function() local ic = IC.Cfg(key); return ic and ic.on end,
            function(v)
                if v then IC.Enable(key); Needs() else IC.Cfg(key, true).on = false end
                TA.RefreshMenuTabs()
            end)
        UI.Tip(row.cbIcon, "Icon", "Shows its icon on screen, with the time left.")
        syncs[#syncs + 1] = function() row.cbIcon:Sync() end
        if r.watch and r.cd then
            -- tracked buffs with a cooldown: keep the icon up after the buff ends, counting down the ability's cooldown
            row.cbCd = UI.Check(frame,
                function() local ic = IC.Cfg(key); return (ic and ic.cdkeep) and true or false end,
                function(v)
                    if v then IC.Enable(key) end
                    IC.Cfg(key, true).cdkeep = v and true or false
                    if row.cbIcon then row.cbIcon:Sync() end
                    TA.RefreshMenuTabs()
                end)
            local isDebuff = (key == "first aid")      -- First Aid: what you wait for is the Recently Bandaged debuff
            row.cdLab = Fs("GameFontHighlightSmall", isDebuff and "Track debuff" or "Track cooldown")
            row.cdLab:SetPoint("RIGHT", row.cbCd, "LEFT", -3, 0)      -- the words sit left of the tick, so the ticks line up in their column
            if row.name then row.name:SetWidth(math.max(120, COLS.text - 13 - 3 - math.ceil(row.cdLab:GetStringWidth() or 80) - 14)) end
            if isDebuff then
                UI.Tip(row.cbCd, "Track debuff", "When the bandage ends, the icon stays on screen, greyed out, counting down the Recently Bandaged debuff, so you can see when you can bandage again (whoever bandaged you). Turns the icon on.")
            else
                UI.Tip(row.cbCd, "Track cooldown", "When the buff runs out, the icon stays on screen, greyed out, counting down the ability's cooldown until it is ready again. Turns the icon on.")
            end
            syncs[#syncs + 1] = function() row.cbCd:Sync() end
        end

        row.more = UI.Button(frame, "More", 56, 22, function() row.expanded = not row.expanded; relayout() end)
        UI.Tip(row.more, "More", "Extra settings for this ability. Tick Text to get the text options.")
        if r.del then
            row.delBtn = UI.Button(frame, "x", 22, 22, function() r.del() end)
            UI.Tip(row.delBtn, "Remove", "Takes this off the list.")
        end
        row.line = frame:CreateTexture(nil, "ARTWORK")
        UI.Fit(row.line, function() row.line:SetHeight(UI.Px(frame)) end)
        UI.Reg(function() UI.Paint(row.line, UI.Col("edge"), 0.6) end)

        -- details strip: a list of lines, laid out top to bottom by relayout
        local strip = CreateFrame("Frame", nil, frame)
        UI.Skin(strip, "panel")
        strip:Hide()
        row.strip = strip
        if not r.iconOnly then
            local ln = { text = true, widgets = {} }
            local lab = Fs("GameFontNormalSmall", "Text", strip)
            local e = UI.Edit(strip, 200, 22)
            e:SetMaxLetters(60)
            local function Commit() TA.Cfg(key, true).text = strtrim(e:GetText() or "") end
            e:SetScript("OnEnterPressed", function(self) Commit(); self:ClearFocus() end)
            e:SetScript("OnEditFocusLost", Commit)
            row.textEdit = e
            UI.Tip(e, "Text", "The words shown on screen. Clear it to go back to the default.")
            local tl = Fs("GameFontHighlightSmall", "Countdown", strip)
            local tk = UI.Check(strip, function() return TA.TimerOn(TA.Cfg(key)) end, function(v) TA.Cfg(key, true).timer = v end)
            lab:SetPoint("TOPLEFT", 12, -6)
            e:SetPoint("TOPLEFT", 150, -3)
            tk:SetPoint("TOPLEFT", 370, -4)
            UI.Tip(tk, "Countdown", "Adds the time left to the text, for example 2:30.")
            tl:SetPoint("LEFT", tk, "RIGHT", 6, 0)
            if TA.COUNTDOWN then ln.widgets = { lab, e, tl, tk } else tl:Hide(); tk:Hide(); ln.widgets = { lab, e } end
            ln.y = 0
            row.det[#row.det + 1] = ln
            syncs[#syncs + 1] = function()
                local a = TA.Cfg(key)
                e:SetText(a and a.text or ""); e:SetCursorPosition(0)
                tk:Sync()
            end
        end
        for _, x in ipairs(r.extras) do
            local ln = { widgets = {}, textOnly = nil }
            local lab = Fs("GameFontNormalSmall", x.label, strip)
            lab:SetPoint("TOPLEFT", 12, -6)
            local w
            if x.kind == "num" then
                w = UI.Number(strip, x.min, x.max, x.step, x.unit, x.get, x.set)
                w:SetPoint("TOPLEFT", 150, -3)
            else
                w = UI.Check(strip, x.get, x.set)
                w:SetPoint("TOPLEFT", 150, -4)
            end
            if x.tip then if w.Tip then w:Tip(x.label, x.tip) else UI.Tip(w, x.label, x.tip) end end
            syncs[#syncs + 1] = function() w:Sync() end
            ln.widgets = { lab, w }
            row.det[#row.det + 1] = ln
        end
        if r.redirect then
            local sp = r.key
            local function altOn() return (NS.DB.redirect[sp] ~= nil) or P.altOpen[sp] end
            local l1 = Fs("GameFontNormalSmall", "Also show on", strip)
            l1:SetPoint("TOPLEFT", 12, -6)
            local tk = UI.Check(strip, altOn, function(v)
                if v then P.altOpen[sp] = true else P.altOpen[sp] = nil; NS.DB.redirect[sp] = nil; NS.DB.redirectCond[sp] = nil end
                relayout()
            end)
            tk:SetPoint("TOPLEFT", 150, -4)
            local tl = Fs("GameFontHighlightSmall", "another button", strip)
            tl:SetPoint("LEFT", tk, "RIGHT", 6, 0)
            UI.Tip(tk, "Also show on another button", "Also shows this proc's glow on a second button of your choice. The original button always glows as normal.")
            syncs[#syncs + 1] = function() tk:Sync() end
            row.det[#row.det + 1] = { widgets = { l1, tk, tl } }
            -- which button
            local l2 = Fs("GameFontNormalSmall", "Button", strip)
            l2:SetPoint("TOPLEFT", 12, -6)
            local dd
            dd = UI.Dropdown(strip, 200, function(self)
                ShowPicker(self, AbilityChoices(c, ClassItems(c)), function(name)
                    NS.DB.redirect[sp] = name
                    dd.label:SetText(tonumber(name) and ("Action slot " .. name) or Title(name))
                end)
            end)
            dd:SetPoint("TOPLEFT", 150, -3)
            UI.Tip(dd, "Which button also shows this proc", "Click to choose from your abilities. Type in the search box to narrow the list, or type an action slot number.")
            syncs[#syncs + 1] = function()
                local n = NS.DB.redirect[sp]
                dd.label:SetText(n and (tonumber(n) and ("Action slot " .. n) or Title(n)) or "Choose a button...")
            end
            row.det[#row.det + 1] = { widgets = { l2, dd }, vis = altOn }
            -- stances / forms (Warrior and Druid, on their own class page)
            if curStances then
                local function StSet()
                    local cond = NS.DB.redirectCond[sp]
                    local set = {}
                    if not cond then return set end
                    if cond.stances then return cond.stances end
                    if cond.mode == "in" and cond.stance then set[cond.stance] = true
                    elseif cond.mode == "notin" and cond.stance then
                        for _, n in ipairs(StanceList()) do if n ~= cond.stance then set[n] = true end end
                    end
                    return set
                end
                local checks, labels, widgets = {}, {}, {}
                local l3 = Fs("GameFontNormalSmall", "Only in", strip)
                l3:SetPoint("TOPLEFT", 12, -6)
                widgets[#widgets + 1] = l3
                for i = 1, 3 do
                    local cb = UI.Check(strip, function() local list = StanceList(); return list[i] and StSet()[list[i]] end, function()
                        local set, any, list = {}, false, StanceList()
                        for k = 1, 3 do if checks[k] and checks[k]:GetChecked() and list[k] then set[list[k]] = true; any = true end end
                        NS.DB.redirectCond[sp] = any and { stances = set } or nil
                    end)
                    cb:SetPoint("TOPLEFT", 150 + (i - 1) * 112, -4)
                    local fs = Fs("GameFontHighlightSmall", "", strip)
                    fs:SetPoint("LEFT", cb, "RIGHT", 6, 0)
                    UI.Tip(cb, "Only in this stance / form", "Ticked = the other button shows the proc while you are in this stance. Nothing ticked = it always shows. The original button is never affected.")
                    checks[i], labels[i] = cb, fs
                    widgets[#widgets + 1] = cb; widgets[#widgets + 1] = fs
                end
                syncs[#syncs + 1] = function()
                    local list = StanceList()
                    for i = 1, 3 do
                        labels[i]:SetText(list[i] and ShortStance(list[i]) or "")
                        checks[i]:Sync()
                    end
                end
                row.det[#row.det + 1] = { widgets = widgets, vis = function() return altOn() and #StanceList() > 0 end,
                    post = function(show)
                        local list = StanceList()
                        for i = 1, 3 do checks[i]:SetShown(show and list[i] ~= nil); labels[i]:SetShown(show and list[i] ~= nil) end
                    end }
            end
        end
        rows[#rows + 1] = row
    end

    ---------------------------------------------------------------- top bar (one Test, one Customise)
    local top = CreateFrame("Frame", nil, frame)
    top:SetSize(508, 30)
    top:SetPoint("TOPLEFT", 0, 0)
    local btnCust = UI.Button(top, "Customise", 110, 26, function()
        if TA.moveSpell then TA.moveSpell = nil; TA.moveSet = nil; TA.ApplyLock(); return end
        local set, firstIcon, firstText = {}, nil, nil
        for _, row in ipairs(rows) do
            local k = row.spec.key
            local a, ic = TA.Cfg(k), IC.Cfg(k)
            if a and a.on then set[k] = true; firstText = firstText or k end
            if ic and ic.on then firstIcon = firstIcon or k end
        end
        if not (firstIcon or firstText) then Print("Tick Text or Icon on at least one ability first."); return end
        TA.moveSet = set
        -- every ticked popup needs its frame to exist before the lock is applied, or only the first one unlocks
        for k in pairs(set) do pcall(TA.GetFrame, k) end
        local ok, err = pcall(TA.OpenMenu, firstText or firstIcon, firstText and "text" or "icon")
        if not ok then Print("Customise could not open: " .. tostring(err)) end
    end)
    btnCust:SetPoint("TOPRIGHT", -2, -2)
    local mine = (c == playerClass) or c == "OTHER"
    local function NotMine() return "Only available while you are playing a " .. ClassLabel(c) .. ". Log in on one to try these." end
    UI.Tip(btnCust, "Customise", "Shows everything you have ticked on this page so you can drag it into place, and opens the window for size, colour and more. Click again (Done) when finished.")
    local btnTest = UI.Button(top, "Test", 90, 26, function()
        for _, row in ipairs(rows) do
            local k = row.spec.key
            local a, ic = TA.Cfg(k), IC.Cfg(k)
            if (a and a.on) or (ic and ic.on) then TA.TestBoth(k) end
        end
    end)
    btnTest:SetPoint("RIGHT", btnCust, "LEFT", -8, 0)
    UI.Tip(btnTest, "Test", "Shows everything you have ticked on this page for a few seconds, as if it had just happened.")
    if not mine then
        -- you can only try out and place things for the class you are playing
        UI.Grey(btnTest, true); UI.Grey(btnCust, true)
        UI.Tip(btnTest, "Not available", NotMine)
        UI.Tip(btnCust, "Not available", NotMine)
    end
    local hint = Fs("GameFontDisableSmall", "Tick how you want each one shown. Test and Customise act on everything ticked here.", top)
    hint:SetPoint("LEFT", 4, 0)
    hint:SetWidth(280); hint:SetJustifyH("LEFT")
    TA.lockHooks[#TA.lockHooks + 1] = function()
        btnCust.label:SetText(TA.moveSpell and TA.moveSet and "Done" or "Customise")
    end

    local function Section(title, sub)
        local s = {}
        s.title = Fs("GameFontNormal", title)
        UI.Reg(function() local c = UI.Col("gold"); s.title:SetTextColor(c[1], c[2], c[3]) end)
        s.line = frame:CreateTexture(nil, "ARTWORK"); UI.Fit(s.line, function() s.line:SetHeight(UI.Px(frame)) end); UI.Reg(function() UI.Paint(s.line, UI.Col("gold"), 0.5) end)
        s.sub = Fs("GameFontDisableSmall", sub)
        s.sub:SetWidth(500); s.sub:SetJustifyH("LEFT"); s.sub:SetWordWrap(false)
        s.h = { Fs("GameFontDisableSmall", "Glow"), Fs("GameFontDisableSmall", "Text"), Fs("GameFontDisableSmall", "Icon") }
        secs[#secs + 1] = s
    end
    Section("Buffs", "Reminds you when your own buff is missing or running out.")
    Section("Procs", "Glows when the ability becomes ready.")
    -- one switch for every buff on the page: stay quiet in towns, inns and on flight paths
    local hasRest = (BUFFS.class[c] ~= nil) or c == "WARRIOR"
    local function RestTbl() return (c == "WARRIOR") and NS.DB.shout or NS.DB.track end
    P.rest = UI.Check(frame, function() return RestTbl().hideResting end, function(v) RestTbl().hideResting = v and true or false end)
    -- a shaded strip with an accent bar, so this reads as a setting for the whole section and is easy to find
    P.restStrip = frame:CreateTexture(nil, "BACKGROUND")
    P.restStrip:SetSize(500, 30)
    P.restStrip:SetColorTexture(1, 1, 1, 0.08)
    P.restBar = frame:CreateTexture(nil, "ARTWORK")
    P.restBar:SetSize(3, 30)
    P.restBar:SetPoint("TOPLEFT", P.restStrip, "TOPLEFT", 0, 0)
    UI.Reg(function() local cc = UI.Col("gold"); P.restBar:SetColorTexture(cc[1], cc[2], cc[3], 0.9) end)
    P.restLab = Fs("GameFontNormal", "All buffs: hide while resting / on a flight path")
    UI.Reg(function() local cc = UI.Col("gold"); P.restLab:SetTextColor(cc[1], cc[2], cc[3]) end)
    P.restLab:SetPoint("LEFT", P.rest, "RIGHT", 8, 0)
    P.restHit = CreateFrame("Button", nil, frame)
    P.restHit:SetPoint("LEFT", P.rest, "RIGHT", 0, 0)
    P.restHit:SetSize(380, 24)
    P.restHit:SetScript("OnClick", function() P.rest:Click() end)
    UI.Tip(P.rest, "Hide while resting", "No buff glows or shows text in towns and inns (where you are resting) or while on a flight path. Applies to every buff on this page.")
    UI.Tip(P.restHit, "Hide while resting", "No buff glows or shows text in towns and inns (where you are resting) or while on a flight path. Applies to every buff on this page.")
    P.rest:Hide(); P.restLab:Hide(); P.restHit:Hide(); P.restStrip:Hide(); P.restBar:Hide()

    function relayout()
        local y = 40
        for _, s in ipairs(secs) do s.used = false end
        for _, row in ipairs(rows) do
            local r = row.spec
            local s = secs[r.section]
            if not s.used then
                s.used = true
                y = y + 8
                s.title:ClearAllPoints(); s.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -y)
                s.sub:ClearAllPoints(); s.sub:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -(y + 25))
                s.line:ClearAllPoints(); s.line:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -(y + 20)); s.line:SetWidth(500)
                local xs = { COLS.glow, COLS.text, COLS.icon }
                for i, h in ipairs(s.h) do
                    h:ClearAllPoints(); h:SetPoint("TOP", frame, "TOPLEFT", xs[i], -(y + 3)); h:Show()
                end
                s.title:Show(); s.line:Show(); s.sub:Show()
                y = y + 44
                if r.section == 1 and hasRest then
                    P.restStrip:ClearAllPoints(); P.restStrip:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -y)
                    P.rest:ClearAllPoints(); P.rest:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -(y + 5))
                    P.rest:Show(); P.restLab:Show(); P.restHit:Show(); P.restStrip:Show(); P.restBar:Show()
                    y = y + 38
                end
            end
            local ry = y
            if row.lab then
                row.lab:ClearAllPoints(); row.lab:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -(ry + 8))
                row.drop:ClearAllPoints(); row.drop:SetPoint("TOPLEFT", frame, "TOPLEFT", 130, -(ry + 4))
                row.lab:Show(); row.drop:Show()
            else
                row.name:ClearAllPoints(); row.name:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -(ry + 8)); row.name:Show()
            end
            local function Col(w, x) if w then w:ClearAllPoints(); w:SetPoint("TOP", frame, "TOPLEFT", x, -(ry + 5)); w:Show() end end
            Col(row.cbGlow, COLS.glow); Col(row.cbText, COLS.text); Col(row.cbIcon, COLS.icon)
            if row.cbCd then Col(row.cbCd, COLS.text); row.cdLab:Show() end
            local ta = TA.Cfg(r.key)
            local hasMore = #r.extras > 0 or r.redirect or (not r.iconOnly and ta and ta.on)
            if not hasMore then row.expanded = false end
            if r.iconOnly and #r.extras == 0 and not r.redirect then
                row.more:Hide()          -- icon-only: there is never anything more to show
            else
                row.more:ClearAllPoints(); row.more:SetPoint("TOPLEFT", frame, "TOPLEFT", 424, -(ry + 4))
                row.more.label:SetText(row.expanded and "Less" or "More"); row.more:Show()
                UI.Grey(row.more, not hasMore)
            end
            if row.delBtn then row.delBtn:ClearAllPoints(); row.delBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 482, -(ry + 4)); row.delBtn:Show() end
            local h = ROWH
            if row.expanded then
                local a = TA.Cfg(r.key)
                local ly = 4
                for _, ln in ipairs(row.det) do
                    local show = (not ln.text) or (a and a.on)
                    if ln.vis then show = ln.vis() and true or false end
                    for _, w in ipairs(ln.widgets) do w:SetShown(show and true or false) end
                    if ln.post then ln.post(show) end
                    if show then
                        for _, w in ipairs(ln.widgets) do
                            -- every widget keeps its x; only the line's top moves
                            if not w.pgBase then
                                local _, _, _, bx, by = w:GetPoint(1)
                                w.pgBase = { bx or 0, by or 0 }
                            end
                            local pt, rel, rp = w:GetPoint(1)
                            if rel == row.strip then
                                w:ClearAllPoints()
                                w:SetPoint(pt, row.strip, rp, w.pgBase[1], w.pgBase[2] - ly + 4)
                            end
                        end
                        ly = ly + DET
                    end
                end
                if ly > 4 then
                    row.strip:ClearAllPoints()
                    row.strip:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -(ry + ROWH - 2))
                    row.strip:SetSize(492, ly + 2)
                    row.strip:Show()
                    h = ROWH + ly + 4
                else
                    row.strip:Hide()
                end
            else
                row.strip:Hide()
            end
            row.line:ClearAllPoints(); row.line:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -(ry + h - 1)); row.line:SetWidth(500); row.line:Show()
            y = y + h
        end
        if not secs[1].used then P.rest:Hide(); P.restLab:Hide(); P.restHit:Hide(); P.restStrip:Hide(); P.restBar:Hide() end
        for _, s in ipairs(secs) do
            if not s.used then s.title:Hide(); s.line:Hide(); s.sub:Hide(); for _, h in ipairs(s.h) do h:Hide() end end
        end
        P.height = y + 16
        frame:SetHeight(P.height)
        if P.onChange then P.onChange(true) end
    end

    local function Clear()
        for _, row in ipairs(rows) do
            -- (not ipairs: a row has no label or drop-down when it is not a group, and ipairs would stop at that gap)
            for _, k in ipairs({ "lab", "drop", "name", "cbGlow", "cbText", "cbIcon", "cbCd", "cdLab", "more", "delBtn", "line", "strip" }) do
                local w = row[k]
                if w then w:Hide() end
            end
        end
        wipe(rows); wipe(syncs)
    end

    function P.Refresh()
        UI.cls = c
        local list = Defs()
        local sig = {}
        for _, r in ipairs(list) do sig[#sig + 1] = r.section .. ":" .. r.key end
        sig = table.concat(sig, "|")
        if P.sig ~= sig then
            P.sig = sig
            Clear()
            for _, r in ipairs(list) do BuildRow(r) end
        end
        for _, f in ipairs(syncs) do f() end
        if hasRest then P.rest:Sync() end
        UI.Retheme()
        relayout()
    end
    return P
end

local function BuildClassPage(page)
    local titleFs = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleFs:SetPoint("TOPLEFT", 16, -12)

    local backBtn = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")

    TA.Acc(backBtn, "btn")
    backBtn:SetSize(110, 22)
    backBtn:SetPoint("TOPRIGHT", -14, -12)
    backBtn:SetText("< All classes")
    backBtn:SetScript("OnClick", function() NS.ShowPage("classes") end)

    local sub = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", 16, -36)
    sub:SetWidth(506)
    sub:SetJustifyH("LEFT")
    sub:SetText("Untick an ability to stop it glowing. Tick \"Allow alternate ability to display proc\" to make another button show it too. The original button always glows.")

    -- the whole area under the intro text (buff section + proc list) scrolls as one,
    -- so nothing can be pushed out of reach when several options are switched on
    local OFF = 60
    local outer = CreateFrame("ScrollFrame", nil, page)
    outer:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -OFF)
    outer:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -14, 44)
    local ochild = CreateFrame("Frame", nil, outer)
    ochild:SetSize(522, 10)
    outer:SetScrollChild(ochild)
    outer:EnableMouseWheel(true)
    local obar = CreateFrame("Slider", nil, page)
    obar:SetOrientation("VERTICAL")
    obar:SetPoint("TOPRIGHT", page, "TOPRIGHT", -3, -(OFF + 4))
    obar:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -3, 48)
    obar:SetWidth(8)
    obar:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
    do
        local th = obar:GetThumbTexture()
        th:SetSize(8, 40); th:SetVertexColor(1, 0.82, 0, 0.55)
        local bg = obar:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(); bg:SetColorTexture(1, 1, 1, 0.06)
    end
    obar:SetMinMaxValues(0, 1); obar:SetValue(0)
    obar:Hide()
    local oSyncing = false
    local function OuterSync()
        local range = math.max(0, ochild:GetHeight() - outer:GetHeight())
        if outer:GetVerticalScroll() > range then outer:SetVerticalScroll(range) end
        oSyncing = true
        obar:SetMinMaxValues(0, math.max(range, 1))
        obar:SetValue(outer:GetVerticalScroll())
        oSyncing = false
        if range > 0 then obar:Show() else obar:Hide() end
    end
    obar:SetScript("OnValueChanged", function(_, v)
        if oSyncing then return end
        outer:SetVerticalScroll(v)
    end)
    local function OuterWheel(_, delta)
        local range = math.max(0, ochild:GetHeight() - outer:GetHeight())
        outer:SetVerticalScroll(math.max(0, math.min(range, outer:GetVerticalScroll() - delta * 40)))
        OuterSync()
    end
    outer:SetScript("OnMouseWheel", OuterWheel)
    outer:SetScript("OnSizeChanged", OuterSync)

    local simplePages = {}
    local curItems = {}
    local Rebuild
    local lastScrollClass

    function Rebuild()
        HidePicker()
        local c = cur.class or "WARRIOR"
        sub:SetText("Tick how each ability should show. Use More for the words, timings and other details.")
        titleFs:SetText(ClassLabel(c))
        local col = RAID_CLASS_COLORS and RAID_CLASS_COLORS[c]
        if col then titleFs:SetTextColor(col.r, col.g, col.b) else titleFs:SetTextColor(1, 0.82, 0) end
        for _, sp in pairs(simplePages) do sp.frame:Hide() end
        local sp = simplePages[c]
        if not sp then
            sp = UI.MakePage(ochild, c)
            simplePages[c] = sp
            sp.onChange = function(sized)
                if sized then
                    ochild:SetHeight(sp.height + 8)
                    OuterSync()
                else
                    Rebuild()
                end
            end
        end
        sp.frame:ClearAllPoints()
        sp.frame:SetPoint("TOPLEFT", ochild, "TOPLEFT", 8, -4)
        sp.frame:Show()
        sp.Refresh()
        if lastScrollClass ~= c then outer:SetVerticalScroll(0); lastScrollClass = c end
        OuterSync()
    end

    -- add a custom ability to the class being shown
    local addLabel = page:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    addLabel:SetPoint("BOTTOMLEFT", 16, 18)
    addLabel:SetText("Track a buff/cooldown:")

    local addEdit = UI.FlatEdit(CreateFrame("EditBox", NextName("ProcGlowAdd"), page, "InputBoxTemplate"))
    addEdit:SetSize(150, 20)
    addEdit:SetPoint("BOTTOMLEFT", 142, 14)
    addEdit:SetAutoFocus(false)
    addEdit:SetMaxLetters(40)

    local function DoAdd()
        local t = strtrim(addEdit:GetText() or ""):lower()
        if t == "" then return end
        if NS.DB.watch[t] then
            Print("|cffffd100" .. t .. "|r is already being tracked.")
            return
        end
        -- a tracked buff: an icon with the time left while the buff is on you
        NS.DB.watch[t] = true
        NS.DB.removed[t] = nil
        if cur.class and cur.class ~= "OTHER" then NS.DB.customClass[t] = cur.class end
        IC.Enable(t)
        addEdit:SetText("")
        addEdit:ClearFocus()
        Rebuild()
    end
    -- suggestions: abilities of the class being edited that match what is typed and are not listed yet
    local SUG_N = 10
    local sugg = CreateFrame("Frame", nil, page, BackdropTemplateMixin and "BackdropTemplate" or nil)
    sugg:SetSize(250, SUG_N * 22 + 10)
    sugg:SetPoint("BOTTOMLEFT", addEdit, "TOPLEFT", -4, 4)
    sugg:SetFrameLevel(page:GetFrameLevel() + 40)
    sugg:EnableMouse(true)
    sugg:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 14,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    sugg:Hide()
    sugg.offset = 0
    sugg.more = sugg:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    sugg.more:SetPoint("TOPLEFT", 10, -7)
    sugg.btns = {}
    for i = 1, SUG_N do
        local b = CreateFrame("Button", nil, sugg)
        b:SetSize(238, 22)
        b:SetPoint("BOTTOMLEFT", 6, 5 + (i - 1) * 22)     -- first match sits nearest the box
        b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize(16, 16)
        b.icon:SetPoint("LEFT", 3, 0)
        b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        b.text:SetPoint("LEFT", b.icon, "RIGHT", 6, 0)
        b:SetScript("OnClick", function(self)
            if not self.value then return end
            addEdit:SetText(self.value)
            sugg:Hide()
            DoAdd()
        end)
        sugg.btns[i] = b
    end

    local function ClassPool()
        local c = cur.class or "WARRIOR"
        local pool, seen = {}, {}
        local function addList(list)
            for _, e in ipairs(list or {}) do
                local k = e[1]
                if not seen[k] and not SHOUTS[k] and not BUFFS.tracked[k] and not BUFFS.auraOf[k]
                    and not (e.race and e.race ~= BUFFS.RaceKey()) then
                    seen[k] = true; pool[#pool + 1] = k
                end
            end
        end
        local function addSeen(t)
            for k in pairs(t or {}) do
                if not seen[k] and not SHOUTS[k] and not BUFFS.tracked[k] and not BUFFS.auraOf[k] and not buffProcs[k]
                    and k ~= "clearcasting" then
                    seen[k] = true; pool[#pool + 1] = k
                end
            end
        end
        -- cooldown abilities (not buffs): only those you have learned (all of them if the spellbook cannot be read)
        local bookOk = BUFFS.Book() ~= nil      -- only filter by spellbook when it can actually be read
        local function addAbil(list)
            for _, k in ipairs(list or {}) do
                if not seen[k] and not SHOUTS[k] and not BUFFS.tracked[k] and not BUFFS.auraOf[k]
                    and (not bookOk or BUFFS.Known(k)) then
                    seen[k] = true; pool[#pool + 1] = k
                end
            end
        end
        if c == "OTHER" then
            for _, list in pairs(BUFFS.list) do addList(list) end
            addList(BUFFS.racials[BUFFS.RaceKey()])
            for _, t in pairs(NS.DB.seen or {}) do addSeen(t) end
        else
            addList(BUFFS.list[c])
            addList(BUFFS.racials[BUFFS.RaceKey()])
            addSeen(NS.DB.seen and NS.DB.seen[c])
            if c == (select(2, UnitClass("player"))) then
                addAbil(BUFFS.abilities[c])
                addAbil(BUFFS.racialAbil[BUFFS.RaceKey()])
            end
        end
        return pool
    end

    local function RefreshSuggestions()
        local q = strtrim(addEdit:GetText() or ""):lower()
        if not addEdit:HasFocus() then sugg:Hide(); return end
        local have = {}
        for _, it in ipairs(curItems) do have[it.spell] = true end
        for n in pairs(NS.DB.added) do have[n] = true end
        for n in pairs(NS.DB.watch) do have[n] = true end
        local starts, contains = {}, {}
        for _, n in ipairs(ClassPool()) do
            if not have[n] and not SHOUTS[n] then
                local pos = n:find(q, 1, true)
                if pos == 1 then starts[#starts + 1] = n
                elseif pos then contains[#contains + 1] = n end
            end
        end
        table.sort(starts); table.sort(contains)
        local list = {}
        for _, n in ipairs(starts) do list[#list + 1] = n end
        for _, n in ipairs(contains) do list[#list + 1] = n end
        if #list == 0 then sugg:Hide(); return end
        sugg.offset = math.max(0, math.min(sugg.offset or 0, #list - SUG_N))
        for i = 1, SUG_N do
            local b = sugg.btns[i]
            local n = list[sugg.offset + i]
            if n then
                b.value = n
                b.text:SetText(Title(n))
                local sc = NS.DB.seen and NS.DB.seen[cur.class or ""]
                local sico = sc and type(sc[n]) == "string" and sc[n] or nil
                b.icon:SetTexture(SpellIcon(n) or sico or BUFFS.auraIcon[n] or "Interface\\Icons\\INV_Misc_QuestionMark")
                b:Show()
            else
                b.value = nil
                b:Hide()
            end
        end
        local shown = math.min(#list, SUG_N)
        local extra = (#list > SUG_N) and 14 or 0
        sugg.more:SetText(extra > 0 and ("scroll for more (" .. #list .. " buffs)") or "")
        sugg:SetHeight(shown * 22 + 10 + extra)
        sugg:Show()
    end
    sugg:EnableMouseWheel(true)
    sugg:SetScript("OnMouseWheel", function(self, delta)
        self.offset = (self.offset or 0) - delta * 3
        RefreshSuggestions()
    end)
    addEdit:SetScript("OnTextChanged", function() sugg.offset = 0; RefreshSuggestions() end)
    addEdit:HookScript("OnMouseUp", RefreshSuggestions)
    addEdit:SetScript("OnEditFocusGained", RefreshSuggestions)
    addEdit:SetScript("OnEditFocusLost", function()
        local over = sugg.IsMouseOver and sugg:IsMouseOver() or (MouseIsOver and MouseIsOver(sugg))
        if not over then sugg:Hide() end
    end)
    addEdit:SetScript("OnEnterPressed", function() sugg:Hide(); DoAdd() end)
    addEdit:SetScript("OnEscapePressed", function(self) sugg:Hide(); self:ClearFocus() end)
    page:HookScript("OnHide", function() sugg:Hide() end)

    local addBtn = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")

    TA.Acc(addBtn, "btn")
    addBtn:SetSize(60, 22)
    addBtn:SetPoint("LEFT", addEdit, "RIGHT", 8, 0)
    addBtn:SetText("Add")
    addBtn:SetScript("OnClick", DoAdd)

    local addHint = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    addHint:SetPoint("LEFT", addBtn, "RIGHT", 10, 0)
    addHint:SetText("click for a list, or type any buff")

    return function() Rebuild() end
end
NS.BuildClassPage = BuildClassPage
