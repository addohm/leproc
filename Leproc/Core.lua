-- Leproc: the defaults, events, the login message and /leproc. Every setting lives in a profile
-- (Profiles.lua); ns.db is the profile the character uses.
local ADDON, ns = ...

ns.ICON = "Interface\\AddOns\\Leproc\\Media\\Icon" -- art/make_logo.py

local DEFAULTS = {
	enabled = true,                     -- off: nothing glows, the addon stays loaded
	modes = {},                         -- ability key -> "any" / "stance" / "off", only where changed
	glow = "pixel", color = "gold",     -- the glow on a lit button (Glow.STYLES, Glow.COLORS) until step 3
	loginMessage = true,                -- a one-line reminder of /leproc in chat at login
	classColour = false,                -- the options window in your class colour
	window = {},                        -- the options window: pos, size, tab
	minimap = { angle = 275, hide = false }, -- clear of Nothing Wasted (200), Ticky (225), Leboof (250)
}
ns.DEFAULTS = DEFAULTS

function ns.CopyDefaults(dst, src)
	for k, v in pairs(src) do
		if dst[k] == nil then
			dst[k] = type(v) == "table" and ns.CopyDefaults({}, v) or v
		elseif type(v) == "table" and type(dst[k]) == "table" then
			ns.CopyDefaults(dst[k], v)
		end
	end
	return dst
end

function ns.DeepCopy(t)
	local copy = {}
	for k, v in pairs(t) do copy[k] = type(v) == "table" and ns.DeepCopy(v) or v end
	return copy
end

function ns.Print(msg)
	print("|cffff8040Leproc|r: " .. msg)
end

-- "v1.0.0"; with withBuild, the build too ("v1.0.0 build abc1234"). The build is for chat only,
-- never the window.
function ns.Version(withBuild)
	local v = C_AddOns.GetAddOnMetadata(ADDON, "Version") or "?"
	return "v" .. v .. (withBuild and ns.build and (" build " .. ns.build) or "")
end

-- A value the game may hide from addons (in combat, in instances) is never compared: this says
-- whether it can be used at all.
function ns.Secret(v)
	return issecretvalue ~= nil and issecretvalue(v) == true
end

function ns.Enabled()
	return ns.db.enabled ~= false
end

function ns.SetEnabled(on)
	ns.db.enabled = on and true or false
	ns.Refresh()
end

-- Spell IDs (from Data.lua) as a set and a list.
local function IDs(names)
	local set, list = {}, {}
	for _, name in ipairs(names) do
		for _, id in ipairs(ns.SpellIDs[name] or {}) do
			if not set[id] then
				set[id] = true
				list[#list + 1] = id
			end
		end
	end
	return set, list
end

-- The catalogue by key and by spell ID (every rank).
ns.byKey, ns.bySpell = {}, {}
for _, e in ipairs(ns.Catalogue) do
	ns.byKey[e.key] = e
	e.label = e.label or e.names[1]
	e.ids, e.idList = IDs(e.names)
	for _, id in ipairs(e.idList) do ns.bySpell[id] = e end
	if e.stances then e.stanceIds = IDs(e.stances) end
	e.triggers = {}
	for _, t in ipairs(e.after) do e.triggers[t] = true end
	if e.targetTypes then
		e.types = {}
		for _, t in ipairs(e.targetTypes) do e.types[t] = true end
	end
end

-- Your class's abilities, in catalogue order.
function ns.ClassEntries()
	local _, class = UnitClass("player")
	local list = {}
	for _, e in ipairs(ns.Catalogue) do
		if e.class == class then list[#list + 1] = e end
	end
	return list
end

-- An ability's mode: "any" (lights in any stance, from its trigger), "stance" (only in the stance
-- the game needs) or "off". Your class's are "any" by default, other classes' "off".
function ns.DefaultMode(e)
	local _, class = UnitClass("player")
	return e.class == class and "any" or "off"
end

function ns.Mode(e)
	local mode = ns.db.modes[e.key] or ns.DefaultMode(e)
	if mode == "stance" and not e.stances then mode = "any" end
	return mode
end

-- Saves a mode; only modes that differ from the default are kept.
function ns.SetMode(e, mode)
	if mode == "default" then mode = nil end
	ns.db.modes[e.key] = (mode and mode ~= ns.DefaultMode(e)) and mode or nil
	ns.Refresh()
end

-- After any setting changes, and when the profile changes: everything shown follows ns.db.
function ns.Refresh()
	if ns.Track then ns.Track.Update() end
	if ns.Theme then ns.Theme.Apply() end
	if ns.Minimap then ns.Minimap.Apply() end
	if ns.Window then ns.Window.Apply() end
end

-- "Reset all settings": every profile, every character's choices, then a reload.
StaticPopupDialogs.LEPROC_RESET_ALL = {
	text = "Reset every Leproc setting, in every profile and for every character, and reload the interface?",
	button1 = YES,
	button2 = NO,
	OnAccept = function()
		LeprocDB = nil
		ReloadUI()
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

function ns.ResetAll()
	StaticPopup_Show("LEPROC_RESET_ALL")
end

-- Once per session, at the first PLAYER_ENTERING_WORLD: a welcome the first time, then a short
-- reminder unless it's turned off.
local greeted = false
local function Greet()
	if greeted then return end
	greeted = true
	if not LeprocDB.welcomed then
		LeprocDB.welcomed = true
		ns.Print("thanks for installing! Type |cffffd100/leproc|r or click the minimap button to choose what glows.")
	elseif ns.db.loginMessage then
		ns.Print(ns.Version(true) .. " loaded. Type |cffffd100/leproc|r to open the options.")
	end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function(_, event, arg)
	if event == "ADDON_LOADED" and arg == ADDON then
		ns.Profiles.Init()
	elseif event == "PLAYER_LOGIN" then
		ns.Profiles.Init() -- again: the surname may only be known now
		ns.Bars.Init()
		ns.Minimap.Init()
		ns.Window.Register()
		ns.Refresh()
	elseif event == "PLAYER_ENTERING_WORLD" then
		Greet()
	end
end)

-- Slash commands ---------------------------------------------------------------------------

-- /leproc <page> opens that tab (the words ProcGlow's players know work too).
local PAGE_WORDS = {
	general = "general", settings = "general",
	abilities = "abilities", classes = "abilities", procs = "abilities",
	glow = "glow", style = "glow", effects = "glow",
	timer = "timer", stacks = "timer",
	text = "text", popups = "text",
	profiles = "profiles",
}

local function Help()
	ns.Print(ns.Version(true))
	ns.Print("/leproc - open or close the options window")
	ns.Print("/leproc general | abilities | glow | timer | text | profiles - open that tab")
	ns.Print("/leproc profile - the profile in use, and the Profiles tab (where they're managed)")
	ns.Print("/leproc spec - your talent trees and group role, as profile switching sees them")
	ns.Print("/leproc minimap - show or hide the minimap button")
	ns.Print("/leproc on | off - turn every glow on or off")
	ns.Print("/leproc test - light your abilities' buttons for " .. ns.WINDOW .. " s")
	ns.Print("/leproc why <ability> - why it is or isn't glowing right now")
	ns.Print("/leproc bars - the action buttons Leproc found, and which hold your abilities; /leproc rescan looks again")
	ns.Print("/leproc macros - the macros on your bars, and the abilities each counts for")
	ns.Print("/leproc log [off | show | clear] - log every trigger, glow and cast, and what the game says about your abilities")
end

local MODE_WORDS = { any = "any stance", stance = "only in its stance", off = "off" }

local function Lines(lines)
	for _, line in ipairs(lines) do ns.Print(line) end
end

-- /leproc why <ability>: everything that decides whether it glows right now.
local function Why(e)
	local s = ns.Track.State(e)
	local _, class = UnitClass("player")
	local lines = { e.label .. ": " .. MODE_WORDS[ns.Mode(e)] .. (ns.db.modes[e.key] and " (changed)" or " (default)")
		.. (e.class ~= class and (", not your class (" .. e.class:lower() .. ")") or "")
		.. (ns.Enabled() and "" or ", |cffff8040Leproc is off|r") }
	lines[#lines + 1] = "lit now: " .. (ns.Track.IsLit(e) and "yes" or "no") .. (s.test and " (the test is on)" or "")
	lines[#lines + 1] = "cooldown: " .. (s.cooldown and string.format("%.1f s left", s.cooldown) or "ready")
		.. (s.gameCooldown == nil and " (the game hides its own cooldown now: timed from your cast)" or "")
	lines[#lines + 1] = "Blizzard's highlight: " .. (s.overlay and "on (it lights)" or "off")
	if e.types then
		lines[#lines + 1] = "target: " .. (s.target == nil and "the game hides what it is (or none)" or (s.target and "undead or a demon" or "not undead or a demon"))
	end
	local GAME = { yes = "usable", short = "usable, short of power", no = "not usable" }
	lines[#lines + 1] = "game: " .. (s.game and (GAME[s.game] .. " (it decides here)")
		or (#e.after > 0 and "can't say here (not in its stance): Leproc's window decides" or "can't say here (not in its stance)"))
	if #e.after > 0 then
		local after = {}
		for _, t in ipairs(e.after) do after[#after + 1] = ns.Track.TRIGGERS[t] end
		lines[#lines + 1] = "window: " .. (s.window and string.format("open, %.1f s left", s.window)
			or ("closed (opens " .. ns.WINDOW .. " s after " .. table.concat(after, ", ") .. ")"))
		if e.triggers.targetdodge and ns.Track.Grouped() then
			lines[#lines + 1] = "in a group: your target's dodges open no window of Leproc's (the game doesn't say whose attack it was), so it lights where the game decides"
		end
		local kind = e.after[1] == "targetdodge" and "target" or "player"
		lines[#lines + 1] = string.format("delay: the game's reports of %s come about %.1f s late; Leproc's own window ends that much sooner",
			kind == "target" and "your target's dodges" or "your blocks, dodges and parries", ns.Track.Delay(kind))
	end
	if e.stances then
		lines[#lines + 1] = "stance: needs " .. table.concat(e.stances, " or ") .. ", you're " .. (s.inStance and "in it" or "not in it")
	end
	local where = ns.Bars.Where(e)
	lines[#lines + 1] = "on screen: " .. (#where > 0 and table.concat(where, ", ") or "no button you can see holds it")
	local points = ns.Bars.Pointing(e)
	if #points > 0 then
		lines[#lines + 1] = "so the buttons for " .. table.concat(points, " or ") .. " glow instead (switch, and it's there)"
	end
	Lines(lines)
end

local function Spec()
	local index, names, points = ns.Profiles.Spec()
	local parts = {}
	for i, name in ipairs(names) do
		parts[#parts + 1] = name .. " " .. (points[i] and (points[i] .. " points") or "?")
	end
	ns.Print("talents: " .. (#parts > 0 and table.concat(parts, ", ") or "none found")
		.. "; most points: " .. (index and names[index] or "none"))
	ns.Print("group role: " .. (ns.Profiles.Role() or "none (not in a group, or no role)"))
	local auto = ns.Profiles.Rules()
	ns.Print("switching by talents or role: " .. (auto.on and "on" or "off") .. "; profile in use: " .. ns.Profiles.Current())
end

SLASH_LEPROC1 = "/leproc"
SLASH_LEPROC2 = "/lpr"
SlashCmdList.LEPROC = function(msg)
	local raw = strtrim(msg or "")
	local cmd, arg = strsplit(" ", raw, 2)
	cmd = (cmd or ""):lower()
	if cmd == "" then
		ns.Window.Toggle()
	elseif PAGE_WORDS[cmd] then
		ns.Window.Show(PAGE_WORDS[cmd])
	elseif cmd == "help" then
		Help()
	elseif cmd == "profile" then
		-- profiles are managed on their tab, nowhere else
		ns.Print("profile: " .. ns.Profiles.Current() .. ". They're managed on the Profiles tab.")
		ns.Window.Show("profiles")
	elseif cmd == "spec" then
		Spec()
	elseif cmd == "minimap" then
		ns.Minimap.SetShown(ns.db.minimap.hide)
	elseif cmd == "test" then
		ns.Track.Test()
	elseif cmd == "why" then
		local e = ns.byKey[(arg or ""):lower():gsub("%s", "")]
		if not e then
			local keys = {}
			for _, c in ipairs(ns.ClassEntries()) do keys[#keys + 1] = c.key end
			ns.Print("why which? " .. (#keys > 0 and table.concat(keys, ", ") or "your class has no abilities Leproc tracks yet"))
			return
		end
		Why(e)
	elseif cmd == "bars" then
		Lines(ns.Bars.Report())
	elseif cmd == "rescan" then
		ns.Bars.Scan()
		ns.Refresh()
		Lines(ns.Bars.Report())
	elseif cmd == "macros" then
		Lines(ns.Bars.MacroReport())
	elseif cmd == "log" then
		arg = (arg or ""):lower()
		if arg == "off" then ns.Log.SetOn(false)
		elseif arg == "show" then ns.Log.Show()
		elseif arg == "clear" then ns.Log.Clear()
		else ns.Log.SetOn(true) end
	elseif cmd == "on" or cmd == "off" then
		ns.SetEnabled(cmd == "on")
		ns.Print(cmd == "on" and "on." or "off: nothing glows until you turn it on again.")
	else
		ns.Print("unknown command '" .. cmd .. "'. /leproc help lists the commands.")
	end
end
