local _, NS = ...
local ApplyAll, ApplyStyleTo, BuildButtons, BuildGlow, CLASS_SPELLS, CopyDefaults = NS.ApplyAll, NS.ApplyStyleTo, NS.BuildButtons, NS.BuildGlow, NS.CLASS_SPELLS, NS.CopyDefaults
local HideGlowFrame, NewForm, POPUP_ONLY, PreviewIcon, Print, SPELL_NOTES = NS.HideGlowFrame, NS.NewForm, NS.POPUP_ONLY, NS.PreviewIcon, NS.Print, NS.SPELL_NOTES
local SS, ShowGlowFrame, TA, Tip, Title, UI = NS.SS, NS.ShowGlowFrame, NS.TA, NS.Tip, NS.Title, NS.UI
local builtinSet, buttons, previewGlows = NS.builtinSet, NS.buttons, NS.previewGlows

---------------------------------------------------------------------------
-- Page: Settings
---------------------------------------------------------------------------
StaticPopupDialogs["PROCGLOW_RESET"] = {
    text = "Reset ALL ProcGlow settings to their defaults and reload the interface?",
    button1 = "Reset", button2 = "Cancel",
    OnAccept = function() ProcGlowDB = nil; ReloadUI() end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

local function BuildSettingsPage(page)
    local F = NewForm(page, 508, 16, 14)
    NS.settingsForm = F

    local head = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    TA.Acc(head, "fs")
    head:SetPoint("TOPLEFT", 16, -12)
    head:SetText("General Settings")
    F:Gap(26)

    F:Section("Getting started")
    F:Text("|cffffd100Class Procs/Buffs|r - start here. Pick your class, then choose what each ability does: glow its action button, show a text popup, or show an icon with a timer. Press Customise to move and style them. \"Track a buff\" at the bottom follows any other buff.\n|cffffd100Glow Style|r, |cffffd100Timer & Stacks|r and |cffffd100Text Alerts|r - how the glow, its countdown and the text popups look.\n|cffffd100Profiles|r - save separate setups (for example tank and damage) and switch between them, even automatically by spec or group role.")
    F:Gap(4)

    F:Section("General")
    F:Tick("Enable ProcGlow",
        function() return NS.DB.enabled ~= false end,
        function(v) NS.DB.enabled = v; NS.RefreshMinimapButton() end,
        0, "Turns every glow off without disabling the addon.")
    F:Tick("Show the minimap button",
        function() return not NS.DB.minimap.hide end,
        function(v) NS.DB.minimap.hide = not v; NS.RefreshMinimapButton() end,
        270)
    F:Row()
    F:Tick("Show a command reminder in chat on log in",
        function() return not NS.DB.hideLoginMsg end,
        function(v) NS.DB.hideLoginMsg = not v end,
        0, "Prints a one-line reminder of the /pg command each time you log in. Untick to hide it.")
    F:Row()
    F:Gap(8)

    F:Section("Buff reminders")
    F:Tick("Hide buff reminders while resting or on a flight path",
        function() return NS.DB.track.hideResting end,
        function(v) v = v and true or false; NS.DB.track.hideResting = v; NS.DB.shout.hideResting = v end,
        0, "Stops the \"buff missing\" glows, popups and icons while you are in a city or inn, or on a flight path. This is the same setting as the one on each class page, so changing it here changes it for every class.")
    F:Row()
    F:Gap(8)

    F:Section("Appearance")
    F:Tick("Use my class colour for the ProcGlow window",
        function() return NS.DB.classUI == true end,
        function(v) NS.DB.classUI = v; TA.PaintAccents() end,
        0, "Gives this window a touch of your class colour: its borders, panel backgrounds, dividers and menu highlight. Text and buttons keep their normal colours.")
    F:Row()
    F:Gap(8)

    F:Section("Troubleshooting")
    F:Tick("Preview glow on every button",
        function() return NS.previewOn end,
        function(v) NS.previewOn = v end,
        0, "Lights every action button up so you can judge the glow style. Untick when you are done.")
    F:Button("Rescan action bars", 150, function()
        BuildButtons()
        Print("found " .. #buttons .. " action buttons")
    end, 270, true)
    F:Row()
    F:Tick("Debug messages in chat",
        function() return NS.debugOn end,
        function(v) NS.debugOn = v end,
        0, "Prints every buff you gain and each time a dodge or parry opens a proc window. The quickest way to find the name of a new proc.")
    local resetBtn = F:Button("Reset all settings", 150, function() StaticPopup_Show("PROCGLOW_RESET") end, 270, true)
    Tip(resetBtn, "Reset all settings", "Puts every ProcGlow setting back to how it was when you first installed it. You will be asked to confirm.")
    F:Row()
    F:Gap(8)

    F:Section("Slash commands")
    F:Text("|cffffd100/pg|r  open or close this window      |cffffd100/pg profile <name>|r  switch profile      |cffffd100/pg minimap|r  show or hide the minimap button\n|cffffd100/pg why <ability>|r  explains why a glow is or is not showing\n|cff999999More: /pg style, /pg classes, /pg add <spell>, /pg remove <spell>, /pg buff <buff> > <spell>, /pg redirect <spell> > <ability or slot>, /pg timer <ability> <seconds>, /pg debug, /pg rescan, /pg list|r")

    return function() F:Refresh() end
end
NS.BuildSettingsPage = BuildSettingsPage

---------------------------------------------------------------------------
-- Page: Glow Style (layers that can be combined) - one compact screen
---------------------------------------------------------------------------
local function MS(F, label, minV, maxV, step, fmt, key, x, tip)
    local get, set = SS(key)
    return F:Mini(label, minV, maxV, step, fmt, get, set, x, tip)
end

local function TS(F, label, key, x, tip)
    local get, set = SS(key)
    return F:Tick(label, get, set, x, tip)
end

local function BuildStylePage(page)
    -- live preview at the top
    local pv = CreateFrame("Frame", nil, page)
    pv:SetSize(40, 40)
    pv:SetPoint("TOPLEFT", 26, -14)
    local ico = pv:CreateTexture(nil, "ARTWORK")
    ico:SetAllPoints()
    ico:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    ico:SetTexture(PreviewIcon())

    local glow = BuildGlow(pv)
    previewGlows[#previewGlows + 1] = { parent = pv, glow = glow }
    ApplyStyleTo(pv, glow)

    local function replay()
        HideGlowFrame(glow)
        ApplyStyleTo(pv, glow)
        ShowGlowFrame(glow)
    end
    page:SetScript("OnShow", replay)
    page:SetScript("OnHide", function() HideGlowFrame(glow) end)

    local head = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    TA.Acc(head, "fs")
    head:SetPoint("TOPLEFT", 84, -14)
    head:SetText("Glow Style")
    local hint = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", 84, -36)
    hint:SetWidth(230)
    hint:SetJustifyH("LEFT")
    hint:SetText("Live preview. Tick any layers - they all stack together.")

    local replayBtn = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")

    TA.Acc(replayBtn, "btn")
    replayBtn:SetSize(80, 22)
    replayBtn:SetPoint("TOPRIGHT", -18, -20)
    replayBtn:SetText("Replay")
    replayBtn:SetScript("OnClick", replay)

    local resetBtn = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")

    TA.Acc(resetBtn, "btn")
    resetBtn:SetSize(100, 22)
    resetBtn:SetPoint("RIGHT", replayBtn, "LEFT", -6, 0)
    resetBtn:SetText("Reset style")
    resetBtn:SetScript("OnClick", function()
        CopyDefaults()
        ApplyAll()
        if NS.styleForm then NS.styleForm:Refresh() end
    end)
    Tip(resetBtn, "Reset glow style", "Puts every glow and animation setting back to its default.")

    local F = NewForm(page, 508, 16, 66)
    NS.styleForm = F
    F.barW = 66              -- short slider bars so two sliders (each with its number box) fit on one row
    local A, B = 118, 322    -- the two slider columns

    -- grey out the sliders of a layer that is switched off
    local function Dep(ticks, keys, ctrls)
        local function apply()
            local on = false
            for _, k in ipairs(keys) do if NS.DB.style[k] then on = true end end
            local al = on and 1 or 0.35
            for _, c in ipairs(ctrls) do
                if on then c:Enable() else c:Disable() end
                c:SetAlpha(al)
                if c.lab then c.lab:SetAlpha(al) end
                if c.val then c.val:SetAlpha(al) end
            end
        end
        for _, t in ipairs(ticks) do t:HookScript("OnClick", apply) end
        F.refreshers[#F.refreshers + 1] = apply
    end

    F:Section("Glow type")
    local tBz = TS(F, "Use Blizzard's default proc glow", "blizzardOn", 0,
        "The golden ring from the default action bars, ready made. Untick it to customise the colour, layers and animation yourself.")
    tBz:HookScript("OnClick", function() replay() end)
    local hintFs = F:Note("<- untick to customise, or press the button below", 250)
    hintFs:SetFontObject("GameFontNormalSmall")
    F:Row()
    local yBlock = F.oy + F.y - 2

    F:Section("Colour and pulse")
    F:ColorAt("Glow colour", 0)
    MS(F, "Intensity", 0.2, 1, 0.05, "%.2f", "intensity", A, "How bright the glow is.")
    F:Row()
    local tPulse = TS(F, "Pulse", "pulse", 0, "Fade the glow in and out.")
    local sPeriod = MS(F, "Period", 0.15, 1.5, 0.05, "%.2f", "speed", A, "Seconds for each fade. Lower is faster.")
    local sDim = MS(F, "Dimmest", 0, 1, 0.05, "%.2f", "minAlpha", B, "How faint the pulse gets. 1 means no fade at all.")
    Dep({ tPulse }, { "pulse" }, { sPeriod, sDim })
    F:Row()

    F:Section("Layers - tick any combination (sliders grey out when a layer is off)")
    local tHalo = TS(F, "Halo", "haloOn", 0, "Soft glow around the button.")
    local sHalo = MS(F, "Size", 1.2, 4, 0.05, "%.2f", "scale", A, "How far the halo reaches past the button.")
    local sStr = MS(F, "Brightness", 1, 3, 1, "%dx", "strength", B, "How many copies of the halo are stacked on top of each other. Higher is brighter and denser.")
    Dep({ tHalo }, { "haloOn" }, { sHalo, sStr })
    F:Row()
    local tHi = TS(F, "Highlight", "highlightOn", 0, "Bright wash over the icon edges.")
    local sHi = MS(F, "Brightness", 1, 3, 1, "%dx", "hiStrength", A, "How many copies of the highlight are stacked on top of each other. Higher is brighter.")
    Dep({ tHi }, { "highlightOn" }, { sHi })
    F:Row()
    local tOut = TS(F, "Outline", "outlineOn", 0, "Solid coloured frame.")
    local sOut = MS(F, "Thickness", 1, 12, 1, "%d", "thickness", A, "Frame thickness in pixels.")
    Dep({ tOut }, { "outlineOn" }, { sOut })
    F:Row()
    local tFill = TS(F, "Fill", "fillOn", 0, "Tint over the whole icon.")
    local sFill = MS(F, "Opacity", 0.05, 0.8, 0.05, "%.2f", "fillAlpha", A, "How strongly the colour covers the icon.")
    Dep({ tFill }, { "fillOn" }, { sFill })
    F:Row()
    local tBurst = TS(F, "Burst", "burstOn", 0, "Rotating star behind the icon.")
    local sBurst = MS(F, "Size", 1.2, 4, 0.05, "%.2f", "burstScale", A)
    Dep({ tBurst }, { "burstOn" }, { sBurst })
    F:Row()
    local tAnts = TS(F, "Marching ants", "antsOn", 0, "Dashes running round the edge.")
    local sAntN = MS(F, "Dashes", 4, 24, 1, "%d", "antCount", A)
    local sAntS = MS(F, "Lap (s)", 0.5, 6, 0.1, "%.1f", "antSpeed", B, "Seconds for a dash to run once round the icon. Lower is faster.")
    F:Row()
    local sAntT = MS(F, "Thickness", 1, 8, 1, "%d", "antThick", A)
    Dep({ tAnts }, { "antsOn" }, { sAntN, sAntS, sAntT })
    F:Row()
    F:Section("Attention animation - plays when a glow first appears")
    local tPop = TS(F, "Pop", "pop", 0, "Starts big and shrinks into place.")
    local sPopS = MS(F, "Size", 1.2, 3, 0.05, "%.2f", "popSize", A)
    local sPopT = MS(F, "Time (s)", 0.15, 1.2, 0.05, "%.2f", "popTime", B)
    Dep({ tPop }, { "pop" }, { sPopS, sPopT })
    F:Row()
    TS(F, "White flash", "flash", 0, "A white burst that fades out.")
    F:Row()

    -- dims and locks everything below the glow-type row while the Blizzard preset is on
    local blocker = CreateFrame("Frame", nil, page)
    blocker:SetPoint("TOPLEFT", page, "TOPLEFT", 6, -yBlock)
    blocker:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -6, 4)
    blocker:SetFrameLevel(page:GetFrameLevel() + 30)
    blocker:EnableMouse(true)
    local shade = blocker:CreateTexture(nil, "OVERLAY")
    shade:SetAllPoints()
    UI.Reg(function() UI.Paint(shade, UI.Col("fill")) end)
    local note = blocker:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    note:SetPoint("CENTER", blocker, "CENTER", 0, 14)
    note:SetText("Using Blizzard's default glow.")
    local custom = UI.Button(blocker, "Customise glow", 150, 24, function()
        NS.DB.style.blizzardOn = false
        ApplyAll()
        F:Refresh()
        for _, pvg in ipairs(previewGlows) do ApplyStyleTo(pvg.parent, pvg.glow) end
        replay()
    end)
    custom:SetPoint("TOP", note, "BOTTOM", 0, -12)
    local function syncBlocker()
        if NS.DB.style.blizzardOn then blocker:Show() else blocker:Hide() end
    end
    tBz:HookScript("OnClick", syncBlocker)
    F.refreshers[#F.refreshers + 1] = syncBlocker

    return function()
        F:Refresh()
        for _, pvg in ipairs(previewGlows) do ApplyStyleTo(pvg.parent, pvg.glow) end
    end
end
NS.BuildStylePage = BuildStylePage

---------------------------------------------------------------------------
-- Page: one class (abilities, redirects, stance conditions, shout timers)
---------------------------------------------------------------------------
local function ClassItems(c)
    local items = {}
    if c ~= "OTHER" then
        for _, sp in ipairs(CLASS_SPELLS[c] or {}) do
          -- the shouts are managed in the timer panel at the top, not in this list
          if sp:lower() ~= "battle shout" and sp:lower() ~= "commanding shout" then
            items[#items + 1] = { spell = sp:lower(), display = sp, extra = SPELL_NOTES[sp], textOnly = POPUP_ONLY[sp:lower()] and true or nil, iconOnly = (sp == "Arcane Blast Stacks") or nil }
          end
        end
    end
    local custom = {}
    for n in pairs(NS.DB.added) do
        if not builtinSet[n] then
            local cc = NS.DB.customClass[n]
            if (c == "OTHER" and not cc) or (c ~= "OTHER" and cc == c) then
                custom[#custom + 1] = n
            end
        end
    end
    table.sort(custom)
    for _, n in ipairs(custom) do
        items[#items + 1] = { spell = n, display = Title(n), custom = true }
    end
    -- buffs you asked to track (icon only): listed last, under their own heading
    local watch = {}
    for n in pairs(NS.DB.watch or {}) do
      if NS.BUFFS.tracked[n] then
        NS.DB.watch[n] = nil          -- now a class buff with its own row (for example Fear Ward): no second copy
      else
        local cc = NS.DB.customClass[n]
        if (c == "OTHER" and not cc) or (c ~= "OTHER" and cc == c) then watch[#watch + 1] = n end
      end
    end
    table.sort(watch)
    -- popup-only procs go last, under their own heading
    local glow, only = {}, {}
    for _, it in ipairs(items) do
        if it.textOnly then only[#only + 1] = it else glow[#glow + 1] = it end
    end
    for _, it in ipairs(only) do glow[#glow + 1] = it end
    for _, n in ipairs(watch) do glow[#glow + 1] = { spell = n, display = Title(n), custom = true, watch = true } end
    return glow
end
NS.ClassItems = ClassItems

-- "berserker stance" -> "Berserker", "cat form" -> "Cat"
local function ShortStance(s)
    if not s then return "(none)" end
    s = s:gsub(" stance$", ""):gsub(" form$", "")
    return Title(s)
end
NS.ShortStance = ShortStance
