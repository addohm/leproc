-- Leproc: the Profiles tab: which profile this character uses, new ones, copying, renaming,
-- deleting, resetting; and switching by talents or group role (from ProcGlow).
local _, ns = ...
local UI = ns.UI
local Profiles = ns.Profiles

-- Prints a failure's reason, and shows the change.
local function Report(ok, err)
	if not ok and err then ns.Print(err) end
	ns.Window.Refresh()
	return ok
end

-- The value picked in a picker whose choices change: kept while it's still a choice.
local function Picker(choices)
	local picked
	local function get()
		local list = choices()
		for _, v in ipairs(list) do
			if v[1] == picked then return picked end
		end
		picked = list[1] and list[1][1]
		return picked
	end
	return get, function(v) picked = v end
end

local function ProfileChoices(skipCurrent)
	return function()
		local list = {}
		for _, name in ipairs(Profiles.Names()) do
			if not (skipCurrent and name == Profiles.Current()) then list[#list + 1] = { name, name } end
		end
		return list
	end
end

-- For a switching rule: no change, or a profile.
local NONE = "\0none"
local function RuleChoices()
	local list = { { NONE, "(no change)" } }
	for _, name in ipairs(Profiles.Names()) do list[#list + 1] = { name, name } end
	return list
end

local function RuleRow(parent, label, tbl, key, tooltip)
	return UI.OptionSelect(parent, type(label) == "function" and "" or label, RuleChoices,
		function() return tbl()[key] or NONE end,
		function(v)
			tbl()[key] = v ~= NONE and v or nil
			Profiles.Auto(true)
			ns.Window.Refresh()
		end,
		{ tooltip = tooltip, sync = type(label) == "function" and function(row) row.label:SetText(label()) end or nil })
end

StaticPopupDialogs.LEPROC_PROFILE = {
	text = "%s",
	button1 = YES,
	button2 = NO,
	OnAccept = function(_, data) data() end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

local function Confirm(text, action)
	StaticPopup_Show("LEPROC_PROFILE", text, nil, function() Report(action()) end)
end

local function TalentsNow()
	local index, names, points = Profiles.Spec()
	local parts = {}
	for i, name in ipairs(names) do
		parts[#parts + 1] = (i == index and "|cffffd100" or "") .. name .. " " .. (points[i] or "?") .. (i == index and "|r" or "")
	end
	local role = Profiles.Role()
	local roleText = "no group role"
	for _, r in ipairs(Profiles.ROLES) do
		if r[1] == role then roleText = "you're the " .. r[2] end
	end
	return "Now: " .. table.concat(parts, " / ") .. "; " .. roleText .. "."
end

ns.Window.Page({
	id = "profiles",
	label = "Profiles",
	order = 6,
	note = "Every setting is in a profile. Each character starts with its own; pick another to share it (say, between two warriors). Profiles are kept for all your characters.",
	fill = function(stack)
		stack:Add(UI.OptionHeading(stack.inner, "This character"))
		stack:Add(UI.OptionSelect(stack.inner, "Profile in use", ProfileChoices(false),
			function() return Profiles.Current() end,
			function(name) Report(Profiles.Switch(name)) end))
		stack:Add(UI.OptionText(stack.inner, function()
			local others = {}
			for _, char in ipairs(Profiles.UsedBy(Profiles.Current())) do
				if char ~= Profiles.CharKey() then others[#others + 1] = char end
			end
			return #others > 0 and ("Also used by: " .. table.concat(others, ", ")) or "No other character uses it."
		end, 24))

		stack:Add(UI.OptionHeading(stack.inner, "New"))
		stack:Add(UI.OptionEdit(stack.inner, "New profile (type a name, press Enter)",
			function() return "" end,
			function(text) return Report(Profiles.New(text)) end,
			{ "New profile", "Starts with the default settings, and this character switches to it." }))

		local fromChoices = ProfileChoices(true)
		local getFrom, setFrom = Picker(fromChoices)
		stack:Add(UI.OptionHeading(stack.inner, "Copy"))
		stack:Add(UI.OptionSelect(stack.inner, "Copy settings from", fromChoices, getFrom, setFrom))
		stack:Add(UI.OptionButton(stack.inner, "", "Copy into this profile", function()
			local from = getFrom()
			if not from then return ns.Print("there's no other profile to copy from.") end
			Confirm("Replace the settings in " .. Profiles.Current() .. " with a copy of " .. from .. "?",
				function() return Profiles.CopyFrom(from) end)
		end))

		stack:Add(UI.OptionHeading(stack.inner, "Switch automatically"))
		stack:Add(UI.OptionCheck(stack.inner, "Switch profile by my talents or group role",
			function() return Profiles.Rules().on end,
			function(v)
				Profiles.Rules().on = v
				Profiles.Auto(true)
				ns.Window.Refresh()
			end,
			{ "Switch automatically", "This character switches to the profile you pick below for the talent tree with the most points, or for your role while you're in a group (a role wins over talents). It happens when your talents or role change, and waits for the end of combat. These rules are this character's own." }))
		stack:Add(UI.OptionText(stack.inner, TalentsNow, 24))
		local rules = Profiles.Rules
		for i = 1, 3 do
			stack:Add(RuleRow(stack.inner, function()
				local _, names = Profiles.Spec()
				return "Most points in " .. (names[i] or ("tree " .. i))
			end, function() return rules().spec end, i))
		end
		for _, r in ipairs(Profiles.ROLES) do
			stack:Add(RuleRow(stack.inner, "In a group as the " .. r[2], function() return rules().role end, r[1],
				{ "In a group as the " .. r[2], "While you're in a group with this role (picked in the group finder or set by the leader). Wins over the talent rules." }))
		end

		stack:Add(UI.OptionHeading(stack.inner, "Manage"))
		stack:Add(UI.OptionEdit(stack.inner, "Rename this profile (press Enter)",
			function() return Profiles.Current() end,
			function(text) return Report(Profiles.Rename(text)) end,
			{ "Rename this profile", "Every character using it, and every switching rule naming it, follows the new name." }))
		local getDel, setDel = Picker(fromChoices)
		stack:Add(UI.OptionSelect(stack.inner, "Delete a profile", fromChoices, getDel, setDel))
		stack:Add(UI.OptionButton(stack.inner, "", "Delete it", function()
			local name = getDel()
			if not name then return ns.Print("there's no other profile to delete.") end
			Confirm("Delete the profile " .. name .. "? Characters using it get a fresh profile of their own, and rules naming it are cleared.",
				function() return Profiles.Delete(name) end)
		end, { "Delete a profile", "The profile in use can't be deleted: switch first." }))
		stack:Add(UI.OptionButton(stack.inner, "Every setting in this profile", "Reset to defaults", function()
			Confirm("Reset every setting in " .. Profiles.Current() .. " to the defaults?",
				function() return Profiles.Reset() end)
		end))
	end,
})
