local _, NS = ...
local ABILITY_DB, BUFFS, CC_BY_CLASS, CLASS_SPELLS, DEFAULT_BUFFS, DEFAULT_SPELLS = NS.ABILITY_DB, NS.BUFFS, NS.CC_BY_CLASS, NS.CLASS_SPELLS, NS.DEFAULT_BUFFS, NS.DEFAULT_SPELLS
local LOC, POPUP_ONLY, PREVIEW_SPELLS, PROC_SECONDS, Print, SHOUTS = NS.LOC, NS.POPUP_ONLY, NS.PREVIEW_SPELLS, NS.PROC_SECONDS, NS.Print, NS.SHOUTS
local SPELL_NOTES, SpellNameByID, buffExpire, buffInfo, buffProcs, learnedDuration = NS.SPELL_NOTES, NS.SpellNameByID, NS.buffExpire, NS.buffInfo, NS.buffProcs, NS.learnedDuration
local reactive = NS.reactive

-- On-screen reminders (text popups, icons, glows) must never catch the mouse: clicks, camera turns and hovering over
-- world objects (mining nodes, NPCs) all pass straight through. Several layers, because one alone was not enough.
local mousePending = {}
function NS.NoMouse(f)
    if not f then return end
    f:EnableMouse(false)
    -- the extra layers are protected functions on frames attached to action buttons: not allowed in combat,
    -- so they wait until combat ends
    if InCombatLockdown and InCombatLockdown() then mousePending[f] = true; return end
    mousePending[f] = nil
    if f.SetMouseClickEnabled then pcall(f.SetMouseClickEnabled, f, false) end
    if f.SetMouseMotionEnabled then pcall(f.SetMouseMotionEnabled, f, false) end
    if f.SetPassThroughButtons then pcall(f.SetPassThroughButtons, f, "LeftButton", "RightButton", "MiddleButton", "Button4", "Button5") end
    if f.SetHitRectInsets then pcall(f.SetHitRectInsets, f, 10000, 10000, 10000, 10000) end   -- nothing left to hover
end
-- only while a reminder is being moved (Unlock / Customise)
function NS.YesMouse(f)
    if not f then return end
    mousePending[f] = nil
    f:EnableMouse(true)
    if InCombatLockdown and InCombatLockdown() then return end
    if f.SetHitRectInsets then pcall(f.SetHitRectInsets, f, 0, 0, 0, 0) end
    if f.SetPassThroughButtons then pcall(f.SetPassThroughButtons, f) end
    if f.SetMouseClickEnabled then pcall(f.SetMouseClickEnabled, f, true) end
    if f.SetMouseMotionEnabled then pcall(f.SetMouseMotionEnabled, f, true) end
end
local mouseEv = CreateFrame("Frame")
mouseEv:RegisterEvent("PLAYER_REGEN_ENABLED")
mouseEv:SetScript("OnEvent", function()
    for f in pairs(mousePending) do mousePending[f] = nil; NS.NoMouse(f) end
end)

---------------------------------------------------------------------------
-- Proc tracking that works in any stance (combat log based)
---------------------------------------------------------------------------
local WINDOW_SECONDS = 5
local OUT_DODGE = { "overpower", "mongoose bite" }   -- opened when YOUR attack is dodged
local LOW_HEALTH = { ["execute"] = 0.2, ["hammer of wrath"] = 0.2 }
-- abilities that only work on certain kinds of target: creature type ids (the same in every language)
BUFFS.targetType = { ["exorcism"] = { [3] = true, [6] = true } }   -- 3 = Demon, 6 = Undead
local procWindow = {}
NS.procWindow = procWindow   -- spell -> { expires =, guid = }


-- abilities that light up after a dodge / parry / block: once you have used one, it should stay dark until
-- the next dodge or parry opens a new window (the game may still call it "usable" while it recharges)
BUFFS.windowed = { ["riposte"] = true, ["counterattack"] = true, ["revenge"] = true, ["overpower"] = true,
    ["mongoose bite"] = true }
BUFFS.used = {}
local function OpenWindow(name, guid)
    BUFFS.used[name] = nil
    procWindow[name] = { expires = GetTime() + WINDOW_SECONDS, guid = guid }
    if NS.debugOn then Print("proc window opened: " .. name) end
end

local function SameTarget(guid)
    local ok, cur = pcall(UnitGUID, "target")
    if not ok or (issecretvalue and issecretvalue(cur)) then return true end
    return cur == guid
end

local function WindowActive(name)
    local w = procWindow[name]
    if not w then return false end
    if w.expires < GetTime() then procWindow[name] = nil; return false end
    if w.guid and not SameTarget(w.guid) then return false end
    return true
end
NS.WindowActive = WindowActive

---------------------------------------------------------------------------
-- Localisation tools: /pg locale (what is going on) and /pg scanids (builds the spell ID table)
---------------------------------------------------------------------------
-- every English name this addon knows about (the names the ID table has to cover)
function LOC.AllKeys()
    local set = {}
    -- (internal labels such as "pal_aura" or "next attack" are not spell names)
    local function add(n)
        if type(n) == "string" and n ~= "" and not n:find("[_/]") and not n:find("^next ") then set[n:lower()] = true end
    end
    local function addList(l) for _, n in ipairs(l or {}) do add(n) end end
    addList(DEFAULT_SPELLS)
    for b, sp in pairs(DEFAULT_BUFFS) do add(b); add(sp) end
    for _, v in pairs(CC_BY_CLASS) do add(v) end
    for k in pairs(POPUP_ONLY) do add(k) end
    for _, l in pairs(CLASS_SPELLS) do addList(l) end
    for k, v in pairs(SPELL_NOTES) do add(k); add(v) end
    for _, l in pairs(ABILITY_DB) do addList(l) end
    for _, l in pairs(PREVIEW_SPELLS) do addList(l) end
    for _, l in pairs(BUFFS.racials) do for _, e in ipairs(l) do add(e[1]) end end
    for _, l in pairs(BUFFS.list) do for _, e in ipairs(l) do add(e[1]) end end
    for k, d in pairs(BUFFS.tracked) do
        add(k); add(d.name)
        for _, a in ipairs(d.auras) do add(a) end
    end
    for k in pairs(SHOUTS) do add(k) end
    for k in pairs(BUFFS.imbueKey) do add(k) end
    for k, d in pairs(BUFFS.cpBuffs) do add(k); add(d.talent) end
    for k in pairs(BUFFS.windowed) do add(k) end
    for k in pairs(LOW_HEALTH) do add(k) end
    for k in pairs(BUFFS.targetType) do add(k) end
    addList(OUT_DODGE)
    -- plus whatever this account has set up or seen on its own characters
    if NS.DB then
        for _, t in pairs({ NS.DB.watch, NS.DB.alerts, NS.DB.icons, NS.DB.added, NS.DB.buffs }) do
            for k in pairs(t) do if type(k) == "string" then add(k) end end
        end
        for _, t in pairs(NS.DB.seen or {}) do
            for k in pairs(t) do if type(k) == "string" then add(k) end end
        end
    end
    return set
end

-- a window with text to copy (Ctrl+A, Ctrl+C)
function LOC.ShowText(text)
    local f = LOC.box
    if not f then
        f = CreateFrame("Frame", "ProcGlowLocBox", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
        tinsert(UISpecialFrames, "ProcGlowLocBox")
        f:SetSize(640, 440); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG")
        f:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 14, insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
        local lab = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lab:SetPoint("TOPLEFT", 14, -12)
        lab:SetText("ProcGlow: click in the box, press Ctrl+A then Ctrl+C to copy all of it")
        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", 2, 2)
        local sf = CreateFrame("ScrollFrame", "ProcGlowLocScroll", f, "UIPanelScrollFrameTemplate")
        sf:SetPoint("TOPLEFT", 14, -36); sf:SetPoint("BOTTOMRIGHT", -34, 14)
        local eb = CreateFrame("EditBox", nil, sf)
        eb:SetMultiLine(true); eb:SetAutoFocus(false); eb:SetFontObject("ChatFontNormal")
        eb:SetWidth(580); eb:SetMaxLetters(0)
        eb:SetScript("OnEscapePressed", function() f:Hide() end)
        sf:SetScrollChild(eb)
        f.eb = eb
        LOC.box = f
    end
    f.eb:SetText(text)
    f.eb:SetCursorPosition(0)
    f:Show()
end

-- Scans every spell ID the client has and keeps the ones whose name is one of ours. Run it ONCE on an
-- English client: the result is the table that lets every other language find its own spell names.
function LOC.Scan()
    if LOC.scanning then Print("a scan is already running"); return end
    if LOC.locale and LOC.locale ~= "enUS" then
        Print("run this on an ENGLISH client: the table has to be built from the English spell names")
        return
    end
    local keys = LOC.AllKeys()
    local nkeys = 0
    for _ in pairs(keys) do nkeys = nkeys + 1 end
    local found, total = {}, 0
    local MAXID, PER, KEEP = 1500000, 25000, 14
    local id = 0
    LOC.scanning = true
    LOC.scanFrame = LOC.scanFrame or CreateFrame("Frame")
    Print("scanning spell IDs for " .. nkeys .. " names, this takes a few seconds...")
    LOC.scanFrame:SetScript("OnUpdate", function(self)
        local last = math.min(id + PER, MAXID)
        for i = id + 1, last do
            local n = LOC.RawName(i)
            if n then
                local low = n:lower()
                if keys[low] then
                    local t = found[low]
                    if not t then t = {}; found[low] = t end
                    t.n = (t.n or 0) + 1
                    if #t < KEEP then t[#t + 1] = i end
                end
            end
        end
        id = last
        if id < MAXID then return end
        self:SetScript("OnUpdate", nil)
        LOC.scanning = false
        local names, missing = {}, {}
        for k in pairs(found) do names[#names + 1] = k end
        table.sort(names)
        for k in pairs(keys) do if not found[k] then missing[#missing + 1] = k end end
        table.sort(missing)
        local build = "?"
        if GetBuildInfo then
            local okb, v, b = pcall(GetBuildInfo)
            if okb then build = tostring(v) .. " (" .. tostring(b) .. ")" end
        end
        local out = { "-- ProcGlow spell ID table, scanned on a " .. tostring(LOC.locale) .. " client, build " ..
            build .. ", " .. #names .. " of " .. nkeys .. " names found",
            "ProcGlowIDs = {" }
        for _, k in ipairs(names) do
            local t = found[k]
            total = total + #t
            out[#out + 1] = string.format("[%q]={%s},%s", k, table.concat(t, ","), (t.n or 0) > #t and (" -- " .. t.n .. " ids in all") or "")
        end
        out[#out + 1] = "}"
        -- does the game hide each buff while you are in combat? (per spell, from the game itself)
        if C_Secrets and C_Secrets.GetSpellAuraSecrecy then
            local levelName = {}
            if Enum and type(Enum.SecrecyLevel) == "table" then
                for nm, v in pairs(Enum.SecrecyLevel) do levelName[v] = nm end
            end
            out[#out + 1] = "ProcGlowSecrecy = {"
            for _, k in ipairs(names) do
                local seen, parts = {}, {}
                for _, sid in ipairs(found[k]) do
                    local okS, lv = pcall(C_Secrets.GetSpellAuraSecrecy, sid)
                    if okS and lv ~= nil then
                        local ln = levelName[lv] or tostring(lv)
                        if not seen[ln] then seen[ln] = true; parts[#parts + 1] = ln end
                    end
                end
                if #parts > 0 then out[#out + 1] = string.format("[%q]=%q,", k, table.concat(parts, "/")) end
            end
            out[#out + 1] = "}"
        else
            out[#out + 1] = "-- (this client has no per-spell secrecy check)"
        end
        -- spell IDs another Forever addon (SpellActivationOverlay) uses: what does this client call them?
        local ref = {}
        for _, rid in ipairs({ 14251, 19306, 7384, 5308, 6572, 402927, 24275, 20473, 879, 16870, 16886, 12536, 16246,
            462707, 462708, 17941, 27828, 48108, 48107, 44544, 44401, 57761 }) do
            ref[#ref + 1] = rid .. "=" .. tostring((LOC.RawName(rid)))
        end
        out[#out + 1] = "-- reference ids: " .. table.concat(ref, "; ")
        out[#out + 1] = "-- not found (" .. #missing .. "): " .. table.concat(missing, "; ")
        local text = table.concat(out, "\n")
        if NS.DB then NS.DB.idscanText = text end
        Print("scan finished: " .. #names .. " of " .. nkeys .. " names found (" .. total .. " ids). Copy the window that just opened and send it to Claude.")
        LOC.ShowText(text)
    end)
end

-- /pg locale: how the language support is doing on this client
function LOC.Report()
    local ids = type(ProcGlowIDs) == "table" and ProcGlowIDs or {}
    local n = 0
    for _ in pairs(ids) do n = n + 1 end
    Print("client language: " .. tostring(LOC.locale) .. ", translation " .. (LOC.on and "ON" or "off (English client)") ..
        (NS.DB and NS.DB.locForce and " (forced on)" or ""))
    Print("spell ID table: " .. n .. " names; " .. LOC.nres .. " of them found in this client's own language")
    if LOC.on then
        local cf = 0
        for _ in pairs(LOC.conf) do cf = cf + 1 end
        local miss = {}
        for k in pairs(LOC.AllKeys()) do
            if not LOC.k2l[k] and (BUFFS.tracked[k] or reactive[k] or buffProcs[k]) then miss[#miss + 1] = k end
        end
        table.sort(miss)
        Print(cf .. " name clashes. Names with no match in your language" .. " (" .. #miss .. "): " ..
            (#miss > 0 and table.concat(miss, ", ") or "none"))
        local sample = {}
        for _, k in ipairs({ "slice and dice", "execute", "overpower", "battle shout", "power word: fortitude" }) do
            if LOC.k2l[k] then sample[#sample + 1] = k .. " = " .. LOC.k2l[k] end
        end
        if #sample > 0 then Print("examples: " .. table.concat(sample, "; ")) end
    end
end

local SHOUT_DURATION = 120   -- assumed length when we cast a shout but can't read the aura

-- UNIT_COMBAT based tracking: used alongside / instead of the combat log
local function OnUnitCombat(unit, action)
    if type(action) ~= "string" then return end
    if issecretvalue and (issecretvalue(unit) or issecretvalue(action)) then return end
    if NS.debugOn and (action == "DODGE" or action == "PARRY" or action == "BLOCK" or action == "MISS") then
        Print("combat event: " .. tostring(unit) .. " " .. action)
    end
    if unit == "player" then
        if action == "DODGE" or action == "PARRY" or action == "BLOCK" then OpenWindow("revenge") end
        if action == "PARRY" then
            OpenWindow("riposte"); OpenWindow("counterattack")
        end
    elseif unit == "target" then
        if action == "DODGE" then
            for _, n in ipairs(OUT_DODGE) do OpenWindow(n, nil) end
        end
    end
end
NS.OnUnitCombat = OnUnitCombat

-- who a cast was aimed at (UNIT_SPELLCAST_SENT gives the target's name), so a buff cast on a party member is not
-- mistaken for one on you
BUFFS.sent = {}
function NS.OnPlayerSent(target, spellID)
    if type(spellID) ~= "number" or (issecretvalue and (issecretvalue(spellID) or issecretvalue(target))) then return end
    BUFFS.sent[spellID] = { name = (type(target) == "string") and target or "", t = GetTime() }
end
function BUFFS.LandedOnMe(spellID, n, key)
    if n ~= key then return true end          -- the group version ("Prayer of ...", "Greater Blessing of ...") includes you
    local sn = spellID and BUFFS.sent[spellID]
    if sn and GetTime() - sn.t < 5 then
        local tn = sn.name
        if tn == "" then return true end       -- no target: it went on you
        local me = UnitName("player")
        if type(me) == "string" and (tn == me or tn:sub(1, #me + 1) == me .. "-") then return true end
        -- a hostile target: the game casts a friendly buff on you instead
        return UnitExists("target") and UnitCanAttack("player", "target") and true or false
    end
    -- no record of where it was aimed: judge by your target
    if not UnitExists("target") or UnitIsUnit("target", "player") then return true end
    return UnitCanAttack("player", "target") and true or false
end

function BUFFS.NotedCast(key)
    local bi = buffInfo[key]
    if not (bi and bi.t) then return nil end
    local left = (bi.expires and bi.expires > 0) and string.format("%.0fs left", bi.expires - GetTime()) or "no timer"
    return string.format("cast %.0fs ago, %s", GetTime() - bi.t, left)
end

-- our own successful casts: close proc windows, note fresh shouts
local function OnPlayerCast(spellID)
    local n = SpellNameByID(spellID)
    if type(n) ~= "string" then return end
    if issecretvalue and issecretvalue(n) then return end
    n = n:lower()
    procWindow[n] = nil
    -- a stacking effect the game hides in combat (Arcane Blast): every cast adds a stack and renews its timer
    local cs = BUFFS.castStack[n]
    if cs then
        -- counted whether or not the game still shows us the auras: a cast that starts the fight lands in the gap
        -- before we know combat began. The length is that of the first stack (later casts do not renew it).
        local now = GetTime()
        local live = buffExpire[n] and buffExpire[n] > now
        BUFFS.stack[n] = math.min(cs.max, (live and BUFFS.stack[n] or 0) + 1)
        if not live then buffExpire[n] = now + cs.dur end
        BUFFS.procLive[n] = buffExpire[n]
        BUFFS.castKeep[n] = { t = now, stack = BUFFS.stack[n], exp = buffExpire[n] }
    end
    if NS.IC and NS.DB and NS.DB.watch and NS.DB.watch[n] then NS.IC.castAt[n] = GetTime() end
    if BUFFS.imbueKey[n] then BUFFS.imbCast = { name = n, t = GetTime() } end
    if BUFFS.windowed[n] then BUFFS.used[n] = GetTime() end
    if n:find("^seal of ") then
        -- only one seal at a time: the new one replaces the old
        for k in pairs(BUFFS.cache) do if k:find("^seal of ") then BUFFS.cache[k] = nil end end
        BUFFS.cache[n] = { expires = GetTime() + (BUFFS.learnedDur[n] or 30) }
    elseif NS.DB and NS.DB.watch and NS.DB.watch[n] and not BUFFS.imbueKey[n] then
        -- a buff you track: assume the cast refreshed it to the length it had last time (no timer if never seen)
        local d = BUFFS.learnedDur[n] or BUFFS.defDur[n]
        local cp = (BUFFS.cpLast and BUFFS.cpT and GetTime() - BUFFS.cpT < 1.5) and BUFFS.cpLast or nil
        if cp then
            BUFFS.castCP[n] = { cp = cp, t = GetTime() }
            d = BUFFS.CPDuration(n, cp) or d
        end
        if d then BUFFS.cache[n] = { expires = GetTime() + d }
        else BUFFS.cache[n] = { expires = GetTime() + 30, guess = true } end   -- length unknown: show it, without a timer, for a while
    end
    local key = BUFFS.auraOf[n] or n          -- "Prayer of Fortitude" counts for Power Word: Fortitude
    local td = BUFFS.tracked[key]
    if td then
        -- a cast that lands on you is noted straight away: while the game hides your buffs (combat, battlegrounds)
        -- this is the only way to know it is on you. A cast on someone else is not noted.
        if td.self or BUFFS.LandedOnMe(spellID, n, key) then
            local dur = learnedDuration[n] or learnedDuration[key] or td.dur
            buffInfo[key] = { mine = true, t = GetTime(), expires = (dur and dur > 0) and (GetTime() + dur) or 0 }
            if td.group then
                for _, m in ipairs(BUFFS.members[td.group]) do
                    if m ~= key then
                        for _, a in ipairs(BUFFS.tracked[m].auras) do
                            if buffInfo[a] and buffInfo[a].mine then buffInfo[a] = nil end
                        end
                    end
                end
            end
        end
    elseif SHOUTS[n] then
        buffInfo[n] = { mine = true, expires = GetTime() + (learnedDuration[n] or SHOUT_DURATION) }
    end
end
NS.OnPlayerCast = OnPlayerCast

function BUFFS.TargetIsType(types)
    if not UnitExists("target") or UnitIsDead("target") or not UnitCanAttack("player", "target") then return false end
    if not UnitCreatureType then return false end
    local _, id = UnitCreatureType("target")
    if type(id) ~= "number" or (issecretvalue and issecretvalue(id)) then return false end   -- hidden (e.g. in a dungeon)
    return types[id] and true or false
end

local function TargetBelow(th)
    if not UnitExists("target") or UnitIsDead("target") or not UnitCanAttack("player", "target") then return false end
    local max = UnitHealthMax("target")
    if not max or max == 0 then return false end
    return UnitHealth("target") / max <= th
end

-- Is this ability's proc condition met, regardless of stance/usability?
-- Battle Shout / Commanding Shout: low on time, and only if YOU cast the active one
local OTHER_SHOUT = { ["battle shout"] = "commanding shout", ["commanding shout"] = "battle shout" }

-- What do we believe about a shout right now?
--   table = it is on me, nil = it is not on me, false = we can't tell
-- While buff data is hidden (combat), we use the last readable state, our own casts,
-- and the expiry time we saw before it was hidden.
local function LiveInfo(name)
    local info = buffInfo[name]
    if info then
        if info.unknown then return false end
        if NS.auraRestricted and info.expires > 0 and info.expires < GetTime() then
            if info.mine then return nil end   -- our own shout ran out
            return false                       -- someone else's: may have been refreshed unseen
        end
        return info
    end
    if NS.auraRestricted and not NS.haveGoodRead then
        -- reloaded while the game was already hiding buffs: in a battleground the casts we see are all we have, so no
        -- note of a buff means it is not on you; elsewhere we cannot tell
        if NS.InBG() then return nil end
        return false
    end
    return nil
end

-- (mine, other) for a tracked buff, or false when we cannot tell right now
function BUFFS.Info(name)
    local def = BUFFS.tracked[name]
    local mine, other
    for _, a in ipairs(def.auras) do
        local i = LiveInfo(a)
        if i == false then return false end
        if i then
            if i.mine then mine = mine or i else other = other or i end
        end
    end
    return mine, other
end

-- which member of each tracked group we are currently watching:
-- the one you last cast (so a swap is respected), falling back to your choice
-- after LINGER seconds without any of your buffs from that group
function BUFFS.Update()
    local t = NS.DB.track
    if not t then return end
    local now = GetTime()
    local _, pc = UnitClass("player")
    for g, gi in pairs(BUFFS.groups) do
        if t.groupOn[g] and gi.class == pc then
            local sel = BUFFS.Selected(g)
            local st = BUFFS.state[g]
            if not st then st = {}; BUFFS.state[g] = st end
            local mineName, unknown
            for _, m in ipairs(BUFFS.members[g]) do
                local mine = BUFFS.Info(m)
                if mine == false then unknown = true; break end
                if mine then mineName = m; break end
            end
            if st.sel ~= sel then
                st.sel = sel
                if not mineName then st.cur = sel end
            end
            if not unknown then
                if mineName then
                    st.cur = mineName; st.last = now
                elseif not st.cur or st.cur == sel then
                    st.cur = sel
                elseif now - (st.last or 0) >= (t.linger and t.linger[g] or BUFFS.LINGER) then
                    st.cur = sel
                end
            end
        end
    end
end

-- is this buff on me, and how long is left? While combat hides the auras this falls back to the
-- last readable state plus our own casts. Returns present, seconds left (or nil), stack count.
function BUFFS.Presence(name, buffs)
    local now = GetTime()
    if BUFFS.imbueKey[name] then
        local left = BUFFS.imb[name]
        if left then return true, left end
        return false
    end
    if not NS.auraRestricted then
        if not buffs[name] then return false end
        local e = buffExpire[name]
        return true, (e and e > now) and (e - now) or nil, BUFFS.stack[name]
    end
    local c = BUFFS.cache[name]
    if c and (c.expires == 0 or c.expires > now) then
        return true, (c.expires > 0 and not c.guess) and (c.expires - now) or nil, c.count
    end
    return false
end

-- a buff added with "Track a buff/cooldown" can be set to show when it is MISSING (for example Find Minerals).
-- Only judged while the game lets us read our own buffs, so a hidden aura in combat never looks like a missing one
-- gathering tracking is only ever wanted as a reminder for when it is missing, so these always work that way
BUFFS.missingOnly = { ["find minerals"] = true, ["find herbs"] = true, ["find treasure"] = true, ["find fish"] = true }
function BUFFS.MissingMode(spell)
    return (BUFFS.missingOnly[spell] or (NS.DB.missing and NS.DB.missing[spell])) and true or false
end
function BUFFS.WatchMissing(spell, buffs)
    if not BUFFS.MissingMode(spell) then return false end
    if not (NS.haveGoodRead and not NS.auraRestricted) then return false end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return false end
    if UnitOnTaxi and UnitOnTaxi("player") then return false end
    if not BUFFS.Known(spell) then return false end    -- you do not have this spell, nothing to remind you of
    local here = BUFFS.Presence(spell, buffs)
    return not here
end
function BUFFS.WatchShown(spell, buffs)
    if BUFFS.MissingMode(spell) then return BUFFS.WatchMissing(spell, buffs) end
    local here = BUFFS.Presence(spell, buffs)
    return here and true or false
end

-- Righteous Fury can be limited to when you are the tank of a party or raid
function BUFFS.RFOK()
    if not (NS.DB.track and NS.DB.track.rfTank) then return true end
    if not (IsInGroup and IsInGroup()) then return false end
    if not UnitGroupRolesAssigned then return true end
    local ok, role = pcall(UnitGroupRolesAssigned, "player")
    return ok and role == "TANK"
end

function BUFFS.Low(name)
    local def = BUFFS.tracked[name]
    local t = NS.DB.track
    if not def or not t then return false end
    local _, pc = UnitClass("player")
    if def.class ~= pc then return false end    -- tracking only works for your own class
    if not BUFFS.Known(def.name or name) then return false end   -- not trained yet
    if name == "righteous fury" and not BUFFS.RFOK() then return false end
    if def.group then
        if not t.groupOn[def.group] then return false end
        local st = BUFFS.state[def.group]
        if not st or st.cur ~= name then return false end
    elseif not t.on[name] then
        return false
    end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return false end
    if t.hideResting and ((IsResting and IsResting()) or (UnitOnTaxi and UnitOnTaxi("player"))) then return false end
    local mine, other = BUFFS.Info(name)
    if mine == false then return false end
    if mine then
        if not mine.expires or mine.expires == 0 then return false end   -- no timer (auras, aspects)
        local th = t.th[def.group or name] or def.th or 0
        return th > 0 and (mine.expires - GetTime()) <= th
    end
    if other then return false end    -- someone else's copy is on you: wait until it falls off
    return t.glowMissing ~= false
end

local function ShoutLow(name)
    if BUFFS.tracked[name] then return BUFFS.Low(name) end
    local s = NS.DB.shout

    -- no shout glows in towns / inns or on a flight path
    if s.hideResting and ((IsResting and IsResting()) or (UnitOnTaxi and UnitOnTaxi("player"))) then
        return false
    end

    local info = LiveInfo(name)
    if info == false then return false end
    if info == nil then
        -- this shout is not on me
        if not s.glowMissing then return false end
        local other = LiveInfo(OTHER_SHOUT[name])
        if other == false then return false end
        if other then
            -- the other shout is on me: only fill the gap if it is someone else's
            return not other.mine
        end
        -- neither shout is on me: only the preferred one glows
        return s.preferred == name
    end

    if not info.mine or info.expires == 0 then return false end
    return (info.expires - GetTime()) <= s.threshold
end
NS.ShoutLow = ShoutLow

local glowStart = {}
NS.glowStart = glowStart   -- spell -> time its proc was first seen glowing

-- seconds left to use a proc, or nil when unknown
local function ProcRemaining(name, buffs)
    local now = GetTime()
    if BUFFS.groups[name] then
        local st = BUFFS.state[name]
        return st and st.cur and ProcRemaining(st.cur, buffs) or nil
    end
    if BUFFS.tracked[name] then
        local mine = BUFFS.Info(name)
        if mine and mine.expires and mine.expires > now then return mine.expires - now end
        return nil
    end
    if SHOUTS[name] then
        local info = buffInfo[name]
        if info and info.mine and info.expires and info.expires > now then return info.expires - now end
        return nil
    end
    for buff, spell in pairs(buffProcs) do
        if spell == name and buffs[buff] and buffExpire[buff] then
            local r = buffExpire[buff] - now
            if r > 0 then return r end
        end
    end
    local w = procWindow[name]
    if w and w.expires > now then return w.expires - now end
    local dur = NS.DB.procTime and NS.DB.procTime[name]
    if dur == nil then dur = PROC_SECONDS[name] end
    if dur and dur > 0 and glowStart[name] then
        local r = dur - (now - glowStart[name])
        if r > 0 then return r end
    end
    return nil
end
NS.ProcRemaining = ProcRemaining

local function ProcActive(name, buffs)
    if BUFFS.groups[name] then
        for _, m in ipairs(BUFFS.members[name]) do
            if BUFFS.Low(m) then return true end
        end
        return false
    end
    if SHOUTS[name] then return ShoutLow(name) end
    if WindowActive(name) then return true end
    local th = LOW_HEALTH[name]
    if th then
        local okh, low = pcall(TargetBelow, th)
        if okh and low then return true end
    end
    local tt = BUFFS.targetType[name]
    if tt then
        local okt, yes = pcall(BUFFS.TargetIsType, tt)
        if okt and yes then return true end
    end
    for buff, spell in pairs(buffProcs) do
        if spell == name and buffs[buff] then return true end
    end
    return false
end
NS.ProcActive = ProcActive
