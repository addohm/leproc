-- Scenarios run by tests/run_tests.py. WM is the mock (wowmock.lua), ns the addon namespace.
-- Step 1 of the rebuild: the window, profiles (with switching by talents or role), the minimap
-- button and the Options > AddOns entry.
local function Check(cond, msg) if not cond then error(msg, 2) end end
local function Printed(pattern)
	for _, line in ipairs(WM.printed) do if line:find(pattern, 1, true) then return true end end
	return false
end
local function Near(a, b) return math.abs(a - b) < 1e-6 end
local P = ns.Profiles

-- Login: the character's own profile, with the defaults, and a welcome the first time only.
ns.build = "abc1234" -- as the install script stamps it
WM.Fire("ADDON_LOADED", "Leproc")
WM.Fire("PLAYER_LOGIN")
WM.Fire("PLAYER_ENTERING_WORLD")
Check(P.Current() == "Tester Smith", "the character's profile isn't in use")
Check(ns.db == LeprocDB.profiles["Tester Smith"], "ns.db isn't the profile")
Check(ns.db.enabled and ns.db.loginMessage and not ns.db.classColour and ns.db.window.scale == 1, "defaults")
Check(Printed("thanks for installing") and LeprocDB.welcomed, "the first login should welcome you")
WM.printed = {}
WM.Fire("PLAYER_ENTERING_WORLD")
Check(#WM.printed == 0, "one greeting per session, not one per loading screen")

-- Options > AddOns: an Enable box and a button that opens the window.
Check(#WM.settings == 1 and WM.settings[1].addon and WM.settings[1].name == "Leproc", "Options > AddOns entry")
local panel = WM.settings[1].frame
panel.scripts.OnShow(panel)
Check(panel.enable:GetChecked(), "the Enable box shows Leproc on")
panel.open.scripts.OnClick(panel.open)
Check(ns.Window.IsShown(), "the button should open Leproc's window")
-- The build number is for chat only: the window and the Options entry show the version alone.
Check(ns.Window.Frame().version:GetText() == "v0.0.0", "the window shows the version without the build")
Check(panel.title:GetText() == "Leproc v0.0.0", "the Options entry too")

-- The window: ProcGlow's pages as our tabs, in order; every page builds.
local ids = table.concat(ns.Window.PageIds(), ",")
Check(ids == "general,abilities,glow,timer,text,profiles", "tab order: " .. ids)
for _, id in ipairs(ns.Window.PageIds()) do
	ns.Window.Select(id)
	Check(ns.Window.CurrentPanel():IsShown() and ns.Window.CurrentPanel().built, id .. " should build and show")
	Check(ns.db.window.tab == id, "the tab shown is kept")
end
local frame = ns.Window.Frame()
Check(frame.w == 700 and frame.h == 520, "default size")

-- Turning Leproc off greys the minimap button; the Options box and /leproc on|off do the same.
local mm = ns.Minimap.Button()
Check(mm:IsShown() and not mm.icon:IsDesaturated(), "the minimap button, in colour")
ns.SetEnabled(false)
Check(mm.icon:IsDesaturated() and not ns.Enabled(), "off: the icon is grey")
WM.Slash("on")
Check(ns.Enabled() and not mm.icon:IsDesaturated(), "/leproc on")
panel.enable:SetChecked(false)
panel.enable.scripts.OnClick(panel.enable)
Check(not ns.Enabled(), "the Options box turns it off")
WM.Slash("on")

-- The class colour: the edge goes from gold to the class's colour, darker.
Check(Near(frame.border[1], 0.6) and Near(frame.border[2], 0.45), "a gold edge by default")
ns.db.classColour = true
ns.Refresh()
Check(Near(frame.border[1], 0.78 * 0.75) and Near(frame.border[2], 0.61 * 0.75), "the warrior's colour")
ns.Window.Select("general")
ns.Window.RunDefaults()
Check(not ns.db.classColour and Near(frame.border[1], 0.6), "General's Defaults: gold again")

-- Scale: the popup's arrows step 5% at a time, Reset is 100%; kept in the profile.
ns.Window.ToggleScale()
local pop = LeprocScale
Check(pop:IsShown(), "the Scale popup opens")
pop.row.next.scripts.OnClick(pop.row.next)
Check(Near(frame:GetScale(), 1.05) and Near(ns.db.window.scale, 1.05), "one step up: 105%")
pop.row.prev.scripts.OnClick(pop.row.prev)
pop.row.prev.scripts.OnClick(pop.row.prev)
Check(Near(frame:GetScale(), 0.95), "two steps down: 95%")
pop.reset.scripts.OnClick(pop.reset)
Check(frame:GetScale() == 1 and ns.db.window.scale == 1, "Reset: 100%")
ns.Window.ToggleScale()
Check(not pop:IsShown(), "the Scale button closes it again")

-- Minimise: folds to the title bar where it is, and back.
ns.Window.Fold(true)
Check(ns.Window.IsFolded() and frame.w == 360 and frame.h == 32, "folded to the title bar")
Check(not ns.Window.CurrentPanel():IsVisible(), "the page is hidden while folded")
ns.Window.Fold(false)
Check(not ns.Window.IsFolded() and frame.w == 700 and frame.h == 520, "restored to its size")
Check(ns.Window.CurrentPanel():IsVisible(), "and the page is back")
ns.Window.Fold(true)
ns.Window.Show("profiles")
Check(not ns.Window.IsFolded(), "opening a tab unfolds the window")

-- Profiles: a new one starts with the defaults; settings follow the profile.
Check(P.New("Tank"), "a new profile")
Check(P.Current() == "Tank" and ns.db.window.scale == 1, "switched to it, with the defaults")
ns.Window.SetScale(1.2)
Check(P.Switch("Tester Smith") and frame:GetScale() == 1, "the window takes the profile's scale")
Check(P.Switch("Tank") and Near(frame:GetScale(), 1.2), "and back")
P.Switch("Tester Smith")

-- Switching by talents: the tree with the most points picks the profile; nothing without a rule.
local rules = P.Rules()
rules.on = true
rules.spec[1] = "Tank"
WM.trees[1][2] = 31
P.Auto(true)
Check(P.Current() == "Tank" and Printed("most of your points are in Arms"), "Arms -> Tank")
WM.trees[1][2], WM.trees[3][2] = 5, 41
WM.Fire("PLAYER_TALENT_UPDATE")
Check(P.Current() == "Tank", "no rule for Protection: no change")
rules.spec[3] = "Tester Smith"
WM.Fire("TRAIT_CONFIG_UPDATED")
Check(P.Current() == "Tank", "a rule added on its own waits for the next change (the tab applies it at once)")
P.Auto(true)
Check(P.Current() == "Tester Smith", "Protection -> Tester Smith")
local index, names, points = P.Spec()
Check(index == 3 and names[2] == "Fury" and points[3] == 41, "the trees, in their order")

-- A group role wins over talents, and switching waits for the end of combat.
WM.group, WM.role = true, "TANK"
rules.role.TANK = "Tank"
WM.Fire("GROUP_ROSTER_UPDATE")
Check(P.Current() == "Tank", "tank in a group -> Tank")
WM.combat = true
WM.group = false
WM.Fire("GROUP_ROSTER_UPDATE")
Check(P.Current() == "Tank", "no switch in combat")
WM.combat = false
WM.Fire("PLAYER_REGEN_ENABLED")
Check(P.Current() == "Tester Smith", "after combat: back to the talent rule")

-- Renaming and deleting keep the rules in step.
P.Switch("Tank")
Check(P.Rename("Tanking") and rules.role.TANK == "Tanking" and rules.spec[1] == "Tanking", "rules follow a rename")
P.Switch("Tester Smith")
Check(P.Delete("Tanking") and rules.role.TANK == nil and rules.spec[1] == nil, "rules naming a deleted profile go")
rules.on = false
P.New("Spare")
WM.trees[1][2], WM.trees[3][2] = 51, 0
rules.spec[1] = "Tester Smith"
WM.Fire("PLAYER_TALENT_UPDATE")
Check(P.Current() == "Spare", "with switching off, talents don't switch")
WM.Slash("spec")
Check(Printed("Arms 51 points") and Printed("most points: Arms") and Printed("switching by talents or role: off"), "/leproc spec")

-- The Profiles tab's rule rows name the trees.
ns.Window.Show("profiles")
local found
for _, row in ipairs(ns.Window.CurrentPanel().stack.rows) do
	if row.label and row.label:GetText() == "Most points in Fury" then found = true end
end
Check(found, "a rule row for Fury")

-- The minimap button: right-click is a menu of profiles (the one in use first), left-click the
-- window; the addon compartment does the same.
mm.scripts.OnClick(mm, "RightButton")
local items = WM.MenuItems()
Check(items[1].kind == "title" and items[2].kind == "radio" and items[2].text == "Spare" and items[2].isSelected(), "the profile in use comes first")
local other
for _, item in ipairs(items) do
	if item.kind == "radio" and item.text == "Tester Smith" then other = item end
end
other.select()
Check(P.Current() == "Tester Smith", "picking one switches to it")
ns.Window.Hide()
items[#items].select()
Check(items[#items].text == "New profile..." and ns.Window.IsShown() and ns.db.window.tab == "profiles", "New profile... opens the Profiles tab")
mm.scripts.OnClick(mm, "LeftButton")
Check(not ns.Window.IsShown(), "left-click closes the window")
WM.contextMenu = nil
Leproc_OnAddonCompartmentClick("Leproc", "RightButton")
Check(WM.contextMenu ~= nil, "the addon compartment opens the menu too")

-- Slash commands.
WM.printed = {}
WM.Slash("help")
Check(Printed("/leproc profile [name]") and Printed("/leproc on | off"), "help")
Check(Printed("v0.0.0 build abc1234"), "help gives the build")
WM.Slash("glow")
Check(ns.Window.IsShown() and ns.db.window.tab == "glow", "/leproc glow opens that tab")
WM.Slash("profile Spare")
Check(P.Current() == "Spare", "/leproc profile <name>")
WM.Slash("profile Nope")
Check(Printed("there's no profile called Nope"), "an unknown profile")
WM.Slash("minimap")
Check(not mm:IsShown() and ns.db.minimap.hide, "/leproc minimap hides it")
WM.Slash("minimap")
Check(mm:IsShown(), "and shows it")
WM.Slash("bogus")
Check(Printed("unknown command 'bogus'"), "unknown command")

-- Reset all settings: asks, then wipes everything and reloads.
ns.ResetAll()
WM.Accept()
Check(LeprocDB == nil and WM.reloaded, "reset all wipes LeprocDB and reloads")
