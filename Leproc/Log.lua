-- Leproc: /leproc log, for finding out why an ability lights when it shouldn't (or the other way
-- round). While it's on, it prints and keeps (the last 300 lines, account-wide in LeprocDB.log):
--   every trigger the game reports (UNIT_COMBAT), the windows it opens, the stance you're in;
--   every glow turning on or off, every cast of a tracked ability, stance and target changes;
--   what the game itself says about your class's abilities being usable: at each trigger, and
--   whenever the game changes its mind (ACTION_USABLE_CHANGED by button, SPELL_UPDATE_USABLE by
--   spell). Values the game hides come out as "secret".
-- Asking the game is for this log only: the glows never do (outside the right stance it says no).
local _, ns = ...

local Log = {}
ns.Log = Log

local MAX = 300

local TRIGGERS = {
	block = "you blocked", dodge = "you dodged", parry = "you parried", targetdodge = "your target dodged",
}

local function Data()
	LeprocDB.log = LeprocDB.log or { on = false, entries = {} }
	return LeprocDB.log
end

function Log.IsOn()
	return LeprocDB ~= nil and LeprocDB.log ~= nil and LeprocDB.log.on == true
end

-- A value as text: "secret" if the game hides it.
local function Value(v)
	if issecretvalue and issecretvalue(v) then return "secret" end
	if v == true then return "yes" end
	if v == false then return "no" end
	if v == nil then return "-" end
	return tostring(v)
end

function Log.Add(text)
	if not Log.IsOn() then return end
	local line = date("%H:%M:%S") .. "." .. (math.floor(GetTime() * 10) % 10) .. " " .. text
	local entries = Data().entries
	entries[#entries + 1] = line
	while #entries > MAX do table.remove(entries, 1) end
	print("|cffff8040Leproc log|r " .. line)
end

local function Stance()
	return ns.Bars.CurrentForm() or "no stance"
end

-- What the game says about an ability now: by spell, and by each button you can see holding it.
local function Usable(e)
	local ok, usable, short = pcall(C_Spell.IsSpellUsable, e.names[1])
	local parts = { "spell " .. (ok and (Value(usable) .. (Value(short) == "yes" and " (short of power)" or "")) or "error") }
	local check = (C_ActionBar and C_ActionBar.IsUsableAction) or IsUsableAction
	for _, slot in ipairs(ns.Bars.Slots(e)) do
		local okA, u = pcall(check, slot)
		parts[#parts + 1] = "button slot " .. slot .. " " .. (okA and Value(u) or "error")
	end
	return "game says usable: " .. table.concat(parts, ", ")
end

-- Track.lua calls these.
function Log.Trigger(trigger, unit, event, flags, opened)
	if not Log.IsOn() then return end
	local names = {}
	for _, e in ipairs(opened) do names[#names + 1] = e.label end
	Log.Add(TRIGGERS[trigger] .. " (" .. tostring(unit) .. " " .. tostring(event) .. (flags ~= "" and (" " .. tostring(flags)) or "")
		.. ") -> window " .. table.concat(names, ", ") .. ", in " .. Stance())
	for _, e in ipairs(opened) do
		if e.class == select(2, UnitClass("player")) then Log.Add("  " .. e.label .. ": " .. Usable(e)) end
	end
end

function Log.Cast(e)
	Log.Add("you cast " .. e.label .. " -> its window closes" .. (e.cooldown > 0 and (", dark for its " .. e.cooldown .. " s cooldown") or ""))
end

function Log.Glow(e, on)
	Log.Add(e.label .. " glow " .. (on and "ON" or "off") .. " (" .. Stance() .. ")")
end

-- The game changing its mind, logged only when the yes/no changes (not for rage going up and down).
local said = {}
local function Said(key, text, value)
	if said[key] == value then return end
	said[key] = value
	Log.Add(text .. value)
end

local function ClassEntries()
	return ns.ClassEntries and ns.ClassEntries() or {}
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "ACTION_USABLE_CHANGED", "SPELL_UPDATE_USABLE", "UPDATE_SHAPESHIFT_FORM", "PLAYER_TARGET_CHANGED",
	"PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
	events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event, changes)
	if not Log.IsOn() then return end
	if event == "ACTION_USABLE_CHANGED" then
		if type(changes) ~= "table" then return end
		for _, e in ipairs(ClassEntries()) do
			local slots = {}
			for _, slot in ipairs(ns.Bars.Slots(e)) do slots[slot] = true end
			for _, c in ipairs(changes) do
				if type(c) == "table" and not (issecretvalue and issecretvalue(c.slot)) and slots[c.slot] then
					Said("slot" .. c.slot, "game: " .. e.label .. " button (slot " .. c.slot .. ") usable: ", Value(c.usable))
				end
			end
		end
	elseif event == "SPELL_UPDATE_USABLE" then
		for _, e in ipairs(ClassEntries()) do
			local ok, usable = pcall(C_Spell.IsSpellUsable, e.names[1])
			Said("spell" .. e.key, "game: " .. e.label .. " spell usable: ", ok and Value(usable) or "error")
		end
	elseif event == "UPDATE_SHAPESHIFT_FORM" then
		Said("stance", "stance: ", Stance())
	elseif event == "PLAYER_TARGET_CHANGED" then
		Log.Add("new target")
	else
		Log.Add(event == "PLAYER_REGEN_DISABLED" and "combat starts" or "combat ends")
	end
end)

function Log.SetOn(on)
	Data().on = on
	wipe(said)
	if on then
		ns.Print("log on: triggers, glows, casts and what the game says about your abilities are listed here. /leproc log show to copy it, /leproc log off to stop.")
		said.stance = Stance()
		for _, e in ipairs(ClassEntries()) do
			local ok, usable = pcall(C_Spell.IsSpellUsable, e.names[1])
			said["spell" .. e.key] = ok and Value(usable) or "error"
			Log.Add(e.label .. " now: " .. Usable(e) .. ", in " .. Stance())
		end
	else
		ns.Print("log off. /leproc log show still shows what was logged.")
	end
end

function Log.Clear()
	Data().entries = {}
	ns.Print("log cleared.")
end

-- A window with the log as text, selected, for Ctrl+C.
local window
function Log.Show()
	if not window then
		window = CreateFrame("Frame", "LeprocLog", UIParent, "BackdropTemplate")
		window:SetSize(680, 380)
		window:SetPoint("CENTER")
		window:SetFrameStrata("DIALOG")
		window:SetBackdrop({
			bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true, tileSize = 16, edgeSize = 16,
			insets = { left = 4, right = 4, top = 4, bottom = 4 },
		})
		window:SetBackdropColor(0.05, 0.06, 0.09, 0.96)
		window:SetBackdropBorderColor(0.6, 0.45, 0.15, 1)
		window:EnableMouse(true)
		window:SetMovable(true)
		window:RegisterForDrag("LeftButton")
		window:SetScript("OnDragStart", window.StartMoving)
		window:SetScript("OnDragStop", window.StopMovingOrSizing)
		tinsert(UISpecialFrames, "LeprocLog")

		local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		title:SetPoint("TOPLEFT", 14, -12)
		title:SetText("Leproc log: Ctrl+C copies it (it's selected)")
		local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
		close:SetPoint("TOPRIGHT", -2, -2)

		local scroll = CreateFrame("ScrollFrame", nil, window, "UIPanelScrollFrameTemplate")
		scroll:SetPoint("TOPLEFT", 14, -36)
		scroll:SetPoint("BOTTOMRIGHT", -32, 14)
		local box = CreateFrame("EditBox", nil, scroll)
		box:SetMultiLine(true)
		box:SetAutoFocus(false)
		box:SetFontObject(ChatFontNormal)
		box:SetWidth(620)
		box:SetScript("OnEscapePressed", function() window:Hide() end)
		scroll:SetScrollChild(box)
		window.box = box
	end
	local entries = Data().entries
	window.box:SetText(#entries > 0 and table.concat(entries, "\n") or "Nothing logged yet. /leproc log turns the log on.")
	window:Show()
	window.box:SetFocus()
	window.box:HighlightText()
end
