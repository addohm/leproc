local _, NS = ...
local ICON_PATH, MINIMAP_ICON_PATH, OpenSettings, ShowPicker, TA, ToggleWindow = NS.ICON_PATH, NS.MINIMAP_ICON_PATH, NS.OpenSettings, NS.ShowPicker, NS.TA, NS.ToggleWindow

---------------------------------------------------------------------------
-- Options > AddOns entry (a small panel with a button that opens the window)
---------------------------------------------------------------------------
local function CloseBlizzardOptions()
    pcall(function()
        if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
        if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then InterfaceOptionsFrame:Hide() end
        if GameMenuFrame and GameMenuFrame:IsShown() then HideUIPanel(GameMenuFrame) end
    end)
end

local function RegisterBlizzardPanel()
    local panel = CreateFrame("Frame", "ProcGlowBlizzardPanel")
    panel.name = "ProcGlow"

    local pic = panel:CreateTexture(nil, "ARTWORK")
    pic:SetSize(36, 36)
    pic:SetPoint("TOPLEFT", 16, -12)
    pic:SetTexture(ICON_PATH)

    local t = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    t:SetPoint("LEFT", pic, "RIGHT", 10, 0)
    t:SetText("ProcGlow")

    local d = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    d:SetPoint("TOPLEFT", pic, "BOTTOMLEFT", 0, -12)
    d:SetWidth(520)
    d:SetJustifyH("LEFT")
    d:SetText("Glows your action bar buttons when a proc or reactive ability is usable. All glow styles, abilities and class settings are in the ProcGlow window (also opened with /pg).")

    local cb = CreateFrame("CheckButton", "ProcGlowBlizzEnable", panel, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", d, "BOTTOMLEFT", -4, -16)
    _G["ProcGlowBlizzEnableText"]:SetText("Enable ProcGlow")
    cb:SetScript("OnClick", function(self)
        NS.DB.enabled = self:GetChecked() and true or false
        NS.RefreshMinimapButton()
    end)

    local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btn:SetSize(220, 26)
    btn:SetPoint("TOPLEFT", cb, "BOTTOMLEFT", 4, -14)
    btn:SetText("Open ProcGlow settings")
    btn:SetScript("OnClick", function()
        CloseBlizzardOptions()
        OpenSettings()
    end)

    panel:SetScript("OnShow", function() cb:SetChecked(NS.DB and NS.DB.enabled ~= false) end)
    panel.OnCommit = function() end
    panel.OnDefault = function() end
    panel.OnRefresh = function() end

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end
NS.RegisterBlizzardPanel = RegisterBlizzardPanel

---------------------------------------------------------------------------
-- Minimap button
---------------------------------------------------------------------------
local minimapBtn

local function PlaceMinimapButton()
    if not minimapBtn or not Minimap then return end
    local angle = math.rad(NS.DB.minimap.angle or 215)
    local x, y = math.cos(angle), math.sin(angle)
    local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
    if shape ~= "ROUND" then
        -- square minimaps: push the button out to the edge of the square
        local m = math.max(math.abs(x), math.abs(y))
        if m > 0 then x, y = x / m, y / m end
    end
    local rw = (Minimap:GetWidth() / 2) + 5
    local rh = (Minimap:GetHeight() / 2) + 5
    minimapBtn:ClearAllPoints()
    minimapBtn:SetPoint("CENTER", Minimap, "CENTER", x * rw, y * rh)
end

function NS.RefreshMinimapButton()
    if not minimapBtn then return end
    if NS.DB.minimap.hide then minimapBtn:Hide() else minimapBtn:Show() end
    minimapBtn.icon:SetDesaturated(NS.DB.enabled == false)
    PlaceMinimapButton()
end

local function CreateMinimapButton()
    if minimapBtn or not Minimap then return end
    local b = CreateFrame("Button", "ProcGlowMinimapButton", Minimap)
    b:SetSize(31, 31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:SetClampedToScreen(true)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(20, 20)
    bg:SetPoint("TOPLEFT", 7, -5)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")

    -- round art that fills the ring; the border texture sits on top and trims the edge
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetSize(21, 21)
    icon:SetPoint("TOPLEFT", 6.5, -4.5)
    icon:SetTexture(MINIMAP_ICON_PATH)
    b.icon = icon

    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    -- slide the icon down a pixel while the mouse is held, like the stock buttons
    b:SetScript("OnMouseDown", function() icon:SetPoint("TOPLEFT", 7.5, -5.5) end)
    b:SetScript("OnMouseUp", function() icon:SetPoint("TOPLEFT", 6.5, -4.5) end)

    -- drag around the edge of the minimap
    local function OnDragUpdate()
        local mx, my = Minimap:GetCenter()
        local cx, cy = GetCursorPosition()
        local s = Minimap:GetEffectiveScale()
        cx, cy = cx / s, cy / s
        NS.DB.minimap.angle = math.deg(math.atan2(cy - my, cx - mx))
        PlaceMinimapButton()
    end
    b:SetScript("OnDragStart", function(self)
        self.dragging = true
        GameTooltip:Hide()
        self:SetScript("OnUpdate", OnDragUpdate)
    end)
    b:SetScript("OnDragStop", function(self)
        self.dragging = nil
        self:SetScript("OnUpdate", nil)
    end)

    b:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            -- a short list of your other profiles: click one to switch to it
            GameTooltip:Hide()
            local okn, names = pcall(function() TA.Prof.Ensure(); return TA.Prof.Names() end)
            local cur = okn and TA.Prof.S().cur
            local labels, map = {}, {}
            if okn then
                -- the profile in use comes first, then the rest
                for pass = 1, 2 do
                    for _, n in ipairs(names) do
                        if (pass == 1) == (n == cur) then
                            local l = (n == cur) and (n .. " (Using)") or n
                            labels[#labels + 1] = l
                            map[l] = n
                        end
                    end
                end
            end
            local SEP, NEW = "--------------------", "+ Create profile"
            labels[#labels + 1] = SEP
            labels[#labels + 1] = NEW
            ShowPicker(b, labels, function(l)
                if l == NEW then OpenSettings("profiles"); return end
                local n = map[l]
                if n and n ~= cur then pcall(TA.Prof.Load, n) end
            end, true, true, true)
        else
            ToggleWindow()
        end
    end)

    b:SetScript("OnEnter", function(self)
        if self.dragging then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("ProcGlow", 1, 0.82, 0)
        GameTooltip:AddLine("Left-click: open the settings window", 1, 1, 1)
        GameTooltip:AddLine("Right-click: choose a profile", 1, 1, 1)
        local okp, cp = pcall(function() return TA.Prof.S().cur end)
        if okp and cp then GameTooltip:AddLine("Current profile: " .. cp, 1, 0.82, 0) end
        GameTooltip:AddLine("Drag: move this button around the minimap", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)

    minimapBtn = b
    NS.RefreshMinimapButton()
end
NS.CreateMinimapButton = CreateMinimapButton
