-- Leproc: profiles. Every setting (ability modes, the glow and sound, the options window, the
-- minimap button) lives in a profile. LeprocDB.profiles holds them by name and LeprocDB.chars
-- says which one each character uses ("First Last" -> profile name). Both are account-wide so
-- every character can see and share them. A character starts with a profile named after itself.
local _, ns = ...

local P = {}
ns.Profiles = P

-- A character by first and last name. On Forever, UnitName's second value is the surname.
local function CharKey()
	local name, surname = UnitName("player")
	name = name or "?"
	if type(surname) == "string" and surname ~= "" and not (issecretvalue and issecretvalue(surname)) then
		return name .. " " .. surname
	end
	return name
end
P.CharKey = CharKey

-- What a character was called if the surname wasn't known yet when it was saved: the first name.
local function OldKey()
	return UnitName("player") or "?"
end

local fresh = {} -- profiles made this session with the defaults

-- Moves a character's old key, and a profile named after it, to the new name.
local function Rename(db, old, new)
	if old == new then return end
	if db.chars[old] and db.chars[new] then
		-- Already moved before. A profile made under the old key this session (before the surname
		-- was known) is just defaults: drop it.
		if fresh[old] and db.chars[old] == old and #P.UsedBy(old) == 1 then db.profiles[old] = nil end
	elseif db.chars[old] then
		local profile = db.chars[old]
		if profile == old and db.profiles[old] and not db.profiles[new] then
			db.profiles[new], db.profiles[old] = db.profiles[old], nil
			for char, p in pairs(db.chars) do
				if p == old then db.chars[char] = new end
			end
			profile = new
		end
		db.chars[new] = profile
	end
	db.chars[old] = nil
end

local function DeepCopy(t)
	local copy = {}
	for k, v in pairs(t) do copy[k] = type(v) == "table" and DeepCopy(v) or v end
	return copy
end

-- Points ns.db at a profile (created with the defaults if it's new) and records it as this
-- character's. Doesn't touch the display: Switch does that.
local function Use(name)
	local db = LeprocDB
	if not db.profiles[name] then fresh[name] = true end
	db.profiles[name] = ns.CopyDefaults(db.profiles[name] or {}, ns.DEFAULTS)
	db.chars[CharKey()] = name
	ns.db = db.profiles[name]
end

local function Apply()
	ns.Minimap.Apply()
	ns.Refresh()
end

function P.Init()
	LeprocDB = LeprocDB or {}
	local db = LeprocDB
	db.profiles = db.profiles or {}
	db.chars = db.chars or {}
	local me = CharKey()
	Rename(db, OldKey(), me)

	local name = db.chars[me]
	if not name or not db.profiles[name] then name = me end
	Use(name)
end

function P.Current()
	return LeprocDB.chars[CharKey()]
end

function P.Names()
	local names = {}
	for name in pairs(LeprocDB.profiles) do names[#names + 1] = name end
	table.sort(names)
	return names
end

-- The characters using a profile, as "First Last".
function P.UsedBy(name)
	local list = {}
	for char, profile in pairs(LeprocDB.chars) do
		if profile == name then list[#list + 1] = char end
	end
	table.sort(list)
	return list
end

local function CleanName(name)
	name = strtrim(name or "")
	if name == "" then return nil, "a profile needs a name." end
	return name
end

-- Each of these returns true, or nil and a reason to show the player.

function P.Switch(name)
	if not LeprocDB.profiles[name] then return nil, "there's no profile called " .. tostring(name) .. "." end
	if name == P.Current() then return true end
	Use(name)
	Apply()
	return true
end

-- A new profile with the default settings, which this character then uses.
function P.New(name)
	local err
	name, err = CleanName(name)
	if not name then return nil, err end
	if LeprocDB.profiles[name] then return nil, "there's already a profile called " .. name .. "." end
	Use(name)
	Apply()
	return true
end

-- Replaces this profile's settings with a copy of another profile's.
function P.CopyFrom(name)
	local source = LeprocDB.profiles[name]
	if not source then return nil, "there's no profile called " .. tostring(name) .. "." end
	if name == P.Current() then return nil, "that's the profile in use." end
	local copy = DeepCopy(source)
	wipe(ns.db)
	for k, v in pairs(copy) do ns.db[k] = v end
	ns.CopyDefaults(ns.db, ns.DEFAULTS)
	Apply()
	return true
end

-- Renames the profile in use; every character using it follows.
function P.Rename(name)
	local err
	name, err = CleanName(name)
	if not name then return nil, err end
	local old = P.Current()
	if name == old then return true end
	if LeprocDB.profiles[name] then return nil, "there's already a profile called " .. name .. "." end
	LeprocDB.profiles[name] = LeprocDB.profiles[old]
	LeprocDB.profiles[old] = nil
	for char, profile in pairs(LeprocDB.chars) do
		if profile == old then LeprocDB.chars[char] = name end
	end
	return true
end

-- Deletes another profile. Characters that used it get a fresh profile of their own next login.
function P.Delete(name)
	if not LeprocDB.profiles[name] then return nil, "there's no profile called " .. tostring(name) .. "." end
	if name == P.Current() then return nil, "switch to another profile before deleting this one." end
	LeprocDB.profiles[name] = nil
	for char, profile in pairs(LeprocDB.chars) do
		if profile == name then LeprocDB.chars[char] = nil end
	end
	return true
end

-- Puts every setting in the profile in use back to its default.
function P.Reset()
	wipe(ns.db)
	ns.CopyDefaults(ns.db, ns.DEFAULTS)
	Apply()
	return true
end
