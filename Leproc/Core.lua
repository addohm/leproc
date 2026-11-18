-- Leproc: the defaults, events, the login message and /leproc. Every setting lives in a profile
-- (Profiles.lua); ns.db is the profile the character uses.
local ADDON, ns = ...

ns.ICON = "Interface\\AddOns\\Leproc\\Media\\Icon" -- art/make_logo.py

local DEFAULTS = {
	enabled = true,                     -- off: nothing glows, the addon stays loaded
	loginMessage = true,                -- a one-line reminder of /leproc in chat at login
	classColour = false,                -- the options window in your class colour
	window = { scale = 1 },             -- the options window: pos, size, tab, scale
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

-- After any setting changes, and when the profile changes: everything shown follows ns.db.
function ns.Refresh()
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
	ns.Print("/leproc profile [name] - list the profiles, or switch to one")
	ns.Print("/leproc spec - your talent trees and group role, as profile switching sees them")
	ns.Print("/leproc minimap - show or hide the minimap button")
	ns.Print("/leproc on | off - turn every glow on or off")
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
		if arg and strtrim(arg) ~= "" then
			local ok, err = ns.Profiles.Switch(strtrim(arg))
			ns.Print(ok and ("profile: " .. ns.Profiles.Current() .. ".") or err)
		else
			ns.Print("profile: " .. ns.Profiles.Current() .. ". All: " .. table.concat(ns.Profiles.Names(), ", "))
		end
	elseif cmd == "spec" then
		Spec()
	elseif cmd == "minimap" then
		ns.Minimap.SetShown(ns.db.minimap.hide)
	elseif cmd == "on" or cmd == "off" then
		ns.SetEnabled(cmd == "on")
		ns.Print(cmd == "on" and "on." or "off: nothing glows until you turn it on again.")
	else
		ns.Print("unknown command '" .. cmd .. "'. /leproc help lists the commands.")
	end
end
