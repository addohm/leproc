local _, NS = ...
local ICON_PATH, TA, UI = NS.ICON_PATH, NS.TA, NS.UI

---------------------------------------------------------------------------
-- One-time thank-you note (shown once per account, until "Okay" is pressed)
---------------------------------------------------------------------------
do
    local URL = "https://www.curseforge.com/wow/addons/procglow/comments"
    local frame
    function TA.ShowThanks()
        if not NS.DB or NS.DB.thanksShown3 then return end   -- (new flag: everyone sees this note once, even if they dismissed an older one)
        if frame then frame:Show(); return end
        local f = CreateFrame("Frame", "ProcGlowThanks", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
        f:SetSize(440, 452)
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
        f:SetFrameStrata("DIALOG")
        f:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })
        f:EnableMouse(true)
        local pic = f:CreateTexture(nil, "ARTWORK")
        pic:SetSize(60, 60)
        pic:SetPoint("TOP", f, "TOP", 0, -24)
        pic:SetTexture(ICON_PATH)
        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", pic, "BOTTOM", 0, -8)
        title:SetJustifyH("CENTER")
        title:SetText("Welcome to ProcGlow!")
        local body = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        body:SetPoint("TOPLEFT", 26, -112)
        body:SetWidth(388)
        body:SetJustifyH("LEFT")
        body:SetSpacing(3)
        body:SetText("Thank you for installing ProcGlow!\n\n" ..
            "If you have a minute, please leave feedback or suggestions in the comments, or send me a direct message on CurseForge, good or bad. It really does help to shape the future of ProcGlow.\n\n" ..
            "ProcGlow is made by one person, with no team behind it. For the first few weeks of launch I'll be playing mainly my Warrior, so I'll have limited visibility of how the other classes are doing. Feedback on any class other than Warrior is especially valuable to me.")
        local hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        hint:SetPoint("BOTTOMLEFT", 30, 92)
        hint:SetWidth(384)
        hint:SetJustifyH("LEFT")
        hint:SetWordWrap(true)
        hint:SetText("Select the link below, press Ctrl+C to copy it, then paste it into your browser.")
        local box = UI.FlatEdit(CreateFrame("EditBox", nil, f, "InputBoxTemplate"))
        box:SetSize(380, 20)
        box:SetPoint("BOTTOMLEFT", 32, 66)
        box:SetAutoFocus(false)
        box:SetText(URL)
        box:SetCursorPosition(0)
        box:SetScript("OnTextChanged", function(self) if self:GetText() ~= URL then self:SetText(URL) end end)
        box:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
        box:SetScript("OnMouseUp", function(self) self:HighlightText() end)
        box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        local ok = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        ok:SetSize(120, 26)
        ok:SetPoint("BOTTOM", 0, 26)
        ok:SetText("Okay")
        ok:SetScript("OnClick", function()
            NS.DB.thanksShown3 = true
            f:Hide()
        end)
        frame = f
    end
end

---------------------------------------------------------------------------
-- Language notice: one box per client language (test build: /pg langtest [code])
---------------------------------------------------------------------------
do
    local URL = "https://www.curseforge.com/wow/addons/procglow/comments"
    local ORDER = { "enUS", "deDE", "frFR", "esES", "esMX", "itIT", "ptBR", "ruRU", "koKR", "zhCN", "zhTW" }
    -- on an English client these game font files stand in for the real client font (test only)
    local TESTFONT = { ruRU = "Fonts\\ARIALN.TTF", koKR = "Fonts\\2002.TTF", zhCN = "Fonts\\ARKai_T.ttf", zhTW = "Fonts\\bLEI00D.ttf" }
    local frame, idx, stress = nil, 1, false

    local function PickFont(code)
        if GetLocale and GetLocale() == code then return STANDARD_TEXT_FONT, true end
        local f = TESTFONT[code]
        if f then return f, false end
        return STANDARD_TEXT_FONT, true
    end
    local function SetF(fs, path, size, flags)
        local ok = fs:SetFont(path, size, flags or "")
        if not ok then fs:SetFont(STANDARD_TEXT_FONT, size, flags or ""); return false end
        return true
    end

    local function Fill(code)
        local L = ProcGlowLang and ProcGlowLang[code]
        if not L then return end
        local f = frame
        local path = PickFont(code)
        local fontOK = true
        fontOK = SetF(f.title, path, 16) and fontOK
        fontOK = SetF(f.body, path, 13) and fontOK
        fontOK = SetF(f.hint, path, 11) and fontOK
        local bt = f.ok:GetFontString()
        if bt then SetF(bt, path, 13) end
        f.title:SetText(L.title)
        local txt = L.p1 .. "\n\n" .. L.p2 .. "\n\n" .. L.p3 .. "\n\n" .. L.p4
        if stress then txt = txt .. " " .. txt:sub(1, math.floor(#txt * 0.2)) end   -- ~20% longer, to check the margin
        f.body:SetText(txt)
        f.hint:SetText(L.hint)
        f.ok:SetText(L.ok)
        local th, bh, hh = f.title:GetStringHeight(), f.body:GetStringHeight(), f.hint:GetStringHeight()
        -- height follows the text: picture + title, body, hint, link box, button
        f:SetHeight(24 + 60 + 8 + th + 16 + bh + 14 + hh + 8 + 20 + 16 + 26 + 24)
        if f.cap then
            f.cap:SetText(code .. "  (" .. idx .. "/" .. #ORDER .. ")  font: " .. (fontOK and "ok" or "MISSING, showing default") ..
                (stress and "  |cffff8040+20% text|r" or ""))
        end
    end

    function TA.ShowLangNotice(code, test)
        local L = ProcGlowLang
        if not L then return end
        if test then
            for i, c in ipairs(ORDER) do if c == code then idx = i end end
        end
        if not frame then
            local f = CreateFrame("Frame", "ProcGlowLangNotice", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
            f:SetWidth(440)
            f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
            f:SetFrameStrata("DIALOG")
            f:SetBackdrop({
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                tile = true, tileSize = 32, edgeSize = 32,
                insets = { left = 11, right = 12, top = 12, bottom = 11 },
            })
            f:EnableMouse(true)
            f:SetMovable(true)
            f:RegisterForDrag("LeftButton")
            f:SetScript("OnDragStart", f.StartMoving)
            f:SetScript("OnDragStop", f.StopMovingOrSizing)
            local pic = f:CreateTexture(nil, "ARTWORK")
            pic:SetSize(60, 60)
            pic:SetPoint("TOP", f, "TOP", 0, -24)
            pic:SetTexture(ICON_PATH)
            f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            f.title:SetPoint("TOP", pic, "BOTTOM", 0, -8)
            f.title:SetWidth(388)
            f.title:SetJustifyH("CENTER")
            f.body = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            f.body:SetPoint("TOP", f.title, "BOTTOM", 0, -16)
            f.body:SetWidth(388)
            f.body:SetJustifyH("LEFT")
            f.body:SetSpacing(3)
            f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            f.hint:SetPoint("TOPLEFT", f.body, "BOTTOMLEFT", 0, -14)
            f.hint:SetWidth(384)
            f.hint:SetJustifyH("LEFT")
            f.hint:SetWordWrap(true)
            local box = UI.FlatEdit(CreateFrame("EditBox", nil, f, "InputBoxTemplate"))
            box:SetSize(380, 20)
            box:SetPoint("TOPLEFT", f.hint, "BOTTOMLEFT", 4, -8)
            box:SetAutoFocus(false)
            box:SetText(URL)
            box:SetCursorPosition(0)
            box:SetScript("OnTextChanged", function(self) if self:GetText() ~= URL then self:SetText(URL) end end)
            box:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
            box:SetScript("OnMouseUp", function(self) self:HighlightText() end)
            box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
            f.ok = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
            f.ok:SetSize(120, 26)
            f.ok:SetPoint("BOTTOM", 0, 24)
            f.ok:SetScript("OnClick", function()
                if not f.testMode and NS.DB then NS.DB.langNoticeShown = true end
                f:Hide()
            end)
            -- test controls (only visible in /pg langtest)
            f.cap = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            f.cap:SetPoint("BOTTOM", f, "TOP", 0, 2)
            f.next = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
            f.next:SetSize(70, 22); f.next:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", 0, -2); f.next:SetText("Next >")
            f.prev = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
            f.prev:SetSize(70, 22); f.prev:SetPoint("RIGHT", f.next, "LEFT", -4, 0); f.prev:SetText("< Prev")
            f.str = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
            f.str:SetSize(90, 22); f.str:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, -2); f.str:SetText("+20% text")
            f.next:SetScript("OnClick", function() idx = idx % #ORDER + 1; Fill(ORDER[idx]) end)
            f.prev:SetScript("OnClick", function() idx = (idx - 2) % #ORDER + 1; Fill(ORDER[idx]) end)
            f.str:SetScript("OnClick", function() stress = not stress; Fill(ORDER[idx]) end)
            frame = f
        end
        frame.testMode = test and true or false
        for _, k in ipairs({ "cap", "next", "prev", "str" }) do frame[k]:SetShown(frame.testMode) end
        Fill(code)
        frame:Show()
    end
    TA.LangOrder = ORDER

    -- English clients get the thank-you note, every other client gets the language note in its own language
    function TA.ShowNotice()
        if not NS.DB then return end
        local loc = GetLocale and GetLocale() or "enUS"
        if loc:sub(1, 2) == "en" or not (ProcGlowLang and ProcGlowLang[loc]) then
            TA.ShowThanks()
        elseif not NS.DB.langNoticeShown then
            TA.ShowLangNotice(loc)
        end
    end
end
