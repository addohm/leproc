-- Leproc: the options window's colours, in the style of Leboof's and Nothing Wasted's: a dark
-- background, a gold edge and gold for what's selected. With "Use my class colour" the edge, the
-- rules and the selection take your class colour instead; text keeps its own colours.
-- Theme.Paint(fn) registers a painter, run now and again whenever the colours change.
local _, ns = ...

local Theme = {}
ns.Theme = Theme

local GOLD = { 1, 0.82, 0 }
local EDGE = { 0.6, 0.45, 0.15 }
Theme.BACKGROUND = { 0.05, 0.06, 0.09, 0.94 }
Theme.GREY = { 0.62, 0.62, 0.62 }

local painters = {}

function Theme.ClassRGB()
	local _, class = UnitClass("player")
	if class and C_ClassColor and C_ClassColor.GetClassColor then
		local c = C_ClassColor.GetClassColor(class)
		if c then return c.r, c.g, c.b end
	end
	local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if c then return c.r, c.g, c.b end
	return GOLD[1], GOLD[2], GOLD[3]
end

local function ClassOn()
	return ns.db and ns.db.classColour
end

-- What's selected (a tab, a heading's rule): gold, or the class colour.
function Theme.Accent()
	if ClassOn() then return Theme.ClassRGB() end
	return GOLD[1], GOLD[2], GOLD[3]
end

-- The window's edge and the rules: a darker gold, or a darker class colour.
function Theme.Edge()
	if ClassOn() then
		local r, g, b = Theme.ClassRGB()
		return r * 0.75, g * 0.75, b * 0.75
	end
	return EDGE[1], EDGE[2], EDGE[3]
end

function Theme.Paint(fn)
	painters[#painters + 1] = fn
	fn(Theme)
end

function Theme.Apply()
	for _, fn in ipairs(painters) do fn(Theme) end
end
