local _, NS = ...
local BUFFS, BuildClassPage, BuildClassesPage, BuildCountersPage, BuildSettingsPage, BuildStylePage = NS.BUFFS, NS.BuildClassPage, NS.BuildClassesPage, NS.BuildCountersPage, NS.BuildSettingsPage, NS.BuildStylePage
local BuildTextPage, CLASS_SPELLS, EnsurePos, FitText, HideGlowFrame, IC = NS.BuildTextPage, NS.CLASS_SPELLS, NS.EnsurePos, NS.FitText, NS.HideGlowFrame, NS.IC
local MakeNavRow, MakePanel, StyleAlertFrame, TA, TEX_BORDER, UI = NS.MakeNavRow, NS.MakePanel, NS.StyleAlertFrame, NS.TA, NS.TEX_BORDER, NS.UI
local WHITE, alertFrames, buffProcs, cur, navRows, pageRefresh = NS.WHITE, NS.alertFrames, NS.buffProcs, NS.cur, NS.navRows, NS.pageRefresh
local pages = NS.pages

---------------------------------------------------------------------------
-- Proc buffs in combat. The game hides your buffs from addons while you fight, but its AuraContainer will
-- show a frame for a buff you have. We attach the glow / text popup / icon to that frame, so they appear
-- and disappear with the buff even though the addon itself cannot see it.
---------------------------------------------------------------------------
do
    BUFFS.slots = {}        -- proc buff -> its aura button
    BUFFS.slots2 = {}       -- proc buff -> a second aura button, whose countdown belongs to the floating icon
    BUFFS.mir = {}          -- action button -> { buff -> glow mirror frame }
    BUFFS.auraLast = 0

    function BUFFS.AuraInit()
        if BUFFS.container ~= nil then return end
        BUFFS.container = false
        if not (C_Secrets and C_Secrets.GetSpellAuraSecrecy) then return end
        local LA = C_AddOns and C_AddOns.LoadAddOn or LoadAddOn
        if LA then
            local ok, loaded, reason = pcall(LA, "Blizzard_AuraContainer")
            if ok and not loaded and reason ~= "ALREADY_LOADED" then BUFFS.auraWhy = "load: " .. tostring(reason); return end
        end
        local ok, c = pcall(CreateFrame, "AuraContainer", "ProcGlowAuraContainer", UIParent, "CustomAuraContainerTemplate")
        if not ok or not c then BUFFS.auraWhy = "no AuraContainer frame type"; return end
        pcall(function()
            c:SetAllPoints(UIParent)
            c:SetUnit("player")
            c:SetEnabled(true)
        end)
        BUFFS.container = c
    end

    -- a slot for every proc buff that has spell IDs (out of combat only)
    function BUFFS.AddSlot(c, name, set)
        return pcall(c.AddAuraSlot, c, name, "HELPFUL", {
            templateNames = { "ProcGlowAuraButtonTemplate" },
            initializeFrame = function(b)
                NS.NoMouse(b)
                b:SetSize(16, 16)
                b:ClearAllPoints()
                b:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
                local pi = b.pulsableItem
                local bar = pi and pi.applicationBar
                if bar then
                    if b.SetApplicationBar then pcall(b.SetApplicationBar, b, bar, { minApplications = 0, maxApplications = 20 }) end
                    if b.SetDurationCooldown and bar.cooldown then pcall(b.SetDurationCooldown, b, bar.cooldown) end
                end
                if b.GetIcon then
                    local okI, ic = pcall(b.GetIcon, b)
                    if okI and ic and ic.Hide then ic:Hide() end
                end
            end,
            candidateFilters = { includeSpellIDs = set },
        })
    end

    function BUFFS.AuraSync()
        if InCombatLockdown() then return end
        BUFFS.AuraInit()
        local c = BUFFS.container
        if not c then return end
        for key in pairs(buffProcs) do
            if BUFFS.slots[key] == nil then
                local ids = (ProcGlowIDs and ProcGlowIDs[key]) or nil
                if ids and not BUFFS.harmful[key] then       -- (effects the game lists as harmful are counted from your casts instead)
                    local set = {}
                    for _, id in ipairs(ids) do set[id] = true end
                    local ok, btn = BUFFS.AddSlot(c, "ProcGlow_" .. key, set)
                    if ok and btn then BUFFS.slots[key] = btn
                    else BUFFS.slots[key] = false; BUFFS.auraWhy = "AddAuraSlot: " .. tostring(btn) end
                    if BUFFS.slots[key] then
                        local ok2, btn2 = BUFFS.AddSlot(c, "ProcGlowI_" .. key, set)
                        BUFFS.slots2[key] = (ok2 and btn2) or false
                    end
                end
            end
        end
    end

    -- the frame that really follows the buff: the bar inside the aura button (else the button itself)
    function BUFFS.Host(slot)
        local pi = slot and slot.pulsableItem
        return (pi and pi.applicationBar) or slot
    end

    -- spell -> the proc buff whose slot carries it

    -- Everything that follows is set up OUT of combat: once you fight, the game treats these frames as
    -- off limits to addons, but it still shows them by itself while the buff is on you. A state driver
    -- keeps each one hidden outside combat, so they never double up with the normal display.
    BUFFS.gated = {}   -- glow mirrors: kept on briefly when combat ends so the real glow can take over without a blink
    function BUFFS.Gate(f, keep)
        if keep then BUFFS.gated[#BUFFS.gated + 1] = f end
        if RegisterStateDriver then
            local ok = pcall(RegisterStateDriver, f, "visibility", "[combat] show; hide")
            if ok then return true end
        end
        return false
    end

    -- In-combat copies: the same engine-animated Blizzard glow as the buttons; custom styles are reduced to
    -- fixed pieces plus an engine-side pulse (addon code cannot run on these frames during combat).
    function BUFFS.PinGlow(m, w, h)
        if not (NS.DB.style and NS.DB.style.blizzardOn) then
            if m.glow then HideGlowFrame(m.glow) end
            return BUFFS.StaticStyle(m, w, h)
        end
        if m.sg then
            m.sg.halo:Hide()
            for _, e in ipairs(m.sg.edges) do e:Hide() end
        end
        if m.glow then HideGlowFrame(m.glow) end
        -- the soft outer edge reaches past the button; make sure nothing above the copy trims it
        pcall(function()
            local par, n = m:GetParent(), 0
            while par and par ~= UIParent and n < 8 do
                if par.SetClipsChildren then par:SetClipsChildren(false) end
                par = par:GetParent(); n = n + 1
            end
        end)
        BUFFS.BzGlow(m, w, h)
    end
    function BUFFS.StaticGlow(f)
        if f.sg then return f.sg end
        local sg = { edges = {} }
        sg.halo = f:CreateTexture(nil, "OVERLAY")
        sg.halo:SetTexture(TEX_BORDER)
        sg.halo:SetBlendMode("ADD")
        sg.halo:SetPoint("CENTER", f, "CENTER", 0, 0)
        for i = 1, 4 do
            local t = f:CreateTexture(nil, "OVERLAY")
            t:SetTexture(WHITE)
            t:SetBlendMode("ADD")
            sg.edges[i] = t
        end
        sg.anim = sg.halo:CreateAnimationGroup()
        sg.anim:SetLooping("BOUNCE")
        local a = sg.anim:CreateAnimation("Alpha")
        if a.SetFromAlpha then a:SetFromAlpha(1); a:SetToAlpha(0.35) else a:SetChange(-0.65) end
        a:SetDuration(0.5)
        f.sg = sg
        return sg
    end
    function BUFFS.StaticStyle(f, w, h)
        local sg = BUFFS.StaticGlow(f)
        local st = NS.DB.style or {}
        local r, g, b = st.r or 1, st.g or 0.82, st.b or 0
        local a = math.min(1, st.intensity or 1)
        local sc = math.max(1.3, math.min(2.2, st.scale or 1.6))
        sg.halo:SetSize(w * sc, h * sc)
        sg.halo:SetVertexColor(r, g, b, a)
        local t = 2
        local e = sg.edges
        for i = 1, 4 do e[i]:SetVertexColor(r, g, b, a); e[i]:ClearAllPoints() end
        e[1]:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0); e[1]:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0); e[1]:SetHeight(t)
        e[2]:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0); e[2]:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0); e[2]:SetHeight(t)
        e[3]:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0); e[3]:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0); e[3]:SetWidth(t)
        e[4]:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0); e[4]:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0); e[4]:SetWidth(t)
        if not sg.anim:IsPlaying() then sg.anim:Play() end
    end

    -- the aura bar may live at a different scale than the rest of the UI: make a copy come out the same size on screen
    function BUFFS.Fit(f, like)
        local host = f:GetParent()
        local hs = host and host:GetEffectiveScale() or 1
        local ls = like:GetEffectiveScale()
        if not hs or hs <= 0 then hs = 1 end
        if not ls or ls <= 0 then ls = 1 end
        f:SetScale(ls / hs)
    end

    -- The game keeps this buff's own countdown (the cooldown inside its aura bar) up to date even in combat.
    -- Show its numbers over the action button, only while in combat (out of combat the normal timer is used).
    function BUFFS.PlaceTimer(m, on)
        local slot = BUFFS.slots[m.key]
        local host = slot and BUFFS.Host(slot)
        local cd = host and host.cooldown
        if not (cd and m.btn) then return end
        if not cd.pgSet then
            cd.pgSet = true
            pcall(function()
                cd:SetHideCountdownNumbers(false)
                cd:SetDrawSwipe(false); cd:SetDrawEdge(false); cd:SetDrawBling(false)
            end)
            BUFFS.Gate(cd)
        end
        cd:ClearAllPoints()
        cd:SetPoint("CENTER", m.btn, "CENTER", 0, 0)
        cd:SetSize(m.btn:GetWidth(), m.btn:GetHeight())
        cd:SetFrameStrata(m.btn:GetFrameStrata())
        cd:SetFrameLevel(m.btn:GetFrameLevel() + 12)
        BUFFS.Fit(cd, m.btn)
        cd:SetAlpha((on and NS.DB.style.timerOn) and 1 or 0)
    end

    -- a glow over an action button, parented to the buff's aura bar
    function BUFFS.GlowMirror(b, name)
        if InCombatLockdown() then return end
        local per = BUFFS.mir[b]
        if per then for _, m in pairs(per) do m.ok = false end end
        for key, sp in pairs(buffProcs) do
            local slot = BUFFS.slots[key]
            if sp == name and slot then
                per = per or {}
                BUFFS.mir[b] = per
                local m = per[key]
                if not m then
                    m = CreateFrame("Frame", nil, BUFFS.Host(slot))
                    BUFFS.Fit(m, b)
                    m:SetSize(b:GetWidth(), b:GetHeight())
                    m:ClearAllPoints()
                    m:SetPoint("CENTER", b, "CENTER", 0, 0)
                    m:SetFrameStrata(b:GetFrameStrata())
                    m:SetFrameLevel(b:GetFrameLevel() + 8)
                    NS.NoMouse(m)
                    BUFFS.PinGlow(m, b:GetWidth(), b:GetHeight())
                    BUFFS.Gate(m, true)
                    per[key] = m
                end
                m.key = key
                m.ok = true
                m.spell = name
                m.btn = b
            end
        end
    end

    BUFFS.tmir, BUFFS.imir = {}, {}     -- text popup / icon mirrors, by spell

    local syncN = 0
    function BUFFS.MirrorTick()
        if InCombatLockdown() then return end          -- nothing here may be touched during combat
        syncN = syncN + 1
        local restyle = (syncN % 4 == 1)
        local en = NS.DB.enabled ~= false
        for _, per in pairs(BUFFS.mir) do
            for _, m in pairs(per) do
                local on = m.ok and en and not NS.DB.disabled[m.spell] and BUFFS.Allowed(m.spell)
                if not m.hold then m:SetAlpha(on and 1 or 0) end
                if m.btn and m.key then pcall(BUFFS.PlaceTimer, m, on) end
                if m.btn then
                    local w, h = m.btn:GetWidth(), m.btn:GetHeight()
                    BUFFS.Fit(m, m.btn)
                    if w and h and (m.pw ~= w or m.ph ~= h or restyle) then
                        m.pw, m.ph = w, h
                        m:SetSize(w, h)
                        BUFFS.PinGlow(m, w, h)
                    end
                end
            end
        end
        -- one text popup / icon mirror for EACH proc buff of a spell (hung on that buff's own aura bar), so
        -- either buff alone brings them up; if both are on, the two copies sit exactly on top of each other
        for key, sp in pairs(buffProcs) do
            do
                local slot = BUFFS.slots[key]
                -- a ramping buff (Heating Up...) never gets its own popup / icon when the full buff for the same spell has one
                if slot and BUFFS.ramp[key] then
                    for k2, sp2 in pairs(buffProcs) do
                        if k2 ~= key and sp2 == sp and BUFFS.slots[k2] then slot = nil; break end
                    end
                end
                if slot then
                    local host = BUFFS.Host(slot)
                    local ok = en and BUFFS.Allowed(sp) and not NS.DB.disabled[sp]
                    -- text popup
                    local a = NS.DB.alerts and NS.DB.alerts[sp]
                    local tm = BUFFS.tmir[key]
                    if a and a.on and ok then
                        if not tm then
                            tm = TA.Build(host)
                            tm:SetFrameStrata("HIGH")
                            tm:SetScript("OnUpdate", nil)
                            tm:SetMovable(false)
                            tm.spell, tm.real, tm.mirror = sp, true, true
                            tm.sp, tm.key, tm.isText = sp, key, true
                            BUFFS.Gate(tm, true)
                            BUFFS.tmir[key] = tm
                            restyle = true
                        end
                        local str = (a.text and a.text ~= "") and a.text or TA.DefaultText(sp)
                        EnsurePos(a)
                        if restyle or tm.lastStr ~= str then
                            StyleAlertFrame(tm)
                            tm.lastStr = str
                            FitText(tm, str)
                            tm:ClearAllPoints()
                            tm:SetPoint("CENTER", UIParent, "CENTER", a.x or 0, a.y or 0)
                            TA.Anim(tm)
                        end
                        BUFFS.Fit(tm, UIParent)
                        if not tm.hold then tm:SetAlpha(1) end
                    elseif tm then
                        if not tm.hold then tm:SetAlpha(0) end
                    end
                    -- icon
                    local c = NS.DB.icons and NS.DB.icons[sp]
                    local im = BUFFS.imir[key]
                    if c and c.on and ok then
                        if not im then
                            local ihost = BUFFS.slots2[key]
                            ihost = ihost and BUFFS.Host(ihost) or host
                            im = CreateFrame("Frame", nil, ihost)
                            im.ihost = ihost
                            im:SetFrameStrata("HIGH")
                            NS.NoMouse(im)
                            im.bg = im:CreateTexture(nil, "BACKGROUND")
                            im.bg:SetPoint("TOPLEFT", -2, 2); im.bg:SetPoint("BOTTOMRIGHT", 2, -2)
                            im.bg:SetColorTexture(0, 0, 0, 1)
                            im.icon = im:CreateTexture(nil, "ARTWORK")
                            im.icon:SetAllPoints()
                            im.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
                            im.sp, im.key = sp, key
                            BUFFS.Gate(im, true)
                            BUFFS.imir[key] = im
                            restyle = true
                        end
                        if restyle then
                            local sw, sh = IC.Dims(c)
                            im:SetSize(sw, sh)
                            im:ClearAllPoints()
                            im:SetPoint("CENTER", UIParent, "CENTER", c.x or 0, c.y or 0)
                            im.icon:SetTexture(IC.Tex(sp))
                            if c.glow then
                                BUFFS.PinGlow(im, sw, sh)
                            elseif im.bz then
                                im.bz:Hide()
                            end
                        end
                        BUFFS.Fit(im, UIParent)
                        if not im.hold then im:SetAlpha(1) end
                        -- the game's own countdown for this buff, shown over the floating icon in combat
                        local icd = im.ihost and im.ihost.cooldown
                        if icd and im.ihost ~= host then
                            if not icd.pgSet then
                                icd.pgSet = true
                                pcall(function()
                                    icd:SetHideCountdownNumbers(false)
                                    icd:SetDrawSwipe(false); icd:SetDrawEdge(false); icd:SetDrawBling(false)
                                end)
                                BUFFS.Gate(icd)
                            end
                            local sw, sh = IC.Dims(c)
                            icd:ClearAllPoints()
                            icd:SetPoint("CENTER", UIParent, "CENTER", c.x or 0, c.y or 0)
                            icd:SetSize(sw, sh)
                            icd:SetFrameStrata("DIALOG")
                            BUFFS.Fit(icd, UIParent)
                            icd:SetAlpha(1)
                        end
                    elseif im then
                        if not im.hold then im:SetAlpha(0) end
                        local icd = im.ihost and im.ihost.cooldown
                        if icd then icd:SetAlpha(0) end
                    end
                end
            end
        end
    end
    function BUFFS.MirrorStyle()
        if InCombatLockdown() then return end
        for _, per in pairs(BUFFS.mir) do
            for _, m in pairs(per) do
                if m.btn then BUFFS.PinGlow(m, m.btn:GetWidth(), m.btn:GetHeight()) end
            end
        end
        syncN = 0           -- text popups and icons restyle on the next pass
    end

    local af = CreateFrame("Frame")
    af:RegisterEvent("PLAYER_REGEN_ENABLED")
    af:RegisterEvent("PLAYER_ENTERING_WORLD")
    -- hand-over at the end of combat: the in-combat glow stays up (unseen while the button's own glow is
    -- showing) until the button's own glow has been steady for a moment, so there is never a gap or a blink
    local hf = CreateFrame("Frame")
    hf:Hide()
    local function EndHold()
        BUFFS.holding = false
        hf:Hide()
        for _, m in ipairs(BUFFS.gated) do
            if m.hold then
                m.hold = false
                if m.open and not InCombatLockdown() then pcall(BUFFS.Gate, m) end
                m.open = false
            end
        end
    end
    -- also run the moment a real glow / popup / icon appears, so the two never show together even for a frame
    function BUFFS.HoldTick()
        for _, m in ipairs(BUFFS.gated) do
            if m.hold then
                local g, want
                if m.isText then    -- text popup: the real one is alertFrames[spell]
                    g = alertFrames[m.sp]
                    local a = NS.DB.alerts and NS.DB.alerts[m.sp]
                    want = a and a.on
                elseif m.sp then      -- floating icon: the real one is IC.frames[spell]
                    g = IC.frames[m.sp]
                    local c = NS.DB.icons and NS.DB.icons[m.sp]
                    want = c and c.on
                else
                    g = m.btn and m.btn.__pgGlow
                    want = m.ok
                end
                -- the in-combat copy is opened only while the real one is not showing, and closed again (back
                -- under the combat-only rule) the moment the real one is: its own visibility is never faked,
                -- so a new fight always finds it ready
                if want and not (g and g:IsShown() and g:GetAlpha() > 0.05) then
                    if not m.open then
                        pcall(UnregisterStateDriver, m, "visibility")
                        pcall(m.Show, m)
                        m.open = true
                    end
                elseif m.open then
                    pcall(BUFFS.Gate, m)
                    m.open = false
                end
            end
        end
    end
    hf:SetScript("OnUpdate", function()
        if InCombatLockdown() or GetTime() > BUFFS.holdEnd then return EndHold() end
        BUFFS.HoldTick()
    end)
    af:SetScript("OnEvent", function(_, e)
        if not NS.DB then return end
        if e == "PLAYER_REGEN_ENABLED" and UnregisterStateDriver then
            for _, m in ipairs(BUFFS.gated) do
                pcall(UnregisterStateDriver, m, "visibility")
                pcall(m.Show, m)
                m.hold, m.open = true, true
            end
            BUFFS.holdEnd = GetTime() + 2
            BUFFS.holding = true
            hf:Show()
        end
        pcall(BUFFS.AuraSync)
    end)
    af:SetScript("OnUpdate", function(_, dt)
        BUFFS.auraLast = BUFFS.auraLast + dt
        if BUFFS.auraLast < 0.25 then return end
        BUFFS.auraLast = 0
        if not NS.DB then return end
        local okM, errM = pcall(BUFFS.MirrorTick)
        if not okM then BUFFS.lastErr = tostring(errM) end
        if not InCombatLockdown() and BUFFS.sync2 ~= true then
            BUFFS.sync2 = (BUFFS.sync2 or 0) + 1
            if BUFFS.sync2 % 8 == 1 then pcall(BUFFS.AuraSync) end     -- picks up buffs added later
            if BUFFS.sync2 > 1000 then BUFFS.sync2 = 1 end
        end
    end)
end

local function CreateWindow()
    local f = CreateFrame("Frame", "ProcGlowFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    f:SetSize(980, 640)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    tinsert(UISpecialFrames, "ProcGlowFrame")
    f:SetBackdropBorderColor(1, 1, 1, 1)
    TA.Acc(f, "border", 1, 1, 1, 1)
    TA.Acc(f, "wbg", 1, 1, 1, 1)

    local header = f:CreateTexture(nil, "ARTWORK")
    header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    header:SetSize(300, 64)
    header:SetPoint("TOP", 0, 12)
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", header, "TOP", 0, -14)
    title:SetText("ProcGlow")
    TA.Acc(title, "fs")

    local close = UI.Close(f, function() f:Hide() end)
    close:SetPoint("TOPRIGHT", -12, -12)

    f:SetScript("OnHide", function() NS.previewOn = false; if TA.moveSpell then TA.moveSpell = nil; TA.ApplyLock() end end)

    -- left list
    local nav = MakePanel(f)
    nav:SetPoint("TOPLEFT", 18, -44)
    nav:SetWidth(170)
    nav:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 18, 18)

    -- right-hand content
    local content = MakePanel(f)
    content:SetPoint("TOPLEFT", nav, "TOPRIGHT", 8, 0)
    content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -18, 18)

    for _, key in ipairs({ "settings", "style", "counters", "text", "classes", "class", "profiles" }) do
        local p = CreateFrame("Frame", nil, content)
        p:SetPoint("TOPLEFT", 4, -4)
        p:SetPoint("BOTTOMRIGHT", -4, 4)
        p:Hide()
        pages[key] = p
    end
    pageRefresh.settings = BuildSettingsPage(pages.settings)
    pageRefresh.style = BuildStylePage(pages.style)
    pageRefresh.counters = BuildCountersPage(pages.counters)
    pageRefresh.text = BuildTextPage(pages.text)
    pageRefresh.classes = BuildClassesPage(pages.classes)
    pageRefresh.class = BuildClassPage(pages.class)
    pageRefresh.profiles = TA.BuildProfilesPage(pages.profiles)

    -- nav rows: Settings, Glow Style, Classes (expands into every class)
    local _, pc = UnitClass("player")
    wipe(navRows)
    navRows[#navRows + 1] = { key = "settings", row = MakeNavRow(nav, "General Settings", 0, function() NS.ShowPage("settings") end) }
    navRows[#navRows + 1] = { key = "classes", row = MakeNavRow(nav, "Class Procs/Buffs", 0, function() NS.ShowPage("classes") end) }
    navRows[#navRows + 1] = { key = "style", row = MakeNavRow(nav, "Glow Style", 0, function() NS.ShowPage("style") end) }
    navRows[#navRows + 1] = { key = "counters", row = MakeNavRow(nav, "Timer & Stacks", 0, function() NS.ShowPage("counters") end) }
    navRows[#navRows + 1] = { key = "text", row = MakeNavRow(nav, "Text Alerts", 0, function() NS.ShowPage("text") end) }
    navRows[#navRows + 1] = { key = "profiles", row = MakeNavRow(nav, "Profiles", 0, function() NS.ShowPage("profiles") end) }

    function NS.NavRefresh()
        local y = 8
        for _, e in ipairs(navRows) do
            local r = e.row
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", nav, "TOPLEFT", 8, -y)
            r:SetPoint("TOPRIGHT", nav, "TOPRIGHT", -8, -y)
            r:Show()
            y = y + 24
            local selected
            if e.key == "classes" then
                selected = (cur.page == "classes" or cur.page == "class")
            else
                selected = (cur.page == e.key)
            end
            if selected then r.sel:Show() else r.sel:Hide() end
        end
    end

    local ver = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    ver:SetPoint("BOTTOMLEFT", 24, 22)
    ver:SetText("ProcGlow v2.0.6")
    local scB = TA.AddScale(f, "main", f, "TOPLEFT", "TOPLEFT", 24, -14, true)
    TA.AddMin(f, close, { nav, content, ver, scB }, 300, 44, 34, true)

    return f
end

local function OpenSettings(page, class)
    if not NS.win then NS.win = CreateWindow() end
    NS.win:Show()
    NS.ShowPage(page or cur.page or "settings", class)
end
NS.OpenSettings = OpenSettings

local function ToggleWindow()
    if NS.win and NS.win:IsShown() then NS.win:Hide(); return end
    -- /pg opens on the class page of the character you are playing
    local _, pc = UnitClass("player")
    if pc and (CLASS_SPELLS[pc] or BUFFS.class[pc]) then OpenSettings("class", pc) else OpenSettings("classes") end
end
NS.ToggleWindow = ToggleWindow
