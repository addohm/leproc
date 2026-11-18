-- Scenarios run by tests/run_tests.py. WM is the mock (wowmock.lua), ns the addon namespace.
-- Step 1 of the rebuild: the window, profiles (managed on their tab, with switching by talents or
-- role), the minimap button and the Options > AddOns entry. Step 2a: the glows.
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

-- Step 2a: the glows. A warrior: Overpower on the Battle Stance page, Revenge on the Defensive
-- Stance page and on the fixed second bar, a Revenge macro next to it. In Battle Stance.
local REVENGE, OVERPOWER, EXECUTE = 6572, 7384, 5308
local Main1, Fixed1, Fixed2 = ActionButton1, MultiBarBottomLeftButton1, MultiBarBottomLeftButton2
local function PrintedNow(f)
	WM.printed = {}
	f()
	return table.concat(WM.printed, "\n")
end
ns.Window.Hide()
WM.SetAction(73, OVERPOWER)
WM.SetAction(85, REVENGE)
WM.SetAction(61, 11601) -- a higher rank of Revenge
WM.SetAction(62, REVENGE, "macro")
ns.Refresh()
Check(ns.Mode(ns.byKey.revenge) == "any" and ns.Mode(ns.byKey.overpower) == "any", "a warrior's abilities should default to any stance")
Check(ns.Mode(ns.byKey.riposte) == "off", "other classes' abilities are off")
Check(ns.byKey.revenge.stanceIds[71] and ns.byKey.overpower.stanceIds[2457], "stance IDs")
Check(ns.byKey.execute.stanceIds[2457] and ns.byKey.execute.stanceIds[2458] and not ns.byKey.execute.stanceIds[71], "Execute: Battle or Berserker")
Check(not WM.Glowing(Fixed1) and not WM.Glowing(Main1), "nothing should glow at login")

-- A partial block in Battle Stance lights Revenge, on every button you can see that holds it.
WM.Combat("player", "WOUND", "BLOCK_REDUCED")
Check(WM.Glowing(Fixed1), "Revenge should glow after a partial block, outside Defensive Stance")
Check(WM.Glowing(Fixed2), "a macro that casts Revenge should glow too")
Check(not WM.Glowing(Main1), "Overpower (the main bar in Battle Stance) shouldn't glow after a block")
Check(ns.Bars.OnScreen(ns.byKey.revenge) and ns.Bars.OnScreen(ns.byKey.overpower), "both are on screen in Battle Stance")
WM.Advance(4)
Check(WM.Glowing(Fixed1), "still lit inside the window")
WM.Advance(1.1)
Check(not WM.Glowing(Fixed1) and not WM.Glowing(Fixed2), "the window should close after 5 s")

-- Full blocks, dodges and parries count; a hit, a miss and a heal don't.
for _, ev in ipairs({ { "BLOCK" }, { "WOUND", "BLOCK" }, { "DODGE" }, { "PARRY" } }) do
	WM.Combat("player", ev[1], ev[2])
	Check(WM.Glowing(Fixed1), "Revenge should light after " .. ev[1] .. " " .. tostring(ev[2]))
	WM.Advance(6)
end
for _, ev in ipairs({ { "WOUND", "" }, { "WOUND", "CRITICAL" }, { "MISS" }, { "HEAL" } }) do
	WM.Combat("player", ev[1], ev[2])
	Check(not WM.Glowing(Fixed1), "Revenge shouldn't light after " .. ev[1] .. " " .. tostring(ev[2]))
end
-- Your target's block doesn't count; its dodge lights Overpower (not Revenge).
WM.Combat("target", "BLOCK")
Check(not WM.Glowing(Fixed1), "the target's block isn't yours")
WM.Combat("target", "DODGE")
Check(WM.Glowing(Main1) and not WM.Glowing(Fixed1), "the target's dodge should light Overpower only")
WM.Advance(6)
-- Events for other units never reach Leproc (it registers player and target only).
WM.Combat("party1", "DODGE")
Check(not WM.Glowing(Fixed1) and not WM.Glowing(Main1), "a party member's dodge")

-- Using it closes the window and starts its cooldown; a trigger during the cooldown lights it
-- once the cooldown ends, if the window is still open.
WM.Combat("player", "DODGE")
WM.Cast(REVENGE)
Check(not WM.Glowing(Fixed1), "using Revenge should turn its glow off")
WM.Advance(1)
WM.Combat("player", "PARRY")
Check(not WM.Glowing(Fixed1), "Revenge is on cooldown")
WM.Advance(4.1)
Check(WM.Glowing(Fixed1), "the cooldown ended inside the window: it should light")
WM.Advance(1)
Check(not WM.Glowing(Fixed1), "the window from the parry closed")
WM.Cast(12345) -- some other spell
WM.Advance(6)

-- Switching stance: the main bar flips to the Defensive page, which holds Revenge.
WM.Combat("target", "DODGE")
Check(WM.Glowing(Main1), "Overpower lit in Battle Stance")
WM.SetStance(2)
Check(not WM.Glowing(Main1), "the main bar now holds Revenge, which isn't lit")
Check(not ns.Bars.OnScreen(ns.byKey.overpower), "Overpower isn't on screen in Defensive Stance")
WM.Combat("player", "BLOCK")
Check(WM.Glowing(Main1) and WM.Glowing(Fixed1), "Revenge should glow on the main bar and the fixed bar")
WM.Advance(6)

-- Only in its stance: Revenge lights only in Defensive Stance, and turns on when you switch.
ns.SetMode(ns.byKey.revenge, "stance")
Check(ns.db.modes.revenge == "stance", "stance mode wasn't saved")
WM.SetStance(1)
WM.Combat("player", "BLOCK")
Check(not WM.Glowing(Fixed1), "stance mode: no glow in Battle Stance")
WM.SetStance(2)
Check(WM.Glowing(Fixed1) and WM.Glowing(Main1), "stance mode: switching to Defensive should light it")
WM.Advance(6)
ns.SetMode(ns.byKey.revenge, "default")
Check(ns.db.modes.revenge == nil, "default should clear the saved mode")
ns.SetMode(ns.byKey.riposte, "stance")
Check(ns.Mode(ns.byKey.riposte) == "any", "an ability without a stance can't be stance-only")
ns.SetMode(ns.byKey.riposte, "default")

-- Off: no glow.
ns.SetMode(ns.byKey.revenge, "off")
WM.Combat("player", "DODGE")
Check(not WM.Glowing(Fixed1) and not WM.Glowing(Main1), "off: no glow")
WM.Advance(6)
ns.SetMode(ns.byKey.revenge, "default")

-- Leproc turned off: nothing lights, the test included.
ns.SetEnabled(false)
WM.Combat("player", "DODGE")
Check(not WM.Glowing(Fixed1), "Leproc off: no glow")
Check(PrintedNow(function() WM.Slash("test") end):find("Leproc is off"), "the test says Leproc is off")
Check(not WM.Glowing(Fixed1), "and lights nothing")
ns.SetEnabled(true)
Check(WM.Glowing(Fixed1), "back on: the dodge's window is still open")
WM.Advance(6)

-- A hidden bar can't glow, and the ability isn't on screen there.
WM.SetStance(1)
WM.bottomLeft:Hide()
WM.Combat("player", "DODGE")
Check(not WM.Glowing(Fixed1), "a hidden bar shouldn't glow")
Check(not ns.Bars.OnScreen(ns.byKey.revenge), "Revenge isn't on screen with its bar hidden in Battle Stance")
WM.bottomLeft:Show()
WM.Advance(6)

-- Secret values are skipped, without errors.
issecretvalue = function(v) return v == "SECRET" end
WM.Combat("player", "SECRET")
WM.Combat("player", "WOUND", "SECRET")
WM.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-GUID", "SECRET")
Check(not WM.Glowing(Fixed1), "secret events shouldn't light anything")
issecretvalue = nil

-- The test lights everything tracked of your class for 5 s.
WM.Slash("test")
Check(WM.Glowing(Fixed1) and WM.Glowing(Main1), "the test lights everything tracked")
Check(Printed("test: lighting Overpower, Revenge, Execute, Victory Rush"), "the test says what it lights")
WM.Advance(6)
Check(not WM.Glowing(Fixed1), "the test ends after 5 s")

-- The glow follows the style picked.
ns.db.glow = "none"
WM.Combat("player", "DODGE")
Check(not WM.Glowing(Fixed1), "style none: no glow")
ns.db.glow = "modern"
ns.Refresh()
Check(WM.Glowing(Fixed1), "the modern glow should play")
WM.Advance(6)
ns.db.glow = "pixel"

-- Execute (ProcGlow's): the game decides, in Battle or Berserker Stance. Addons can't see the
-- target's health, so in Defensive Stance it can't light.
WM.SetAction(63, EXECUTE)
local ExeButton = MultiBarBottomLeftButton3
WM.spellUsable.Execute = true -- the target is below 20%
WM.Fire("SPELL_UPDATE_USABLE")
Check(WM.Glowing(ExeButton), "Execute lights when the game says usable, in Battle Stance")
WM.SetStance(3)
Check(WM.Glowing(ExeButton), "in Berserker Stance too")
WM.SetStance(2)
Check(not WM.Glowing(ExeButton), "not in Defensive Stance: the game isn't asked there")
WM.SetStance(1)
WM.spellUsable.Execute = "short"
WM.Fire("SPELL_UPDATE_USABLE")
Check(WM.Glowing(ExeButton), "short of rage still glows")
WM.spellUsable.Execute = nil
WM.Fire("SPELL_UPDATE_USABLE")
Check(not WM.Glowing(ExeButton), "the game says no: dark")
-- The game's own cooldown counts where it shows it; the global cooldown doesn't.
WM.spellUsable.Execute = true
WM.cooldowns.Execute = { WM.now, 1.5 }
WM.Fire("SPELL_UPDATE_COOLDOWN")
Check(WM.Glowing(ExeButton), "the global cooldown doesn't count")
WM.cooldowns.Execute = { WM.now, 10 }
WM.Fire("SPELL_UPDATE_COOLDOWN")
Check(not WM.Glowing(ExeButton), "on the game's cooldown: dark")
issecretvalue = function(v) return v == "SECRET" end
WM.cooldowns.Execute = "SECRET"
WM.Fire("SPELL_UPDATE_COOLDOWN")
Check(WM.Glowing(ExeButton), "a hidden cooldown falls back to your casts (none): lit")
issecretvalue = nil
WM.cooldowns.Execute = nil
WM.spellUsable.Execute = nil
WM.Fire("SPELL_UPDATE_USABLE")

-- Victory Rush: the game decides, in any stance (no stance needed).
WM.SetAction(66, 402927)
local VRButton = MultiBarBottomLeftButton6
WM.spellUsable["Victory Rush"] = true
WM.SetStance(2)
Check(WM.Glowing(VRButton), "Victory Rush lights when the game says usable, in any stance")
WM.spellUsable["Victory Rush"] = nil
WM.Fire("SPELL_UPDATE_USABLE")
Check(not WM.Glowing(VRButton), "and goes when the game says no")
WM.SetStance(1)

-- Blizzard's own highlight lights an ability, in any stance, but not during its cooldown.
WM.overlayed[11601] = true
WM.Fire("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 11601)
Check(WM.Glowing(Fixed1), "Blizzard's highlight lights Revenge, with no trigger, in Battle Stance")
WM.Cast(REVENGE)
Check(not WM.Glowing(Fixed1), "used: dark for its cooldown, highlight or not")
WM.Advance(5.1)
Check(WM.Glowing(Fixed1), "the cooldown's over and the highlight's still on: lit")
WM.overlayed[11601] = nil
WM.Fire("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", 11601)
Check(not WM.Glowing(Fixed1), "the highlight goes: dark")
WM.SetAction(63, nil)
WM.SetAction(66, nil)
ns.Refresh()

-- Bar addons: EllesmereUI hides Blizzard's bars and builds its own buttons (EABButton1...),
-- which hold their slot in `_state_action`, possibly after login. Leproc finds them by scanning.
WM.mainBar:Hide()
WM.bottomLeft:Hide()
WM.Fire("PLAYER_ENTERING_WORLD")
Check(not ns.Bars.OnScreen(ns.byKey.revenge), "Blizzard's bars are hidden and there's no other bar yet")
-- EllesmereUI builds its bars late, with no event Leproc listens to: the 2 s watch finds them.
local eab = WM.AddonBar("EAB", { 73, 61 }, "state")
WM.Advance(2)
Check(WM.Glowing(EABButton1) == false and ns.Bars.OnScreen(ns.byKey.revenge) and ns.Bars.OnScreen(ns.byKey.overpower), "the late EAB buttons should be found")
WM.Combat("player", "PARRY")
Check(WM.Glowing(EABButton2) and not WM.Glowing(EABButton1), "Revenge should glow on EllesmereUI's button")
Check(not WM.Glowing(Fixed1), "Blizzard's hidden button shouldn't glow")
WM.Advance(6)
EABButton1._state_action = 85 -- the bar addon pages to Defensive Stance
WM.Fire("UPDATE_BONUS_ACTIONBAR")
WM.Combat("player", "BLOCK")
Check(WM.Glowing(EABButton1) and WM.Glowing(EABButton2), "a paged EAB button holding Revenge should glow")
WM.Advance(6)
-- Buttons on the secure action template hold their slot in the "action" attribute. One built in
-- combat is found once combat ends.
WM.combat = true
local bt = WM.AddonBar("BT4Bar", { 62 }, "attribute")
WM.Fire("PLAYER_ENTERING_WORLD")
WM.Combat("player", "DODGE")
Check(not WM.Glowing(BT4BarButton1), "no overlay can be made in combat")
WM.combat = false
WM.Fire("PLAYER_REGEN_ENABLED")
Check(not WM.Glowing(BT4BarButton1), "combat ending closes the window")
WM.Combat("player", "DODGE")
Check(WM.Glowing(BT4BarButton1), "after combat the attribute button should be found, and glow")
WM.Advance(6)
eab:Hide()
bt:Hide()
WM.mainBar:Show()
WM.bottomLeft:Show()
EABButton1._state_action = 73

-- Every bar on ProcGlow's list is found, however the button holds its slot. Each holds Revenge
-- (a different rank or slot each) and glows after a block.
WM.mainBar:Hide()
WM.bottomLeft:Hide()
local listed = WM.AddonBar("Listed", {}, "state")
local LIST = {
	{ "MultiBarBottomRightButton1", "action" }, { "MultiBarRightButton1", "action" },
	{ "MultiBarLeftButton1", "action" }, { "MultiBar5Button1", "action" }, { "MultiBar6Button1", "action" },
	{ "MultiBar7Button1", "action" }, { "MultiBar8Button1", "action" },
	{ "BT4Button1", "state" }, { "BT4Button120", "attribute" },
	{ "DominosActionButton1", "attribute" }, { "DominosActionButton120", "action" },
	{ "ElvUI_Bar1Button1", "state" }, { "ElvUI_Bar15Button12", "state" },
	{ "EABButton180", "state" },
	{ "GamepadMainActionBarFramePageUnitBottomCenteredAnchorBottomBarActionButton1", "action" },
	{ "GamepadMainActionBarFramePageUnitShortcutsActionBarActionButton1", "action" },
}
for i, b in ipairs(LIST) do
	WM.SetAction(120 + i, REVENGE)
	WM.Button(b[1], listed, b[2], 120 + i)
end
WM.Fire("PLAYER_ENTERING_WORLD")
WM.Combat("player", "BLOCK")
for _, b in ipairs(LIST) do
	Check(WM.Glowing(_G[b[1]]), b[1] .. " (" .. b[2] .. ") should be found and glow")
end
WM.Advance(6)
listed:Hide()

-- Macros: a stance-dance macro names Revenge, so its button is Revenge's even while it would
-- cast Defensive Stance; one naming both abilities lights for either; #showtooltip counts; a
-- macro naming no tracked ability doesn't light.
local DEFENSIVE = 71
local mbar = WM.AddonBar("Macros", {}, "state")
WM.SetMacro(140, 1, "Rev", "#showtooltip\n/cast [nostance:2] Defensive Stance; Revenge", DEFENSIVE)
WM.SetMacro(141, 2, "Both", "/cast [stance:1] Overpower; [stance:2] !Revenge(Rank 6)", OVERPOWER)
WM.SetMacro(142, 3, "Tip", "#showtooltip Revenge\n/startattack\n/cast Revenge", nil)
WM.SetMacro(143, 4, "Other", "/cast [nostance:2] Defensive Stance; Shield Block", DEFENSIVE)
WM.SetMacro(144, 5, "Seq", "/castsequence reset=5 Sunder Armor, Revenge", nil)
local mRev = WM.Button("MacroRev", mbar, "action", 140)
local mBoth = WM.Button("MacroBoth", mbar, "action", 141)
local mTip = WM.Button("MacroTip", mbar, "action", 142)
local mOther = WM.Button("MacroOther", mbar, "action", 143)
local mSeq = WM.Button("MacroSeq", mbar, "action", 144)
WM.Fire("PLAYER_ENTERING_WORLD")
WM.Combat("player", "WOUND", "BLOCK_REDUCED")
Check(WM.Glowing(mRev), "a stance-dance macro should glow for Revenge in Battle Stance")
Check(WM.Glowing(mBoth), "a macro naming Revenge in another clause should glow")
Check(WM.Glowing(mTip), "a macro with #showtooltip Revenge should glow")
Check(WM.Glowing(mSeq), "a /castsequence with Revenge should glow")
Check(not WM.Glowing(mOther), "a macro without a tracked ability shouldn't glow")
WM.Advance(6)
WM.Combat("target", "DODGE")
Check(WM.Glowing(mBoth) and not WM.Glowing(mRev), "the two-ability macro should glow for Overpower too")
WM.Advance(6)
mbar:Hide()
WM.mainBar:Show()
WM.bottomLeft:Show()

-- Diagnostics: /leproc bars, macros and why say what Leproc sees.
local out = PrintedNow(function() WM.Slash("bars") end)
Check(out:find("action buttons found") and out:find("MultiBarBottomLeftButton1 %(slot 61%): Revenge"), "bars should list Revenge's button: " .. out)
Check(not out:find("MacroRev") and out:find("and %d+ hidden buttons hold one"), "bars should count hidden buttons, not list them: " .. out)
out = PrintedNow(function() WM.Slash("rescan") end)
Check(out:find("action buttons found"), "rescan scans and reports: " .. out)
mbar:Show()
out = PrintedNow(function() WM.Slash("macros") end)
Check(out:find('macro "Rev", text read, counts for Revenge'), "macros should show the stance-dance macro: " .. out)
Check(out:find('macro "Other", text read, no tracked ability'), "macros should show a macro with none: " .. out)
mbar:Hide()
WM.Combat("player", "BLOCK")
out = PrintedNow(function() WM.Slash("why revenge") end)
Check(out:find("Revenge: any stance %(default%)") and out:find("lit now: yes") and out:find("window: open, %d.%d s left"), "why while lit: " .. out)
Check(out:find("stance: needs Defensive Stance, you're not in it") and out:find("on screen: MultiBarBottomLeftButton1 %(slot 61%)"), "why: stance and buttons: " .. out)
Check(out:find("Blizzard's highlight: off") and out:find("game: can't say here %(not in its stance%): Leproc's window decides"), "why: the highlight and the game: " .. out)
WM.Cast(REVENGE)
out = PrintedNow(function() WM.Slash("why revenge") end)
Check(out:find("lit now: no") and out:find("window: closed") and out:find("cooldown: 5.0 s left"), "why after casting: " .. out)
WM.Advance(6)
out = PrintedNow(function() WM.Slash("why mongoose bite") end)
Check(out:find("not your class %(hunter%)"), "why for another class's ability: " .. out)
out = PrintedNow(function() WM.Slash("why execute") end)
Check(out:find("stance: needs Battle Stance or Berserker Stance, you're in it") and not out:find("window:"), "why for Execute (no window): " .. out)
out = PrintedNow(function() WM.Slash("why") end)
Check(out:find("why which%? overpower, revenge, execute, victoryrush"), "why without an ability lists them: " .. out)

-- /leproc log: triggers, glows, casts, and what the game says, with secret values shown as such.
out = PrintedNow(function() WM.Slash("log") end)
Check(out:find("combat text settings: enableFloatingCombatText 1, floatingCombatTextReactives 1"), "log on shows the combat text settings: " .. out)
Check(out:find("log on") and out:find("Overpower now: game says usable: spell no, button slot 73 no, highlighted: no, in Battle Stance"), "log on: " .. out)
out = PrintedNow(function() WM.Combat("target", "DODGE") end)
Check(out:find("your target dodged %(target DODGE%) %-> window Overpower %(%d.%d s, allowing for the delay%), in Battle Stance"), "log: the trigger: " .. out)
Check(out:find("Overpower: game says usable: spell yes, button slot 73 yes"), "log: the game's answer at the trigger: " .. out)
Check(out:find("Overpower glow ON %(Battle Stance%)"), "log: the glow: " .. out)
out = PrintedNow(function() WM.Fire("ACTION_USABLE_CHANGED", { { slot = 73, usable = true, noMana = false } }) end)
Check(out:find("game: Overpower button %(slot 73%) usable: yes"), "log: the game changing its mind: " .. out)
out = PrintedNow(function() WM.Fire("ACTION_USABLE_CHANGED", { { slot = 73, usable = false, noMana = true } }) end)
Check(out:find("game: Overpower button %(slot 73%) usable: no %(short of power%)"), "log: short of power: " .. out)
out = PrintedNow(function() WM.Fire("ACTION_USABLE_CHANGED", { { slot = 73, usable = false, noMana = true } }) end)
Check(out == "", "log: no line when nothing changed: " .. out)
WM.spellUsable.Overpower = "short"
out = PrintedNow(function() WM.Fire("SPELL_UPDATE_USABLE") end)
Check(out:find("game: Overpower spell usable: no %(short of power%)") and not out:find("Revenge spell"), "log: by spell, only changes: " .. out)
issecretvalue = function(v) return v == "SECRET" end
WM.spellUsable.Overpower = "SECRET"
out = PrintedNow(function() WM.Fire("SPELL_UPDATE_USABLE") end)
Check(out:find("game: Overpower spell usable: secret"), "log: secret values: " .. out)
issecretvalue = nil
WM.spellUsable.Overpower = nil
out = PrintedNow(function() WM.Cast(OVERPOWER) end)
Check(out:find("you cast Overpower %-> its window closes, dark for its 5 s cooldown") and out:find("Overpower glow off"), "log: the cast: " .. out)
out = PrintedNow(function() WM.Fire("PLAYER_TARGET_CHANGED") end)
Check(out:find("new target"), "log: target change: " .. out)
-- The reactive-alert probe: the game's "<Overpower>" combat text, with the spell when readable.
WM.combatText = "Overpower"
out = PrintedNow(function() WM.Fire("COMBAT_TEXT_UPDATE", "SPELL_ACTIVE") end)
Check(out:find("game: reactive alert %(SPELL_ACTIVE%) for Overpower, in Battle Stance"), "log: reactive alert: " .. out)
issecretvalue = function(v) return v == "SECRET" end
WM.combatText = "SECRET"
out = PrintedNow(function() WM.Fire("COMBAT_TEXT_UPDATE", "SPELL_ACTIVE") end)
Check(out:find("for a spell the game hides"), "log: hidden reactive alert: " .. out)
issecretvalue = nil
out = PrintedNow(function() WM.Fire("COMBAT_TEXT_UPDATE", "DAMAGE") end)
Check(out == "", "log: other combat text isn't logged: " .. out)
-- The proc-highlight probe: Blizzard's events for any spell, and at a trigger whether the
-- ability is highlighted (any rank).
out = PrintedNow(function() WM.Fire("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 11584) end)
Check(out:find("game: button highlight ON for Overpower %(11584%), in Battle Stance"), "log: highlight on: " .. out)
out = PrintedNow(function() WM.Fire("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", 12345) end)
Check(out:find("game: button highlight off for spell 12345"), "log: highlight off, another spell: " .. out)
out = PrintedNow(function() WM.Fire("SPELL_ACTIVATION_OVERLAY_HIDE") end)
Check(out:find("game: screen proc alert off for everything"), "log: alert off with no spell: " .. out)
WM.overlayed[11584] = true
WM.SetStance(2)
WM.Advance(5.1)
out = PrintedNow(function() WM.Fire("UNIT_COMBAT", "target", "DODGE", "", 0, 1) end)
Check(out:find("Overpower: game says usable: spell no, highlighted: yes"), "log: highlighted at the trigger: " .. out)
WM.overlayed[11584] = nil
WM.SetStance(1)
WM.Advance(6)
out = PrintedNow(function() WM.Cast(12294) end)
Check(out:find("you cast spell 12294") or out:find("you cast %a"), "log: other casts: " .. out)
out = PrintedNow(function() WM.Combat("player", "DODGE") end)
Check(out:find("you dodged %(player DODGE%) %-> window Revenge %(%d.%d s, allowing for the delay%), in Battle Stance") and not out:find("Mongoose"), "log: only your class's abilities: " .. out)
Check(out:find("t%d+%.%d you dodged"), "log: the game's timer: " .. out)
out = PrintedNow(function() WM.Fire("PLAYER_DEAD") end)
Check(out:find("you died") and out:find("windows cleared: you died") and out:find("Revenge glow off"), "log: death clears the windows: " .. out)
Check(not WM.Glowing(Fixed1), "no glow after death")
WM.Combat("player", "BLOCK")
WM.Fire("PLAYER_REGEN_ENABLED")
Check(not WM.Glowing(Fixed1), "combat ending clears the windows")
WM.Slash("log show")
Check(LeprocLog and LeprocLog:IsShown(), "log show should open the window")
Check(#LeprocDB.log.entries > 5, "the log should be kept")
WM.Slash("log off")
out = PrintedNow(function() WM.Fire("PLAYER_TARGET_CHANGED") end)
Check(out == "", "log off: nothing logged: " .. out)
LeprocDB.log.on = true
for i = 1, 10010 do ns.Log.Add("line " .. i) end
Check(#LeprocDB.log.entries == 10000 and LeprocDB.log.entries[10000]:find("line 10010"), "the log keeps the last 10000 lines")
WM.Slash("log show")
local shown = LeprocLog.box.text
Check(shown:find("^%(The newest 3000 of 10000 lines") and shown:find("line 10010$") and not shown:find("line 7010\n"), "the window shows the newest 3000")
LeprocDB.log.on = false
WM.Slash("log clear")
Check(#LeprocDB.log.entries == 0, "log clear")
WM.Advance(6)

-- A target's dodge while you're out of combat isn't yours (the owner's log: four while a party
-- member fought his target): ignored, and the log says so. Your own block still counts.
WM.fighting = false
out = PrintedNow(function() WM.Slash("log") end)
WM.SetStance(2)
WM.Advance(1)
out = PrintedNow(function() WM.Fire("UNIT_COMBAT", "target", "DODGE", "", 0, 1) end)
Check(out:find("your target dodged %(target DODGE%) %-> ignored: you're not in combat"), "the log says why: " .. out)
Check(not ns.Track.IsLit(ns.byKey.overpower), "no Overpower guess out of combat")
WM.Combat("player", "BLOCK")
Check(ns.Track.IsLit(ns.byKey.revenge), "your own block still counts")
WM.fighting = true
WM.Fire("UNIT_COMBAT", "target", "DODGE", "", 0, 1)
Check(ns.Track.IsLit(ns.byKey.overpower), "in combat the guess lights it")
WM.Slash("log off")
WM.SetStance(1)
WM.Advance(6)

-- The game decides where it can. The owner's logs: the game makes Revenge usable 0.2-0.9 s
-- before the report of the block reaches addons, and ends it 5 s after its own start.
LeprocDB.delay = nil
Check(ns.Track.Delay("player") == 0.5 and ns.Track.Delay("target") == 0.4, "the starting delays, from the owner's logs")
WM.SetStance(2)
WM.Advance(1)
WM.Combat("player", "BLOCK", nil, 0.7)
Check(WM.Glowing(Fixed1), "in Defensive Stance Revenge lights the moment the game says so, before the report")
WM.short = true
WM.Fire("SPELL_UPDATE_USABLE")
Check(WM.Glowing(Fixed1), "short of power still glows")
WM.short = false
WM.Fire("SPELL_UPDATE_USABLE")
WM.Advance(0.7)
Check(math.abs(ns.Track.Delay("player") - (0.5 * 0.7 + 0.7 * 0.3)) < 0.001, "the report's delay should be measured: " .. ns.Track.Delay("player"))
WM.Advance(4.29)
Check(WM.Glowing(Fixed1), "still lit just before the game's 5 s")
WM.Advance(0.02)
Check(not WM.Glowing(Fixed1), "dark the moment the game says it's over, not 5 s after the late report")
-- Out of its stance the game can't say: Leproc's window, shortened by the measured delay.
WM.SetStance(1)
WM.Advance(1)
local d = ns.Track.Delay("player")
WM.Combat("player", "BLOCK", nil, 0.7)
Check(not WM.Glowing(Fixed1), "in Battle Stance Revenge waits for the report")
WM.Advance(0.7)
Check(WM.Glowing(Fixed1), "the report lights it")
WM.Advance(5 - d - 0.1)
Check(WM.Glowing(Fixed1), "lit until its shortened window ends")
WM.Advance(0.2)
Check(not WM.Glowing(Fixed1), "dark " .. string.format("%.2f", d) .. " s before the full 5 s")
-- Overpower in Battle Stance: the game ending it early (the owner's PvP log) turns it off.
WM.Combat("target", "DODGE")
Check(WM.Glowing(Main1), "Overpower lights")
WM.Advance(1.2)
WM.reactive.Overpower = WM.now
WM.Fire("SPELL_UPDATE_USABLE")
Check(not WM.Glowing(Main1), "the game said no after 1.2 s: dark")
WM.Advance(5)
-- A target dodge the game didn't count (someone else's attack) in Defensive Stance lights
-- Overpower by guess; switching to Battle Stance, the game says no and the guess goes.
WM.SetStance(2)
WM.Advance(1)
WM.Fire("UNIT_COMBAT", "target", "DODGE", "", 0, 1)
Check(ns.Track.IsLit(ns.byKey.overpower), "the guess lights Overpower in Defensive Stance")
WM.SetStance(1)
Check(not ns.Track.IsLit(ns.byKey.overpower) and not WM.Glowing(Main1), "in Battle Stance the game's no wins")
WM.SetStance(2)
Check(not ns.Track.IsLit(ns.byKey.overpower), "and the guess stays closed")
WM.SetStance(1)
WM.Advance(6)
local whyOut = PrintedNow(function() WM.Slash("why overpower") end)
Check(whyOut:find("game: not usable %(it decides here%)") and whyOut:find("delay: the game's reports of your target's dodges"), "why shows the game and the delay: " .. whyOut)

-- Other classes: a rogue sees Riposte, a priest sees none.
WM.class = "ROGUE"
Check(#ns.ClassEntries() == 1 and ns.ClassEntries()[1].key == "riposte" and ns.Mode(ns.byKey.riposte) == "any", "a rogue's abilities")
WM.SetAction(64, 14251)
WM.Combat("player", "PARRY")
Check(WM.Glowing(MultiBarBottomLeftButton4), "Riposte should light after a parry")
WM.Advance(7)
WM.class = "PRIEST"
Check(#ns.ClassEntries() == 0, "a priest has none yet")
Check(PrintedNow(function() WM.Slash("test") end):find("nothing of your class is tracked"), "the test for a class without abilities")
WM.Advance(6)
WM.class = "HUNTER"
WM.SetAction(65, 1495)
WM.Combat("target", "DODGE")
Check(not WM.Glowing(MultiBarBottomLeftButton5), "Mongoose Bite follows your own dodge, not the target's")
WM.Combat("player", "DODGE")
Check(WM.Glowing(MultiBarBottomLeftButton5), "Mongoose Bite should light after you dodge")
WM.Advance(6)

-- A paladin: Hammer of Wrath when the game says usable (the target below 20%); Exorcism only on
-- an undead or demon target, never when the game hides what it is, and dark for its cooldown.
WM.class = "PALADIN"
local HOW, EXORCISM = 24275, 879
WM.SetAction(67, HOW)
WM.SetAction(68, EXORCISM)
local HowButton, ExoButton = MultiBarBottomLeftButton7, MultiBarBottomLeftButton8
WM.spellUsable["Hammer of Wrath"] = true
WM.Fire("SPELL_UPDATE_USABLE")
Check(WM.Glowing(HowButton), "Hammer of Wrath lights when the game says usable")
WM.spellUsable["Hammer of Wrath"] = nil
WM.Fire("SPELL_UPDATE_USABLE")
Check(not WM.Glowing(HowButton), "and goes when it says no")
WM.spellUsable.Exorcism = true
WM.target = { type = 7 } -- a humanoid
WM.Fire("PLAYER_TARGET_CHANGED")
Check(not WM.Glowing(ExoButton), "Exorcism doesn't light on a humanoid, usable or not")
WM.target = { type = 6 } -- undead
WM.Fire("PLAYER_TARGET_CHANGED")
Check(WM.Glowing(ExoButton), "Exorcism lights on an undead target")
WM.target = { type = 3 } -- a demon
WM.Fire("PLAYER_TARGET_CHANGED")
Check(WM.Glowing(ExoButton), "and on a demon")
WM.target = { type = 6, dead = true }
WM.Fire("PLAYER_TARGET_CHANGED")
Check(not WM.Glowing(ExoButton), "not on a dead one")
issecretvalue = function(v) return v == "SECRET" end
WM.target = { type = "SECRET" }
WM.Fire("PLAYER_TARGET_CHANGED")
Check(not WM.Glowing(ExoButton), "the game hides the type (a dungeon): dark")
issecretvalue = nil
WM.target = { type = 6 }
WM.Fire("PLAYER_TARGET_CHANGED")
WM.Cast(EXORCISM)
Check(not WM.Glowing(ExoButton), "used: dark for its 15 s cooldown")
WM.Advance(15.1)
Check(WM.Glowing(ExoButton), "ready again")
out = PrintedNow(function() WM.Slash("why exorcism") end)
Check(out:find("target: undead or a demon") and out:find("lit now: yes"), "why for Exorcism: " .. out)
WM.target = nil
WM.spellUsable.Exorcism = nil
WM.Fire("PLAYER_TARGET_CHANGED")
Check(not WM.Glowing(ExoButton), "no target: dark")
WM.class = "WARRIOR"
for slot = 64, 68 do WM.SetAction(slot, nil) end
ns.Refresh()

-- Reset all settings: asks, then wipes everything and reloads.
ns.ResetAll()
WM.Accept()
Check(LeprocDB == nil and WM.reloaded, "reset all wipes LeprocDB and reloads")
