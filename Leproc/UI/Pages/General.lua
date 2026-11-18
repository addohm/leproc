-- Leproc: the General tab, as ProcGlow's General Settings: turning Leproc on and off, the minimap
-- button, the login reminder, the class-coloured window, resetting everything, and the commands.
local _, ns = ...
local UI = ns.UI

local GOLD = "|cffffd100"

ns.Window.Page({
	id = "general",
	label = "General",
	order = 1,
	fill = function(stack)
		stack:Add(UI.OptionHeading(stack.inner, "Getting started"))
		stack:Add(UI.OptionText(stack.inner,
			GOLD .. "Procs & Buffs|r: start here. For each ability, choose what it does when it's ready: "
			.. "glow its action button, show a text popup, or show an icon with a timer.\n"
			.. GOLD .. "Glow|r, " .. GOLD .. "Timer & Stacks|r and " .. GOLD .. "Text Alerts|r: how they look.\n"
			.. GOLD .. "Profiles|r: separate setups (tank and damage, say), switched by hand or by your talents or group role.\n"
			.. "|cffff8040A development build of the rebuild:|r so far only this window, the profiles and the minimap "
			.. "button work. The glows come back in the next step.", 96))

		stack:Add(UI.OptionHeading(stack.inner, "General"))
		stack:Add(UI.OptionCheck(stack.inner, "Enable Leproc",
			function() return ns.Enabled() end,
			function(v) ns.SetEnabled(v) end,
			{ "Enable Leproc", "Turns every glow, popup and icon off without disabling the addon. The minimap button greys out while it's off." }))
		stack:Add(UI.OptionCheck(stack.inner, "Show the minimap button",
			function() return not ns.db.minimap.hide end,
			function(v) ns.Minimap.SetShown(v) end))
		stack:Add(UI.OptionCheck(stack.inner, "Show a reminder in chat when you log in",
			function() return ns.db.loginMessage end,
			function(v) ns.db.loginMessage = v end,
			{ "Login reminder", "A line in chat each time you log in, saying how to open the options." }))

		stack:Add(UI.OptionHeading(stack.inner, "Appearance"))
		stack:Add(UI.OptionCheck(stack.inner, "Use my class colour for this window",
			function() return ns.db.classColour end,
			function(v)
				ns.db.classColour = v
				ns.Refresh()
			end,
			{ "Class colour", "The window's edge, its rules and the selected tab take your class colour instead of gold. Text keeps its own colours." }))

		stack:Add(UI.OptionHeading(stack.inner, "Troubleshooting"))
		stack:Add(UI.OptionButton(stack.inner, "Every setting, in every profile", "Reset all settings", ns.ResetAll,
			{ "Reset all settings", "Puts Leproc back as it was when you installed it: every profile and every character's choices. You're asked first, and the interface reloads." }))

		stack:Add(UI.OptionHeading(stack.inner, "Chat commands"))
		stack:Add(UI.OptionText(stack.inner,
			GOLD .. "/leproc|r opens or closes this window (" .. GOLD .. "/lpr|r for short).\n"
			.. GOLD .. "/leproc general|r, " .. GOLD .. "abilities|r, " .. GOLD .. "glow|r, " .. GOLD .. "timer|r, "
			.. GOLD .. "text|r, " .. GOLD .. "profiles|r open a tab.\n"
			.. GOLD .. "/leproc profile <name>|r switches profile. " .. GOLD .. "/leproc spec|r shows your talents and role as profile switching sees them.\n"
			.. GOLD .. "/leproc minimap|r shows or hides the minimap button; " .. GOLD .. "/leproc on|r and " .. GOLD .. "off|r turn every glow on or off.\n"
			.. GOLD .. "/leproc help|r lists them all.", 92))

		stack:Add(UI.OptionHeading(stack.inner, "About"))
		stack:Add(UI.OptionText(stack.inner, function()
			return "Leproc " .. ns.Version() .. ". By addohm, for WoW: Forever."
		end, 28))
	end,
	defaults = function()
		local d = ns.DEFAULTS
		ns.db.enabled, ns.db.loginMessage, ns.db.classColour = d.enabled, d.loginMessage, d.classColour
		ns.db.minimap.hide = d.minimap.hide
	end,
})
