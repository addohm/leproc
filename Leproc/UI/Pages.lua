-- Leproc: the options window's tabs: Abilities (your class's, each Any stance / Only in its
-- stance / Off), Glow (the glow, the sound, a test), General (minimap button, about) and Profiles.
local _, ns = ...
local UI = ns.UI

local TRIGGER_TEXT = {
	block = "you block", dodge = "you dodge", parry = "you parry", targetdodge = "your target dodges",
}

local function Icon(e)
	local texture = e.idList[1] and C_Spell.GetSpellTexture(e.idList[1])
	return "|T" .. tostring(texture or "Interface\\Icons\\INV_Misc_QuestionMark") .. ":20:20:0:0:64:64:5:59:5:59|t  "
end

local function Triggers(e)
	local parts = {}
	for _, t in ipairs(e.after) do parts[#parts + 1] = TRIGGER_TEXT[t] end
	if #parts == 1 then return parts[1] end
	return table.concat(parts, ", ", 1, #parts - 1) .. " or " .. parts[#parts]
end

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

-- def: { id, label, note, fill(stack, panel), refresh(panel) (default: sync the rows), defaults }
local function Page(def)
	ns.Window.AddPage({
		id = def.id,
		label = def.label,
		build = function(panel)
			local top = 0
			if def.note then
				local note = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
				note:SetPoint("TOPLEFT", 4, -2)
				note:SetPoint("TOPRIGHT", -28, -2)
				note:SetJustifyH("LEFT")
				note:SetText(def.note)
				top = -36
			end
			local holder = CreateFrame("Frame", nil, panel)
			holder:SetPoint("TOPLEFT", 0, top)
			holder:SetPoint("BOTTOMRIGHT")
			panel.stack = UI.Stack(holder)
			def.fill(panel.stack, panel)
		end,
		refresh = def.refresh or function(panel) panel.stack:Sync() end,
		defaults = def.defaults,
	})
end

-- Abilities: one row per ability of your class, with its mode, and whether it's on a bar you can
-- see right now (it can only glow there).
local MODE_X, MODE_BOX = 250, 150

local function ModeChoices(e)
	local list = { { "any", "Any stance" } }
	if e.stance then list[#list + 1] = { "stance", "Only in " .. e.stance } end
	list[#list + 1] = { "off", "Off" }
	return list
end

local function AbilityTooltip(e)
	local lines = { e.label, "Lights for " .. ns.WINDOW .. " s after " .. Triggers(e) .. ", or until you use it." }
	if e.stance then
		lines[#lines + 1] = "The game needs " .. e.stance .. " to use it. In Any stance it lights anyway, so you know it's worth switching."
	end
	if e.note then lines[#lines + 1] = e.note end
	lines[#lines + 1] = "Cooldown after you use it: " .. e.cooldown .. " s."
	if not ns.Bars.OnScreen(e) then
		lines[#lines + 1] = "|cffff8040Not on a bar you can see now.|r A warrior's main bar changes with stance: put it on a bar that doesn't (bars 2 to 8) to see it light in every stance."
	end
	return lines
end

local function AbilityRow(parent, e)
	local row = UI.OptionSelect(parent, "", function() return ModeChoices(e) end,
		function() return ns.Mode(e) end,
		function(mode) ns.SetMode(e, mode) end,
		{
			font = "GameFontHighlight", controlX = MODE_X, boxWidth = MODE_BOX,
			tooltip = function() return AbilityTooltip(e) end,
			sync = function(r)
				local changed = ns.db.modes[e.key] and "  |cff999999(changed)|r" or ""
				local where = ns.Bars.OnScreen(e) and "" or "  |cffff8040(not on a bar you can see)|r"
				r.label:SetText(Icon(e) .. e.label .. changed .. where)
			end,
		})
	row.entry = e
	return row
end

Page({
	id = "abilities",
	label = "Abilities",
	note = "Any stance: an ability's button glows after its trigger whatever stance or form you're in. Only in its stance: just when the game would let you use it. It can only glow on a bar you can see.",
	fill = function(stack, panel)
		local list = ns.ClassEntries()
		panel.rows = {}
		if #list == 0 then
			stack:Add(UI.OptionText(stack.inner, "Your class has no abilities Leproc tracks yet. So far it covers the ones that light after a block, dodge or parry: Revenge and Overpower (warrior), Riposte (rogue), Counterattack and Mongoose Bite (hunter).", 60))
			return
		end
		for _, e in ipairs(list) do
			panel.rows[#panel.rows + 1] = stack:Add(AbilityRow(stack.inner, e))
		end
		stack:Add(UI.OptionText(stack.inner, "Leproc watches the blocks, dodges and parries the game reports, which addons can see in combat too. It never asks the game whether a button is usable, since that's what says no outside the right stance.", 54))
	end,
	defaults = function() ns.ResetModes() end,
})

Page({
	id = "glow",
	label = "Glow",
	fill = function(stack)
		stack:Add(UI.OptionHeading(stack.inner, "On the button"))
		stack:Add(UI.GlowPreview(stack.inner))
		stack:Add(UI.OptionSelect(stack.inner, "Glow", ns.Glow.STYLES,
			function() return ns.db.glow end,
			function(v) ns.db.glow = v; ns.Refresh() end))
		stack:Add(UI.OptionSelect(stack.inner, "Glow colour", ns.Glow.COLORS,
			function() return ns.db.color end,
			function(v) ns.db.color = v; ns.Refresh() end))
		stack:Add(UI.OptionHeading(stack.inner, "Sound"))
		stack:Add(UI.OptionSound(stack.inner, "When an ability lights up",
			function() return ns.db.sound end,
			function(v) ns.db.sound = v end,
			{ "When an ability lights up", "In combat too: Leproc knows when it lights a button, since it's its own glow." }))
		stack:Add(UI.OptionHeading(stack.inner, "Try it"))
		stack:Add(UI.OptionButton(stack.inner, "Light your abilities' buttons", "Test", function() ns.Track.Test() end,
			{ "Test", "Lights every tracked ability's buttons for " .. ns.WINDOW .. " s, without the sound. Only buttons on a bar you can see glow." }))
	end,
	defaults = function()
		ns.db.glow, ns.db.color, ns.db.sound = ns.DEFAULTS.glow, ns.DEFAULTS.color, ns.DEFAULTS.sound
	end,
})

Page({
	id = "general",
	label = "General",
	fill = function(stack)
		stack:Add(UI.OptionCheck(stack.inner, "Show the minimap button",
			function() return not ns.db.minimap.hide end,
			function(v) ns.Minimap.SetShown(v) end))
		stack:Add(UI.OptionHeading(stack.inner, "About"))
		stack:Add(UI.OptionText(stack.inner, function()
			return "Leproc " .. ns.Version() .. "\n\n"
				.. "Abilities like Revenge and Overpower only work for a few seconds after you block, dodge or "
				.. "parry, or your target dodges. The game only shows them as usable in the right stance, so "
				.. "Leproc watches for the trigger itself and lights the button in any stance, so you know when "
				.. "it's worth switching.\n\n"
				.. "/leproc opens this window. /leproc help lists the chat commands."
		end, 150))
	end,
	defaults = function() ns.Minimap.SetShown(true) end,
})

-- Profiles: which profile this character uses, new ones, copying, renaming, deleting, resetting.
local Profiles = ns.Profiles

local function ProfileChoices(skipCurrent)
	return function()
		local list = {}
		for _, name in ipairs(Profiles.Names()) do
			if not (skipCurrent and name == Profiles.Current()) then list[#list + 1] = { name, name } end
		end
		return list
	end
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

Page({
	id = "profiles",
	label = "Profiles",
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

		stack:Add(UI.OptionHeading(stack.inner, "Manage"))
		stack:Add(UI.OptionEdit(stack.inner, "Rename this profile (press Enter)",
			function() return Profiles.Current() end,
			function(text) return Report(Profiles.Rename(text)) end,
			{ "Rename this profile", "Every character using it follows the new name." }))
		local getDel, setDel = Picker(fromChoices)
		stack:Add(UI.OptionSelect(stack.inner, "Delete a profile", fromChoices, getDel, setDel))
		stack:Add(UI.OptionButton(stack.inner, "", "Delete it", function()
			local name = getDel()
			if not name then return ns.Print("there's no other profile to delete.") end
			Confirm("Delete the profile " .. name .. "? Characters using it get a fresh profile of their own.",
				function() return Profiles.Delete(name) end)
		end, { "Delete a profile", "The profile in use can't be deleted: switch first." }))
		stack:Add(UI.OptionButton(stack.inner, "Every setting in this profile", "Reset to defaults", function()
			Confirm("Reset every setting in " .. Profiles.Current() .. " to the defaults?",
				function() return Profiles.Reset() end)
		end))
	end,
})
