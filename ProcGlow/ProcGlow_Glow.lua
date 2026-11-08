local _, NS = ...
local BUFFS, IsOverlayed, LOC, ProcActive, SHOUTS, ShoutLow = NS.BUFFS, NS.IsOverlayed, NS.LOC, NS.ProcActive, NS.SHOUTS, NS.ShoutLow
local SpellIcon, WindowActive, buffProcs, reactive, shoutSpellID = NS.SpellIcon, NS.WindowActive, NS.buffProcs, NS.reactive, NS.shoutSpellID

---------------------------------------------------------------------------
-- Glow frames (several styles, all driven by DB.style)
---------------------------------------------------------------------------
local TEX_BORDER = "Interface\\Buttons\\UI-ActionButton-Border"
NS.TEX_BORDER = TEX_BORDER
local TEX_HILITE = "Interface\\Buttons\\CheckButtonHilight"
local WHITE = "Interface\\Buttons\\WHITE8X8"
NS.WHITE = WHITE

local MAX_ANTS = 24

-- Blizzard's own proc glow, built ONCE here and used everywhere (action buttons, in-combat copies, floating
-- icons). Two pieces: the soft outer glow and the 22-picture ring of ants (48px pictures on a 256px sheet),
-- animated by the game's own engine so it keeps running in combat when addon code cannot touch the frame.
function BUFFS.BzGlow(f, w, h)
    local z = f.bz
    if not z then
        z = CreateFrame("Frame", nil, f)
        z:SetFrameLevel(f:GetFrameLevel() + 6)
        z.outer = z:CreateTexture(nil, "ARTWORK")
        z.outer:SetTexture("Interface\\SpellActivationOverlay\\IconAlert")
        z.outer:SetTexCoord(0.00781250, 0.50781250, 0.27734375, 0.52734375)
        z.outer:SetBlendMode("ADD")
        z.outer:SetPoint("CENTER", z, "CENTER", 0, 0)
        -- one group, 22 steps in a row: only one picture is ever lit. A finished step keeps its last
        -- value until the group loops, so each picture is switched back off exactly as the next one lights.
        local grp = z:CreateAnimationGroup()
        grp:SetLooping("REPEAT")
        z.frames = {}
        for i = 0, 21 do
            local t = z:CreateTexture(nil, "OVERLAY")
            t:SetTexture("Interface\\SpellActivationOverlay\\IconAlertAnts")
            local col, row = i % 5, math.floor(i / 5)
            t:SetTexCoord(col * 48 / 256, (col + 1) * 48 / 256, row * 48 / 256, (row + 1) * 48 / 256)
            t:SetPoint("CENTER", z, "CENTER", 0, 0)
            t:SetAlpha(0)
            z["pgAnt" .. i] = t
            local function step(order, v)
                local an = grp:CreateAnimation("Alpha")
                an:SetOrder(order)
                an:SetDuration(0.025)
                if an.SetTarget then an:SetTarget(t) else an:SetChildKey("pgAnt" .. i) end
                if an.SetFromAlpha then an:SetFromAlpha(v); an:SetToAlpha(v) else an:SetChange(0) end
            end
            step(i + 1, 1)
            if i < 21 then step(i + 2, 0) end
            z.frames[#z.frames + 1] = t
        end
        z.antGroup = grp
        f.bz = z
    end
    z:ClearAllPoints()
    z:SetPoint("CENTER", f, "CENTER", 0, 0)
    z:SetSize(w, h)
    z.outer:SetSize(w * 1.4, h * 1.4)
    for _, t in ipairs(z.frames) do t:SetSize(w * 1.19, h * 1.19) end
    z:Show()
    if not z.antGroup:IsPlaying() then z.antGroup:Play() end   -- started even while hidden: addon code cannot start it in combat
    return z
end

-- moves the "ants" (dashes) clockwise around the edge of the glow frame
local function AntsUpdate(f, dt)
    local s = NS.DB.style
    local n = math.max(1, math.min(MAX_ANTS, math.floor((s.antCount or 12) + 0.5)))
    f.antT = ((f.antT or 0) + dt / (s.antSpeed or 2.5)) % 1
    local w, h = f:GetSize()
    if not w or w < 1 or not h or h < 1 then return end
    local per = 2 * (w + h)
    local len = math.max(2, w * (s.antLen or 0.18))
    local th = s.antThick or 3
    for i = 1, n do
        local ant = f.ants[i]
        local d = ((f.antT + (i - 1) / n) % 1) * per
        local x, y, aw, ah
        if d < w then                              -- top edge, moving right
            x = math.min(d, w - len); y = th / 2; aw, ah = len, th
        elseif d < w + h then                      -- right edge, moving down
            local v = math.min(d - w, h - len)
            x = w - th / 2; y = -v; aw, ah = th, len
        elseif d < 2 * w + h then                  -- bottom edge, moving left
            local u = d - (w + h)
            x = math.max(w - u - len, 0); y = -h + th / 2; aw, ah = len, th
        else                                       -- left edge, moving up
            local v = d - (2 * w + h)
            x = -th / 2; y = -math.max(h - v - len, 0); aw, ah = th, len
        end
        ant:ClearAllPoints()
        ant:SetSize(aw, ah)
        ant:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
    end
end

local function BuildGlow(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetAllPoints(parent)
    f:SetFrameLevel(parent:GetFrameLevel() + 6)
    NS.NoMouse(f)

    f.borders, f.hilites = {}, {}
    for k = 1, 3 do
        local bt = f:CreateTexture(nil, "OVERLAY")
        bt:SetTexture(TEX_BORDER)
        bt:SetBlendMode("ADD")
        bt:SetPoint("CENTER", f, "CENTER", 0, 0)
        f.borders[k] = bt

        local ht = f:CreateTexture(nil, "OVERLAY")
        ht:SetTexture(TEX_HILITE)
        ht:SetBlendMode("ADD")
        ht:SetAllPoints(f)
        f.hilites[k] = ht
    end

    -- rotating star burst
    f.star = f:CreateTexture(nil, "OVERLAY")
    f.star:SetTexture("Interface\\Cooldown\\star4")
    f.star:SetBlendMode("ADD")
    f.star:SetPoint("CENTER", f, "CENTER", 0, 0)
    f.starAnim = f.star:CreateAnimationGroup()
    f.starAnim:SetLooping("REPEAT")
    local rot = f.starAnim:CreateAnimation("Rotation")
    rot:SetDegrees(-360)
    rot:SetDuration(4)

    -- marching ants
    f.ants = {}
    for i = 1, MAX_ANTS do
        local t = f:CreateTexture(nil, "OVERLAY")
        t:SetTexture(WHITE)
        t:SetBlendMode("ADD")
        t:Hide()
        f.ants[i] = t
    end
    f.antT = 0

    -- attention flash (white burst that fades out)
    f.flash = f:CreateTexture(nil, "OVERLAY")
    f.flash:SetTexture(TEX_BORDER)
    f.flash:SetBlendMode("ADD")
    f.flash:SetPoint("CENTER", f, "CENTER", 0, 0)
    f.flash:SetVertexColor(1, 1, 1, 1)
    f.flash:Hide()
    f.flashAnim = f.flash:CreateAnimationGroup()
    local fa = f.flashAnim:CreateAnimation("Alpha")
    if fa.SetFromAlpha then
        fa:SetFromAlpha(1)
        fa:SetToAlpha(0)
    else
        fa:SetChange(-1)
    end
    fa:SetDuration(0.5)
    f.flashAnimA = fa
    f.flashAnim:SetScript("OnFinished", function() f.flash:Hide() end)

    -- attention pop (starts big, shrinks into place)
    f.pop = f:CreateAnimationGroup()
    local sc = f.pop:CreateAnimation("Scale")
    sc:SetDuration(0.35)
    sc:SetSmoothing("OUT")
    f.popScale = sc

    f.fill = f:CreateTexture(nil, "OVERLAY")
    f.fill:SetColorTexture(1, 1, 1, 0.3)
    f.fill:SetAllPoints(f)

    f.edges = {}
    for i = 1, 4 do
        local e = f:CreateTexture(nil, "OVERLAY")
        e:SetTexture(WHITE)
        f.edges[i] = e
    end

    local ag = f:CreateAnimationGroup()
    ag:SetLooping("BOUNCE")
    local a = ag:CreateAnimation("Alpha")
    if a.SetFromAlpha then
        a:SetFromAlpha(1)
        a:SetToAlpha(0.3)
    else
        a:SetChange(-0.7)
    end
    f.anim = ag
    f.animAlpha = a

    f:Hide()
    return f
end
NS.BuildGlow = BuildGlow

local function ShowGlowFrame(f)
    f:SetAlpha(1)
    f:Show()
    if BUFFS.holding then BUFFS.HoldTick() end
    if NS.DB.style.blizzardOn then
        if f.bz and not f.bz.antGroup:IsPlaying() then f.bz.antGroup:Play() end
        return
    end
    if NS.DB.style.pulse then f.anim:Play() end
    if f.star:IsShown() then f.starAnim:Play() end
    -- attention animation when the glow first appears
    if NS.DB.style.pop then f.pop:Stop(); f.pop:Play() end
    if NS.DB.style.flash then
        f.flash:Show()
        f.flashAnim:Stop()
        f.flashAnim:Play()
    end
end
NS.ShowGlowFrame = ShowGlowFrame

local function HideGlowFrame(f)
    f.anim:Stop()
    f.starAnim:Stop()
    f.pop:Stop()
    f.flashAnim:Stop()
    f.flash:Hide()
    f:SetAlpha(1)
    f:Hide()
end
NS.HideGlowFrame = HideGlowFrame

local function ApplyStyleTo(parent, f, isAlert)
    local s = NS.DB.style
    local r, g, b, a = s.r, s.g, s.b, s.intensity
    local w, h = parent:GetSize()
    if not w or w < 1 then w, h = 36, 36 end
    local layers = math.max(1, math.min(3, math.floor((s.strength or 1) + 0.5)))
    local hiLayers = math.max(1, math.min(3, math.floor((s.hiStrength or 2) + 0.5)))

    for k = 1, 3 do f.borders[k]:Hide(); f.hilites[k]:Hide() end
    f.fill:Hide(); f.star:Hide(); f.starAnim:Stop()
    for i = 1, 4 do f.edges[i]:Hide() end
    for i = 1, MAX_ANTS do f.ants[i]:Hide() end
    local antsOn = false

    -- standalone Blizzard preset: nothing else is drawn
    if s.blizzardOn then
        f.anim:Stop(); f.pop:Stop(); f.flashAnim:Stop(); f.flash:Hide()
        f:SetAlpha(1)
        f:SetScript("OnUpdate", nil)
        BUFFS.BzGlow(f, w, h)
        return
    end
    if f.bz then f.bz.antGroup:Stop(); f.bz:Hide() end

    -- halo
    if s.haloOn then
        for k = 1, layers do
            local bt = f.borders[k]
            bt:SetSize(w * s.scale, h * s.scale)
            bt:SetVertexColor(r, g, b, a)
            bt:Show()
        end
    end

    -- highlight
    if s.highlightOn then
        for k = 1, hiLayers do
            f.hilites[k]:SetVertexColor(r, g, b, a)
            f.hilites[k]:Show()
        end
    end

    -- fill
    if s.fillOn then
        f.fill:SetColorTexture(r, g, b, math.min(1, s.fillAlpha or 0.35))
        f.fill:Show()
    end

    -- outline
    if s.outlineOn then
        local t, o = s.thickness, 0
        local top, bot, left, right = f.edges[1], f.edges[2], f.edges[3], f.edges[4]
        top:ClearAllPoints(); top:SetPoint("TOPLEFT", f, "TOPLEFT", -o, o); top:SetPoint("TOPRIGHT", f, "TOPRIGHT", o, o); top:SetHeight(t)
        bot:ClearAllPoints(); bot:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", -o, -o); bot:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", o, -o); bot:SetHeight(t)
        left:ClearAllPoints(); left:SetPoint("TOPLEFT", f, "TOPLEFT", -o, o); left:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", -o, -o); left:SetWidth(t)
        right:ClearAllPoints(); right:SetPoint("TOPRIGHT", f, "TOPRIGHT", o, o); right:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", o, -o); right:SetWidth(t)
        for i = 1, 4 do
            f.edges[i]:SetVertexColor(r, g, b, a)
            f.edges[i]:Show()
        end
    end

    -- burst
    if s.burstOn then
        f.star:SetSize(w * (s.burstScale or 2), h * (s.burstScale or 2))
        f.star:SetVertexColor(r, g, b, a)
        f.star:Show()
        if f:IsShown() then f.starAnim:Play() end
    end

    -- marching ants (lighter shade of the glow colour so they stand out on the halo)
    if s.antsOn then
        local n = math.max(1, math.min(MAX_ANTS, math.floor((s.antCount or 12) + 0.5)))
        local ar = r + (1 - r) * 0.65
        local ag = g + (1 - g) * 0.65
        local ab = b + (1 - b) * 0.65
        for i = 1, n do
            f.ants[i]:SetVertexColor(ar, ag, ab, a)
            f.ants[i]:Show()
        end
        antsOn = true
    end
    f:SetScript("OnUpdate", antsOn and AntsUpdate or nil)

    -- attention animation settings
    f.flash:SetSize(w * 1.7, h * 1.7)
    f.flashAnimA:SetDuration(math.max(0.2, (s.popTime or 0.35) * 1.6))
    local ps = s.popSize or 1.8
    f.popScale:SetDuration(s.popTime or 0.35)
    if f.popScale.SetScaleFrom then
        f.popScale:SetScaleFrom(ps, ps)
        f.popScale:SetScaleTo(1, 1)
    else
        f.popScale:SetScale(1 / ps, 1 / ps)
    end

    f.animAlpha:SetDuration(s.speed)
    if f.animAlpha.SetToAlpha then f.animAlpha:SetToAlpha(s.minAlpha or 0.3) end
    if f:IsShown() then
        f.anim:Stop()
        f:SetAlpha(1)
        if s.pulse then f.anim:Play() end
    end
end
NS.ApplyStyleTo = ApplyStyleTo

local TIMER_FONT = "Fonts\\FRIZQT__.TTF"

BUFFS.stack, BUFFS.scratch, BUFFS.seen = {}, {}, {}   -- aura stack counts (name -> count)
-- stacking procs that only become worth using at full stacks: they glow faintly (with the
-- stack count) until the buff reaches this many stacks, then glow normally
BUFFS.ramp = { ["heating up"] = 3, ["thousand cuts"] = 5, ["maelstrom weapon"] = 5, ["eclipse"] = 4 }
BUFFS.castKeep = {}
BUFFS.castStack = { ["arcane blast"] = { max = 4, dur = 18 } }   -- stacking effects counted from your own casts while combat hides the auras
BUFFS.stacky = { ["arcane blast"] = true, ["fingers of frost"] = true, ["maelstrom weapon"] = true, ["heating up"] = true, ["thousand cuts"] = true, ["eclipse"] = true }
BUFFS.pos = {
    topleft = { "TOPLEFT", 4, -4 }, topright = { "TOPRIGHT", -4, -4 }, center = { "CENTER", 0, 0 },
    bottomleft = { "BOTTOMLEFT", 4, 4 }, bottomright = { "BOTTOMRIGHT", -4, 4 },
}
local function ApplyTimerStyle(tf)
    local k = tf.kind or "timer"
    local st = NS.DB.style
    tf.lastS, tf.lastN = nil, nil
    tf.text:SetFont(TIMER_FONT, st[k .. "Size"] or 16, "OUTLINE")
    local pt = BUFFS.pos[st[k .. "Pos"] or "center"] or BUFFS.pos.center
    tf.text:ClearAllPoints()
    tf.text:SetPoint(pt[1], tf, pt[1], pt[2] + (st[k .. "X"] or 0), pt[3] + (st[k .. "Y"] or 0))
end
NS.ApplyTimerStyle = ApplyTimerStyle

local function ApplyStyle(btn)
    if btn.__pgGlow then ApplyStyleTo(btn, btn.__pgGlow) end
    if btn.__pgAlert then ApplyStyleTo(btn.__pgAlert, btn.__pgAlert.glow, true) end
    if btn.__pgTimer then ApplyTimerStyle(btn.__pgTimer) end
    if btn.__pgStack then ApplyTimerStyle(btn.__pgStack) end
    if btn.__pgAlert and btn.__pgAlert.timer then ApplyTimerStyle(btn.__pgAlert.timer) end
    if btn.__pgAlert and btn.__pgAlert.stack then ApplyTimerStyle(btn.__pgAlert.stack) end
end

-- countdown number (its own frame, so the glow's pulse does not fade it)
local function SetTimer(owner, key, rem)
    local tf = owner[key]
    if rem and NS.DB.style.timerOn then
        if not tf then
            tf = CreateFrame("Frame", nil, owner)
            tf:SetAllPoints(owner)
            tf:SetFrameLevel(owner:GetFrameLevel() + 16)
            NS.NoMouse(tf)
            tf.kind = "timer"
            tf.text = tf:CreateFontString(nil, "OVERLAY")
            tf.text:SetPoint("CENTER", tf, "CENTER", 0, 0)
            ApplyTimerStyle(tf)
            owner[key] = tf
        end
        local str = BUFFS.Fmt(rem)
        if tf.lastS ~= str then       -- the number only changes once a second: no need to rewrite it every tick
            tf.lastS = str
            tf.text:SetText(str)
            if rem <= 5 then tf.text:SetTextColor(1, 0.3, 0.2) else tf.text:SetTextColor(1, 1, 1) end
        end
        if not tf:IsShown() then tf:Show() end
    elseif tf and tf:IsShown() then
        tf:Hide()
    end
end
NS.SetTimer = SetTimer

-- stack count number (e.g. Fingers of Frost x2): same idea as the countdown, its own frame
local function SetStack(owner, key, n)
    local tf = owner[key]
    if n and n > 0 and NS.DB.style.stackOn then
        if not tf then
            tf = CreateFrame("Frame", nil, owner)
            tf:SetAllPoints(owner)
            tf:SetFrameLevel(owner:GetFrameLevel() + 17)
            NS.NoMouse(tf)
            tf.kind = "stack"
            tf.text = tf:CreateFontString(nil, "OVERLAY")
            ApplyTimerStyle(tf)
            owner[key] = tf
        end
        if tf.lastN ~= n then
            tf.lastN = n
            tf.text:SetText(n)
            tf.text:SetTextColor(1, 0.95, 0.35)
        end
        if not tf:IsShown() then tf:Show() end
    elseif tf and tf:IsShown() then
        tf:Hide()
    end
end
NS.SetStack = SetStack

-- Glow on the button that holds the ability (custom layers + optional Blizzard glow)
local function SetGlow(btn, on, rem, stk, faint)
    local s = NS.DB.style

    if on then
        if not btn.__pgGlow then
            btn.__pgGlow = BuildGlow(btn)
            ApplyStyleTo(btn, btn.__pgGlow)
        end
        local g = btn.__pgGlow
        if not g:IsShown() then
            ShowGlowFrame(g)
            if faint then g.pop:Stop(); g.flashAnim:Stop(); g.flash:Hide() end
        elseif btn.__pgFaint and not faint and not s.blizzardOn then
            -- reached full stacks: the attention animation plays now
            if s.pulse then g.anim:Play() end
            if s.pop then g.pop:Stop(); g.pop:Play() end
            if s.flash then g.flash:Show(); g.flashAnim:Stop(); g.flashAnim:Play() end
        end
        if faint then g.anim:Stop() end
        g:SetAlpha(faint and 0.3 or 1)
        btn.__pgFaint = faint and true or false
    elseif btn.__pgGlow and btn.__pgGlow:IsShown() then
        HideGlowFrame(btn.__pgGlow)
        btn.__pgFaint = false
    end
    SetTimer(btn, "__pgTimer", on and rem or nil)
    SetStack(btn, "__pgStack", on and stk or nil)
end
NS.SetGlow = SetGlow

-- "Redirect" alert: shows another ability's icon + glow on this button
local function BuildAlert(btn)
    local h = CreateFrame("Frame", nil, btn)
    h:SetAllPoints(btn)
    h:SetFrameLevel(btn:GetFrameLevel() + 8)
    NS.NoMouse(h)
    h.icon = h:CreateTexture(nil, "ARTWORK")
    h.icon:SetAllPoints(h)
    h.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    h.cd = CreateFrame("Cooldown", nil, h, "CooldownFrameTemplate")
    h.cd:SetAllPoints(h)
    h.cd:Hide()
    h.glow = BuildGlow(h)
    h:Hide()
    return h
end

local function SetAlert(btn, spell, rem, cdStart, cdDur, stk)
    if spell then
        local h = btn.__pgAlert
        if not h then
            h = BuildAlert(btn)
            btn.__pgAlert = h
            ApplyStyleTo(h, h.glow, true)
        end
        if btn.__pgAlertSpell ~= spell then
            local tex = SpellIcon(spell)
            if tex then h.icon:SetTexture(tex) end
            btn.__pgAlertSpell = spell
        end
        if not h:IsShown() then h:Show() end
        if cdStart then
            -- ability is on cooldown: stay greyed out, no glow, until it is ready
            h.icon:SetDesaturated(true)
            if h.glow:IsShown() then HideGlowFrame(h.glow) end
            local key = cdStart .. ":" .. cdDur
            if h.cdKey ~= key then
                h.cd:SetCooldown(cdStart, cdDur)
                h.cdKey = key
            end
            h.cd:Show()
        else
            h.icon:SetDesaturated(false)
            h.cd:Hide()
            h.cdKey = nil
            if not h.glow:IsShown() then ShowGlowFrame(h.glow) end
        end
        SetTimer(h, "timer", rem)
        SetStack(h, "stack", stk)
    elseif btn.__pgAlert and btn.__pgAlert:IsShown() then
        SetStack(btn.__pgAlert, "stack", nil)
        HideGlowFrame(btn.__pgAlert.glow)
        btn.__pgAlert.cd:Hide()
        btn.__pgAlert.cdKey = nil
        btn.__pgAlert.icon:SetDesaturated(false)
        btn.__pgAlert:Hide()
        btn.__pgAlertSpell = nil
    end
end
NS.SetAlert = SetAlert

-- cooldown of a spell by name: start, duration when it is really on cooldown (not just the GCD)
local function SpellCD(name)
    name = LOC.Local(name) or name
    local ok, st, du = pcall(function()
        local a, b
        if C_Spell and C_Spell.GetSpellCooldown then
            local t = C_Spell.GetSpellCooldown(name)
            if t then a, b = t.startTime, t.duration end
        elseif GetSpellCooldown then
            a, b = GetSpellCooldown(name)
        end
        if issecretvalue and (issecretvalue(a) or issecretvalue(b)) then return nil, nil end
        if type(a) == "number" and type(b) == "number" and b > 1.5 and a > 0 then return a, b end
        return nil, nil
    end)
    if ok then return st, du end
end
NS.SpellCD = SpellCD

-- like SpellCD, but says what the answer means: start, duration = on cooldown; false = readable and ready;
-- nil = cannot be read right now (the game hides cooldowns from addons in some fights)
function NS.SpellCDState(name)
    name = LOC.Local(name) or name
    local ok, st, du, known = pcall(function()
        local a, b
        if C_Spell and C_Spell.GetSpellCooldown then
            local t = C_Spell.GetSpellCooldown(name)
            if t then a, b = t.startTime, t.duration end
        elseif GetSpellCooldown then
            a, b = GetSpellCooldown(name)
        end
        if issecretvalue and (issecretvalue(a) or issecretvalue(b)) then return nil, nil, false end
        if type(a) ~= "number" or type(b) ~= "number" then return nil, nil, false end
        if b > 1.5 and a > 0 then return a, b, true end
        return nil, nil, true
    end)
    if not ok then return nil end
    if st then return st, du end
    return known and false or nil
end

---------------------------------------------------------------------------
-- Button discovery
---------------------------------------------------------------------------
local buttons = {}
NS.buttons = buttons

local function AddIfExists(name)
    local b = _G[name]
    if b and b.IsObjectType and b:IsObjectType("Button") then
        buttons[#buttons + 1] = b
    end
end

local function BuildButtons()
    wipe(buttons)
    local blizz = {
        "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
        "MultiBarRightButton", "MultiBarLeftButton",
        "MultiBar5Button", "MultiBar6Button", "MultiBar7Button",
        "MultiBar8Button",
    }
    for _, prefix in ipairs(blizz) do
        for i = 1, 12 do AddIfExists(prefix .. i) end
    end
    for i = 1, 120 do
        AddIfExists("BT4Button" .. i)
        AddIfExists("DominosActionButton" .. i)
    end
    for bar = 1, 15 do
        for i = 1, 12 do AddIfExists("ElvUI_Bar" .. bar .. "Button" .. i) end
    end
    -- EllesmereUI makes its own buttons (EABButton1-180) and hides Blizzard's
    for i = 1, 180 do AddIfExists("EABButton" .. i) end
    NS.eabBuilt = _G["EABButton1"] ~= nil
    -- the gamepad UI's own action bars (found with /pgdev gamepad2): they only count while that UI is showing
    NS.gpBuilt = false
    local GP = "GamepadMainActionBarFramePageUnit"
    for _, bar in ipairs({ "BottomCenteredAnchorBottomBar", "LeftCenteredAnchorLeftBar", "TopCenteredAnchorTopBar",
                           "TopCenteredAnchorPossessBar", "FriendlyTargetingActionBar", "HostileTargetingActionBar",
                           "ShortcutsActionBar" }) do
        for i = 1, 12 do
            local before = #buttons
            AddIfExists(GP .. bar .. "ActionButton" .. i)
            if #buttons > before then NS.gpBuilt = true end
        end
    end
    AddIfExists(GP .. "RightClassAction")
    -- any other gamepad button (for example the right-hand bar): found by what it is, not by a fixed name
    if EnumerateFrames and _G.GamepadActionBarButtonMixin then
        local ref = _G.GamepadActionBarButtonMixin.UpdateButtonArt
        if ref then
            local have = {}
            for _, b in ipairs(buttons) do have[b] = true end
            local f = EnumerateFrames()
            local guard = 0
            while f and guard < 60000 do
                guard = guard + 1
                if not have[f] then
                    local okf, fn = pcall(function() return f.UpdateButtonArt end)
                    if okf and fn == ref then
                        local nm = f.GetName and f:GetName()
                        if type(nm) == "string" and nm:find("^GamepadMainActionBarFrame") and f.IsObjectType and f:IsObjectType("Button") then
                            buttons[#buttons + 1] = f
                            have[f] = true
                            NS.gpBuilt = true
                        end
                    end
                end
                f = EnumerateFrames(f)
            end
        end
    end
    if _G[GP .. "BottomCenteredAnchorBottomBarActionButton1"] then NS.gpBuilt = true end   -- looked once: no repeat scans
    -- the gamepad "stance bar" holds ordinary actions in slots 265-272 (not stance forms), so it is read like any other bar
    for i = 1, 12 do
        local before = #buttons
        AddIfExists(GP .. "TopCenteredAnchorStanceBarActionButton" .. i)
        if #buttons > before then NS.gpBuilt = true end
    end
    -- stance / aura / form bars (paladin auras live here)
    for i = 1, 10 do
        for _, prefix in ipairs({ "StanceButton", "BT4StanceButton", "DominosStanceButton", "ElvUI_StanceBarButton" }) do
            local b = _G[prefix .. i]
            if b and b.IsObjectType and b:IsObjectType("Button") then
                b.__pgStance = i
                buttons[#buttons + 1] = b
            end
        end
    end
end
NS.BuildButtons = BuildButtons

local function SlotOf(btn)
    local s = btn._state_action or btn.action
    if type(s) ~= "number" and btn.GetAttribute then
        s = btn:GetAttribute("action")
    end
    if type(s) == "number" and s > 0 then return s end
end
NS.SlotOf = SlotOf

local previewGlows = {}
NS.previewGlows = previewGlows   -- { parent =, glow = } used by the Glow Style page

local function ApplyAll()
    for i = 1, #buttons do ApplyStyle(buttons[i]) end
    for _, pv in ipairs(previewGlows) do ApplyStyleTo(pv.parent, pv.glow) end
    if BUFFS.MirrorStyle then pcall(BUFFS.MirrorStyle) end
end
NS.ApplyAll = ApplyAll

---------------------------------------------------------------------------
-- Glow decision
---------------------------------------------------------------------------
local function CooldownReady(slot)
    local start, duration = GetActionCooldown(slot)
    if type(start) == "table" then start, duration = start.startTime, start.duration end
    if not start or not duration then return true end
    if issecretvalue and (issecretvalue(start) or issecretvalue(duration)) then return true end
    return duration == 0 or start == 0 or duration <= 1.5
end

local function OffCooldown(slot)
    local ok, res = pcall(CooldownReady, slot)
    if not ok then return true end
    return res and true or false
end
NS.OffCooldown = OffCooldown

local function ShouldGlow(slot, name, id, buffs)
    if not name then return false end
    if NS.DB.disabled[name] then return false end
    if not BUFFS.Allowed(BUFFS.auraOf[name] or name) then return false end   -- another class's spell

    -- a "Greater Blessing of X" / "Prayer of X" button counts as the tracked buff it stands for
    local tk = BUFFS.auraOf[name]
    if tk and tk ~= name then name = tk end

    if SHOUTS[name] and id then shoutSpellID[name] = id end

    -- used since its last dodge / parry: stay dark until a new one (or until the game says it is not usable)
    if BUFFS.windowed[name] and BUFFS.used[name] then
        local okU, u = pcall(IsUsableAction, slot)
        if okU and not (issecretvalue and issecretvalue(u)) and not u then
            BUFFS.used[name] = nil
        else
            return false
        end
    end

    -- target-type spells (Exorcism): glow only on a matching target, never just because usable
    local ttp = BUFFS.targetType[name]
    if ttp then
        local okt, yes = pcall(BUFFS.TargetIsType, ttp)
        if not (okt and yes) then return false end
        local okU, u = pcall(IsUsableAction, slot)
        if okU and not (issecretvalue and issecretvalue(u)) and not u then return false end
        -- strict: an unreadable cooldown (e.g. right after retargeting) counts as NOT ready
        local okC, cs, cd = pcall(GetActionCooldown, slot)
        if not okC then return false end
        if type(cs) == "table" then cs, cd = cs.startTime, cs.duration end
        if type(cs) ~= "number" or type(cd) ~= "number" then return false end
        if issecretvalue and (issecretvalue(cs) or issecretvalue(cd)) then return false end
        return (cd == 0 or cs == 0 or cd <= 1.5) and true or false
    end

    -- Game-native proc overlay (if this client has one)
    if IsOverlayed(id) then return true end

    -- shouts are a reminder: optionally glow even when you lack the rage
    if SHOUTS[name] and NS.DB.shout.ignoreRage then
        return OffCooldown(slot) and ShoutLow(name)
    end

    local usable, noPower = IsUsableAction(slot)
    -- proc is live but you are short of rage / energy: still glow so you see it
    if not usable and noPower and not (issecretvalue and issecretvalue(noPower))
        and reactive[name] and WindowActive(name) and OffCooldown(slot) then
        return true
    end
    if issecretvalue and issecretvalue(usable) then
        -- usability can't be read right now: fall back to the proc tracker
        if SHOUTS[name] then return OffCooldown(slot) and ShoutLow(name) end
        return (reactive[name] and ProcActive(name, buffs) and OffCooldown(slot)) and true or false
    end
    if not usable then return false end

    if SHOUTS[name] then return OffCooldown(slot) and ShoutLow(name) end

    -- Reactive abilities: only usable while their condition is met
    if reactive[name] and OffCooldown(slot) then return true end

    -- Buff based procs
    local faint = false
    for buff, spell in pairs(buffProcs) do
        if spell == name and buffs[buff] and OffCooldown(slot) then
            local mx = BUFFS.ramp[buff]
            if mx and (BUFFS.stack[buff] or 1) < mx then faint = true else return true end
        end
    end
    return faint and "faint" or false
end
NS.ShouldGlow = ShouldGlow

local activeRedirects = {}
NS.activeRedirects = activeRedirects
local activeRemain = {}
NS.activeRemain = activeRemain
local seenProcs = {}
NS.seenProcs = seenProcs

-- which active redirected proc (if any) should be shown on this slot?
local function MatchRedirect(slot, name)
    for spell, target in pairs(activeRedirects) do
        if name ~= spell then
            local n = tonumber(target)
            if n then
                if slot == n then return spell end
            elseif name and name == target then
                return spell
            end
        end
    end
end
NS.MatchRedirect = MatchRedirect
