-- Leproc: profiles. Every setting lives in a profile. LeprocDB.profiles holds them by name and
-- LeprocDB.chars says which one each character uses ("First Last" -> profile name). Both are
-- account-wide so every character can see and share them. A character starts with a profile named
-- after itself. LeprocDB.auto["First Last"] are that character's rules for switching by talents
-- or group role (as ProcGlow does): a role rule wins while you're in a group with a role, then the
-- talent tree with the most points.
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
	ns.Refresh()
end

function P.Init()
	LeprocDB = LeprocDB or {}
	local db = LeprocDB
	db.profiles = db.profiles or {}
	db.chars = db.chars or {}
	db.auto = db.auto or {}
	local me = CharKey()
	Rename(db, OldKey(), me)
	if db.auto[OldKey()] and OldKey() ~= me then
		db.auto[me] = db.auto[me] or db.auto[OldKey()]
		db.auto[OldKey()] = nil
	end

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
	local copy = ns.DeepCopy(source)
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
	P.EachRule(function(rules, key, profile)
		if profile == old then rules[key] = name end
	end)
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
	P.EachRule(function(rules, key, profile)
		if profile == name then rules[key] = nil end
	end)
	return true
end

-- Puts every setting in the profile in use back to its default.
function P.Reset()
	wipe(ns.db)
	ns.CopyDefaults(ns.db, ns.DEFAULTS)
	Apply()
	return true
end

-- Switching by talents or group role ------------------------------------------------------

-- The three talent trees of each class, for when the game doesn't give their names.
local TREES = {
	WARRIOR = { "Arms", "Fury", "Protection" }, PALADIN = { "Holy", "Protection", "Retribution" },
	HUNTER = { "Beast Mastery", "Marksmanship", "Survival" }, ROGUE = { "Assassination", "Combat", "Subtlety" },
	PRIEST = { "Discipline", "Holy", "Shadow" }, SHAMAN = { "Elemental", "Enhancement", "Restoration" },
	MAGE = { "Arcane", "Fire", "Frost" }, WARLOCK = { "Affliction", "Demonology", "Destruction" },
	DRUID = { "Balance", "Feral Combat", "Restoration" },
}

P.ROLES = { { "TANK", "tank" }, { "HEALER", "healer" }, { "DAMAGER", "damage dealer" } }

local function Number(v)
	if type(v) == "number" and not ns.Secret(v) then return v end
end

local function Text(v)
	if type(v) == "string" and v ~= "" and not ns.Secret(v) then return v end
end

-- Forever's talents: one trait tree for the class, with a group for each talent tree (Arms, Fury,
-- Protection), whose currency says how many points are spent in it. The active config follows
-- dual spec.
local function TraitTrees()
	if not (C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_Traits and C_Traits.GetConfigInfo
		and C_Traits.GetGroupDisplayInfoByTreeID and C_Traits.GetGroupCurrencyInfo) then return end
	local configID = Number(C_ClassTalents.GetActiveConfigID())
	local info = configID and C_Traits.GetConfigInfo(configID)
	local treeID = info and info.treeIDs and Number(info.treeIDs[1])
	if not treeID then return end
	local groups = {}
	for _, g in ipairs(C_Traits.GetGroupDisplayInfoByTreeID(treeID) or {}) do
		if Number(g.groupID) then groups[#groups + 1] = g end
	end
	if #groups == 0 then return end
	table.sort(groups, function(a, b) return (Number(a.orderIndex) or 0) < (Number(b.orderIndex) or 0) end)
	local ids = {}
	for i, g in ipairs(groups) do ids[i] = g.groupID end
	local spent = {}
	for _, c in ipairs(C_Traits.GetGroupCurrencyInfo(configID, ids) or {}) do
		local total = 0
		for _, ci in ipairs(c.currencyInfos or {}) do total = total + (Number(ci.spent) or 0) end
		if Number(c.traitNodeGroupID) then spent[c.traitNodeGroupID] = total end
	end
	local trees = {}
	for i, g in ipairs(groups) do trees[i] = { name = Text(g.displayName), points = spent[g.groupID] } end
	return trees
end

-- The classic talent tabs, where a client has them: (name, icon, points) or (id, name, description,
-- icon, points).
local function TalentTabs()
	if not (GetNumTalentTabs and GetTalentTabInfo) then return end
	local trees = {}
	for i = 1, Number(GetNumTalentTabs()) or 0 do
		local a, b, c, _, e = GetTalentTabInfo(i)
		if type(a) == "string" then
			trees[i] = { name = Text(a), points = Number(c) }
		else
			trees[i] = { name = Text(b), points = Number(e) }
		end
	end
	if #trees > 0 then return trees end
end

-- The talent tree with the most points (its index, or nil with none spent), and every tree as
-- { name, points }: names and points (nil where the game didn't say).
function P.Spec()
	local _, class = UnitClass("player")
	local fallback = TREES[class] or {}
	local ok, trees = pcall(TraitTrees)
	if not (ok and trees) then
		ok, trees = pcall(TalentTabs)
		if not ok then trees = nil end
	end
	trees = trees or {}
	local names, points, best, index = {}, {}, 0, nil
	for i = 1, math.max(#trees, #fallback) do
		local t = trees[i] or {}
		names[i] = t.name or fallback[i] or ("Tree " .. i)
		points[i] = t.points
		if t.points and t.points > best then best, index = t.points, i end
	end
	return index, names, points
end

-- Your role in a group ("TANK", "HEALER", "DAMAGER"), or nil when you're not in one or have none.
function P.Role()
	if not (IsInGroup and IsInGroup() and UnitGroupRolesAssigned) then return nil end
	local ok, role = pcall(UnitGroupRolesAssigned, "player")
	if not ok or ns.Secret(role) then return nil end
	if role == "TANK" or role == "HEALER" or role == "DAMAGER" then return role end
end

-- This character's rules: { on, spec = { [tree index] = profile }, role = { [role] = profile } }.
function P.Rules()
	local key = CharKey()
	local rules = LeprocDB.auto[key]
	if not rules then
		rules = { on = false, spec = {}, role = {} }
		LeprocDB.auto[key] = rules
	end
	rules.spec, rules.role = rules.spec or {}, rules.role or {}
	return rules
end

-- fn(rules table, key, profile name) for every rule of every character.
function P.EachRule(fn)
	for _, rules in pairs(LeprocDB.auto or {}) do
		for _, t in ipairs({ rules.spec or {}, rules.role or {} }) do
			for key, profile in pairs(t) do fn(t, key, profile) end
		end
	end
end

local lastKey, pending

-- Switches to the profile the rules give for your talents and role, when they've changed (or
-- always, with force). Waits for the end of combat.
function P.Auto(force)
	if not ns.db then return end
	local rules = P.Rules()
	if not rules.on then
		lastKey = nil
		return
	end
	local index, names = P.Spec()
	local role = P.Role()
	local key = tostring(index) .. ":" .. tostring(role)
	if key == lastKey and not force then return end
	if InCombatLockdown() then
		pending = true
		return
	end
	pending, lastKey = false, key
	local target, why = role and rules.role[role], nil
	if target and LeprocDB.profiles[target] then
		for _, r in ipairs(P.ROLES) do
			if r[1] == role then why = "you're the " .. r[2] end
		end
	else
		target = index and rules.spec[index]
		why = index and ("most of your points are in " .. names[index])
	end
	if target and LeprocDB.profiles[target] and target ~= P.Current() then
		P.Switch(target)
		ns.Print("profile " .. target .. ": " .. why .. ".")
	end
end

local autoEvents = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_TALENT_UPDATE", "ACTIVE_TALENT_GROUP_CHANGED",
	"TRAIT_CONFIG_UPDATED", "CHARACTER_POINTS_CHANGED", "GROUP_ROSTER_UPDATE", "PLAYER_ROLES_ASSIGNED",
	"PLAYER_REGEN_ENABLED" }) do
	pcall(autoEvents.RegisterEvent, autoEvents, event) -- some may not exist on every client
end
autoEvents:SetScript("OnEvent", function(_, event)
	if not ns.db then return end
	if event == "PLAYER_REGEN_ENABLED" then
		if pending then P.Auto(true) end
	elseif event == "PLAYER_ENTERING_WORLD" then
		-- talents can take a moment to load after a login or loading screen
		C_Timer.After(4, function() P.Auto(true) end)
	else
		C_Timer.After(1, function() P.Auto() end)
	end
end)
