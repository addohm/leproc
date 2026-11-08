-- Scenarios run by tests/run_tests.py. WM is the mock (wowmock.lua), ns the addon namespace.
local function Check(cond, msg) if not cond then error(msg, 2) end end
local function Printed(pattern)
	for _, line in ipairs(WM.printed) do if line:find(pattern, 1, true) then return true end end
	return false
end
local REVENGE, OVERPOWER = 6572, 7384
local Main1, Fixed1, Fixed2 = ActionButton1, MultiBarBottomLeftButton1, MultiBarBottomLeftButton2

-- A warrior: Overpower on the Battle Stance page, Revenge on the Defensive Stance page and on the
-- fixed second bar, a Revenge macro next to it. In Battle Stance.
WM.SetAction(73, OVERPOWER)
WM.SetAction(85, REVENGE)
WM.SetAction(61, 11601) -- a higher rank of Revenge
WM.SetAction(62, REVENGE, "macro")
WM.Fire("ADDON_LOADED", "Leproc")
WM.Fire("PLAYER_LOGIN")
Check(ns.Profiles.Current() == "Tester Smith", "the character's profile isn't in use")
Check(ns.db == LeprocDB.profiles["Tester Smith"], "ns.db isn't the profile")
Check(ns.Mode(ns.byKey.revenge) == "any" and ns.Mode(ns.byKey.overpower) == "any", "a warrior's abilities should default to any stance")
Check(ns.Mode(ns.byKey.riposte) == "off", "other classes' abilities are off")
Check(ns.byKey.revenge.stanceIds[71] and ns.byKey.overpower.stanceIds[2457], "stance IDs")
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
WM.Slash("revenge stance")
Check(ns.db.modes.revenge == "stance", "stance mode wasn't saved")
WM.SetStance(1)
WM.Combat("player", "BLOCK")
Check(not WM.Glowing(Fixed1), "stance mode: no glow in Battle Stance")
WM.SetStance(2)
Check(WM.Glowing(Fixed1) and WM.Glowing(Main1), "stance mode: switching to Defensive should light it")
WM.Advance(6)
WM.Slash("revenge default")
Check(ns.db.modes.revenge == nil, "default should clear the saved mode")
WM.Slash("riposte stance")
Check(Printed("doesn't need a stance"), "Riposte has no stance")
WM.Slash("riposte default")

-- Off: no glow.
WM.Slash("revenge off")
WM.Combat("player", "DODGE")
Check(not WM.Glowing(Fixed1) and not WM.Glowing(Main1), "off: no glow")
WM.Advance(6)
WM.Slash("revenge default")

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

-- The sound plays when an ability lights up (in combat too), not for the test.
ns.db.sound = "RAID_WARNING"
WM.combat = true
WM.Combat("player", "DODGE")
Check(WM.Played("RAID_WARNING"), "the sound should play when Revenge lights")
local played = #WM.sounds
WM.Combat("player", "PARRY")
Check(#WM.sounds == played, "already lit: no second sound")
WM.combat = false
WM.Advance(6)
WM.Slash("test")
Check(WM.Glowing(Fixed1) and WM.Glowing(Main1) and #WM.sounds == played, "the test lights everything tracked, silently")
Check(Printed("test: lighting Revenge, Overpower"), "the test says what it lights")
WM.Advance(6)
Check(not WM.Glowing(Fixed1), "the test ends after 5 s")
ns.db.sound = "none"

-- The glow follows the style picked.
ns.db.glow = "none"
WM.Combat("player", "DODGE")
Check(not WM.Glowing(Fixed1), "style none: no glow")
ns.db.glow = "modern"
ns.Refresh()
Check(WM.Glowing(Fixed1), "the modern glow should play")
WM.Advance(6)
ns.db.glow = "pixel"

-- The options window and its pages.
WM.Slash("")
Check(ns.Window.IsShown(), "/leproc didn't open the window")
ns.Window.Select("abilities")
local panel = ns.Window.CurrentPanel()
Check(panel.rows and #panel.rows == 2, "a warrior should have 2 ability rows")
Check(panel.rows[1].label.text:find("Revenge"), "the first row should be Revenge")
panel.rows[1].next.scripts.OnClick()
Check(ns.db.modes.revenge == "stance", "the arrow should step to Only in its stance")
Check(panel.rows[1].box.text == "Only in Defensive Stance", "the picker should name the stance")
WM.SetStance(2)
WM.SetAction(73, nil)
ns.Window.Refresh()
Check(panel.rows[2].label.text:find("not on screen"), "Overpower should be flagged as not on screen")
WM.SetAction(73, OVERPOWER)
WM.SetStance(1)
for _, id in ipairs({ "abilities", "glow", "general", "profiles" }) do
	ns.Window.Select(id)
	Check(ns.Window.CurrentPanel().stack, id .. " page didn't build")
end
ns.Window.Select("abilities")
ns.Window.Refresh()
WM.Slash("")
Check(not ns.Window.IsShown(), "/leproc didn't close the window")
WM.Slash("reset")
Check(ns.db.modes.revenge == nil, "reset should clear the modes")

-- Minimap: left-click opens, right-click runs the test.
Check(LeprocMinimapButton and LeprocMinimapButton:IsShown(), "no minimap button")
LeprocMinimapButton.scripts.OnClick(LeprocMinimapButton, "LeftButton")
Check(ns.Window.IsShown(), "left-click didn't open the window")
ns.Window.Hide()
Leproc_OnAddonCompartmentClick(nil, "RightButton")
Check(WM.Glowing(Fixed1), "right-click should light the buttons")
WM.Advance(6)
WM.Slash("minimap")
Check(not LeprocMinimapButton:IsShown() and ns.db.minimap.hide, "/leproc minimap didn't hide it")
WM.Slash("minimap")

-- Chat commands.
WM.Slash("help")
Check(Printed("/leproc test"), "help should list the test")
WM.Slash("list")
Check(Printed("revenge: any stance, on a bar you can see"), "list should show Revenge")
WM.Slash("nonsense")
Check(Printed("unknown command"), "an unknown command should say so")

-- Profiles: new, switch, copy, rename, delete, reset.
local P = ns.Profiles
WM.Slash("overpower off")
Check(P.New("Tank") and P.Current() == "Tank" and ns.db.modes.overpower == nil, "a new profile starts with defaults")
Check(P.CopyFrom("Tester Smith") and ns.db.modes.overpower == "off", "copy didn't copy")
Check(P.Rename("Prot") and P.Current() == "Prot" and LeprocDB.profiles.Tank == nil, "rename")
Check(P.Switch("Tester Smith") and ns.db.modes.overpower == "off", "switch back")
Check(not P.Delete("Tester Smith"), "the profile in use can't be deleted")
Check(P.Delete("Prot") and LeprocDB.profiles.Prot == nil, "delete")
Check(P.Reset() and ns.db.modes.overpower == nil and ns.db.glow == "pixel", "reset")
ns.Window.Show()
ns.Window.Select("profiles")
local resetRow
for _, row in ipairs(ns.Window.CurrentPanel().stack.rows) do
	if row.button and row.button.text == "Reset to defaults" then resetRow = row end
end
Check(resetRow, "no reset button on the Profiles tab")
WM.Slash("overpower off")
resetRow.button.scripts.OnClick(resetRow.button)
WM.Accept()
Check(ns.db.modes.overpower == nil, "the Reset button didn't reset after confirming")
ns.Window.Hide()

-- The surname isn't known when the addon loads: the first-name profile is replaced at login.
LeprocDB = nil
WM.surname = nil
ns.Profiles.Init()
Check(ns.Profiles.Current() == "Tester", "without a surname the key is the first name")
WM.surname = "Smith"
ns.Profiles.Init()
Check(ns.Profiles.Current() == "Tester Smith" and LeprocDB.profiles.Tester == nil, "the first-name profile should be dropped")

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
local function PrintedNow(f)
	WM.printed = {}
	f()
	return table.concat(WM.printed, "\n")
end
local out = PrintedNow(function() WM.Slash("bars") end)
Check(out:find("action buttons found") and out:find("MultiBarBottomLeftButton1 %(slot 61%): Revenge"), "bars should list Revenge's button: " .. out)
Check(not out:find("MacroRev") and out:find("and %d+ hidden buttons hold one"), "bars should count hidden buttons, not list them: " .. out)
mbar:Show()
out = PrintedNow(function() WM.Slash("macros") end)
Check(out:find('macro "Rev", text read, counts for Revenge'), "macros should show the stance-dance macro: " .. out)
Check(out:find('macro "Other", text read, no tracked ability'), "macros should show a macro with none: " .. out)
mbar:Hide()
WM.Combat("player", "BLOCK")
out = PrintedNow(function() WM.Slash("why revenge") end)
Check(out:find("Revenge: any stance %(default%)") and out:find("lit now: yes") and out:find("window: open, 5.0 s left"), "why while lit: " .. out)
Check(out:find("stance: needs Defensive Stance, you're not in it") and out:find("on screen: MultiBarBottomLeftButton1 %(slot 61%)"), "why: stance and buttons: " .. out)
WM.Cast(REVENGE)
out = PrintedNow(function() WM.Slash("why revenge") end)
Check(out:find("lit now: no") and out:find("window: closed") and out:find("cooldown: 5.0 s left"), "why after casting: " .. out)
WM.Advance(6)
out = PrintedNow(function() WM.Slash("why mongoose bite") end)
Check(out:find("not your class %(hunter%)"), "why for another class's ability: " .. out)
out = PrintedNow(function() WM.Slash("why") end)
Check(out:find("why which%? revenge, overpower"), "why without an ability lists them: " .. out)

-- The countdown: off by default; on, a lit button shows the whole seconds left, ticking down,
-- and nothing once the window closes.
WM.Combat("player", "BLOCK")
Check(WM.Countdown(Fixed1) == nil, "the countdown is off by default")
WM.Advance(6)
ns.db.countdown = true
WM.Combat("player", "BLOCK")
Check(WM.Countdown(Fixed1) == "5", "the countdown should start at 5: " .. tostring(WM.Countdown(Fixed1)))
WM.Advance(2.05)
Check(WM.Countdown(Fixed1) == "3", "the countdown should tick down: " .. tostring(WM.Countdown(Fixed1)))
WM.Advance(3)
Check(WM.Countdown(Fixed1) == nil and not WM.Glowing(Fixed1), "the countdown should go when the window closes")
WM.Slash("test")
Check(WM.Countdown(Main1) == "5", "the test shows the countdown too")
WM.Advance(6)
ns.db.countdown = false

-- Options > AddOns: Leproc is listed, and its button opens Leproc's window.
local cat = WM.settings[1]
Check(cat and cat.name == "Leproc" and cat.addon, "Leproc should be in Options > AddOns")
SettingsPanel:Show()
cat.frame.open.scripts.OnClick(cat.frame.open)
Check(ns.Window.IsShown() and not SettingsPanel:IsShown(), "the AddOns entry's button should open Leproc's window")
ns.Window.Hide()

-- Other classes: a rogue sees Riposte, a priest sees none.
WM.class = "ROGUE"
Check(#ns.ClassEntries() == 1 and ns.ClassEntries()[1].key == "riposte" and ns.Mode(ns.byKey.riposte) == "any", "a rogue's abilities")
WM.SetAction(64, 14251)
WM.Combat("player", "PARRY")
Check(WM.Glowing(MultiBarBottomLeftButton4), "Riposte should light after a parry")
WM.Advance(7)
WM.class = "PRIEST"
Check(#ns.ClassEntries() == 0, "a priest has none yet")
WM.Slash("list")
Check(Printed("no abilities Leproc tracks yet"), "list for a class without abilities")
WM.class = "HUNTER"
WM.SetAction(65, 1495)
WM.Combat("target", "DODGE")
Check(not WM.Glowing(MultiBarBottomLeftButton5), "Mongoose Bite follows your own dodge, not the target's")
WM.Combat("player", "DODGE")
Check(WM.Glowing(MultiBarBottomLeftButton5), "Mongoose Bite should light after you dodge")
