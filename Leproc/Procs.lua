-- Leproc: abilities a proc buff makes usable (Bloodthrill -> Overpower, Victorious -> Victory
-- Rush...). In combat the game hides your buffs from addons, so Leproc never reads them. Instead,
-- one of Blizzard's aura containers gets a slot per proc buff; the game shows a slot's button
-- only while you have that buff (CustomAuraButton ApplyVisibility), in combat too. Leproc's glow
-- for the ability is a child of that button, placed over each action button holding the
-- ability: the game shows and hides it with the buff, in any stance or form.
--
-- The glows are placed out of combat only (a slot's button is closed to addons while auras are
-- secret), whenever the bars change. In combat they stay where they were placed, so one on a bar
-- page that changes with stance stays on that button. No sound or countdown: Leproc doesn't know
-- when the buff comes.
local _, ns = ...

local Procs = {}
ns.Procs = Procs

local container      -- nil: not built yet; false: the game refused
local slots = {}     -- key -> the slot's button (shown by the game while you have the buff)
local glows = {}     -- key -> the glow frames on that slot, reused

local function Invisible(button)
	button:SetSize(1, 1)
	button:EnableMouse(false)
end

-- Makes the container and a slot per proc buff, once. False if the game won't.
function Procs.Build()
	if container ~= nil then return container ~= false end
	container = false
	if InCombatLockdown() then
		container = nil
		return false
	end
	if not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
		pcall(C_AddOns.LoadAddOn, "Blizzard_AuraContainer")
	end
	local ok, err = pcall(function()
		local c = CreateFrame("AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")
		c:SetUnit("player")
		c:SetSize(1, 1)
		c:SetPoint("CENTER")
		c:Show()
		for _, e in ipairs(ns.Catalogue) do
			if e.buffSet then
				slots[e.key] = c:AddAuraSlot("leproc_" .. e.key, "HELPFUL", {
					candidateFilters = { includeSpellIDs = e.buffSet },
					initializeFrame = Invisible,
				})
			end
		end
		container = c
	end)
	if not ok then Procs.why = tostring(err) end
	return ok
end

-- Places the glows: holders is key -> a list of { button, size } (the action buttons you can see
-- holding each ability). Out of combat only.
function Procs.Place(holders)
	if InCombatLockdown() or not Procs.Build() then return end
	for key, slot in pairs(slots) do
		local e = ns.byKey[key]
		local list = glows[key] or {}
		glows[key] = list
		local want = (ns.Mode(e) ~= "off" and holders[key]) or {}
		for i, h in ipairs(want) do
			local g = list[i]
			if not g then
				g = CreateFrame("Frame", nil, slot)
				g:EnableMouse(false)
				list[i] = g
			end
			local button, size = h[1], h[2]
			local scale = (slot:GetEffectiveScale() or 1)
			g:SetScale(scale > 0 and (button:GetEffectiveScale() or 1) / scale or 1)
			g:ClearAllPoints()
			g:SetPoint("CENTER", button, "CENTER")
			g:SetSize(size, size)
			g:SetFrameStrata(button:GetFrameStrata() or "MEDIUM")
			g:SetFrameLevel((button:GetFrameLevel() or 1) + 11)
			g.button = button
			g:Show()
			ns.Glow.Show(g, ns.db.glow, ns.db.color, size)
		end
		for i = #want + 1, #list do
			ns.Glow.Show(list[i], "none", ns.db.color, 0)
			list[i].button = nil
			list[i]:Hide()
		end
	end
end
