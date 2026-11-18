-- Leproc: the tabs the rebuild hasn't reached yet (ROADMAP.md, "The rebuild"). Each one moves to a
-- file of its own when its step lands.
local _, ns = ...
local UI = ns.UI

local function Soon(id, label, order, text)
	ns.Window.Page({
		id = id,
		label = label,
		order = order,
		fill = function(stack)
			stack:Add(UI.OptionText(stack.inner, "|cffff8040Not built yet.|r " .. text, 60))
		end,
	})
end

Soon("abilities", "Procs & Buffs", 2, "Comes in the next step: a page for each class, with a row for each proc and reactive ability (glow its button, show a text popup, show an icon), and the buff reminders.")
Soon("glow", "Glow", 3, "Comes with the glow designer: Blizzard's glow or your own layers, with a live preview.")
Soon("timer", "Timer & Stacks", 4, "Comes with the glow designer: the countdown and the stack count on a lit button, their size and place.")
Soon("text", "Text Alerts", 5, "Comes with the text popups: their font, size, colours, box and animations, and where they show.")
