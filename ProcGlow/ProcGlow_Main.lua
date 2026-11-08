local _, NS = ...
local BUFFS, BuildButtons, CreateMinimapButton, CurrentForm, DebugBuffs, IsOverlayed = NS.BUFFS, NS.BuildButtons, NS.CreateMinimapButton, NS.CurrentForm, NS.DebugBuffs, NS.IsOverlayed
local LOC, LoadLists, MacroSpellName, OffCooldown, OnPlayerCast, OnUnitCombat = NS.LOC, NS.LoadLists, NS.MacroSpellName, NS.OffCooldown, NS.OnPlayerCast, NS.OnUnitCombat
local OpenSettings, PG, PlayerBuffs, Print, RegisterBlizzardPanel, ResolveSlot = NS.OpenSettings, NS.PG, NS.PlayerBuffs, NS.Print, NS.RegisterBlizzardPanel, NS.ResolveSlot
local SHOUTS, STYLE_DEFAULTS, ShouldGlow, ShoutLow, SlotOf, SpellIcon = NS.SHOUTS, NS.STYLE_DEFAULTS, NS.ShouldGlow, NS.ShoutLow, NS.SlotOf, NS.SpellIcon
local SpellNameByID, TA, TEXT_DEFAULTS, Tick, ToggleWindow, WindowActive = NS.SpellNameByID, NS.TA, NS.TEXT_DEFAULTS, NS.Tick, NS.ToggleWindow, NS.WindowActive
local buffInfo, buffProcs, buttons, iconCache, learnedDuration, procWindow = NS.buffInfo, NS.buffProcs, NS.buttons, NS.iconCache, NS.learnedDuration, NS.procWindow
local reactive = NS.reactive

---------------------------------------------------------------------------
-- Setup / events
---------------------------------------------------------------------------
local elapsed = 0
PG:SetScript("OnUpdate", function(_, dt)
    if not NS.DB then return end
    elapsed = elapsed + dt
    -- 20 times a second in a fight, 10 times a second otherwise (a glow showing 50 ms later is not noticeable out of combat)
    if elapsed < ((InCombatLockdown and InCombatLockdown()) and 0.05 or 0.1) then return end
    elapsed = 0
    pcall(Tick)
    if NS.debugOn then pcall(DebugBuffs) end
end)

PG:RegisterEvent("PLAYER_LOGIN")
PG:RegisterEvent("PLAYER_ENTERING_WORLD")
PG:RegisterEvent("PLAYER_DEAD")
pcall(PG.RegisterEvent, PG, "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")

pcall(PG.RegisterEvent, PG, "SPELLS_CHANGED")
pcall(PG.RegisterEvent, PG, "LEARNED_SPELL_IN_TAB")
PG:SetScript("OnEvent", function(_, event, arg1, arg2, arg3)
    if event == "SPELLS_CHANGED" or event == "LEARNED_SPELL_IN_TAB" then wipe(BUFFS.kc); return end
    if event == "PLAYER_LOGIN" then
        ProcGlowDB = ProcGlowDB or {}
        NS.DB = ProcGlowDB
        NS.DB.added = NS.DB.added or {}
        NS.DB.removed = NS.DB.removed or {}
        NS.DB.buffs = NS.DB.buffs or {}
        NS.DB.disabled = NS.DB.disabled or {}
        NS.DB.redirect = NS.DB.redirect or {}
        NS.DB.redirectCond = NS.DB.redirectCond or {}
        NS.DB.procTime = NS.DB.procTime or {}
        NS.DB.icons = NS.DB.icons or {}
        NS.DB.alerts = NS.DB.alerts or {}
        for _, a in pairs(NS.DB.alerts) do if a.timer == true then a.timer = nil end end   -- "on" is now the default
        NS.DB.textStyle = NS.DB.textStyle or {}
        for k, v in pairs(TEXT_DEFAULTS) do
            if NS.DB.textStyle[k] == nil then NS.DB.textStyle[k] = v end
        end
        -- the "Track a buff" suggestions used to include other players' buffs on you: start that list again, from your own buffs only
        if not NS.DB.seenMineOnly then NS.DB.seen = {}; NS.DB.seenMineOnly = true end
        -- Fear Ward is now a class buff with its own glow option: drop a copy added by hand under "Track a buff"
        if NS.DB.watch and NS.BUFFS.tracked["fear ward"] then NS.DB.watch["fear ward"] = nil end
        -- window sizes are reset once (the default window scale changed), so everyone starts from the new default
        if not NS.DB.winScaleReset then NS.DB.winScale = nil; NS.DB.winScaleReset = true end
        -- the countdown on text popups is off for everyone (see TA.COUNTDOWN): clear any saved "on" once, in the live settings and in every saved profile
        if not NS.DB.countdownOff then
            local function Off(t)
                if type(t) ~= "table" then return end
                if type(t.textStyle) == "table" then t.textStyle.timer = false end
                if type(t.alerts) == "table" then for _, a in pairs(t.alerts) do if type(a) == "table" then a.timer = nil end end end
            end
            Off(NS.DB)
            for _, p in pairs(NS.DB.profiles or {}) do Off(p) end
            for _, c in pairs(NS.DB.chars or {}) do
                for _, p in pairs(type(c) == "table" and c.profiles or {}) do Off(p) end
            end
            NS.DB.countdownOff = true
        end
        local ts = NS.DB.textStyle
        if type(ts.borderCol) ~= "table" then ts.borderCol = { r = ts.r, g = ts.g, b = ts.b } end
        if type(ts.outlineCol) ~= "table" then ts.outlineCol = { r = 0, g = 0, b = 0 } end
        if type(ts.bgCol) ~= "table" then ts.bgCol = { r = 0, g = 0, b = 0 } end
        NS.DB.customClass = NS.DB.customClass or {}
        NS.DB.watch = NS.DB.watch or {}
        NS.DB.missing = NS.DB.missing or {}
        NS.DB.learned = NS.DB.learned or {}
        NS.DB.seen = NS.DB.seen or {}
        LOC.Init()                             -- non-English client: set up the name <-> spell ID translation
        BUFFS.learnedDur = NS.DB.learned          -- buff lengths seen before, so the first fight after a login works too
        for k, v in pairs(NS.DB.learned) do learnedDuration[k] = v end
        NS.DB.minimap = NS.DB.minimap or {}
        if NS.DB.minimap.angle == nil then NS.DB.minimap.angle = 215 end
        if NS.DB.enabled == nil then NS.DB.enabled = true end
        NS.DB.shout = NS.DB.shout or {}
        NS.DB.track = NS.DB.track or {}
        NS.DB.track.on = NS.DB.track.on or {}
        NS.DB.track.groupOn = NS.DB.track.groupOn or {}
        NS.DB.track.sel = NS.DB.track.sel or {}
        NS.DB.track.th = NS.DB.track.th or {}
        NS.DB.track.linger = NS.DB.track.linger or {}
        if NS.DB.track.glowMissing == nil then NS.DB.track.glowMissing = true end
        if NS.DB.track.hideResting == nil then NS.DB.track.hideResting = true end
        if NS.DB.shout.threshold == nil then NS.DB.shout.threshold = 10 end
        if NS.DB.shout.glowMissing == nil then NS.DB.shout.glowMissing = true end
        if NS.DB.shout.hideResting == nil then NS.DB.shout.hideResting = true end
        if NS.DB.shout.ignoreRage == nil then NS.DB.shout.ignoreRage = true end
        NS.DB.shout.preferred = "battle shout"     -- Commanding Shout does not exist in WoW Forever
        NS.DB.style = NS.DB.style or {}
        -- migrate the old "pick one style" setting to the layer switches
        local old = NS.DB.style.style
        if old ~= nil then
            local st = NS.DB.style
            st.haloOn = (old == "glow" or old == "proc")
            st.highlightOn = (old == "highlight")
            st.outlineOn = (old == "outline")
            st.fillOn = (old == "fill")
            st.burstOn = (old == "burst")
            st.antsOn = (old == "ants" or old == "proc")
            st.blizzardOn = (old == "blizzard")
            st.style = nil
        end
        for k, v in pairs(STYLE_DEFAULTS) do
            if NS.DB.style[k] == nil then NS.DB.style[k] = v end
        end
        if not NS.DB.style.fillV2 then      -- fill now uses a plain tint; reset its old (very faint) value
            NS.DB.style.fillV2 = true
            NS.DB.style.fillAlpha = STYLE_DEFAULTS.fillAlpha
        end
        NS.playerGUID = UnitGUID("player")
        LoadLists()
        BuildButtons()
        pcall(RegisterBlizzardPanel)
        pcall(CreateMinimapButton)
        -- the combat log is blocked for addons on this client, so it is not registered
        pcall(PG.RegisterUnitEvent, PG, "UNIT_COMBAT", "player", "target")
        pcall(PG.RegisterUnitEvent, PG, "UNIT_SPELLCAST_SUCCEEDED", "player")
        pcall(PG.RegisterUnitEvent, PG, "UNIT_SPELLCAST_SENT", "player")
    elseif event == "PLAYER_ENTERING_WORLD" then
        NS.playerGUID = UnitGUID("player")
        if LOC.on and LOC.nres == 0 then LOC.Build() end    -- spell names were not ready at login
        BuildButtons()
        pcall(NS.RefreshMinimapButton)
        if not NS.DB.welcomed then
            NS.DB.welcomed = true
            NS.loginMsgDone = true
            Print("thanks for installing! Type |cffffd100/pg|r or click the minimap button to choose which abilities glow.")
        elseif not NS.loginMsgDone then
            NS.loginMsgDone = true
            if not NS.DB.hideLoginMsg then
                Print("loaded. Type |cffffd100/pg|r to open the settings.")
            end
        end
        -- other bar addons often create buttons a moment later
        if C_Timer and C_Timer.After then
            C_Timer.After(3, BuildButtons)
            C_Timer.After(6, function() pcall(TA.ShowNotice) end)
            -- fonts can finish loading a moment after login: restyle the text popups once they have
            C_Timer.After(2, function() pcall(TA.RefreshStyle) end)
            C_Timer.After(6, function() pcall(TA.RefreshStyle) end)
        end
    elseif event == "UNIT_COMBAT" then
        pcall(OnUnitCombat, arg1, arg2)
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        pcall(OnPlayerCast, arg3)
    elseif event == "UNIT_SPELLCAST_SENT" then
        pcall(NS.OnPlayerSent, arg2, arg4)
    elseif event == "PLAYER_DEAD" then
        -- dying removes every buff
        wipe(buffInfo)
        wipe(procWindow)
    elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" and NS.debugOn then
        Print("native overlay event for: " .. tostring(SpellNameByID(arg1)) .. " (" .. tostring(arg1) .. ")")
    end
end)

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
local function ShoutDebug()
    pcall(PlayerBuffs)
    Print("resting=" .. tostring(IsResting and IsResting()) ..
        " onTaxi=" .. tostring(UnitOnTaxi and UnitOnTaxi("player")) ..
        " hideWhenResting=" .. tostring(NS.DB.shout.hideResting))
    Print("aura data restricted=" .. tostring(NS.auraRestricted) ..
        " everReadOK=" .. tostring(NS.haveGoodRead) ..
        " glowMissing=" .. tostring(NS.DB.shout.glowMissing) ..
        " preferred=" .. tostring(NS.DB.shout.preferred) ..
        " ignoreRage=" .. tostring(NS.DB.shout.ignoreRage))
    for name in pairs(SHOUTS) do
        local info = buffInfo[name]
        local txt = "not on me"
        if info then
            if info.unknown then
                txt = "on me, details unreadable"
            else
                txt = info.mine and "mine" or "someone else's"
                if info.expires and info.expires > 0 then
                    txt = txt .. ", " .. math.floor(info.expires - GetTime()) .. "s left"
                else
                    txt = txt .. ", no timer"
                end
            end
        end
        Print(name .. ": " .. txt)
    end
    local found = false
    for i = 1, #buttons do
        local slot = SlotOf(buttons[i])
        if slot and HasAction(slot) then
            local n = ResolveSlot(slot)
            if n and SHOUTS[n] then
                found = true
                local okc, res = pcall(ShoutLow, n)
                Print("button slot " .. slot .. " (" .. n .. "): offCooldown=" ..
                    tostring(OffCooldown(slot)) .. " shoutWantsGlow=" .. tostring(okc and res))
            end
        end
    end
    if not found then Print("no shout found on the action bars I can see (try /pg rescan)") end
end

SLASH_PROCGLOW1 = "/procglow"
SLASH_PROCGLOW2 = "/pg"
SlashCmdList["PROCGLOW"] = function(msg)
    if not NS.DB then return end
    msg = msg or ""
    local cmd, rest = msg:match("^(%S*)%s*(.-)$")
    cmd = cmd:lower()
    local restRaw = rest
    rest = rest:lower()

    if cmd == "" or cmd == "options" or cmd == "config" then
        ToggleWindow()
    elseif cmd == "abilities" or cmd == "classes" then
        OpenSettings("classes")
    elseif cmd == "text" then
        OpenSettings("text")
    elseif cmd == "lock" then
        TA.SetUnlocked(false)
        Print("text popups locked")
    elseif cmd == "effects" or cmd == "style" then
        OpenSettings("style")
    elseif cmd == "profile" or cmd == "profiles" then
        if restRaw == "" then OpenSettings("profiles") else TA.Prof.LoadByName(restRaw) end
    elseif cmd == "minimap" then
        NS.DB.minimap.hide = not NS.DB.minimap.hide
        NS.RefreshMinimapButton()
        if NS.settingsForm then NS.settingsForm:Refresh() end
        Print("minimap button " .. (NS.DB.minimap.hide and "hidden" or "shown"))
    elseif cmd == "locale" or cmd == "language" then
        if rest == "on" or rest == "off" or rest == "auto" then
            NS.DB.locForce = (rest == "on") or nil
            LOC.Init(); wipe(iconCache)
            Print("translation layer: " .. (rest == "auto" and "automatic (on for non-English clients)" or rest))
        end
        LOC.Report()
    elseif cmd == "langtest" then
        local c = rest ~= "" and rest or "deDE"
        local found
        for _, x in ipairs(TA.LangOrder) do if x:lower() == c:lower() then c = x; found = true end end
        if found then TA.ShowLangNotice(c, true) else Print("langtest codes: " .. table.concat(TA.LangOrder, ", ")) end
    elseif cmd == "scanids" then
        if rest == "show" and NS.DB.idscanText then LOC.ShowText(NS.DB.idscanText) else LOC.Scan() end
    elseif cmd == "add" and rest ~= "" then
        rest = LOC.Key(rest, true)
        NS.DB.added[rest] = true; NS.DB.removed[rest] = nil
        LoadLists(); Print("added spell: " .. rest)
    elseif cmd == "remove" and rest ~= "" then
        rest = LOC.Key(rest, true)
        NS.DB.added[rest] = nil; NS.DB.removed[rest] = true
        LoadLists(); Print("removed spell: " .. rest)
    elseif cmd == "buff" and rest:find(">") then
        local b, s = rest:match("^(.-)%s*>%s*(.-)$")
        b, s = LOC.Key(b, true), LOC.Key(s, true)
        if b ~= "" and s ~= "" then
            NS.DB.buffs[b] = s
            LoadLists(); Print("buff '" .. b .. "' now glows '" .. s .. "'")
        end
    elseif cmd == "redirect" and rest ~= "" then
        if rest:find(">") then
            local s, t = rest:match("^(.-)%s*>%s*(.-)$")
            if s ~= "" and t ~= "" then
                -- optional: "... > charge if berserker stance" / "... unless battle stance"
                local mode = "in"
                local tgt, st = t:match("^(.-)%s+if%s+(.+)$")
                if not tgt then
                    tgt, st = t:match("^(.-)%s+unless%s+(.+)$")
                    mode = "notin"
                end
                if tgt and tgt ~= "" then
                    NS.DB.redirect[s] = tgt
                    NS.DB.redirectCond[s] = { mode = mode, stance = st }
                    Print("'" .. s .. "' proc will also show on '" .. tgt .. "' (" .. (mode == "in" and "only in " or "not in ") .. st .. ")")
                else
                    NS.DB.redirect[s] = t
                    NS.DB.redirectCond[s] = nil
                    Print("'" .. s .. "' proc will also show on '" .. t .. "'")
                end
            end
        else
            NS.DB.redirect[rest] = nil
            NS.DB.redirectCond[rest] = nil
            Print("redirect cleared for '" .. rest .. "'")
        end
    elseif cmd == "timer" then
        local sp, secs = rest:match("^(.-)%s+(%d+%.?%d*)$")
        if sp and sp ~= "" then
            secs = tonumber(secs)
            NS.DB.procTime[sp] = secs
            Print(secs > 0 and ("'" .. sp .. "' countdown starts at " .. secs .. " seconds")
                or ("'" .. sp .. "' countdown turned off"))
        else
            Print("usage: /pg timer <ability> <seconds>   (0 turns that ability's countdown off)")
        end
    elseif cmd == "shout" and tonumber(rest) then
        NS.DB.shout.threshold = math.max(1, math.min(60, math.floor(tonumber(rest))))
        Print("shouts now glow at " .. NS.DB.shout.threshold .. " seconds left")
    elseif cmd == "why" then
        local sp = LOC.Key((rest ~= "" and rest or "overpower"):lower(), true)
        local okf, form = pcall(CurrentForm)
        Print("why '" .. sp .. "': stance/form=" .. tostring(okf and form or "?") ..
            " tracked=" .. tostring(reactive[sp] and true or false) ..
            " disabled=" .. tostring(NS.DB.disabled[sp] and true or false) ..
            " windowOpen=" .. tostring(WindowActive(sp)) ..
            " enabled=" .. tostring(NS.DB.enabled ~= false))
        local td = BUFFS.tracked[sp]
        if td then
            local mine, other = BUFFS.Info(sp)
            local st = td.group and BUFFS.state[td.group]
            Print("buff tracking: on=" .. tostring(td.group and NS.DB.track.groupOn[td.group] or NS.DB.track.on[sp]) ..
                " group=" .. tostring(td.group) .. " watching=" .. tostring(st and st.cur) ..
                " mineOnMe=" .. tostring(mine and true or false) .. " otherOnMe=" .. tostring(other and true or false) ..
                " wantsGlow=" .. tostring(BUFFS.Low(sp)))
        end
        local found = false
        for i = 1, #buttons do
            local slot = SlotOf(buttons[i])
            if slot and HasAction(slot) then
                local okr, n, id = pcall(ResolveSlot, slot)
                if okr and (n == sp or BUFFS.auraOf[n] == sp) then
                    found = true
                    local okc, u, np = pcall(IsUsableAction, slot)
                    Print("button slot " .. slot .. ": usable=" .. tostring(okc and u) ..
                        " notEnoughPower=" .. tostring(okc and np) ..
                        " offCooldown=" .. tostring(OffCooldown(slot)) ..
                        " nativeOverlay=" .. tostring(IsOverlayed(id)) ..
                        " glowNow=" .. tostring(select(2, pcall(ShouldGlow, slot, n, id, PlayerBuffs()))))
                end
            end
        end
        if not found then Print("no action button holds '" .. sp .. "' (is it on a bar I can see? try /pg bars to list what I can see)") end
    elseif cmd == "macros" then
        -- shows what the addon can read from every macro on your bars
        local count, done = 0, {}
        for i = 1, #buttons do
            local slot = SlotOf(buttons[i])
            if slot and HasAction(slot) and not done[slot] then
                local k, id = GetActionInfo(slot)
                if k == "macro" then
                    done[slot] = true
                    count = count + 1
                    local gs = GetMacroSpell or (C_Macro and C_Macro.GetMacroSpell)
                    local oks, a = false, nil
                    if gs then oks, a = pcall(gs, id) end
                    local gb = GetMacroBody or (C_Macro and C_Macro.GetMacroBody)
                    local okb, body = false, nil
                    if gb then okb, body = pcall(gb, id) end
                    local okp, parsed = pcall(MacroSpellName, id)
                    Print("slot " .. slot .. " macro id=" .. tostring(id) ..
                        " name=" .. tostring(GetActionText and GetActionText(slot)) ..
                        " | GetMacroSpell=" .. tostring(gs and (oks and tostring(a) or "error") or "missing") ..
                        " | body=" .. ((okb and type(body) == "string") and ("readable (" .. #body .. " chars)") or (gb and "unreadable" or "missing")) ..
                        " | parsed=" .. tostring(okp and parsed))
                end
            end
        end
        Print(count .. " macros on the bars I can see")
    elseif cmd == "bars" then
        -- lists the spell names found on the action buttons, to check names match
        local seen, list, odd, noSlot, hidden = {}, {}, {}, 0, 0
        local oddSeen = {}
        for i = 1, #buttons do
            local slot = SlotOf(buttons[i])
            if not slot then
                noSlot = noSlot + 1
            elseif HasAction(slot) then
                local okr, n = pcall(ResolveSlot, slot)
                if okr and n then
                    if not seen[n] then seen[n] = true; list[#list + 1] = n end
                elseif not oddSeen[slot] then
                    oddSeen[slot] = true
                    local k, id = GetActionInfo(slot)
                    odd[#odd + 1] = slot .. "=" .. tostring(k) .. ":" .. tostring(type(id) == "number" and id or "?")
                end
                if not buttons[i]:IsVisible() then hidden = hidden + 1 end
            end
        end
        table.sort(list)
        Print(#buttons .. " action buttons found (" .. noSlot .. " with no action slot, " .. hidden .. " with a spell but hidden), " ..
            #list .. " different spells: " .. table.concat(list, ", "))
        if #odd > 0 then Print("slots I could not read a spell name from (slot=kind:id): " .. table.concat(odd, ", ")) end
        for i = 1, 10 do
            local ok, n = pcall(BUFFS.StanceGlow, i)
            if ok and n then Print("stance button " .. i .. ": " .. n) end
        end
    elseif cmd == "shoutdebug" then
        local okd, err = pcall(ShoutDebug)
        if not okd then Print("shoutdebug failed: " .. tostring(err)) end
    elseif cmd == "list" then
        local t = {}
        for n in pairs(reactive) do t[#t + 1] = n end
        table.sort(t)
        Print("spells: " .. table.concat(t, ", "))
        for b, s in pairs(buffProcs) do Print("buff: " .. b .. " > " .. s) end
        for s, tg in pairs(NS.DB.redirect) do Print("redirect: " .. s .. " > " .. tg) end
    elseif cmd == "auras" then
        local names = {}
        for n in pairs(PlayerBuffs()) do names[#names + 1] = n end
        table.sort(names)
        Print(#names .. " buffs on you right now: " .. (#names > 0 and table.concat(names, ", ") or "none") ..
            ". Gain a proc, type /pg auras, and use /pg buff <name> > <spell> if a name isn't recognised.")
    elseif cmd == "debug" then
        NS.debugOn = not NS.debugOn
        Print("debug " .. (NS.debugOn and "ON - gain a proc and watch chat" or "OFF"))
    elseif cmd == "procs" then
        -- diagnostic for a proc icon that stays up: what the addon believes right now
        local now = GetTime()
        Print("auras hidden by the game: " .. tostring(NS.auraRestricted) .. ", in combat: " .. tostring(InCombatLockdown() and true or false))
        local any = false
        for k, t in pairs(BUFFS.procLive) do
            any = true
            Print(k .. ": held for " .. string.format("%.1f", t - now) .. "s more, lookup answered this fight: " .. tostring(BUFFS.dpWorks[k] and true or false)
                .. ", on the aura list: " .. tostring(PlayerBuffs()[k] and true or false))
        end
        if not any then Print("no proc is being held") end
    elseif cmd == "mouse" then
        -- hover over the thing that will not highlight: after 4 seconds this names whatever frame is under the pointer
        Print("hover the object now, checking in 4 seconds...")
        C_Timer.After(4, function()
            local list = {}
            if GetMouseFoci then list = GetMouseFoci() or {} elseif GetMouseFocus then list = { GetMouseFocus() } end
            if #list == 0 then Print("nothing from the interface is under the pointer") end
            for _, fr in ipairs(list) do
                local chain, p, n = {}, fr, 0
                while p and n < 6 do
                    local nm = p.GetName and p:GetName() or (p == WorldFrame and "WorldFrame") or "(unnamed)"
                    chain[#chain + 1] = tostring(nm)
                    p = p.GetParent and p:GetParent() or nil
                    n = n + 1
                end
                Print("under the pointer: " .. table.concat(chain, " < "))
            end
        end)
    elseif cmd == "bg" then
        -- diagnostic for buff glows in battlegrounds: what the game lets the addon see about each tracked buff
        local okI, inInst, it = pcall(IsInInstance)
        Print("instance type: " .. tostring(okI and it) .. ", auras hidden: " .. tostring(NS.auraRestricted) ..
            ", had a full read: " .. tostring(NS.haveGoodRead) .. ", a direct lookup has answered: " .. tostring(BUFFS.dAny and true or false))
        local _, pc = UnitClass("player")
        local n = 0
        for key, def in pairs(BUFFS.tracked) do
            local wanted = def.class == pc and ((def.group and NS.DB.track.groupOn[def.group]) or (not def.group and NS.DB.track.on[key]))
            if wanted then
                n = n + 1
                local nm = (NS.LOC and NS.LOC.Local and NS.LOC.Local(key)) or def.name or key
                local okd, d = pcall(function() return C_UnitAuras.GetAuraDataBySpellName("player", nm, "HELPFUL") end)
                local ans = not okd and "error" or (type(d) == "table" and "present" or "empty")
                local secretNums = "-"
                if okd and type(d) == "table" then
                    secretNums = tostring(issecretvalue and (issecretvalue(d.expirationTime) or issecretvalue(d.sourceUnit)) and true or false)
                end
                local sec = "?"
                if C_Secrets and C_Secrets.GetSpellAuraSecrecy then
                    local oks, r = pcall(C_Secrets.GetSpellAuraSecrecy, nm)
                    if oks then sec = tostring(r) end
                end
                local mine, other = BUFFS.Info(key)
                local low = false
                pcall(function() low = BUFFS.Low(key) end)
                local noted = "no cast noted"
                do
                    local ok2, rec = pcall(function() return NS.BUFFS.NotedCast and NS.BUFFS.NotedCast(key) end)
                    if ok2 and rec then noted = rec end
                end
                Print(def.name .. ": lookup " .. ans .. " (numbers hidden: " .. secretNums .. ", secrecy " .. sec .. "), believed mine=" ..
                    tostring(mine == false and "unknown" or (mine and "yes" or "no")) .. " other=" .. tostring(other and true or false) .. ", cast record: " .. noted .. ", glowing: " .. tostring(low and true or false))
            end
        end
        if n == 0 then Print("no tracked buffs are switched on for your class") end
    elseif cmd == "icon" then
        -- diagnostic: what icon does the game give for each spell ID listed under this name, and for the bare name?
        if rest == "" then Print("type a spell name, e.g. /pg icon ice armor"); return end
        local function Show(tex)
            if tex == nil then return "nil" end
            if type(tex) == "number" or type(tex) == "string" then return "|T" .. tex .. ":16|t " .. tostring(tex) end
            return tostring(tex)
        end
        local ids = type(ProcGlowIDs) == "table" and ProcGlowIDs[rest]
        Print("icon check for |cffffd100" .. rest .. "|r" .. (ids and "" or " (no IDs listed for that name)"))
        for _, id in ipairs(ids or {}) do
            local okk, known = pcall(function() if IsPlayerSpell then return IsPlayerSpell(id) end end)
            local nm, tex, tex2
            pcall(function() if GetSpellInfo then local n, _, ic = GetSpellInfo(id); nm, tex2 = n, ic end end)
            pcall(function()
                if GetSpellTexture then tex = GetSpellTexture(id)
                elseif C_Spell and C_Spell.GetSpellTexture then tex = C_Spell.GetSpellTexture(id) end
            end)
            Print("  id " .. id .. "  name=" .. tostring(nm) .. "  known=" .. tostring(okk and known) ..
                "  texture=" .. Show(tex) .. "  info icon=" .. Show(tex2))
        end
        local byName
        pcall(function()
            if GetSpellTexture then byName = GetSpellTexture(rest)
            elseif C_Spell and C_Spell.GetSpellTexture then byName = C_Spell.GetSpellTexture(rest) end
        end)
        Print("  by name: " .. Show(byName))
        Print("  what ProcGlow uses: " .. Show(SpellIcon(rest)) .. "   aura icon: " .. Show(BUFFS.auraIcon[rest]))
    elseif cmd == "rescan" then
        BuildButtons(); Print("found " .. #buttons .. " action buttons")
    else
        Print("/pg opens the window | locale | profile <name> | style | classes | minimap | add <spell> | remove <spell> | buff <buff> > <spell> | auras | redirect <spell> > <ability or slot> | list | debug | rescan")
    end
end
-- (end of the removed block)
