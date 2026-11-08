local _, NS = ...
local ApplyAll, BUFFS, IC, LoadLists, NewForm, PlaceAlert = NS.ApplyAll, NS.BUFFS, NS.IC, NS.LoadLists, NS.NewForm, NS.PlaceAlert
local Print, TA, Tip, alertFrames, cur = NS.Print, NS.TA, NS.Tip, NS.alertFrames, NS.cur

---------------------------------------------------------------------------
-- Profiles: named copies of your settings, optionally switched by spec or group role
---------------------------------------------------------------------------
do
    local PF = {}
    TA.Prof = PF
    PF.MAX = 8
    -- not part of a profile: install state, the minimap button, window scales, the master switch
    local SKIP = { profiles = true, profileCur = true, auto = true, welcomed = true, hideLoginMsg = true,
                   minimap = true, seenMineOnly = true, cdLearned = true, countdownOff = true, winScaleReset = true, chars = true, learned = true, seen = true, thanksShown = true, thanksShown2 = true, thanksShown3 = true, langNoticeShown = true, enabled = true, winScale = true, classUI = true,
                   locForce = true, imbueIds = true, idscanText = true }

    -- profiles and automatic-switch rules belong to the character you are playing
    function PF.S()
        NS.DB.chars = NS.DB.chars or {}
        local key = (UnitName("player") or "?") .. "-" .. ((GetRealmName and GetRealmName()) or "?")
        local t = NS.DB.chars[key]
        if not t then
            t = {}
            if NS.DB.profiles then      -- profiles made before they were per character go to the first character to load
                t.profiles, t.cur, t.auto = NS.DB.profiles, NS.DB.profileCur, NS.DB.auto
                NS.DB.profiles, NS.DB.profileCur, NS.DB.auto = nil, nil, nil
            end
            NS.DB.chars[key] = t
        end
        t.profiles = t.profiles or {}
        t.auto = t.auto or {}
        return t
    end

    local function DeepCopy(v)
        if type(v) ~= "table" then return v end
        local t = {}
        for k, x in pairs(v) do t[k] = DeepCopy(x) end
        return t
    end
    -- copies src into dst in place, so any table the addon already holds a reference to stays valid
    local function SyncInto(dst, src)
        for k in pairs(dst) do if src[k] == nil then dst[k] = nil end end
        for k, v in pairs(src) do
            if type(v) == "table" then
                if type(dst[k]) ~= "table" then dst[k] = {} end
                SyncInto(dst[k], v)
            else
                dst[k] = v
            end
        end
    end

    function PF.Snapshot()
        local t = {}
        for k, v in pairs(NS.DB) do if not SKIP[k] then t[k] = DeepCopy(v) end end
        return t
    end

    function PF.Names()
        local list = {}
        for n in pairs(PF.S().profiles or {}) do list[#list + 1] = n end
        table.sort(list, function(a, b) return a:lower() < b:lower() end)
        return list
    end

    function PF.Ensure()
        PF.S().profiles = PF.S().profiles or {}
        PF.S().auto = PF.S().auto or {}
        PF.S().auto.role = PF.S().auto.role or {}
        PF.S().auto.spec = PF.S().auto.spec or {}
        if not PF.S().cur or not PF.S().profiles[PF.S().cur] then
            local name = "Default"
            while PF.S().profiles[name] do name = name .. "+" end
            PF.S().profiles[name] = PF.Snapshot()
            PF.S().cur = name
        end
    end

    -- keep the active profile's saved copy in step with the live settings
    function PF.SaveCurrent()
        if PF.S().cur and PF.S().profiles and PF.S().profiles[PF.S().cur] then
            PF.S().profiles[PF.S().cur] = PF.Snapshot()
        end
    end

    function PF.Reapply()
        pcall(LoadLists)
        wipe(BUFFS.state)
        pcall(ApplyAll)
        pcall(TA.RefreshStyle)
        for sp, f in pairs(alertFrames) do
            if NS.DB.alerts[sp] then pcall(PlaceAlert, f, sp) end
        end
        for sp, f in pairs(IC.frames) do
            if IC.Cfg(sp) then pcall(IC.Place, f) end
        end
        if TA.moveSpell then TA.moveSpell = nil; pcall(TA.ApplyLock) end
        if NS.win and NS.win:IsShown() then pcall(NS.ShowPage, cur.page, cur.class) end
    end

    function PF.Load(name, auto, noSave)
        if not noSave then PF.Ensure() end
        local snap = PF.S().profiles[name]
        if not snap or name == PF.S().cur then return false end
        if not noSave then PF.SaveCurrent() end
        local copy = DeepCopy(snap)
        for k, v in pairs(NS.DB) do
            if not SKIP[k] and copy[k] == nil then
                if type(v) == "table" then SyncInto(v, {}) else NS.DB[k] = nil end
            end
        end
        for k, v in pairs(copy) do
            if type(v) == "table" then
                if type(NS.DB[k]) ~= "table" then NS.DB[k] = {} end
                SyncInto(NS.DB[k], v)
            else
                NS.DB[k] = v
            end
        end
        PF.S().cur = name
        PF.Reapply()
        Print((auto and "switched to profile " or "profile ") .. "|cffffd100" .. name .. "|r" .. (auto and "" or " loaded"))
        return true
    end

    function PF.Valid(name)
        name = strtrim(name or "")
        if name == "" then return nil, "Type a name first." end
        if #name > 18 then return nil, "Keep the name to 18 letters or fewer." end
        for n in pairs(PF.S().profiles) do
            if n:lower() == name:lower() then return nil, "There is already a profile called " .. n .. "." end
        end
        return name
    end

    -- a new profile starts as a copy of what you have now, and becomes the active one
    function PF.Create(name)
        PF.Ensure()
        local n, err = PF.Valid(name)
        if not n then Print(err); return false end
        local count = 0
        for _ in pairs(PF.S().profiles) do count = count + 1 end
        if count >= PF.MAX then Print("that is the most profiles you can have (" .. PF.MAX .. "). Delete one first."); return false end
        PF.SaveCurrent()
        PF.S().profiles[n] = PF.Snapshot()
        PF.S().cur = n
        return true
    end

    local function EachRule(fn)
        local a = PF.S().auto
        if not a then return end
        for k, v in pairs(a.role or {}) do a.role[k] = fn(v) end
        for _, t in pairs(a.spec or {}) do
            for k, v in pairs(t) do t[k] = fn(v) end
        end
    end

    function PF.Rename(old, new)
        local n, err = PF.Valid(new)
        if not n then Print(err); return false end
        PF.S().profiles[n] = PF.S().profiles[old]
        PF.S().profiles[old] = nil
        if PF.S().cur == old then PF.S().cur = n end
        EachRule(function(v) if v == old then return n end return v end)
        return true
    end

    function PF.Delete(name)
        local names = PF.Names()
        if #names <= 1 or not PF.S().profiles[name] then return false end
        local wasActive = (PF.S().cur == name)
        PF.S().profiles[name] = nil
        EachRule(function(v) if v == name then return nil end return v end)
        if wasActive then
            PF.S().cur = nil          -- so the deleted one is not saved back
            for _, n in ipairs(names) do
                if n ~= name then PF.Load(n, false, true); break end
            end
        end
        return true
    end

    ------------------------------------------------------------------ spec / role
    -- the three talent trees of each class, used for the labels when the game doesn't hand the names over
    local TREE_NAMES = {
        WARRIOR = { "Arms", "Fury", "Protection" }, PALADIN = { "Holy", "Protection", "Retribution" },
        HUNTER = { "Beast Mastery", "Marksmanship", "Survival" }, ROGUE = { "Assassination", "Combat", "Subtlety" },
        PRIEST = { "Discipline", "Holy", "Shadow" }, SHAMAN = { "Elemental", "Enhancement", "Restoration" },
        MAGE = { "Arcane", "Fire", "Frost" }, WARLOCK = { "Affliction", "Demonology", "Destruction" },
        DRUID = { "Balance", "Feral Combat", "Restoration" },
    }
    function PF.Spec()
        local names, best, bi = {}, 0, nil
        if GetSpecialization and GetSpecializationInfo then
            local n = (GetNumSpecializations and GetNumSpecializations()) or 0
            for i = 1, n do
                local _, nm = GetSpecializationInfo(i)
                names[i] = nm
            end
            if #names > 0 then
                local s = GetSpecialization()
                if tonumber(s) and s > 0 then bi = s end
                return bi, names
            end
        end
        if GetNumTalentTabs and GetTalentTabInfo then
            for i = 1, (GetNumTalentTabs() or 0) do
                local a, b, c, _, e = GetTalentTabInfo(i)
                local nm, pts
                if type(a) == "string" then nm, pts = a, c else nm, pts = b, e end
                names[i] = nm or ("Spec " .. i)
                pts = tonumber(pts) or 0
                if pts > best then best, bi = pts, i end
            end
        end
        return bi, names
    end

    function PF.Role()
        if not UnitGroupRolesAssigned then return nil end
        if IsInGroup and not IsInGroup() then return nil end
        local ok, r = pcall(UnitGroupRolesAssigned, "player")
        if ok and (r == "TANK" or r == "HEALER" or r == "DAMAGER") then return r end
        return nil
    end

    function PF.ClassRules()
        local _, pc = UnitClass("player")
        PF.S().auto.spec[pc] = PF.S().auto.spec[pc] or {}
        return PF.S().auto.spec[pc]
    end

    function PF.Auto(force)
        if not NS.DB then return end
        PF.Ensure()
        if not PF.S().auto.on then return end
        local ok, spec = pcall(PF.Spec)
        if not ok then spec = nil end
        local role = PF.Role()
        local key = tostring(spec) .. ":" .. tostring(role)
        if not force and key == PF.lastKey then return end
        if InCombatLockdown and InCombatLockdown() then PF.pending = true; return end
        PF.lastKey = key
        local target = role and PF.S().auto.role[role]
        if not (target and PF.S().profiles[target]) then
            target = spec and PF.ClassRules()[spec]
        end
        if target and PF.S().profiles[target] and target ~= PF.S().cur then
            PF.Load(target, true)
        end
    end

    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_TALENT_UPDATE", "CHARACTER_POINTS_CHANGED",
        "ACTIVE_TALENT_GROUP_CHANGED", "PLAYER_SPECIALIZATION_CHANGED", "GROUP_ROSTER_UPDATE",
        "PLAYER_ROLES_ASSIGNED", "PLAYER_REGEN_ENABLED" }) do
        pcall(ev.RegisterEvent, ev, e)
    end
    ev:SetScript("OnEvent", function(_, e)
        if not NS.DB then return end
        if e == "PLAYER_REGEN_ENABLED" then
            if PF.pending then PF.pending = false; pcall(PF.Auto) end
        elseif C_Timer and C_Timer.After then
            C_Timer.After(e == "PLAYER_ENTERING_WORLD" and 4 or 1, function() pcall(PF.Auto, e == "PLAYER_ENTERING_WORLD") end)
        else
            pcall(PF.Auto)
        end
    end)

    ------------------------------------------------------------------ popups
    local function EB(self) return self.editBox or self.EditBox end
    StaticPopupDialogs["PROCGLOW_PROFILE_NAME"] = {
        text = "%s", button1 = "OK", button2 = "Cancel", hasEditBox = 1, maxLetters = 18,
        OnShow = function(self, data)
            local eb = EB(self)
            if eb then eb:SetText((data and data.default) or ""); eb:HighlightText(); eb:SetFocus() end
        end,
        OnAccept = function(self, data)
            local eb = EB(self)
            data = data or self.data
            if data and data.done and eb then data.done(eb:GetText()) end
        end,
        EditBoxOnEnterPressed = function(self)
            local p = self:GetParent()
            local data = p.data
            if data and data.done then data.done(self:GetText()) end
            p:Hide()
        end,
        EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
    StaticPopupDialogs["PROCGLOW_PROFILE_DELETE"] = {
        text = "Delete the profile \"%s\"? This cannot be undone.",
        button1 = "Delete", button2 = "Cancel",
        OnAccept = function(self, data)
            data = data or self.data
            if data and data.done then data.done() end
        end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }

    ------------------------------------------------------------------ page
    function TA.BuildProfilesPage(page)
        local head = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        TA.Acc(head, "fs")
        head:SetPoint("TOPLEFT", 16, -12)
        head:SetText("Profiles")
        local hint = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        hint:SetPoint("TOPLEFT", 16, -36)
        hint:SetWidth(500)
        hint:SetJustifyH("LEFT")
        hint:SetText("A profile is a saved set of all your ProcGlow settings (which abilities glow, text popups, icons, tracked buffs, positions and styles). Click a profile to switch to it. Changes you make are kept in the active profile. To make a new setup, press New profile first (it starts as a copy of what you have now), then change things.")

        local LIST_Y = 96
        local rows = {}
        for i = 1, PF.MAX do
            local r = CreateFrame("Frame", nil, page)
            r:SetSize(510, 24)
            r.bg = r:CreateTexture(nil, "BACKGROUND")
            r.bg:SetAllPoints()
            r.bg:SetColorTexture(1, 0.82, 0, 0.12)
            r.sel = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
            TA.Acc(r.sel, "btn")
            r.sel:SetSize(200, 22)
            r.sel:SetPoint("LEFT", 2, 0)
            r.sel:SetScript("OnClick", function() PF.Load(r.name); TA.ProfRefresh() end)
            r.tag = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            r.tag:SetPoint("LEFT", 212, 0)
            r.ren = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
            TA.Acc(r.ren, "btn")
            r.ren:SetSize(70, 22)
            r.ren:SetPoint("LEFT", 296, 0)
            r.ren:SetText("Rename")
            r.ren:SetScript("OnClick", function()
                StaticPopup_Show("PROCGLOW_PROFILE_NAME", "New name for this profile:", nil,
                    { default = r.name, done = function(t) if PF.Rename(r.name, t) then TA.ProfRefresh() end end })
            end)
            r.del = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
            TA.Acc(r.del, "btn")
            r.del:SetSize(70, 22)
            r.del:SetPoint("LEFT", 372, 0)
            r.del:SetText("Delete")
            r.del:SetScript("OnClick", function()
                StaticPopup_Show("PROCGLOW_PROFILE_DELETE", r.name, nil,
                    { done = function() PF.Delete(r.name); TA.ProfRefresh() end })
            end)
            r:Hide()
            rows[i] = r
        end

        local newBtn = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
        TA.Acc(newBtn, "btn")
        newBtn:SetSize(200, 22)
        newBtn:SetText("New profile (copy of current)")
        newBtn:SetScript("OnClick", function()
            StaticPopup_Show("PROCGLOW_PROFILE_NAME", "Name for the new profile:", nil,
                { default = "", done = function(t) if PF.Create(t) then TA.ProfRefresh() end end })
        end)
        Tip(newBtn, "New profile", "Saves a copy of your current settings under a new name and switches to it. Then change whatever you like: the profile you came from stays as it was.")

        local ac = CreateFrame("Frame", nil, page)
        ac:SetSize(520, 230)
        local F = NewForm(ac, 508, 0, 0)
        F:Section("Switch automatically")
        F:Tick("Switch profile by my spec or group role",
            function() return PF.S().auto and PF.S().auto.on end,
            function(v) PF.Ensure(); PF.S().auto.on = v and true or false; PF.lastKey = nil; if v then PF.Auto(true) end end, 0,
            "When your talent spec or your party / raid role changes, ProcGlow loads the profile you choose below. It waits until combat ends. You can still switch by hand at any time.")
        F:Row()

        local function Cycle(x, w, getv, setv)
            local b = F:Button("", w, nil, x, true)
            b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            local function paint()
                local v = getv()
                b:SetText((v and PF.S().profiles[v]) and v or "(no change)")
            end
            b:SetScript("OnClick", function(_, btn)
                PF.Ensure()
                local opts = { false }
                for _, nm in ipairs(PF.Names()) do opts[#opts + 1] = nm end
                local cv, idx = getv() or false, 1
                for i, o in ipairs(opts) do if o == cv then idx = i end end
                idx = idx + (btn == "RightButton" and -1 or 1)
                if idx > #opts then idx = 1 elseif idx < 1 then idx = #opts end
                setv(opts[idx] or nil)
                paint()
            end)
            Tip(b, "Profile to load", "Click to step through your profiles, right-click to go back. \"(no change)\" leaves the current profile alone.")
            F.refreshers[#F.refreshers + 1] = paint
            return b
        end

        local colA = ac:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        F:Pos(colA, 4, 4)
        colA:SetText("When I play this spec:")
        local colB = ac:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        F:Pos(colB, 274, 4)
        colB:SetText("When my group role is:")
        F:Row(24)

        local specLabels = {}
        local roleList = { { "TANK", "Tank" }, { "HEALER", "Healer" }, { "DAMAGER", "Damage" } }
        for i = 1, 3 do
            local sl = ac:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            sl:SetWidth(100)       -- wide enough for the longest tree name ("Assassination", "Beast Mastery")
            sl:SetJustifyH("LEFT")
            sl:SetWordWrap(false)
            F:Pos(sl, 4, 8)
            specLabels[i] = sl
            local b = Cycle(108, 150,
                function() PF.Ensure(); return PF.ClassRules()[i] end,
                function(v) PF.ClassRules()[i] = v; PF.lastKey = nil end)
            sl.btn = b
            local rl = ac:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            F:Pos(rl, 274, 8)
            rl:SetText(roleList[i][2])
            rl:SetWidth(80)
            rl:SetJustifyH("LEFT")
            local role = roleList[i][1]
            Cycle(352, 160,
                function() PF.Ensure(); return PF.S().auto.role[role] end,
                function(v) PF.S().auto.role[role] = v; PF.lastKey = nil end)
            F:Row(28)
        end
        F:Gap(4)
        F:Text("|cff999999A role rule wins while you are in a group with a role set; otherwise your spec decides. Spec rules are kept separately for each class. Tip: |cffffd100/pg profile <name>|r|cff999999 switches by hand, e.g. from a macro.|r")

        local function Layout()
            PF.Ensure()
            local names = PF.Names()
            local n = #names
            for i, r in ipairs(rows) do
                local nm = names[i]
                if nm then
                    r.name = nm
                    r:ClearAllPoints()
                    r:SetPoint("TOPLEFT", page, "TOPLEFT", 16, -(LIST_Y + (i - 1) * 26))
                    r.sel:SetText(nm)
                    local active = (nm == PF.S().cur)
                    r.bg:SetShown(active)
                    r.tag:SetText(active and "|cffffd100Active|r" or "")
                    r.del:SetEnabled(n > 1)
                    r:Show()
                else
                    r:Hide()
                end
            end
            newBtn:ClearAllPoints()
            newBtn:SetPoint("TOPLEFT", page, "TOPLEFT", 18, -(LIST_Y + n * 26 + 4))
            newBtn:SetEnabled(n < PF.MAX)
            ac:ClearAllPoints()
            ac:SetPoint("TOPLEFT", page, "TOPLEFT", 16, -(LIST_Y + n * 26 + 44))
            local _, snames = PF.Spec()
            local _, pcls = UnitClass("player")
            for i = 1, 3 do
                local nm = snames and snames[i]
                if type(nm) ~= "string" or nm == "" or nm:find("^Spec %d") then
                    nm = TREE_NAMES[pcls] and TREE_NAMES[pcls][i] or ("Spec " .. i)
                end
                specLabels[i]:SetText(nm)
                specLabels[i]:SetShown(true)
            end
        end

        TA.ProfRefresh = function() Layout(); F:Refresh() end
        return TA.ProfRefresh
    end
end
