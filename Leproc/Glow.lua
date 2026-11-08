-- Leproc: glow styles (the same as Leboof's). Glow.Build(owner, style, color, size) makes a glow
-- on `owner` out of its own textures and animation groups, and returns { regions = {...},
-- groups = {...} }; Glow.Show keeps one active on a frame. Leproc's frames are its own overlays on
-- the action buttons (Bars.lua) and the options preview. Everything is a texture with Alpha,
-- Translation, Rotation or FlipBook animations. The art is Blizzard's (Forever's action bars use
-- the modern proc flipbook); the styles are our own.
local _, ns = ...

local Glow = {}
ns.Glow = Glow

Glow.STYLES = {
	{ "none", "None" },
	{ "pulse", "Pulse" },
	{ "pixel", "Pixel glow" },
	{ "action", "Action button glow" },
	{ "autocast", "Auto-cast shine" },
	{ "gcd", "GCD" },
	{ "modern", "Modern WoW glow" },
	{ "classic", "Classic WoW glow" },
}

Glow.COLORS = {
	{ "gold", "Gold" }, { "white", "White" }, { "red", "Red" }, { "orange", "Orange" },
	{ "yellow", "Yellow" }, { "green", "Green" }, { "cyan", "Cyan" }, { "blue", "Blue" },
	{ "purple", "Purple" }, { "pink", "Pink" }, { "class", "Class colour" },
}

local RGB = {
	gold = { 1, 0.82, 0 }, white = { 1, 1, 1 }, red = { 1, 0.2, 0.15 }, orange = { 1, 0.5, 0 },
	yellow = { 1, 1, 0.2 }, green = { 0.2, 1, 0.2 }, cyan = { 0.2, 0.9, 1 }, blue = { 0.25, 0.45, 1 },
	purple = { 0.7, 0.35, 1 }, pink = { 1, 0.4, 0.8 },
}

function Glow.RGB(color)
	if color == "class" then
		local _, class = UnitClass("player")
		local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
		if c then return c.r, c.g, c.b end
		color = "gold"
	end
	local c = RGB[color] or RGB.gold
	return c[1], c[2], c[3]
end

local ICON_ALERT = "Interface\\SpellActivationOverlay\\IconAlert"
local ICON_ALERT_ANTS = "Interface\\SpellActivationOverlay\\IconAlertAnts"
local OUTER_GLOW = { 0.00781250, 0.50781250, 0.27734375, 0.52734375 } -- IconAlert's glow frame
local SPARK = "Interface\\Cooldown\\star4"
local PROC_LOOP = "UI-HUD-ActionBar-Proc-Loop-Flipbook"

-- A texture tinted to the colour. Gold art keeps its own colours when gold is chosen.
local function Tint(t, color, goldArt)
	if goldArt and color == "gold" then return end
	if goldArt then t:SetDesaturated(true) end
	t:SetVertexColor(Glow.RGB(color))
end

local function Solid(owner, color, layer)
	local t = owner:CreateTexture(nil, "OVERLAY", nil, layer or 6)
	t:SetColorTexture(1, 1, 1, 1)
	t:SetVertexColor(Glow.RGB(color))
	return t
end

local function Looping(owner, kind)
	local group = owner:CreateAnimationGroup()
	group:SetLooping(kind or "REPEAT")
	return group
end

local function Fade(group, target, from, to, duration, order)
	local a = group:CreateAnimation("Alpha")
	a:SetTarget(target)
	a:SetFromAlpha(from)
	a:SetToAlpha(to)
	a:SetDuration(duration)
	if order then a:SetOrder(order) end
	return a
end

local function Move(group, target, dx, dy, duration, order)
	local a = group:CreateAnimation("Translation")
	a:SetTarget(target)
	a:SetOffset(dx, dy)
	a:SetDuration(duration)
	if order then a:SetOrder(order) end
	return a
end

local Builders = {}

-- A pulsing edge around the icon.
function Builders.pulse(owner, color, size, out)
	local group = Looping(owner, "BOUNCE")
	local edges = {
		{ "TOPLEFT", -3, 3, "TOPRIGHT", 3, 1 }, { "BOTTOMLEFT", -3, -1, "BOTTOMRIGHT", 3, -3 },
		{ "TOPLEFT", -3, 3, "BOTTOMLEFT", -1, -3 }, { "TOPRIGHT", 1, 3, "BOTTOMRIGHT", 3, -3 },
	}
	for _, p in ipairs(edges) do
		local edge = Solid(owner, color)
		edge:SetPoint(p[1], p[2], p[3])
		edge:SetPoint(p[4], p[5], p[6])
		table.insert(out.regions, edge)
		Fade(group, edge, 1, 0.2, 0.5)
	end
	table.insert(out.groups, group)
end

-- Dashes marching clockwise around the edge, two per side.
function Builders.pixel(owner, color, size, out)
	local group = Looping(owner)
	local edge = size + 4
	local len = math.max(4, math.floor(size * 0.25))
	local travel = (edge - len) / 2
	-- side: anchor point, the dash's offset from it for a start position s, its size, its direction
	local sides = {
		{ "TOPLEFT", function(s) return -2 + s, 2 end, len, 2, travel, 0 },
		{ "TOPRIGHT", function(s) return 2, 2 - s end, 2, len, 0, -travel },
		{ "BOTTOMRIGHT", function(s) return 2 - s, -2 end, len, 2, -travel, 0 },
		{ "BOTTOMLEFT", function(s) return -2, -2 + s end, 2, len, 0, travel },
	}
	for _, side in ipairs(sides) do
		for _, start in ipairs({ 0, travel }) do
			local dash = Solid(owner, color)
			dash:SetSize(side[3], side[4])
			dash:SetPoint(side[1], owner, side[1], side[2](start))
			table.insert(out.regions, dash)
			Move(group, dash, side[5], side[6], 0.6)
		end
	end
	table.insert(out.groups, group)
end

-- Blizzard's spell-alert glow frame around the icon, pulsing.
function Builders.action(owner, color, size, out)
	local glow = owner:CreateTexture(nil, "OVERLAY", nil, 5)
	glow:SetTexture(ICON_ALERT)
	glow:SetTexCoord(unpack(OUTER_GLOW))
	glow:SetBlendMode("ADD")
	glow:SetSize(size * 1.5, size * 1.5)
	glow:SetPoint("CENTER", owner, "CENTER")
	Tint(glow, color, true)
	table.insert(out.regions, glow)
	local group = Looping(owner, "BOUNCE")
	Fade(group, glow, 1, 0.45, 0.6)
	table.insert(out.groups, group)
end

-- Four sparkles chasing each other clockwise around the icon.
function Builders.autocast(owner, color, size, out)
	local group = Looping(owner)
	local corners = { "TOPLEFT", "TOPRIGHT", "BOTTOMRIGHT", "BOTTOMLEFT" }
	local steps = { { size, 0 }, { 0, -size }, { -size, 0 }, { 0, size } } -- from each corner to the next
	for i, corner in ipairs(corners) do
		local spark = owner:CreateTexture(nil, "OVERLAY", nil, 7)
		spark:SetTexture(SPARK)
		spark:SetBlendMode("ADD")
		spark:SetSize(size * 0.4, size * 0.4)
		spark:SetPoint("CENTER", owner, corner)
		Tint(spark, color, true)
		table.insert(out.regions, spark)
		for k = 0, 3 do
			local step = steps[(i - 1 + k) % 4 + 1]
			Move(group, spark, step[1], step[2], 0.5, k + 1)
		end
	end
	table.insert(out.groups, group)
end

-- A bright hand sweeping round over a darkened icon, like the global cooldown.
function Builders.gcd(owner, color, size, out)
	local shade = owner:CreateTexture(nil, "OVERLAY", nil, 4)
	shade:SetAllPoints(owner)
	shade:SetColorTexture(0, 0, 0, 0.35)
	table.insert(out.regions, shade)
	local hand = Solid(owner, color, 6)
	hand:SetSize(2, size / 2)
	hand:SetPoint("BOTTOM", owner, "CENTER")
	table.insert(out.regions, hand)
	local group = Looping(owner)
	local spin = group:CreateAnimation("Rotation")
	spin:SetTarget(hand)
	spin:SetOrigin("BOTTOM", 0, 0)
	spin:SetDegrees(-360)
	spin:SetDuration(1)
	table.insert(out.groups, group)
end

-- Today's action-bar proc glow: Blizzard's looping flipbook.
function Builders.modern(owner, color, size, out)
	local loop = owner:CreateTexture(nil, "OVERLAY", nil, 5)
	loop:SetAtlas(PROC_LOOP)
	loop:SetSize(size * 1.4, size * 1.4)
	loop:SetPoint("CENTER", owner, "CENTER")
	Tint(loop, color, true)
	table.insert(out.regions, loop)
	local group = Looping(owner)
	local flip = group:CreateAnimation("FlipBook")
	flip:SetTarget(loop)
	flip:SetFlipBookRows(6)
	flip:SetFlipBookColumns(5)
	flip:SetFlipBookFrames(30)
	flip:SetDuration(1)
	table.insert(out.groups, group)
end

-- The classic proc glow: the glow frame with marching ants.
function Builders.classic(owner, color, size, out)
	Builders.action(owner, color, size, { regions = out.regions, groups = {} })
	local ants = owner:CreateTexture(nil, "OVERLAY", nil, 6)
	ants:SetTexture(ICON_ALERT_ANTS)
	ants:SetBlendMode("ADD")
	ants:SetSize(size * 1.25, size * 1.25)
	ants:SetPoint("CENTER", owner, "CENTER")
	Tint(ants, color, true)
	table.insert(out.regions, ants)
	local group = Looping(owner)
	local flip = group:CreateAnimation("FlipBook")
	flip:SetTarget(ants)
	flip:SetFlipBookRows(5)
	flip:SetFlipBookColumns(5)
	flip:SetFlipBookFrames(22)
	flip:SetFlipBookFrameWidth(48)
	flip:SetFlipBookFrameHeight(48)
	flip:SetDuration(0.6)
	table.insert(out.groups, group)
end

function Glow.Build(owner, style, color, size)
	local out = { regions = {}, groups = {} }
	local builder = Builders[style]
	if builder then builder(owner, color or "gold", size, out) end
	return out
end

-- Our own frames: show and play a built glow, or hide and stop it.
function Glow.SetActive(built, on)
	for _, r in ipairs(built.regions) do r:SetShown(on) end
	for _, g in ipairs(built.groups) do
		if on then
			if not g:IsPlaying() then g:Play() end
		else
			g:Stop()
		end
	end
end

-- Keeps one active glow per style/colour/size on one of our frames, making them as needed.
function Glow.Show(owner, style, color, size)
	owner.glows = owner.glows or {}
	local key = style .. ":" .. tostring(color) .. ":" .. size
	for k, built in pairs(owner.glows) do
		if k ~= key then Glow.SetActive(built, false) end
	end
	if style == "none" then return end
	if not owner.glows[key] then
		owner.glows[key] = Glow.Build(owner, style, color, size)
	end
	Glow.SetActive(owner.glows[key], true)
end
