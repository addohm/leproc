local _, NS = ...
local buffProcs = NS.buffProcs
local BUFFS, LOC, POPUP_ONLY, ProcActive, ProcRemaining, WHITE = NS.BUFFS, NS.LOC, NS.POPUP_ONLY, NS.ProcActive, NS.ProcRemaining, NS.WHITE

---------------------------------------------------------------------------
-- Text popups: on-screen text shown while a proc is up
---------------------------------------------------------------------------
local TA = {}
NS.TA = TA                 -- text-alert helpers (kept in one table to save upvalues)
-- window accents: text is always white; borders, highlights and buttons pick up
-- a little of your class colour when the option is on
TA.acc = {}
TA.quiet, TA.full = {}, {}   -- names glowing faintly / fully this tick
function TA.PaintAccents()
    local _, pc = UnitClass("player")
    local cc = NS.DB and NS.DB.classUI and RAID_CLASS_COLORS and RAID_CLASS_COLORS[pc]
    for _, a in ipairs(TA.acc) do
        local o, k = a.obj, a.kind
        if k == "fs" then
            o:SetTextColor(1, 1, 1)
        else
            local r, g, b = a.r, a.g, a.b
            if cc then
                if k == "tex" then r, g, b = cc.r * 0.6, cc.g * 0.6, cc.b * 0.6
                elseif k == "bg" then r, g, b = cc.r * 0.2, cc.g * 0.2, cc.b * 0.2
                else
                    local m = (k == "border") and 0.6 or (k == "wbg") and 0.3 or 1
                    r, g, b = r + (cc.r - r) * m, g + (cc.g - g) * m, b + (cc.b - b) * m
                end
            end
            if k == "tex" then o:SetVertexColor(r, g, b)
            elseif k == "ctex" then o:SetColorTexture(r, g, b, a.a)
            elseif k == "border" then o:SetBackdropBorderColor(r, g, b, a.a)
            elseif k == "bg" or k == "wbg" then o:SetBackdropColor(r, g, b, a.a) end
        end
    end
    if TA.UIRetheme then TA.UIRetheme() end
end
-- button label that never spills out of the button: only the name part is shortened ("Name...")
function TA.FitBtn(b, pre, name, suf)
    suf = suf or ""
    local fs = b:GetFontString()
    b:SetText(pre .. name .. suf)
    if not fs then return end
    fs:SetWordWrap(false)
    fs:SetWidth(0)
    b.baseW = b.baseW or b:GetWidth()
    -- grow the button to fit the whole label; only a very long one is shortened
    local need = math.ceil(fs:GetStringWidth()) + 26
    b:SetWidth(math.max(b.baseW, math.min(need, b.baseW + 130)))
    local maxW = b:GetWidth() - 18
    local n = name
    while #n > 3 and fs:GetStringWidth() > maxW do
        n = n:gsub("[\128-\191]*[^\128-\191]$", "")
        fs:SetText(pre .. n .. "..." .. suf)
    end
end

function TA.Acc(obj, kind, r, g, b, a)
    if kind == "btn" then
        obj:SetNormalFontObject("GameFontHighlight")
        obj:SetHighlightFontObject("GameFontHighlight")
        if TA.FlatButton then TA.FlatButton(obj) end      -- every standard button takes the flat look
        return
    end
    TA.acc[#TA.acc + 1] = { obj = obj, kind = kind, r = r or 1, g = g or 0.82, b = b or 0, a = a or 1 }
    TA.PaintAccents()
end
local alertFrames = {}
NS.alertFrames = alertFrames        -- spell -> frame
local alertTest = {}          -- spell -> time its test ends
local onBarNames = {}
NS.onBarNames = onBarNames         -- spell names found on visible action buttons this tick
TA.unlocked = false
TA.moveSpell = nil
TA.lockHooks = {}
function TA.TextEditing(spell)
    if not TA.moveSpell then return false end
    -- Customise on a whole page: every ticked popup stays unlocked whichever tab is open
    if TA.moveSet and TA.moveSet[spell] then return true end
    return TA.moveSpell == spell and TA.menuTab ~= "icon"
end
function TA.Unlocked(f) return TA.unlocked or (f.spell ~= nil and TA.TextEditing(f.spell)) end

-- a popup only takes the mouse while you are moving it; otherwise clicks and camera turns pass straight through it
local function SetMouse(f, on)
    if on then NS.YesMouse(f) else NS.NoMouse(f) end
end
TA.SetMouse = SetMouse

local TEXT_FONTS = {
    -- the game's own font for the client's language (the plain Friz Quattrocento file has no Cyrillic / CJK letters)
    ["friz quattrocento"] = (({ ruRU = 1, koKR = 1, zhCN = 1, zhTW = 1 })[GetLocale and GetLocale() or ""] and STANDARD_TEXT_FONT) or "Fonts\\FRIZQT__.TTF",
    ["arial narrow"] = "Fonts\\ARIALN.TTF",
    ["morpheus"] = "Fonts\\MORPHEUS.TTF",
    ["skurri"] = "Fonts\\SKURRI.TTF",
}

local function SharedMedia()
    return LibStub and LibStub("LibSharedMedia-3.0", true)
end

function TA.FontNames()
    local out, seen = {}, {}
    for n in pairs(TEXT_FONTS) do out[#out + 1] = n; seen[n] = true end
    local lsm = SharedMedia()
    if lsm then
        for _, n in ipairs(lsm:List("font")) do
            local k = n:lower()
            if not seen[k] then seen[k] = true; out[#out + 1] = k end
        end
    end
    table.sort(out)
    return out
end

local function FontPath(name)
    if TEXT_FONTS[name] then return TEXT_FONTS[name] end
    local lsm = SharedMedia()
    if lsm then
        for _, n in ipairs(lsm:List("font")) do
            if n:lower() == name then return lsm:Fetch("font", n) end
        end
    end
    return TEXT_FONTS["friz quattrocento"]
end

-- countdown shown with a text popup: an ability's own setting wins, otherwise the Text Alerts default
-- The countdown on TEXT popups is switched off and its settings hidden: it cannot be shown for buff procs in combat
-- (their popup is the buff's own copy, which addon code can't update). Set to true to bring the option back.
TA.COUNTDOWN = false
function TA.TimerOn(a)
    if not TA.COUNTDOWN then return false end
    if a and a.timer ~= nil then return a.timer and true or false end
    return NS.DB.textStyle.timer ~= false
end
function TA.Tpos(a) return (a and a.tpos) or NS.DB.textStyle.tpos or "right" end
function TA.WithTimer(str, n, tp)
    if tp == "left" then return n .. "  " .. str
    elseif tp == "below" then return str .. "\n" .. n
    elseif tp == "above" then return n .. "\n" .. str end
    return str .. "  " .. n
end

function TA.Cfg(spell, create)
    local a = NS.DB.alerts[spell]
    if not a and create then
        a = { on = false, text = "" }
        NS.DB.alerts[spell] = a
    end
    return a
end

local function CapWords(sp)
    local l = LOC.Local(sp)
    if l then return l end          -- the client's own spelling (accented letters would trip the pattern below)
    return (sp:gsub("(%a)([%w']*)", function(a, b) return a:upper() .. b end))
end
NS.CapWords = CapWords
function TA.DefaultText(spell)
    local gi = BUFFS.groups[spell]
    if gi then return gi.label .. " missing!" end
    if POPUP_ONLY[spell] then return POPUP_ONLY[spell] end
    if BUFFS.missingOnly and BUFFS.missingOnly[spell] then return CapWords(spell) .. " missing!" end
    return CapWords(spell) .. "!"
end

local OL_DIRS = { {-1,0},{1,0},{0,-1},{0,1},{-1,-1},{1,-1},{-1,1},{1,1} }
local function SyncOutline(f)
    if not f.ol then return end
    local str = f.text:GetText() or ""
    -- the outline copies always use exactly the font the main text ended up with
    local p, sz = f.text:GetFont()
    for _, o in ipairs(f.ol) do
        if p then
            local op, os = o:GetFont()
            if op ~= p or os ~= sz then o:SetFont(p, sz, "") end
        end
        o:SetText(str)
    end
end

function TA.SyncUI(f)
    if not f.anchor then return end
    f.anchor:ClearAllPoints()
    if f.dragging then
        f.anchor:SetAllPoints(f)
    else
        f.anchor:SetPoint("CENTER", UIParent, "CENTER", f.baseX or 0, f.baseY or 0)
        f.anchor:SetSize(f:GetWidth(), f:GetHeight())
    end
    f.ui:SetShown(TA.Unlocked(f) and f:IsShown())
end

local function FitText(f, str)
    f.text:SetText(str)
    SyncOutline(f)
    local w = f.text:GetStringWidth() or 40
    local h = f.text:GetStringHeight() or 20
    f:SetSize(math.max(60, w + 34), h + 20)
    TA.SyncUI(f)
end
NS.FitText = FitText

-- fonts can finish loading a moment after the popup is first built (seen on the first login of
-- a session), which left the outline copies the wrong size. Re-apply them a few times, once.
local function KickFonts(f)
    if f.kicked or not (C_Timer and C_Timer.After) then return end
    f.kicked = true
    for _, d in ipairs({ 0.25, 1, 3 }) do
        C_Timer.After(d, function()
            if f.mirror and InCombatLockdown and InCombatLockdown() then return end
            local p, s, fl = f.text:GetFont()
            if p and s then
                f.text:SetFont(p, s + 1, fl or ""); f.text:SetFont(p, s, fl or "")
                for _, o in ipairs(f.ol or {}) do o:SetFont(p, s + 1, ""); o:SetFont(p, s, "") end
            end
            if f.lastStr then FitText(f, f.lastStr) end
        end)
    end
end

local function StyleAlertFrame(f)
    local st = NS.DB.textStyle
    local ac = f.spell and NS.DB.alerts[f.spell]
    local function E(k) return TA.Eff(f, k) end     -- this ability's own setting, else the global one
    local flags = ""
    local path = FontPath((ac and ac.font) or st.font)
    if not f.text:SetFont(path, E("size"), flags) then
        path = TEXT_FONTS["friz quattrocento"]
        f.text:SetFont(path, E("size"), flags)
    end
    -- coloured outline: eight offset copies of the text behind it
    local fpath, fsize = f.text:GetFont()
    path = fpath or path
    f.ol = f.ol or {}
    if #f.ol == 0 then
        for i = 1, 8 do f.ol[i] = f:CreateFontString(nil, "BORDER") end
    end
    local want = E("outline") or E("thick")
    local oc = E("outlineCol") or { r = 0, g = 0, b = 0 }
    local d = E("thick") and 2 or 1
    for i, o in ipairs(f.ol) do
        if want then
            o:SetFont(path, fsize or E("size"), "")
            o:SetTextColor(oc.r, oc.g, oc.b, 1)
            o:ClearAllPoints()
            o:SetPoint("CENTER", f.text, "CENTER", OL_DIRS[i][1] * d, OL_DIRS[i][2] * d)
            o:Show()
        else
            o:Hide()
        end
    end
    SyncOutline(f)
    local tc = (ac and ac.col) or st
    f.text:SetTextColor(tc.r, tc.g, tc.b, 1)
    if E("shadow") then
        f.text:SetShadowColor(0, 0, 0, 1); f.text:SetShadowOffset(2, -2)
    else
        f.text:SetShadowOffset(0, 0)
    end
    if f.SetBackdrop then
        if E("border") or E("bg") then
            f:SetBackdrop({
                bgFile = E("bg") and WHITE or nil,
                edgeFile = E("border") and "Interface\\Tooltips\\UI-Tooltip-Border" or nil,
                edgeSize = 14, insets = { left = 4, right = 4, top = 4, bottom = 4 },
            })
            if E("bg") then local bc = E("bgCol") or { r = 0, g = 0, b = 0 }; f:SetBackdropColor(bc.r, bc.g, bc.b, E("bgAlpha")) end
            if E("border") then local bc = E("borderCol") or st; f:SetBackdropBorderColor(bc.r, bc.g, bc.b, 1) end
        else
            f:SetBackdrop(nil)
        end
    end
    if f.lastStr then FitText(f, f.lastStr) end
    if not f.mirror and f:IsShown() then TA.Anim(f) end   -- (a mirror's shown state is hidden from addons)
    KickFonts(f)
end
NS.StyleAlertFrame = StyleAlertFrame

TA.Style, TA.Fit = StyleAlertFrame, FitText
TA.previews = {}

local function RestorePoint(f)
    f:ClearAllPoints()
    f:SetPoint("CENTER", f.shakeRel or UIParent, "CENTER", f.baseX or 0, f.baseY or 0)
end

-- (re)starts the continuous animations that are switched on
function TA.Eff(f, key)
    local ac = f.real and f.spell and NS.DB.alerts[f.spell]
    if ac and ac[key] ~= nil then return ac[key] end
    return NS.DB.textStyle[key]
end

function TA.Anim(f)
    f.pulse:Stop()
    f:SetAlpha(1)
    if f.real and TA.unlocked then return end
    if TA.Eff(f, "pulse") then
        local mn = TA.Eff(f, "pulseMin") or 0.35
        f.pulseA:SetDuration(TA.Eff(f, "pulsePeriod") or 0.5)
        if f.pulseA.SetToAlpha then f.pulseA:SetToAlpha(mn) else f.pulseA:SetChange(-(1 - mn)) end
        f.pulse:Play()
    end
    f.throbOn = TA.Eff(f, "throb") and true or false
    f.shakeOn = TA.Eff(f, "shake") and true or false
    if not (f.throbOn or f.shakeOn) and f.baseX then
        f:SetScale(1)
        RestorePoint(f)
    end
end

function TA.PlayPreview()
    for _, pf in ipairs(TA.previews) do TA.Anim(pf) end
end

-- builds a text popup frame; parent = nil for a real on-screen one
function TA.Build(parent)
    local f = CreateFrame("Frame", nil, parent or UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    if not parent then f:SetFrameStrata("HIGH") end
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    SetMouse(f, false)
    f:RegisterForDrag("LeftButton")
    f.text = f:CreateFontString(nil, "OVERLAY")
    f.text:SetPoint("CENTER", f, "CENTER", 0, 0)
    f.lockTex = f:CreateTexture(nil, "BACKGROUND")
    f.lockTex:SetAllPoints()
    f.lockTex:SetColorTexture(0.2, 0.6, 1, 0.25)
    f.lockTex:Hide()

    -- pulse: fades in and out the whole time
    f.pulse = f:CreateAnimationGroup()
    f.pulse:SetLooping("BOUNCE")
    f.pulseA = f.pulse:CreateAnimation("Alpha")
    if f.pulseA.SetFromAlpha then f.pulseA:SetFromAlpha(1) end

    -- throb (frame scale, so borders and backgrounds scale with the text) and shake
    f.animT = 0
    f:SetScript("OnUpdate", function(self, dt)
        if not self.baseX or not (self.throbOn or self.shakeOn) then return end
        if self.real and (TA.unlocked or self.dragging) then return end
        self.animT = self.animT + dt
        local sc, dx = 1, 0
        if self.throbOn then
            local per = TA.Eff(self, "throbPeriod") or 0.8
            sc = 1 + ((TA.Eff(self, "throbSize") or 1.2) - 1) * (0.5 - 0.5 * math.cos(self.animT * 6.2832 / per))
        end
        if self.shakeOn then
            dx = math.sin(self.animT * 6.2832 / (TA.Eff(self, "shakePeriod") or 0.3)) * (TA.Eff(self, "shakeDist") or 6)
        end
        self:SetScale(sc)
        self:ClearAllPoints()
        self:SetPoint("CENTER", self.shakeRel or UIParent, "CENTER", (self.baseX + dx) / sc, self.baseY / sc)
    end)
    return f
end

local function EnsurePos(a)
    if a.y == nil then
        NS.DB.alertSlots = (NS.DB.alertSlots or 0) + 1
        a.x = 0
        a.y = 220 - 55 * (NS.DB.alertSlots - 1)
    end
end
NS.EnsurePos = EnsurePos

local function PlaceAlert(f, spell)
    local a = NS.DB.alerts[spell]
    EnsurePos(a)
    f.baseX, f.baseY = a.x, a.y
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", a.x, a.y)
    TA.SyncUI(f)
end
NS.PlaceAlert = PlaceAlert

-- axis "x": centre across the screen (keeps the height); "y": centre in height (keeps the side)
function TA.Centre(axis, spell)
    for sp, a in pairs(NS.DB.alerts) do
        if not spell or sp == spell then
            EnsurePos(a)
            if axis == "x" then a.x = 0 else a.y = 0 end
            local f = alertFrames[sp]
            if f then PlaceAlert(f, sp) end
        end
    end
    if TA.onMove then TA.onMove() end
end

local TPOS_NAMES = { right = "Right of text", left = "Left of text", below = "Below text", above = "Above text" }
NS.TPOS_NAMES = TPOS_NAMES

do
local function GetAlertFrame(spell)
    local f = alertFrames[spell]
    if not f then
        f = TA.Build(nil)
        alertFrames[spell] = f
        f:SetScript("OnDragStart", function(self)
            if not TA.Unlocked(self) then return end
            self.dragging = true
            self:SetScale(1)
            RestorePoint(self)
            TA.SyncUI(self)
            self:StartMoving()
        end)
        f:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            self.dragging = false
            local fx, fy = self:GetCenter()
            local ux, uy = UIParent:GetCenter()
            local a = NS.DB.alerts[spell]
            if a and fx and ux then
                a.x, a.y = math.floor(fx - ux + 0.5), math.floor(fy - uy + 0.5)
                PlaceAlert(self, spell)
                if TA.onMove then TA.onMove() end
            end
        end)
        -- while a whole page is being customised, clicking a popup makes it the one the window edits
        f:SetScript("OnMouseDown", function(self)
            if TA.moveSet and TA.moveSet[spell] and (TA.moveSpell ~= spell or TA.menuTab ~= "text") then
                TA.moveSpell = spell
                TA.menuTab = "text"
                TA.ApplyLock()
            end
        end)
        f.spell = spell
        f.real = true
        f.anchor = CreateFrame("Frame", nil, UIParent)
        f.ui = CreateFrame("Frame", nil, UIParent)
        f.ui:SetAllPoints(f.anchor)
        f.ui:SetFrameStrata("TOOLTIP")
        f.ui:SetFrameLevel(5)
        f.ui:Hide()
        StyleAlertFrame(f)
        PlaceAlert(f, spell)
    end
    return f
end

TA.GetFrame = GetAlertFrame
function TA.RefreshStyle()
    for _, f in pairs(alertFrames) do StyleAlertFrame(f) end
    for _, f in ipairs(TA.previews) do StyleAlertFrame(f) end
end

-- a soft ring round the popup the Customise window is editing (only while a whole page is being customised)
function TA.SetSel(f, on)
    if on then
        if not f.pgSel then
            local s = CreateFrame("Frame", nil, f)
            s:SetPoint("TOPLEFT", f, "TOPLEFT", -6, 6)
            s:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 6, -6)
            s.t = {}
            for _, ring in ipairs({ { 0, 3, 0.3 }, { 3, 2, 0.95 } }) do
                local i, th, al = ring[1], ring[2], ring[3]
                local function Edge(p1, x1, y1, p2, x2, y2, w, h)
                    local e = s:CreateTexture(nil, "OVERLAY")
                    e:SetPoint(p1, s, p1, x1, y1); e:SetPoint(p2, s, p2, x2, y2)
                    if w then e:SetWidth(w) end
                    if h then e:SetHeight(h) end
                    e.al = al
                    s.t[#s.t + 1] = e
                end
                Edge("TOPLEFT", i, -i, "TOPRIGHT", -i, -i, nil, th)
                Edge("BOTTOMLEFT", i, i, "BOTTOMRIGHT", -i, i, nil, th)
                Edge("TOPLEFT", i, -i, "BOTTOMLEFT", i, i, th, nil)
                Edge("TOPRIGHT", -i, -i, "BOTTOMRIGHT", -i, i, th, nil)
            end
            f.pgSel = s
        end
        local r, g, b = 1, 0.82, 0
        local _, pc = UnitClass("player")
        local cc = NS.DB and NS.DB.classUI and RAID_CLASS_COLORS and RAID_CLASS_COLORS[pc]
        if cc then r, g, b = cc.r, cc.g, cc.b end
        for _, e in ipairs(f.pgSel.t) do e:SetColorTexture(r, g, b, e.al) end
        f.pgSel:Show()
    elseif f.pgSel then
        f.pgSel:Hide()
    end
end

function TA.ApplyLock()
    if not TA.moveSpell then TA.moveSet = nil end
    -- the Customise window follows the ability being edited
    if TA.moveSpell and TA.ShowMenu then TA.ShowMenu(TA.moveSpell)
    elseif TA.HideMenu then TA.HideMenu() end
    for _, f in pairs(alertFrames) do
        TA.SetSel(f, TA.moveSet and TA.moveSpell == f.spell and TA.menuTab ~= "icon" and true or false)
        local un = TA.Unlocked(f)
        SetMouse(f, un and true or false)
        f:SetFrameStrata(un and "TOOLTIP" or "HIGH")
        if un then
            f.lockTex:Show()
            if TA.unlocked then
                f.pulse:Stop(); f:SetAlpha(1)
                f:SetScale(1)
                if f.baseX then RestorePoint(f) end
            elseif f:IsShown() then
                TA.Anim(f)   -- single-ability customise: keep animating so changes can be seen
            end
        else
            f.lockTex:Hide()
            if f:IsShown() then TA.Anim(f) end
        end
        TA.SyncUI(f)
    end
    for _, h in ipairs(TA.lockHooks) do h() end
end

function TA.SetUnlocked(v)
    TA.unlocked = v and true or false
    TA.moveSpell = nil
    TA.ApplyLock()
end

-- unlock just one ability's popup for dragging (toggle)
-- open (or close) the Customise window on a tab: "text" or "icon"
function TA.OpenMenu(spell, tab)
    if TA.moveSpell == spell and TA.menuTab == tab then
        TA.moveSpell = nil
    else
        TA.moveSpell = spell
        TA.menuTab = tab
        if tab == "text" then GetAlertFrame(spell) end
    end
    TA.ApplyLock()
end
function TA.Test(spell) alertTest[spell] = GetTime() + 6 end
function TA.TestAll()
    for sp, a in pairs(NS.DB.alerts) do if a.on then TA.Test(sp) end end
end
function TA.ResetPositions()
    NS.DB.alertSlots = 0
    for sp, a in pairs(NS.DB.alerts) do
        a.x, a.y = nil, nil
        local f = alertFrames[sp]
        if f then PlaceAlert(f, sp) end
    end
end

local function ShowAlertFrame(f)
    StyleAlertFrame(f)   -- re-apply font/outline every time it appears (fonts can still be loading at login)
    f:Show()
    if BUFFS.holding then BUFFS.HoldTick() end
    TA.Anim(f)
    TA.SyncUI(f)
end

local function HideAlertFrame(f)
    f.pulse:Stop()
    f:Hide()
    TA.SyncUI(f)
end

function TA.Update(buffs, seen)
    local en = NS.DB.enabled ~= false
    local now = GetTime()
    for spell, a in pairs(NS.DB.alerts) do
      if not (alertFrames[spell] and alertFrames[spell].pgMirror) then
        local want, rem = false, nil
        local testing = alertTest[spell] and alertTest[spell] > now
        if a.on and en and BUFFS.Allowed(spell) then
            local active
            if NS.DB.watch and NS.DB.watch[spell] and (BUFFS.MissingMode(spell) or (not onBarNames[spell] and not BUFFS.CanCD(spell))) then
                -- a tracked buff: text while it is on you, or while it is missing (checked before the action-bar glow test,
                -- which would otherwise decide it whenever the spell sits on your bars)
                local ok, r = pcall(BUFFS.WatchShown, spell, buffs)
                active = ok and r
            elseif onBarNames[spell] then
                active = seen[spell]
            else
                local ok, r = pcall(ProcActive, spell, buffs)
                active = ok and r
            end
            -- in combat the buff's own aura bar already carries a copy of this popup (BUFFS.MirrorTick) that the game shows while
            -- the buff is up; a second one from here would double it up (this one is also driven by the button glow, not the buff)
            if active and BUFFS.tmir and InCombatLockdown() then
                for key, sp in pairs(buffProcs) do
                    if sp == spell and BUFFS.tmir[key] then active = false; break end
                end
            end
            if active then
                want = true
                rem = ProcRemaining(spell, buffs)
            end
        end
        if testing then
            want = true
            rem = (alertTest[spell] - now) * 2
        end
        if (TA.unlocked or TA.TextEditing(spell)) and a.on then want = true end
        local f = alertFrames[spell]
        if want then
            f = f or GetAlertFrame(spell)
            local str = (a.text and a.text ~= "") and a.text or TA.DefaultText(spell)
            if TA.TextEditing(spell) and not (rem and rem > 0) then rem = 12 end
            if TA.TimerOn(a) and rem and rem > 0 then
                str = TA.WithTimer(str, BUFFS.Fmt(rem), TA.Tpos(a))
            end
            if f.lastStr ~= str then f.lastStr = str; FitText(f, str) end
            if not f:IsShown() then ShowAlertFrame(f) end
        elseif f and f:IsShown() then
            HideAlertFrame(f)
        end
      end
    end
    -- a popup whose setting no longer exists (another profile was loaded) must not stay on screen
    for spell, f in pairs(alertFrames) do
        if not NS.DB.alerts[spell] and f:IsShown() then HideAlertFrame(f) end
    end
end
end
