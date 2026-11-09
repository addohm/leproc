-- Leproc: /leproc log, for finding out why an ability lights when it shouldn't (or the other way
-- round). While it's on, it prints and keeps (the last 2000 lines, account-wide in LeprocDB.log):
--   every trigger the game reports (UNIT_COMBAT), the windows it opens, the stance you're in;
--   every glow turning on or off, every spell you cast, stance and target changes, deaths;
--   what the game itself says about your class's abilities being usable: at each trigger, and
--   whenever the game changes its mind (ACTION_USABLE_CHANGED by button, SPELL_UPDATE_USABLE by
--   spell). Values the game hides come out as "secret".
--   Blizzard's proc highlights (SPELL_ACTIVATION_OVERLAY_GLOW_SHOW/HIDE, SPELL_ACTIVATION_OVERLAY_
--   SHOW/HIDE) for any spell, and at each trigger whether the game highlights the ability
--   (C_SpellActivationOverlay.IsSpellOverlayed): a probe for a signal that might say "your own
--   attack was dodged" in any stance (Forever's Bloodthrill speaks of "an activation of Overpower").
-- Asking the game is for this log only: the glows never do (outside the right stance it says no).
local _, ns = ...

local Log = {}
ns.Log = Log

local MAX = 2000

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
	-- The clock to the second, then the game's timer to a tenth (the clock has no tenths: mixing
	-- the two put lines out of order).
	local line = date("%H:%M:%S") .. string.format(" t%.1f ", GetTime()) .. text
	local entries = Data().entries
	entries[#entries + 1] = line
	while #entries > MAX do table.remove(entries, 1) end
	print("|cffff8040Leproc log|r " .. line)
end

local function Stance()
	return ns.Bars.CurrentForm() or "no stance"
end

-- The game's answer as text: "yes", "no", "no (short of power)" (the only reason is rage, energy
-- or mana), or "secret".
local function Answer(usable, short)
	local text = Value(usable)
	if text == "no" and Value(short) == "yes" then text = "no (short of power)" end
	return text
end

local function SpellAnswer(e)
	local ok, usable, short = pcall(C_Spell.IsSpellUsable, e.names[1])
	return ok and Answer(usable, short) or "error"
end

-- Whether the game highlights the ability (its proc glow), any rank: "yes", "no", "secret", or
-- nil if the client has no such call.
local function Highlighted(e)
	local api = C_SpellActivationOverlay and C_SpellActivationOverlay.IsSpellOverlayed
	if not api then return nil end
	local answer = "no"
	for _, id in ipairs(e.idList) do
		local ok, on = pcall(api, id)
		local v = ok and Value(on) or "error"
		if v == "yes" or v == "secret" or v == "error" then answer = v end
		if v == "yes" then break end
	end
	return answer
end

local function SpellLabel(id)
	if issecretvalue and issecretvalue(id) then return "a hidden spell" end
	local e = ns.bySpell[id]
	if e then return e.label .. " (" .. tostring(id) .. ")" end
	local ok, name = pcall(C_Spell.GetSpellName, id)
	if ok and type(name) == "string" and not (issecretvalue and issecretvalue(name)) then return name .. " (" .. tostring(id) .. ")" end
	return "spell " .. tostring(id)
end

-- What the game says about an ability now: by spell, by each button you can see holding it, and
-- whether it highlights it.
local function Usable(e)
	local parts = { "spell " .. SpellAnswer(e) }
	local check = (C_ActionBar and C_ActionBar.IsUsableAction) or IsUsableAction
	for _, slot in ipairs(ns.Bars.Slots(e)) do
		local okA, u, short = pcall(check, slot)
		parts[#parts + 1] = "button slot " .. slot .. " " .. (okA and Answer(u, short) or "error")
	end
	local lit = Highlighted(e)
	return "game says usable: " .. table.concat(parts, ", ") .. (lit and (", highlighted: " .. lit) or "")
end

local function Mine(e)
	return e.class == select(2, UnitClass("player"))
end

-- Track.lua calls these.
function Log.Trigger(trigger, unit, event, flags, opened, length)
	if not Log.IsOn() then return end
	local names = {}
	for _, e in ipairs(opened) do
		if Mine(e) then names[#names + 1] = e.label end
	end
	Log.Add(TRIGGERS[trigger] .. " (" .. tostring(unit) .. " " .. tostring(event) .. (flags ~= "" and (" " .. tostring(flags)) or "")
		.. ") -> " .. (#names > 0 and ("window " .. table.concat(names, ", ") .. string.format(" (%.1f s, allowing for the delay)", length)) or "nothing of yours")
		.. ", in " .. Stance())
	for _, e in ipairs(opened) do
		if Mine(e) then Log.Add("  " .. e.label .. ": " .. Usable(e)) end
	end
end

function Log.Cast(e)
	Log.Add("you cast " .. e.label .. " -> its window closes" .. (e.cooldown > 0 and (", dark for its " .. e.cooldown .. " s cooldown") or ""))
end

function Log.GameOpened(e)
	Log.Add("game: " .. e.label .. " became usable -> it lights now")
end

function Log.GameClosed(e)
	Log.Add("game: " .. e.label .. " no longer usable -> its window closes")
end

function Log.Delay(kind, seconds, now)
	Log.Add(string.format("the %s report came %.1f s after the game: delay now %.2f s",
		kind == "target" and "target's dodge" or "block/dodge/parry", seconds, now))
end

function Log.Cleared(why)
	Log.Add("windows cleared: " .. why)
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
	"PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_DEAD" }) do
	events:RegisterEvent(event)
end
-- The proc highlights: registered one by one, in case a client lacks any of them.
for _, event in ipairs({ "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE",
	"SPELL_ACTIVATION_OVERLAY_SHOW", "SPELL_ACTIVATION_OVERLAY_HIDE" }) do
	pcall(events.RegisterEvent, events, event)
end
local HIGHLIGHTS = {
	SPELL_ACTIVATION_OVERLAY_GLOW_SHOW = "game: button highlight ON for ",
	SPELL_ACTIVATION_OVERLAY_GLOW_HIDE = "game: button highlight off for ",
	SPELL_ACTIVATION_OVERLAY_SHOW = "game: screen proc alert ON for ",
	SPELL_ACTIVATION_OVERLAY_HIDE = "game: screen proc alert off for ",
}
events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
events:SetScript("OnEvent", function(_, event, changes, _, spellID)
	if not Log.IsOn() then return end
	if event == "ACTION_USABLE_CHANGED" then
		if type(changes) ~= "table" then return end
		for _, e in ipairs(ClassEntries()) do
			local slots = {}
			for _, slot in ipairs(ns.Bars.Slots(e)) do slots[slot] = true end
			for _, c in ipairs(changes) do
				if type(c) == "table" and not (issecretvalue and issecretvalue(c.slot)) and slots[c.slot] then
					Said("slot" .. c.slot, "game: " .. e.label .. " button (slot " .. c.slot .. ") usable: ", Answer(c.usable, c.noMana))
				end
			end
		end
	elseif event == "SPELL_UPDATE_USABLE" then
		for _, e in ipairs(ClassEntries()) do
			Said("spell" .. e.key, "game: " .. e.label .. " spell usable: ", SpellAnswer(e))
		end
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		-- Tracked abilities are logged by Track (with what happens to their window).
		if issecretvalue and issecretvalue(spellID) then
			Log.Add("you cast something (the game hides which)")
		elseif not ns.bySpell[spellID] then
			local ok, name = pcall(C_Spell.GetSpellName, spellID)
			Log.Add("you cast " .. ((ok and type(name) == "string" and not (issecretvalue and issecretvalue(name))) and name or ("spell " .. tostring(spellID))))
		end
	elseif event == "PLAYER_DEAD" then
		Log.Add("you died")
	elseif HIGHLIGHTS[event] then
		local id = changes
		Log.Add(HIGHLIGHTS[event] .. (id ~= nil and SpellLabel(id) or "everything") .. ", in " .. Stance())
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
			said["spell" .. e.key] = SpellAnswer(e)
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
