-- Leproc: settings, modes, sounds and events. All settings live in a profile (Profiles.lua); ns.db
-- is the profile the character uses, by default its own.
local ADDON, ns = ...

ns.ICON = "Interface\\AddOns\\Leproc\\Media\\Icon" -- art/make_logo.py

local DEFAULTS = {
	modes = {},                         -- key -> "any" / "stance" / "off", only where changed
	glow = "pixel", color = "gold",     -- the glow on a lit button (Glow.STYLES, Glow.COLORS)
	sound = "none",                     -- played when an ability lights up (ns.SOUNDS)
	window = {},                        -- the options window: pos, size, tab
	minimap = { angle = 275, hide = false }, -- clear of Nothing Wasted (200), Ticky (225), Leboof (250)
}
ns.DEFAULTS = DEFAULTS

-- any: lights after its trigger in any stance or form; stance: only in the stance it needs.
ns.MODES = { any = true, stance = true, off = true }

ns.SOUNDS = {
	{ "none", "None" },
	{ "RAID_WARNING", "Raid warning" },
	{ "READY_CHECK", "Ready check" },
	{ "RAID_BOSS_EMOTE_WARNING", "Boss emote" },
	{ "UI_RAID_BOSS_WHISPER_WARNING", "Boss whisper" },
	{ "ALARM_CLOCK_WARNING_3", "Alarm clock" },
	{ "TELL_MESSAGE", "Whisper" },
	{ "MAP_PING", "Map ping" },
}

function ns.Play(name)
	local id = name and name ~= "none" and SOUNDKIT and SOUNDKIT[name]
	if id then PlaySound(id, "Master") end
end

local function CopyDefaults(dst, src)
	for k, v in pairs(src) do
		if dst[k] == nil then
			dst[k] = type(v) == "table" and CopyDefaults({}, v) or v
		elseif type(v) == "table" and type(dst[k]) == "table" then
			CopyDefaults(dst[k], v)
		end
	end
	return dst
end
ns.CopyDefaults = CopyDefaults

function ns.Print(msg)
	print("|cffff8040Leproc|r: " .. msg)
end

function ns.Version()
	local v = C_AddOns.GetAddOnMetadata(ADDON, "Version") or "?"
	return "v" .. v .. (ns.build and (" build " .. ns.build) or "")
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

-- The catalogue by key and by spell ID.
ns.byKey, ns.bySpell = {}, {}
for _, e in ipairs(ns.Catalogue) do
	ns.byKey[e.key] = e
	e.ids, e.idList = IDs(e.names)
	for _, id in ipairs(e.idList) do ns.bySpell[id] = e end
	if e.stance then e.stanceIds = IDs({ e.stance }) end
	e.label = e.label or e.names[1]
	e.triggers = {}
	for _, t in ipairs(e.after) do e.triggers[t] = true end
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

function ns.DefaultMode(e)
	local _, class = UnitClass("player")
	return e.class == class and "any" or "off"
end

function ns.Mode(e)
	local mode = ns.db.modes[e.key] or ns.DefaultMode(e)
	if mode == "stance" and not e.stance then mode = "any" end
	return mode
end

-- Saves a mode; only modes that differ from the default are kept.
function ns.SetMode(e, mode)
	if mode == "default" then mode = nil end
	ns.db.modes[e.key] = (mode and mode ~= ns.DefaultMode(e)) and mode or nil
	ns.Refresh()
end

function ns.ResetModes()
	wipe(ns.db.modes)
end

-- Glows and lit states can change at any time, in combat too: nothing here touches Blizzard's
-- protected frames, only Leproc's own overlays.
function ns.Refresh()
	if ns.Track then ns.Track.Update() end
	if ns.Window then ns.Window.Refresh() end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(_, event, arg)
	if event == "ADDON_LOADED" and arg == ADDON then
		ns.Profiles.Init()
	elseif event == "PLAYER_LOGIN" then
		ns.Profiles.Init() -- again: the surname may only be known now
		ns.Bars.Init()
		ns.Minimap.Init()
		ns.Refresh()
	end
end)

-- Slash commands ---------------------------------------------------------------------------

local MODE_WORDS = { any = "any stance", stance = "only in its stance", off = "off" }

local function List()
	local list = ns.ClassEntries()
	if #list == 0 then
		ns.Print("your class has no abilities Leproc tracks yet.")
		return
	end
	for _, e in ipairs(list) do
		local mode = ns.Mode(e)
		local where = ns.Bars.OnScreen(e) and "on a bar you can see" or "not on a bar you can see now"
		ns.Print(e.key .. (ns.db.modes[e.key] and "*" or "") .. ": " .. MODE_WORDS[mode] .. ", " .. where)
	end
	ns.Print("* = changed from the default. Set one with /leproc <ability> any|stance|off|default")
end

local function Help()
	ns.Print(ns.Version())
	ns.Print("/leproc - open or close the options window")
	ns.Print("/leproc list - your class's abilities, their modes, and whether they're on a bar you can see")
	ns.Print("/leproc <ability> any|stance|off|default - any: lights in any stance; stance: only in the one it needs")
	ns.Print("/leproc test - light your abilities' buttons for " .. ns.WINDOW .. " s")
	ns.Print("/leproc minimap - show or hide the minimap button")
	ns.Print("/leproc profile - the profile in use and the others (the Profiles tab manages them)")
	ns.Print("/leproc reset - default modes, glow and sound")
end

SLASH_LEPROC1 = "/leproc"
SLASH_LEPROC2 = "/lpr"
SlashCmdList.LEPROC = function(msg)
	local cmd, arg = strsplit(" ", strtrim(msg or ""):lower(), 2)
	if cmd == "" then
		ns.Window.Toggle()
	elseif cmd == "help" then
		Help()
	elseif cmd == "list" then
		List()
	elseif cmd == "test" then
		ns.Track.Test()
	elseif cmd == "minimap" then
		ns.Minimap.SetShown(ns.db.minimap.hide)
	elseif cmd == "profile" then
		ns.Print("profile: " .. ns.Profiles.Current() .. ". All: " .. table.concat(ns.Profiles.Names(), ", "))
	elseif cmd == "reset" then
		ns.ResetModes()
		ns.db.glow, ns.db.color, ns.db.sound = DEFAULTS.glow, DEFAULTS.color, DEFAULTS.sound
		ns.Refresh()
		ns.Print("reset.")
	elseif ns.byKey[cmd] then
		local e = ns.byKey[cmd]
		if arg ~= "default" and not ns.MODES[arg or ""] then
			ns.Print(e.label .. " is " .. MODE_WORDS[ns.Mode(e)] .. ". Use any, stance, off or default.")
			return
		end
		if arg == "stance" and not e.stance then
			ns.Print(e.label .. " doesn't need a stance, so it's the same as any.")
		end
		ns.SetMode(e, arg)
		ns.Print(e.label .. ": " .. MODE_WORDS[ns.Mode(e)])
	else
		ns.Print("unknown command or ability '" .. cmd .. "'. /leproc help lists the commands.")
	end
end
