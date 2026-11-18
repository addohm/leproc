-- Scenarios run by tests/run_tests.py. WM is the mock (wowmock.lua), ns the addon namespace.
-- Step 1 of the rebuild: the window, profiles (managed on their tab, with switching by talents or
-- role), the minimap button and the Options > AddOns entry.
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
Check(ns.db.enabled and ns.db.loginMessage and not ns.db.classColour, "defaults")
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

-- No Scale or minimise in the title bar (the owner: unnecessary; the window resizes from its corner).
Check(LeprocScale == nil and ns.Window.Fold == nil and ns.Window.ToggleScale == nil, "no Scale or minimise")

-- Profiles: a new one starts with the defaults; settings follow the profile.
Check(P.New("Tank"), "a new profile")
Check(P.Current() == "Tank" and ns.db.window.size == nil, "switched to it, with the defaults")
ns.db.window.size = { 800, 600 }
ns.Window.Apply()
Check(frame.w == 800, "the window takes the profile's size")
Check(P.Switch("Tester Smith") and frame.w == 700, "another profile, its own size")
Check(P.Switch("Tank") and frame.w == 800, "and back")
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

-- The minimap button: either click opens or closes the window (profiles are managed on their tab);
-- the addon compartment does the same.
ns.Window.Hide()
WM.contextMenu = nil
mm.scripts.OnClick(mm, "RightButton")
Check(ns.Window.IsShown() and WM.contextMenu == nil, "right-click opens the window, no menu")
mm.scripts.OnClick(mm, "LeftButton")
Check(not ns.Window.IsShown(), "a click closes it")
Leproc_OnAddonCompartmentClick("Leproc", "RightButton")
Check(ns.Window.IsShown(), "the addon compartment opens it too")

-- Slash commands.
WM.printed = {}
WM.Slash("help")
Check(Printed("/leproc profile -") and Printed("/leproc on | off"), "help")
Check(Printed("v0.0.0 build abc1234"), "help gives the build")
WM.Slash("glow")
Check(ns.Window.IsShown() and ns.db.window.tab == "glow", "/leproc glow opens that tab")
ns.Window.Hide()
WM.Slash("profile Tester Smith")
Check(P.Current() == "Spare" and Printed("profile: Spare") and ns.db.window.tab == "profiles" and ns.Window.IsShown(),
	"/leproc profile names the one in use and opens the tab; it doesn't switch")
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
