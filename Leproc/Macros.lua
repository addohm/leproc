-- Leproc: which ability a macro button is. A button is the ability it shows. For a macro the game
-- reports the spell it shows for that slot (GetActionInfo: "macro", spellID, "spell"): its
-- #showtooltip spell, else the first /cast that applies now. The owner's dumps prove it: an MKR
-- macro showing Retaliation, which never casts it, reports Retaliation. So a macro counts as the
-- spell on its icon, two macros with one name don't get mixed up, and a Shield Block macro with a
-- "/cast [stance:2] Revenge" line is still Shield Block's button.
--
-- One case needs the macro's text: a stance-dance macro without a #showtooltip naming the ability
-- (/cast [nostance:2] Defensive Stance; Revenge) shows the stance until you switch. While a macro
-- shows one of your stances, Leproc reads its text and works out what it would show in each
-- stance: only the stance conditions are decided, for a press without modifiers, in combat, with
-- a target. If that's a tracked ability in the stance it needs, the button is that ability's too,
-- so it lights in any stance like the ability does. The text is the macro's own: of the macros
-- with the button's name, the ones the game says show what the slot shows (GetMacroSpell).
local _, ns = ...

local Macros = {}
ns.Macros = Macros

local Secret = ns.Secret

local function Number(v)
	if type(v) == "number" and not Secret(v) and v > 0 then return v end
end

local function Text(v)
	if type(v) == "string" and v ~= "" and not Secret(v) then return v end
end

-- Tracked abilities by lower-case name: the English names, and the game's own (localized).
local byName = {}
function Macros.Names()
	for _, e in ipairs(ns.Catalogue) do
		for _, name in ipairs(e.names) do byName[name:lower()] = e end
		for _, id in ipairs(e.idList) do
			local ok, name = pcall(C_Spell.GetSpellName, id)
			if ok and Text(name) then byName[name:lower()] = e end
		end
	end
end

-- Your stances and forms: spell ID -> its number in macro conditions ([stance:2]).
local function Forms()
	local forms = {}
	local ok, n = pcall(GetNumShapeshiftForms)
	for i = 1, (ok and Number(n)) or 0 do
		local okInfo, _, _, _, id = pcall(GetShapeshiftFormInfo, i)
		if okInfo and Number(id) then forms[id] = i end
	end
	return forms
end

function Macros.IsForm(spellID)
	return Forms()[spellID] ~= nil
end

-- Does one condition hold in that stance? Only stances are decided; the rest is a plain press
-- (no modifier) in combat, with a target: anything else is taken as true.
local function Holds(cond, stance)
	local no, word, value = cond:match("^%s*(n?o?)([%a@]+):?(.-)%s*$")
	if not word then return true end
	if no ~= "no" then no, word = "", no .. word end
	local negate = no == "no"
	local result
	if word == "stance" or word == "form" then
		if value == "" then
			result = stance > 0
		else
			result = false
			for n in value:gmatch("%d+") do
				if tonumber(n) == stance then result = true end
			end
		end
	elseif word == "mod" or word == "modifier" then
		result = false
	elseif word == "combat" then
		result = true
	else
		return true
	end
	if negate then return not result end
	return result
end

-- Does a [group] of conditions hold (all of them)?
local function GroupHolds(group, stance)
	for cond in group:gmatch("[^,]+") do
		if not Holds(cond, stance) then return false end
	end
	return true
end

-- A spell's name as written in a macro, lower case: no "!", "(Rank 3)", "(Racial)".
local function Clean(name)
	name = name:gsub("%b()", ""):gsub("^[%s!]+", ""):gsub("%s+$", "")
	return name ~= "" and name or nil
end

-- The spell the arguments of a /cast or #showtooltip line pick in that stance: the first clause
-- whose conditions hold ("[c1][c2] Spell; [c3] Other; Fallback"). For /castsequence, its first
-- spell.
local function Pick(args, stance)
	for clause in (args .. ";"):gmatch("([^;]*);") do
		local groups, held = {}, false
		local rest = clause:gsub("^%s*", "")
		while rest:sub(1, 1) == "[" do
			local group = rest:match("^%b[]")
			if not group then break end
			groups[#groups + 1] = group:sub(2, -2)
			rest = rest:sub(#group + 1):gsub("^%s*", "")
		end
		if #groups == 0 then
			held = true
		else
			for _, g in ipairs(groups) do
				if GroupHolds(g, stance) then held = true end
			end
		end
		if held then
			rest = rest:gsub("reset=%S+", "")
			local name = Clean(rest:match("^[^,]*") or "")
			if name then return name end
		end
	end
end

-- What a macro shows in stance number `stance`: its #showtooltip spell if it names one, else the
-- first /cast, /castsequence or /use that applies. Lower case, or nil.
local shows = {}
function Macros.Shows(body, stance)
	local key = stance .. "\0" .. body
	if shows[key] ~= nil then return shows[key] or nil end
	local found
	for line in body:lower():gmatch("[^\n]+") do
		local tip = line:match("^%s*#show%a*%s+(.+)")
		local cast = line:match("^%s*/cast%a*%s+(.+)") or line:match("^%s*/use%s+(.+)")
		local args = tip or cast
		if args then
			found = Pick(args, stance)
			if found then break end
		end
	end
	shows[key] = found or false
	return found
end

-- The texts of the macro on a slot: the macros with the button's name that show what the slot
-- shows (two macros can share a name), else every macro with that name.
local function Bodies(slot, shownID)
	local getText = (C_ActionBar and C_ActionBar.GetActionText) or GetActionText
	local ok, name = pcall(getText, slot)
	name = ok and Text(name)
	if not name then return {} end
	local okNum, account, character = pcall(GetNumMacros)
	if not okNum then return {} end
	local indexes = {}
	for i = 1, Number(account) or 0 do indexes[#indexes + 1] = i end
	local first = (MAX_ACCOUNT_MACROS or 120) + 1
	for i = first, first + (Number(character) or 0) - 1 do indexes[#indexes + 1] = i end
	local named, matching = {}, {}
	for _, i in ipairs(indexes) do
		local okInfo, mName, _, body = pcall(GetMacroInfo, i)
		if okInfo and Text(mName) == name and Text(body) then
			named[#named + 1] = body
			local okSpell, id = pcall(GetMacroSpell, i)
			if okSpell and Number(id) == shownID then matching[#matching + 1] = body end
		end
	end
	return #matching > 0 and matching or named
end

-- The tracked abilities a macro showing one of your stances is a stance-dance for: those it would
-- show in the stance they need. With more than one candidate text, only what they all agree on.
function Macros.Dance(slot, shownID)
	local forms = Forms()
	if not forms[shownID] then return {} end
	local agreed
	for _, body in ipairs(Bodies(slot, shownID)) do
		local here = {}
		for _, e in ipairs(ns.Catalogue) do
			for id in pairs(e.stanceIds or {}) do
				local stance = forms[id]
				if stance and byName[Macros.Shows(body, stance) or ""] == e then here[e] = true end
			end
		end
		if agreed then
			for e in pairs(agreed) do
				if not here[e] then agreed[e] = nil end
			end
		else
			agreed = here
		end
	end
	local list = {}
	for _, e in ipairs(ns.Catalogue) do
		if agreed and agreed[e] then list[#list + 1] = e end
	end
	return list
end
