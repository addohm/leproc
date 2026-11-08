local _, NS = ...
local ApplyStyleTo, BUFFS, BuildGlow, CondOK, CurrentForm, HideGlowFrame = NS.ApplyStyleTo, NS.BUFFS, NS.BuildGlow, NS.CondOK, NS.CurrentForm, NS.HideGlowFrame
local MatchRedirect, PlayerBuffs, Print, ProcActive, ProcRemaining, ResolveSlot = NS.MatchRedirect, NS.PlayerBuffs, NS.Print, NS.ProcActive, NS.ProcRemaining, NS.ResolveSlot
local SetAlert, SetGlow, ShouldGlow, ShowGlowFrame, SlotOf, SpellCD = NS.SetAlert, NS.SetGlow, NS.ShouldGlow, NS.ShowGlowFrame, NS.SlotOf, NS.SpellCD
local SpellIcon, TA, activeRedirects, activeRemain, buffProcs, buttons = NS.SpellIcon, NS.TA, NS.activeRedirects, NS.activeRemain, NS.buffProcs, NS.buttons
local glowStart, onBarNames, seenProcs = NS.glowStart, NS.onBarNames, NS.seenProcs

---------------------------------------------------------------------------
-- Icon popups: the proc's icon on screen while it is up
---------------------------------------------------------------------------
local IC = { frames = {}, test = {} }
NS.IC = IC
-- procs with no button of their own show the icon of the talent behind them
IC.ART = {
    ["omen of clarity"] = "Interface\\Icons\\Spell_Nature_CrystalBall",
    ["arcane concentration"] = "Interface\\Icons\\Spell_Shadow_ManaBurn",
    ["elemental focus"] = "Interface\\Icons\\Spell_Shadow_ManaBurn",
    ["remorseless attacks"] = "Interface\\Icons\\Ability_FiegnDead",
    ["rapid killing"] = "Interface\\Icons\\Ability_Hunter_RunningShot",
    ["seals"] = "Interface\\Icons\\Ability_ThunderBolt",
}
function IC.Cfg(spell, create)
    NS.DB.icons = NS.DB.icons or {}
    local c = NS.DB.icons[spell]
    if not c and create then
        c = { on = false, size = 48, timer = true, stacks = true }
        NS.DB.icons[spell] = c
    end
    return c
end
-- procs whose own buff icon is shown on the floating icon instead of the ability's icon
IC.BUFFICON = { ["missile barrage"] = true, ["arcane blast"] = true }
function IC.Tex(spell)
    for k in pairs(IC.BUFFICON) do
        if buffProcs[k] == spell then
            local t = SpellIcon(k) or BUFFS.auraIcon[k]
            if t then return t end
        end
    end
    return IC.ART[spell] or SpellIcon(spell) or BUFFS.auraIcon[spell] or "Interface\\Icons\\INV_Misc_QuestionMark"
end
-- the proc being edited on the Icon tab, if the Customise window is on that tab
function IC.Editing()
    if TA.moveSet and TA.moveSpell then return TA.moveSpell end     -- page Customise: every icon stays editable
    return TA.moveSpell and TA.menuTab == "icon" and TA.moveSpell or nil
end
function IC.Gap() return NS.DB.iconGap or 2 end
-- an icon is square (size) unless it has its own width / height
function IC.Dims(c) return (c.sw or c.size or 48), (c.sh or c.size or 48) end

function IC.Place(f)
    local c = IC.Cfg(f.spell)
    if not c then return end
    local w, h = IC.Dims(c)
    local sz = math.min(w, h)
    f:SetSize(w, h)
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", c.x or 0, c.y or 0)
    local font = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    f.timer:SetFont(font, math.max(10, math.floor(sz * 0.38)), "OUTLINE")
    f.stack:SetFont(font, math.max(9, math.floor(sz * 0.3)), "OUTLINE")
    local gk = w * 1000 + h
    if f.glow and f.glowSz ~= gk then f.glowSz = gk; ApplyStyleTo(f, f.glow, true) end
end

-- sticks an icon to its neighbours while it is dragged: side by side, or stacked, lined up
function IC.Magnet(f, x, y, skip)
    local c = IC.Cfg(f.spell)
    local w, h = IC.Dims(c)
    local T, gap = 12, IC.Gap()
    local bx, by
    for sp, g in pairs(IC.frames) do
        local gc = IC.Cfg(sp)
        if g ~= f and g:IsShown() and gc and not (skip and skip[sp]) then
            local gw, gh = IC.Dims(gc)
            local gx, gy = gc.x or 0, gc.y or 0
            local half, halfV = (w + gw) / 2, (h + gh) / 2
            local dx, dy = math.abs(x - gx), math.abs(y - gy)
            if dy < halfV + T then
                local sx
                if math.abs(x - (gx + half + gap)) < T then sx = gx + half + gap
                elseif math.abs(x - (gx - half - gap)) < T then sx = gx - half - gap end
                if sx then
                    bx = sx
                    by = gy          -- always lined up, never off-centre
                end
            end
            if dx < half + T then
                local sy
                if math.abs(y - (gy + halfV + gap)) < T then sy = gy + halfV + gap
                elseif math.abs(y - (gy - halfV - gap)) < T then sy = gy - halfV - gap end
                if sy then
                    by = sy
                    bx = gx
                end
            end
        end
    end
    return bx or x, by or y
end

-- every icon touching this one, directly or through others (they move together)
function IC.Cluster(spell)
    local gap = IC.Gap()
    local seen, list = { [spell] = true }, { spell }
    local i = 1
    while i <= #list do
        local a = IC.Cfg(list[i])
        for sp, g in pairs(IC.frames) do
            local b = IC.Cfg(sp)
            if not seen[sp] and g:IsShown() and b and a then
                local aw, ah = IC.Dims(a)
                local bw, bh = IC.Dims(b)
                local half, halfV = (aw + bw) / 2, (ah + bh) / 2
                local dx, dy = math.abs((b.x or 0) - (a.x or 0)), math.abs((b.y or 0) - (a.y or 0))
                local side = math.abs(dx - (half + gap)) <= 2 and dy <= 2
                local stack = math.abs(dy - (halfV + gap)) <= 2 and dx <= 2
                if side or stack then seen[sp] = true; list[#list + 1] = sp end
            end
        end
        i = i + 1
    end
    return list, seen
end

function IC.DragStart(f)
    if not IC.Editing() then return end
    GameTooltip:Hide()
    IC.PadHide()
    local c = IC.Cfg(f.spell)
    if not c then return end
    f.group, f.groupSet = nil, nil
    if NS.DB.iconGroup ~= false and not (IsShiftKeyDown and IsShiftKeyDown()) then
        local list, set = IC.Cluster(f.spell)
        if #list > 1 then
            f.group, f.groupSet = {}, set
            for _, sp in ipairs(list) do
                local mc = IC.Cfg(sp)
                f.group[#f.group + 1] = { sp = sp, x0 = mc.x or 0, y0 = mc.y or 0 }
            end
            f.lx0, f.ly0 = c.x or 0, c.y or 0
        end
    end
    local cx, cy = GetCursorPosition()
    local sc = UIParent:GetEffectiveScale()
    local ux, uy = UIParent:GetCenter()
    f.offX = (c.x or 0) - (cx / sc - ux)
    f.offY = (c.y or 0) - (cy / sc - uy)
    f.dragging = true
end
function IC.DragStop(f)
    f.dragging = false
    if IC.onMove then IC.onMove() end
end
function IC.OnUpdate(f)
    if not f.dragging then return end
    local c = IC.Cfg(f.spell)
    if not c then return end
    local cx, cy = GetCursorPosition()
    local sc = UIParent:GetEffectiveScale()
    local ux, uy = UIParent:GetCenter()
    local x, y = IC.Magnet(f, cx / sc - ux + f.offX, cy / sc - uy + f.offY, f.groupSet)
    c.x, c.y = math.floor(x + 0.5), math.floor(y + 0.5)
    if f.group then
        local dx, dy = c.x - f.lx0, c.y - f.ly0
        for _, m in ipairs(f.group) do
            local mc = IC.Cfg(m.sp)
            mc.x, mc.y = m.x0 + dx, m.y0 + dy
            local mf = IC.frames[m.sp]
            if mf then IC.Place(mf) end
        end
    end
    IC.Place(f)
    if IC.onMove then IC.onMove() end
end

-- hover arrows for fine movement: along the bottom edge of the icon you get left/right,
-- along either side you get up/down. Snapped icons move together.
function IC.PadHide()
    local p = IC.pad
    if not p then return end
    for _, b in pairs(p.btns) do b:Hide() end
    p.owner, p.zone, p.hold = nil, nil, nil
    p:Hide()
end
function IC.PadZone(zone)
    local p, o = IC.pad, IC.pad.owner
    for _, b in pairs(p.btns) do b:Hide(); b:ClearAllPoints() end
    p.zone = zone
    local B = p.btns
    if zone == "B" then
        B.L:SetPoint("TOPRIGHT", o, "BOTTOM", -1, 1)
        B.R:SetPoint("TOPLEFT", o, "BOTTOM", 1, 1)
        B.L:Show(); B.R:Show()
    elseif zone == "R" then
        B.U:SetPoint("BOTTOMLEFT", o, "RIGHT", -1, 1)
        B.D:SetPoint("TOPLEFT", o, "RIGHT", -1, -1)
        B.U:Show(); B.D:Show()
    elseif zone == "L" then
        B.U:SetPoint("BOTTOMRIGHT", o, "LEFT", 1, 1)
        B.D:SetPoint("TOPRIGHT", o, "LEFT", 1, -1)
        B.U:Show(); B.D:Show()
    end
end
do
local function PadHit(fr, m, x, y)
    local l, b, w, h = fr:GetLeft(), fr:GetBottom(), fr:GetWidth(), fr:GetHeight()
    if not (l and b and w and h) then return false end
    return x >= l - m and x <= l + w + m and y >= b - m and y <= b + h + m
end
local function PadStep(b)
    local st = (IsShiftKeyDown and IsShiftKeyDown()) and 10 or 1
    local o = IC.pad.owner
    if o then IC.Nudge(o.spell, b.dx * st, b.dy * st) end
end
function IC.Pad()
    if IC.pad then return IC.pad end
    local p = CreateFrame("Frame", nil, UIParent)
    p:SetSize(1, 1)
    p.btns = {}
    local def = {
        L = { "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-", -1, 0 },
        R = { "Interface\\Buttons\\UI-SpellbookIcon-NextPage-", 1, 0 },
        U = { "Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-", 0, 1 },
        D = { "Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-", 0, -1 },
    }
    for k, d in pairs(def) do
        local b = CreateFrame("Button", nil, UIParent)
        b:SetSize(24, 24)
        b:SetFrameStrata("TOOLTIP")
        b:SetFrameLevel(60)
        b:SetNormalTexture(d[1] .. "Up")
        b:SetPushedTexture(d[1] .. "Down")
        b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
        b.dx, b.dy = d[2], d[3]
        b:SetScript("OnMouseDown", function(self) PadStep(self); p.hold, p.t = self, -0.4 end)
        b:SetScript("OnMouseUp", function() p.hold = nil end)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText("Nudge", 1, 1, 1)
            GameTooltip:AddLine("Click to move 1 pixel. Hold to keep moving, or hold Shift for 10 pixels.", nil, nil, nil, true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b:Hide()
        p.btns[k] = b
    end
    p:SetScript("OnUpdate", function(self, el)
        local o = self.owner
        if not o or not o:IsShown() or o.dragging or not IC.Editing() then IC.PadHide() return end
        local cx, cy = GetCursorPosition()
        local sc = UIParent:GetEffectiveScale()
        cx, cy = cx / sc, cy / sc
        local overIcon = PadHit(o, 0, cx, cy)
        local overBtn = false
        for _, b in pairs(self.btns) do
            if b:IsShown() and PadHit(b, 2, cx, cy) then overBtn = true end
        end
        if not overBtn then self.hold = nil end
        if not overIcon and not overBtn then IC.PadHide() return end
        if overIcon then
            local rx = (cx - o:GetLeft()) / o:GetWidth()
            local ry = (cy - o:GetBottom()) / o:GetHeight()
            local zone
            if ry < 0.34 then zone = "B" elseif rx < 0.3 then zone = "L" elseif rx > 0.7 then zone = "R" end
            if zone ~= self.zone then IC.PadZone(zone) end
        end
        if self.hold then
            self.t = (self.t or 0) + el
            if self.t > 0.05 then self.t = 0; PadStep(self.hold) end
        end
    end)
    p:Hide()
    IC.pad = p
    return p
end
end
function IC.PadShow(f)
    local p = IC.Pad()
    if p.owner ~= f then
        IC.PadHide()
        p.owner = f
        p:Show()
    end
end

function IC.Get(spell)
    local f = IC.frames[spell]
    if f then return f end
    f = CreateFrame("Frame", nil, UIParent)
    f.spell = spell
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    NS.NoMouse(f)
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetPoint("TOPLEFT", -2, 2); f.bg:SetPoint("BOTTOMRIGHT", 2, -2)
    f.bg:SetColorTexture(0, 0, 0, 1)
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetAllPoints()
    f.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    f.sel = f:CreateTexture(nil, "OVERLAY")
    f.sel:SetAllPoints()
    f.sel:SetColorTexture(0.2, 0.6, 1, 0.25)
    f.sel:Hide()
    f.tf = CreateFrame("Frame", nil, f)
    f.tf:SetAllPoints(f)
    f.tf:SetFrameLevel(f:GetFrameLevel() + 16)
    NS.NoMouse(f.tf)
    f.timer = f.tf:CreateFontString(nil, "OVERLAY")
    f.timer:SetPoint("CENTER", 0, 0)
    f.stack = f.tf:CreateFontString(nil, "OVERLAY")
    f.stack:SetPoint("BOTTOMRIGHT", -2, 2)
    f:RegisterForDrag("LeftButton")
    -- quiet hint, only when this icon is snapped to others
    f:SetScript("OnEnter", function(self)
        if self.dragging or not IC.Editing() then return end
        IC.PadShow(self)
        if NS.DB.iconGroup == false then return end
        local list = IC.Cluster(self.spell)
        if #list < 2 then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Snapped together", 1, 1, 1)
        GameTooltip:AddLine("Dragging moves them all. Hold Shift while dragging to detach just this icon.", nil, nil, nil, true)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f:SetScript("OnMouseDown", function(self)
        if IC.Editing() and (TA.moveSpell ~= self.spell or TA.menuTab ~= "icon") then
            TA.moveSpell = self.spell
            TA.menuTab = "icon"          -- clicking an icon switches the window to that icon
            TA.ApplyLock()
        end
    end)
    f:SetScript("OnDragStart", IC.DragStart)
    f:SetScript("OnDragStop", IC.DragStop)
    f:SetScript("OnUpdate", IC.OnUpdate)
    IC.frames[spell] = f
    IC.Place(f)
    f:Hide()
    return f
end

function IC.Test(spell) IC.test[spell] = GetTime() + 6 end
-- one Test button: shows whichever of the text popup and the icon are switched on
function TA.TestBoth(spell)
    local a = NS.DB.alerts[spell]
    if a and a.on then TA.Test(spell) end
    local c = NS.DB.icons and NS.DB.icons[spell]
    if c and c.on then IC.Test(spell) end
end
function IC.Nudge(spell, dx, dy)
    local list = { spell }
    if NS.DB.iconGroup ~= false then list = IC.Cluster(spell) end
    for _, sp in ipairs(list) do
        local c = IC.Cfg(sp, true)
        c.x, c.y = (c.x or 0) + dx, (c.y or 0) + dy
        local f = IC.frames[sp]
        if f then IC.Place(f) end
    end
    if IC.onMove then IC.onMove() end
end
function IC.Centre(axis, spell)
    local c = IC.Cfg(spell, true)
    if axis == "x" then c.x = 0 else c.y = 0 end
    local f = IC.frames[spell]
    if f then IC.Place(f) end
    if IC.onMove then IC.onMove() end
end
-- a new icon starts beside the ones already switched on, so they never sit on top of each other
function IC.Enable(spell)
    local c = IC.Cfg(spell, true)
    c.on = true
    if c.x == nil then
        local n = 0
        for sp, o in pairs(NS.DB.icons) do if sp ~= spell and o.on and o.x ~= nil then n = n + 1 end end
        c.x = n * ((IC.Dims(c)) + IC.Gap() + 2)
        c.y = 140
    end
    local f = IC.frames[spell]
    if f then IC.Place(f) end
end

-- line every other icon up against this one, in a row or a column
function IC.LineUp(anchor, vertical)
    local ac = IC.Cfg(anchor)
    if not ac then return end
    local gap = IC.Gap()
    local aw, ah = IC.Dims(ac)
    local asz = vertical and ah or aw
    local ax, ay = ac.x or 0, ac.y or 0
    local near, far = {}, {}
    for sp, c in pairs(NS.DB.icons) do
        if c.on and sp ~= anchor and BUFFS.Allowed(sp) then
            local d = vertical and ((c.y or 0) - ay) or ((c.x or 0) - ax)
            local cw, ch = IC.Dims(c)
            local t = { sp = sp, d = d, size = vertical and ch or cw }
            if vertical then
                if d > 0 then near[#near + 1] = t else far[#far + 1] = t end    -- above / below
            else
                if d < 0 then near[#near + 1] = t else far[#far + 1] = t end    -- left / right
            end
        end
    end
    local function byDist(a, b)
        if math.abs(a.d) ~= math.abs(b.d) then return math.abs(a.d) < math.abs(b.d) end
        return a.sp < b.sp
    end
    table.sort(near, byDist); table.sort(far, byDist)
    local edge
    if vertical then
        edge = ay + asz / 2 + gap
        for _, t in ipairs(near) do local c = NS.DB.icons[t.sp]; c.x = ax; c.y = edge + t.size / 2; edge = edge + t.size + gap end
        edge = ay - asz / 2 - gap
        for _, t in ipairs(far) do local c = NS.DB.icons[t.sp]; c.x = ax; c.y = edge - t.size / 2; edge = edge - t.size - gap end
    else
        edge = ax - asz / 2 - gap
        for _, t in ipairs(near) do local c = NS.DB.icons[t.sp]; c.y = ay; c.x = edge - t.size / 2; edge = edge - t.size - gap end
        edge = ax + asz / 2 + gap
        for _, t in ipairs(far) do local c = NS.DB.icons[t.sp]; c.y = ay; c.x = edge + t.size / 2; edge = edge + t.size + gap end
    end
    for sp, c in pairs(NS.DB.icons) do
        if c.x then c.x = math.floor(c.x + 0.5) end
        if c.y then c.y = math.floor(c.y + 0.5) end
        local f = IC.frames[sp]
        if f then IC.Place(f) end
    end
    if IC.onMove then IC.onMove() end
end

-- seconds left on the cooldown of a tracked ability, for the icon that stays up after the buff ends
IC.castAt = {}      -- spell -> when you last cast it (the cooldown starts then)
-- First Aid has no cooldown: what you wait for is the Recently Bandaged debuff (a minute, shorter with the Field
-- Medicine legacy perk, and only out in the open world). The real length is read from the debuff each time it can be
-- seen and remembered, so the perk's ranks never need to be known; before it has been seen once, a minute is assumed.
function IC.BandagedLeft()
    local now = GetTime()
    NS.DB.cdLearned = NS.DB.cdLearned or {}
    local d
    local okA, r = pcall(function()
        if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
            local x = C_UnitAuras.GetPlayerAuraBySpellID(11196)
            if type(x) == "table" then return x end
        end
        if C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName then
            local x = C_UnitAuras.GetAuraDataBySpellName("player", LOC.Local("recently bandaged") or "Recently Bandaged", "HARMFUL")
            if type(x) == "table" then return x end
        end
    end)
    if okA and r then d = r end
    if d then
        local ex, du = d.expirationTime, d.duration
        if type(ex) == "number" and type(du) == "number" and not (issecretvalue and (issecretvalue(ex) or issecretvalue(du))) then
            if du > 0 then NS.DB.cdLearned["first aid"] = du end
            local left = ex - now
            return left > 0 and left or nil
        end
    end
    -- not seen: either it is over, or the game is hiding your debuffs right now (then count from the cast)
    if NS.auraRestricted then
        local t = IC.castAt["first aid"]
        if t then
            local left = t + (NS.DB.cdLearned["first aid"] or 60) - now
            if left > 0 then return left end
        end
    end
    return nil
end

function IC.CooldownLeft(spell)
    if spell == "first aid" then return IC.BandagedLeft() end
    local now = GetTime()
    local st, du = NS.SpellCDState(spell)
    if st then
        NS.DB.cdLearned = NS.DB.cdLearned or {}
        NS.DB.cdLearned[spell] = du                 -- remembered, for fights where the game hides cooldowns
        local left = st + du - now
        return left > 0 and left or nil
    elseif st == nil then
        -- cannot be read now: count from your cast, using the length seen last time
        local t, d = IC.castAt[spell], NS.DB.cdLearned and NS.DB.cdLearned[spell]
        if t and d then
            local left = t + d - now
            if left > 0 then return left end
        end
    end
    return nil
end

function IC.Update(buffs, seen)
    local en = NS.DB.enabled ~= false
    local now = GetTime()
    local editing = IC.Editing()
    for spell, c in pairs(NS.DB.icons or {}) do
      if not (IC.frames[spell] and IC.frames[spell].pgMirror) then
        local want, rem, stk, sealName, cdMode = false, nil, nil, nil, false
        local allowed = BUFFS.Allowed(spell)
        if c.on and en and allowed then
            if spell == "seals" then
                -- one icon for every seal: it takes the look and timer of whichever one you have up
                for k in pairs(NS.auraRestricted and BUFFS.cache or buffs) do
                    if BUFFS.IsSeal(k) then sealName = k; break end
                end
                if sealName then
                    local here, left = BUFFS.Presence(sealName, buffs)
                    if here then want = true; rem = left else sealName = nil end
                end
            elseif NS.DB.watch and NS.DB.watch[spell] then
                -- a buff you asked to track: shown while it is on you, with the time left
                local here, left, n = BUFFS.Presence(spell, buffs)
                if BUFFS.MissingMode(spell) then
                    -- set to show when the buff is missing: shown only while it is NOT on you
                    if BUFFS.WatchMissing(spell, buffs) then want = true end
                elseif here then
                    want = true
                    rem = left
                    if n and n > 1 then stk = n end
                elseif c.cdkeep or BUFFS.abil[spell] then
                    -- the buff is over: keep the icon up, greyed, with the time left on the ability's cooldown
                    local left = IC.CooldownLeft(spell)
                    if left then want = true; rem = left; cdMode = true end
                end
            else
                local active
                if onBarNames[spell] then
                    active = seen[spell]
                else
                    local ok, r = pcall(ProcActive, spell, buffs)
                    active = ok and r
                end
                if active then
                    want = true
                    rem = ProcRemaining(spell, buffs)
                    stk = BUFFS.Stacks(spell, buffs)
                end
            end
        end
        local tt = IC.test[spell]
        if tt and tt > now and c.on then want = true; rem = tt - now; stk = 2 end
        local editingThis = c.on and editing and allowed
        if editingThis then
            want = true
            if not (rem and rem > 0) then rem = 12 end
            stk = stk or 2
        end
        local f = IC.frames[spell]
        if want then
            f = f or IC.Get(spell)
            -- a group (armor, aspect, blessing...) shows the icon of the member being tracked
            local gname = sealName
            if not gname and BUFFS.groups[spell] then
                local st = BUFFS.state[spell]
                gname = (st and st.cur) or BUFFS.Selected(spell)
            end
            local tx = (gname and (SpellIcon(gname) or BUFFS.auraIcon[gname])) or IC.Tex(spell)
            if f.texKey ~= tx then f.texKey = tx; f.icon:SetTexture(tx) end
            if f.lastDesat ~= cdMode then f.lastDesat = cdMode; f.icon:SetDesaturated(cdMode) end
            local tstr = ((c.timer ~= false or cdMode) and rem and rem > 0) and BUFFS.Fmt(rem, spell == "arcane blast stacks") or ""
            if f.lastTimer ~= tstr then f.lastTimer = tstr; f.timer:SetText(tstr) end
            -- combat hides the numbers: let the game draw the countdown from its own duration object
            local lv = (not cdMode and c.timer ~= false and NS.auraRestricted and NS.DB.watch and NS.DB.watch[spell]) and BUFFS.live[spell] or nil
            if lv and lv.obj and now - lv.t < 1.5 and f.cd ~= false and (f.cd or CreateFrame) then
                if not f.cd then
                    local okc, cd = pcall(CreateFrame, "Cooldown", nil, f, "CooldownFrameTemplate")
                    if okc and cd and cd.SetCooldownFromDurationObject then
                        cd:SetAllPoints(f)
                        cd:SetDrawSwipe(false); cd:SetDrawEdge(false); cd:SetDrawBling(false)
                        cd:SetHideCountdownNumbers(false)
                        f.cd = cd
                    else
                        f.cd = false
                    end
                end
                if f.cd and f.cdStamp ~= lv.t then
                    f.cdStamp = lv.t
                    pcall(f.cd.SetCooldownFromDurationObject, f.cd, lv.obj)
                    f.cd:Show()
                end
            elseif f.cd and f.cdStamp then
                f.cdStamp = nil
                f.cd:Hide()
            end
            local sstr = (c.stacks ~= false and stk and stk >= 1) and tostring(stk) or ""
            if f.lastStack ~= sstr then f.lastStack = sstr; f.stack:SetText(sstr) end
            local et = editingThis and true or false
            local gold = (et and editing == spell and TA.menuTab == "icon") and true or false
            if f.lastEdit ~= et or f.lastGold ~= gold or (f:IsMouseEnabled() and true or false) ~= et then        -- editing look: only redone when it changes
                f.lastEdit, f.lastGold = et, gold
                if et then NS.YesMouse(f) else NS.NoMouse(f) end
                f.sel:SetShown(et)
                if gold then f.bg:SetColorTexture(1, 0.82, 0, 1) else f.bg:SetColorTexture(0, 0, 0, 1) end
                f:SetFrameStrata(et and "TOOLTIP" or "HIGH")
            end
            if not f:IsShown() then f:Show(); if BUFFS.holding then BUFFS.HoldTick() end end
            if c.glow and not cdMode then
                if not f.glow then f.glow = BuildGlow(f); f.glowSz = nil end
                if not f.glow:IsShown() then
                    f.glowSz = (IC.Dims(c)) * 1000 + select(2, IC.Dims(c))
                    ApplyStyleTo(f, f.glow, true)
                    ShowGlowFrame(f.glow)
                end
            elseif f.glow and f.glow:IsShown() then
                HideGlowFrame(f.glow)
            end
        elseif f and f:IsShown() then
            if f.glow and f.glow:IsShown() then HideGlowFrame(f.glow) end
            f.dragging = false
            NS.NoMouse(f)
            f.lastEdit, f.lastGold = nil, nil      -- hiding resets the edit look, so the next Customise applies it again
            f:Hide()
        end
      end
    end
    -- same for an icon whose setting no longer exists (another profile was loaded)
    for spell, f in pairs(IC.frames) do
        if not (NS.DB.icons and NS.DB.icons[spell]) and f:IsShown() then
            if f.glow and f.glow:IsShown() then HideGlowFrame(f.glow) end
            f.dragging = false
            NS.NoMouse(f)
            f.lastEdit, f.lastGold = nil, nil      -- hiding resets the edit look, so the next Customise applies it again
            f:Hide()
        end
    end
end

local function RedirectActive(spell, buffs)
    return BUFFS.Allowed(spell) and ProcActive(spell, buffs)
end

local function Tick()
    local buffs = PlayerBuffs()
    local now = GetTime()
    wipe(activeRedirects); wipe(activeRemain); wipe(seenProcs); wipe(onBarNames); wipe(TA.quiet); wipe(TA.full)
    local okf, form = pcall(CurrentForm)
    if not okf then form = nil end
    for spell, target in pairs(NS.DB.redirect) do
        local okp, active = pcall(RedirectActive, spell, buffs)
        if okp and active and not NS.DB.disabled[spell] and CondOK(spell, form) then
            activeRedirects[spell] = target
            seenProcs[spell] = true
            if not glowStart[spell] then glowStart[spell] = now end
            activeRemain[spell] = ProcRemaining(spell, buffs)
        end
    end
    local enabled = NS.DB.enabled ~= false
    if not enabled then wipe(activeRedirects) end
    local hasRedirect = next(activeRedirects) ~= nil

    -- the gamepad bars can be created after the first scan: pick them up as soon as they exist
    if (not NS.gpBuilt and _G["GamepadMainActionBarFramePageUnitBottomCenteredAnchorBottomBarActionButton1"])
        or (not NS.eabBuilt and _G["EABButton1"]) then
        NS.BuildButtons()
    end
    for i = 1, #buttons do
        local b = buttons[i]
        local want, alertSpell, rem, stk, faint = false, nil, nil, nil, false
        if b:IsVisible() and b.__pgStance then
            local okr, name, res = pcall(BUFFS.StanceGlow, b.__pgStance)
            if okr and name then
                onBarNames[name] = true
                want = NS.previewOn or (enabled and res) or false
                if enabled and res then
                    seenProcs[name] = true
                    if not glowStart[name] then glowStart[name] = now end
                    rem = ProcRemaining(name, buffs)
                end
            end
        elseif b:IsVisible() then
            local slot = SlotOf(b)
            if slot then
                if HasAction(slot) then
                    local okr, name, id = pcall(ResolveSlot, slot)
                    if not okr then name, id = nil, nil end
                    if name then onBarNames[name] = true end
                    if name and BUFFS.slots then pcall(BUFFS.GlowMirror, b, name) end
                    local okg, res = pcall(ShouldGlow, slot, name, id, buffs)
                    want = NS.previewOn or (enabled and okg and res) or false
                    if enabled and okg and res and name then
                        seenProcs[name] = true
                        if not glowStart[name] then glowStart[name] = now end
                        rem = ProcRemaining(name, buffs)
                        stk = BUFFS.Stacks(name, buffs)
                        if res == "faint" then faint = true; TA.quiet[name] = true else TA.full[name] = true end
                    elseif NS.previewOn then
                        rem = 12; stk = 2
                    end
                    if hasRedirect then alertSpell = MatchRedirect(slot, name) end
                elseif hasRedirect then
                    alertSpell = MatchRedirect(slot, nil)
                end
            end
        end
        SetGlow(b, want, rem, stk, faint)
        local cs, cdur
        if alertSpell then cs, cdur = SpellCD(alertSpell) end
        SetAlert(b, alertSpell, alertSpell and activeRemain[alertSpell] or nil, cs, cdur, alertSpell and BUFFS.Stacks(alertSpell, buffs) or nil)
    end
    for k in pairs(glowStart) do
        if not seenProcs[k] then glowStart[k] = nil end
    end
    -- a faintly glowing (not yet full) stacking proc doesn't trigger its text popup
    for k in pairs(TA.quiet) do if not TA.full[k] then seenProcs[k] = nil end end
    pcall(TA.Update, buffs, seenProcs)
    pcall(IC.Update, buffs, seenProcs)
end
NS.Tick = Tick

---------------------------------------------------------------------------
-- Debug: print buffs gained and native overlay events
---------------------------------------------------------------------------
local lastBuffs = {}
local function DebugBuffs()
    local cur = PlayerBuffs()
    for n in pairs(cur) do
        if not lastBuffs[n] then Print("buff gained: " .. n) end
    end
    wipe(lastBuffs)
    for n in pairs(cur) do lastBuffs[n] = true end
end
NS.DebugBuffs = DebugBuffs
