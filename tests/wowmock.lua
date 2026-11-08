-- A small fake WoW client for Leproc's tests. Frames accept any method call. Blizzard's action
-- buttons exist (ActionButton1-12, MultiBarBottomLeftButton1-12), each with an `action` slot; the
-- test puts spells on slots (WM.SetAction), flips stance, and fires combat events.
local M = { printed = {}, combat = false, class = "WARRIOR", known = {}, frames = {}, actions = {} }

-- Unknown methods (capitalised names) do nothing; unknown fields are nil, as on a real frame.
local function Permissive(t)
	return setmetatable(t, { __index = function(_, k)
		if type(k) == "string" and k:match("^%u") then return function() return nil end end
	end })
end

local function NewFrame(kind, name, parent)
	local f = { kind = kind, name = name, parent = parent, shown = true, points = {}, scripts = {}, events = {}, level = 1, w = 0, h = 0, attributes = {} }
	function f:Show()
		local was = self.shown
		self.shown = true
		if not was and self.scripts.OnShow then self.scripts.OnShow(self) end
	end
	function f:Hide() self.shown = false end
	function f:SetShown(v) self.shown = v and true or false end
	function f:IsShown() return self.shown end
	-- Visible: shown, and so is every parent.
	function f:IsVisible()
		local p = self
		while p do
			if not p.shown then return false end
			p = p.parent
		end
		return true
	end
	function f:SetParent(p) self.parent = p end
	function f:GetName() return self.name end
	function f:IsObjectType(t) return self.kind == t end
	function f:IsForbidden() return false end
	function f:SetAttribute(k, v) self.attributes[k] = v end
	function f:GetAttribute(k) return self.attributes[k] end
	function f:SetSize(w, h) self.w, self.h = w, h end
	function f:GetSize() return self.w, self.h end
	function f:SetWidth(w) self.w = w end
	function f:SetHeight(h) self.h = h end
	function f:GetWidth() return self.w end
	function f:GetHeight() return self.h end
	function f:GetCenter() return 0, 0 end
	function f:GetEffectiveScale() return 1 end
	function f:GetChecked() return self.checked end
	function f:SetText(t) self.text = t end
	function f:GetText() return self.text end
	function f:SetChecked(v) self.checked = v end
	function f:ClearAllPoints() self.points = {} end
	function f:SetPoint(...) table.insert(self.points, { ... }) end
	function f:GetPoint() local p = self.points[1] or {} return p[1], nil, p[3], p[4], p[5] end
	function f:GetFrameLevel() return self.level end
	function f:SetFrameLevel(l) self.level = l end
	function f:SetScript(event, fn) self.scripts[event] = fn end
	function f:RegisterEvent(e) self.events[e] = true end
	function f:RegisterUnitEvent(e, ...) self.events[e] = { ... } end
	function f:CreateTexture() return Permissive({}) end
	function f:CreateAnimationGroup()
		local g = Permissive({ animations = {}, playing = false })
		function g:CreateAnimation(kind)
			local a = Permissive({ kind = kind })
			table.insert(self.animations, a)
			return a
		end
		function g:Play() self.playing = true end
		function g:Stop() self.playing = false end
		function g:IsPlaying() return self.playing end
		return g
	end
	function f:CreateFontString()
		local fs = Permissive({ shown = true })
		function fs:SetText(t) self.text = t end
		function fs:GetText() return self.text end
		function fs:SetShown(v) self.shown = v and true or false end
		function fs:IsShown() return self.shown end
		return fs
	end
	table.insert(M.frames, f)
	f.order = #M.frames
	return Permissive(f)
end

-- Every frame, in the order made, as the game's EnumerateFrames walks them.
function EnumerateFrames(prev)
	return M.frames[(prev and prev.order or 0) + 1]
end

-- Blizzard's aura containers: AddAuraSlot checks its arguments like Blizzard's and returns the
-- slot's button, hidden. WM.SetAura(spellID, on) is the game showing or hiding every slot button
-- whose spell IDs include it (as CustomAuraButton's ApplyVisibility does, in combat too).
M.slots = {}
local function NewContainer(parent)
	local c = NewFrame("AuraContainer", nil, parent)
	c.keys = {}
	function c:SetUnit(u) self.unit = u end
	function c:AddAuraSlot(key, filter, options)
		assert(filter == "HELPFUL" or filter == "HARMFUL", "bad filter string")
		assert(not self.keys[key], "aura slot '" .. key .. "' already exists with this key.")
		assert(options.candidateFilters and options.candidateFilters.includeSpellIDs, "no spell IDs")
		local b = NewFrame("AuraButton", nil, self)
		b.shown = false
		if options.initializeFrame then options.initializeFrame(b) end
		self.keys[key] = b
		table.insert(M.slots, { button = b, ids = options.candidateFilters.includeSpellIDs })
		return b
	end
	return c
end
function M.SetAura(id, on)
	for _, s in ipairs(M.slots) do
		if s.ids[id] then s.button.shown = on and true or false end
	end
end

-- True if a proc glow (Procs.lua) shows over this button: a visible frame placed on it with a
-- glow playing.
function M.ProcGlowing(button)
	for _, f in ipairs(M.frames) do
		if f.button == button and f.glows and f:IsVisible() then
			for _, built in pairs(f.glows) do
				for _, g in ipairs(built.groups) do
					if g.playing then return true end
				end
			end
		end
	end
	return false
end

function CreateFrame(kind, name, parent, template)
	if kind == "AuraContainer" then
		assert(template == "CustomAuraContainerTemplate")
		return NewContainer(parent)
	end
	local f = NewFrame(kind, name, parent)
	if kind == "DropdownButton" then
		function f:SetupMenu(generator) self.generator = generator end
	end
	if name then _G[name] = f end
	return f
end

UIParent = NewFrame("Frame", "UIParent")
Minimap = NewFrame("Frame", "Minimap")
Minimap:SetSize(140, 140)
GameTooltip = NewFrame("GameTooltip", "GameTooltip")
function GameTooltip_Hide() end

-- Two of Blizzard's bars. The main bar's slots page with stance: WM.SetStance moves its buttons
-- to that stance's page (Battle 73-84, Defensive 85-96, as on a warrior); the second bar is fixed
-- at 61-72 (MultiBarBottomLeft).
M.mainBar = NewFrame("Frame", "MainActionBar")
M.bottomLeft = NewFrame("Frame", "MultiBarBottomLeft")
for i = 1, 12 do
	local b = NewFrame("CheckButton", "ActionButton" .. i, M.mainBar)
	b:SetSize(45, 45)
	b.action = 72 + i
	_G["ActionButton" .. i] = b
	local c = NewFrame("CheckButton", "MultiBarBottomLeftButton" .. i, M.bottomLeft)
	c:SetSize(40, 40)
	c.action = 60 + i
	_G["MultiBarBottomLeftButton" .. i] = c
end

-- Bar addons' buttons, made by the test after login (as an addon building its bars late):
-- WM.AddonBar(name, slots, how) makes a bar of CheckButtons holding those slots, the way
-- EllesmereUI's EABButtons (how = "state": `_state_action`) or secure-template buttons
-- (how = "attribute": the "action" attribute) do.
function M.AddonBar(name, slots, how)
	local bar = NewFrame("Frame", name)
	bar.buttons = {}
	for i, slot in ipairs(slots) do
		local b = NewFrame("CheckButton", name .. "Button" .. i, bar)
		b:SetSize(38, 38)
		if how == "attribute" then b:SetAttribute("action", slot) else b._state_action = slot end
		_G[name .. "Button" .. i] = b
		bar.buttons[i] = b
	end
	return bar
end

-- One named button of a bar addon (ProcGlow's list), holding `slot` the way `how` says:
-- "action" (the field), "state" (`_state_action`) or "attribute".
function M.Button(name, parent, how, slot)
	local b = NewFrame("CheckButton", name, parent)
	b:SetSize(38, 38)
	if how == "attribute" then b:SetAttribute("action", slot)
	elseif how == "state" then b._state_action = slot
	else b.action = slot end
	_G[name] = b
	return b
end

-- Action slots: WM.SetAction(slot, spellID) or WM.SetAction(slot, spellID, "macro") (a macro
-- whose text isn't known). WM.SetMacro(slot, index, name, body, castsNow) puts macro `index`
-- on the slot; castsNow is the spell it would cast right now (nil: none). As on Forever, the
-- slot then reports that spell's ID, not the macro's index.
M.macros = {}
function M.SetAction(slot, spellID, kind)
	M.actions[slot] = spellID and { kind or "spell", spellID } or nil
end
function M.SetMacro(slot, index, name, body, castsNow)
	M.macros[index] = { name = name, body = body }
	M.actions[slot] = { "macro", castsNow or index, castsNow and "spell" or nil, name = name }
end
function GetActionInfo(slot)
	local a = M.actions[slot]
	if not a then return nil end
	if a[1] == "macro" then
		if a.name then return "macro", a[2], a[3] end
		return "macro", a[2], "spell"
	end
	return "spell", a[2]
end
C_ActionBar = {
	GetActionText = function(slot)
		local a = M.actions[slot]
		return a and a.name or nil
	end,
	IsUsableAction = function(slot) return M.slotUsable[slot] or false, false end,
}
-- GetMacroInfo(index or name): name, icon, body.
function GetMacroInfo(which)
	for index, m in pairs(M.macros) do
		if index == which or m.name == which then return m.name, 134400, m.body end
	end
end

-- Stances: index 1 Battle (2457), 2 Defensive (71), 3 Berserker (2458). WM.SetStance(1 to 3,
-- or 0 for none). Blizzard's stance bar: StanceButton1-3.
M.stance = 1
M.forms = { { spellID = 2457, page = 73 }, { spellID = 71, page = 85 }, { spellID = 2458, page = 97 } }
M.stanceBar = NewFrame("Frame", "StanceBar")
for i = 1, 3 do
	local b = NewFrame("CheckButton", "StanceButton" .. i, M.stanceBar)
	b:SetSize(30, 30)
	_G["StanceButton" .. i] = b
end
function GetNumShapeshiftForms() return #M.forms end
function GetShapeshiftForm() return M.stance end
function GetShapeshiftFormInfo(i)
	local f = M.forms[i]
	if not f then return nil end
	return 1000 + i, i == M.stance, true, f.spellID
end
function M.SetStance(i)
	M.stance = i
	local page = M.forms[i] and M.forms[i].page or 1
	for n = 1, 12 do _G["ActionButton" .. n].action = page + n - 1 end
	M.Fire("UPDATE_SHAPESHIFT_FORM")
	M.Fire("UPDATE_BONUS_ACTIONBAR")
end

-- Leproc's overlay on a button.
function M.Overlay(button)
	for _, f in ipairs(M.frames) do
		if f.parent == button and f.glows ~= nil then return f end
	end
end

-- The countdown on a button: its text if shown, else nil.
function M.Countdown(button)
	local o = M.Overlay(button)
	return o and o.count and o.count:IsShown() and o.count:GetText() or nil
end

-- The game's Options > AddOns list.
M.settings = {}
Settings = {
	RegisterCanvasLayoutCategory = function(frame, name)
		local c = { frame = frame, name = name }
		table.insert(M.settings, c)
		return c
	end,
	RegisterAddOnCategory = function(c) c.addon = true end,
}
SettingsPanel = NewFrame("Frame", "SettingsPanel")
function HideUIPanel(f) f:Hide() end
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"

-- True if Leproc's overlay on this button has a glow playing.
function M.Glowing(button)
	for _, f in ipairs(M.frames) do
		if f.parent == button and f.glows then
			for _, built in pairs(f.glows) do
				for _, g in ipairs(built.groups) do
					if g.playing then return true end
				end
			end
		end
	end
	return false
end

UISpecialFrames = {}
tinsert = table.insert
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function GetCursorPosition() return 0, 0 end
M.name, M.surname, M.realm = "Tester", "Smith", "Realm"
-- On Forever the second value is the surname.
function UnitName() return M.name, M.surname end
function GetRealmName() return M.realm end
YES, NO = "Yes", "No"
StaticPopupDialogs = {}
-- The test accepts popups with WM.Accept().
function StaticPopup_Show(which, text, _, data) M.popup = { which = which, text = text, data = data } end
function M.Accept()
	local p = assert(M.popup, "no popup shown")
	M.popup = nil
	StaticPopupDialogs[p.which].OnAccept(nil, p.data)
end
SlashCmdList = {}

C_AddOns = {
	IsAddOnLoaded = function() return true end,
	LoadAddOn = function() return true end,
	GetAddOnMetadata = function(_, field) if field == "Version" then return "0.0.0" end end,
}
-- A clock the tests move (WM.Advance). C_Timer.After runs at once; NewTimer and NewTicker wait
-- for WM.Advance.
M.now = 1000
function GetTime() return M.now end
M.timers = {}
C_Timer = {
	After = function(_, fn) fn() end,
	NewTimer = function(seconds, fn)
		local t = { at = M.now + seconds, fn = fn }
		function t:Cancel() self.cancelled = true end
		table.insert(M.timers, t)
		return t
	end,
	NewTicker = function(seconds, fn, iterations)
		local t = { at = M.now + seconds, every = seconds, fn = fn, left = iterations }
		function t:Cancel() self.cancelled = true end
		table.insert(M.timers, t)
		return t
	end,
}
function M.Advance(seconds)
	local target = M.now + seconds
	while true do
		local next
		for _, t in ipairs(M.timers) do
			if not t.cancelled and t.at <= target and (not next or t.at < next.at) then next = t end
		end
		if not next then break end
		M.now = next.at
		if next.every then
			next.at = next.at + next.every
			if next.left then
				next.left = next.left - 1
				if next.left <= 0 then next.cancelled = true end
			end
		else
			next.cancelled = true
		end
		next.fn()
	end
	M.now = target
end
-- Sounds played, by sound kit ID; SOUNDKIT maps each name to a made-up ID.
M.sounds = {}
SOUNDKIT = setmetatable({ READY_CHECK = 8960 }, { __index = function(_, name) return "kit:" .. name end })
function PlaySound(id) table.insert(M.sounds, id) end
function M.Played(name)
	for _, id in ipairs(M.sounds) do if id == SOUNDKIT[name] then return true end end
	return false
end
MenuUtil = { CreateContextMenu = function(owner, generator) M.contextMenu = { owner = owner, generator = generator } end }
C_SpellBook = { IsSpellKnown = function(id) return M.known[id] == true end }
function date() return "12:00:00" end
ChatFontNormal = {}
-- What the game says is usable: WM.spellUsable[name] (C_Spell.IsSpellUsable) and
-- WM.slotUsable[slot] (C_ActionBar.IsUsableAction).
M.spellUsable, M.slotUsable = {}, {}

-- Spell names: the stances, and every ID in the addon's Data.lua by its name.
M.spellNames = { [2458] = "Berserker Stance" }
C_Spell = {
	GetSpellTexture = function(id) return 100000 + id end,
	IsSpellUsable = function(spell) return M.spellUsable[spell] or false, false end,
	GetSpellName = function(id)
		if M.spellNames[id] then return M.spellNames[id] end
		for name, ids in pairs(ns and ns.SpellIDs or {}) do
			for _, i in ipairs(ids) do if i == id then return name end end
		end
	end,
}
function UnitClass() return "Class", M.class end
function InCombatLockdown() return M.combat end
function print(...)
	local parts = {}
	for i = 1, select("#", ...) do parts[i] = tostring(select(i, ...)) end
	table.insert(M.printed, table.concat(parts, " "))
end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function strsplit(sep, s, limit)
	local out, start = {}, 1
	while true do
		if limit and #out == limit - 1 then break end
		local i = s:find(sep, start, true)
		if not i then break end
		table.insert(out, s:sub(start, i - 1))
		start = i + #sep
	end
	table.insert(out, s:sub(start))
	return unpack(out)
end

-- Fires an event at every frame that registered it. Unit events reach a frame only for the units
-- it registered, as with RegisterUnitEvent.
function M.Fire(event, ...)
	local unit = ...
	for _, f in ipairs(M.frames) do
		local reg = f.events[event]
		if reg and f.scripts.OnEvent then
			local wanted = reg == true
			if type(reg) == "table" then
				for _, u in ipairs(reg) do if u == unit then wanted = true end end
			end
			if wanted then f.scripts.OnEvent(f, event, ...) end
		end
	end
end

-- Combat events as the game sends them: UNIT_COMBAT (unit, event, flagText, amount, schoolMask).
function M.Combat(unit, event, flags) M.Fire("UNIT_COMBAT", unit, event, flags or "", 0, 1) end
function M.Cast(spellID) M.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-GUID", spellID) end

function M.Slash(msg) SlashCmdList.LEPROC(msg) end

return M
