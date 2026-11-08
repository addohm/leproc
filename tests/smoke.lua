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
Check(panel.rows and #panel.rows == 3, "a warrior should have 3 ability rows")
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
local function PrintedNow(f)
	WM.printed = {}
	f()
	return table.concat(WM.printed, "\n")
end
local out = PrintedNow(function() WM.Slash("bars") end)
Check(out:find("stance bar buttons found") and out:find("MultiBarBottomLeftButton1 %(slot 61%): Revenge"), "bars should list Revenge's button: " .. out)
Check(not out:find("MacroRev") and out:find("and %d+ hidden buttons hold one"), "bars should count hidden buttons, not list them: " .. out)
mbar:Show()
out = PrintedNow(function() WM.Slash("macros") end)
Check(out:find('macro "Rev", text read, counts for Revenge'), "macros should show the stance-dance macro: " .. out)
Check(out:find('macro "Other", text read, no tracked ability'), "macros should show a macro with none: " .. out)
mbar:Hide()
WM.Combat("player", "BLOCK")
out = PrintedNow(function() WM.Slash("why revenge") end)
Check(out:find("Revenge: any stance %(default%)") and out:find("lit now: yes") and out:find("window: open, %d.%d s left"), "why while lit: " .. out)
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

-- Also glow: Revenge points at Defensive Stance. While Revenge is lit and you're not in
-- Defensive Stance, its stance bar button and any action button holding it glow too.
WM.SetAction(66, 71) -- Defensive Stance on the fixed bar
local DefButton = MultiBarBottomLeftButton6
Check(#ns.Bars.Forms() == 3 and ns.Bars.Forms()[2] == "Defensive Stance", "the warrior's stances")
WM.Combat("player", "BLOCK")
Check(not WM.Glowing(StanceButton2) and not WM.Glowing(DefButton), "nothing else glows by default")
WM.Advance(6)
ns.Window.Show()
ns.Window.Select("abilities")
local apanel = ns.Window.CurrentPanel()
Check(apanel.also and #apanel.also == 3, "each ability should have an Also glow row")
local alsoRev = apanel.also[1]
alsoRev.box.scripts.OnClick() -- Nothing else -> Battle Stance
alsoRev.box.scripts.OnClick() -- -> Defensive Stance
Check(ns.db.also.revenge == "Defensive Stance" and alsoRev.box.text == "Defensive Stance", "the picker should set Defensive Stance")
ns.Window.Hide()
WM.Combat("player", "BLOCK")
Check(WM.Glowing(Fixed1), "Revenge glows")
Check(WM.Glowing(StanceButton2) and not WM.Glowing(StanceButton1) and not WM.Glowing(StanceButton3), "the Defensive Stance button on the stance bar should glow")
Check(WM.Glowing(DefButton), "an action button holding Defensive Stance should glow")
Check(PrintedNow(function() WM.Slash("why revenge") end):find("also glows: the Defensive Stance button"), "why shows Also glow")
ns.db.countdown = true
ns.Refresh()
Check(WM.Countdown(StanceButton2) == "5", "the stance button shows the countdown too")
ns.db.countdown = false
WM.SetStance(2)
Check(WM.Glowing(Fixed1) and not WM.Glowing(StanceButton2) and not WM.Glowing(DefButton), "in Defensive Stance only Revenge glows")
WM.SetStance(1)
Check(WM.Glowing(StanceButton2), "back in Battle Stance the stance button glows again")
WM.Advance(6)
Check(not WM.Glowing(StanceButton2) and not WM.Glowing(DefButton), "the stance glow ends with the window")
local out2 = PrintedNow(function() WM.Slash("bars") end)
Check(out2:find("3 stance bar buttons found"), "bars counts stance buttons: " .. out2)
WM.Slash("reset")
Check(ns.db.also.revenge == nil, "reset clears Also glow")
WM.SetAction(66, nil)

-- Proc buffs: Bloodthrill makes Overpower usable, Victorious Victory Rush. The game shows the
-- glow (a slot button in Blizzard's aura container) while you have the buff; Leproc only places
-- it over the buttons, out of combat, and never reads the buff.
local VICTORY, VICTORIOUS, BLOODTHRILL = 402927, 402975, 1289681
WM.SetAction(67, VICTORY)
local VRButton = MultiBarBottomLeftButton7
ns.Refresh()
Check(not WM.ProcGlowing(VRButton), "no Victorious, no glow")
WM.SetAura(VICTORIOUS, true)
Check(WM.ProcGlowing(VRButton), "Victorious should light Victory Rush")
WM.SetAura(VICTORIOUS, false)
Check(not WM.ProcGlowing(VRButton), "Victorious gone, glow gone")
-- In combat the game does it alone: Leproc runs no code and places nothing new.
WM.combat = true
WM.SetAura(BLOODTHRILL, true)
Check(WM.ProcGlowing(Main1), "Bloodthrill should light Overpower in combat")
WM.SetAura(VICTORIOUS, true)
Check(WM.ProcGlowing(VRButton), "Victorious in combat")
WM.SetAura(BLOODTHRILL, false)
WM.SetAura(VICTORIOUS, false)
Check(not WM.ProcGlowing(Main1) and not WM.ProcGlowing(VRButton), "both gone in combat")
WM.combat = false
-- Out of combat the glows follow the bars: in Defensive Stance the main bar holds Revenge, so
-- Bloodthrill's glow leaves it.
WM.SetStance(2)
WM.SetAura(BLOODTHRILL, true)
Check(not WM.ProcGlowing(Main1), "Overpower isn't on the main bar in Defensive Stance")
WM.SetStance(1)
Check(WM.ProcGlowing(Main1), "back in Battle Stance the glow is on Overpower again")
-- Off: no proc glow.
WM.Slash("overpower off")
Check(not WM.ProcGlowing(Main1), "off: no proc glow")
WM.Slash("overpower default")
Check(WM.ProcGlowing(Main1), "back on")
WM.SetAura(BLOODTHRILL, false)
local out3 = PrintedNow(function() WM.Slash("why victory rush") end)
Check(out3:find("buff: also lights while you have Victorious") and not out3:find("window:"), "why for a buff-only ability: " .. out3)
ns.Window.Show()
ns.Window.Select("abilities")
Check(#ns.Window.CurrentPanel().rows == 3, "a warrior now has Victory Rush too")
ns.Window.Hide()
WM.SetAction(67, nil)
ns.Refresh()

-- /leproc log: triggers, glows, casts, and what the game says, with secret values shown as such.
out = PrintedNow(function() WM.Slash("log") end)
Check(out:find("log on") and out:find("Overpower now: game says usable: spell no, button slot 73 no, in Battle Stance"), "log on: " .. out)
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
for i = 1, 2010 do ns.Log.Add("line " .. i) end
Check(#LeprocDB.log.entries == 2000 and LeprocDB.log.entries[2000]:find("line 2010"), "the log keeps the last 2000 lines")
LeprocDB.log.on = false
WM.Slash("log clear")
Check(#LeprocDB.log.entries == 0, "log clear")
WM.Advance(6)

-- The game decides where it can. The owner's logs: the game makes Revenge usable 0.2-0.9 s
-- before the report of the block reaches addons, and ends it 5 s after its own start.
LeprocDB.delay = nil
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
Check(#ns.ClassEntries() == 2 and ns.ClassEntries()[1].key == "riposte" and ns.ClassEntries()[2].key == "ambush" and ns.Mode(ns.byKey.riposte) == "any", "a rogue's abilities")
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
WM.Advance(6)
WM.SetAura(1310726, true) -- Expose Prey
Check(WM.ProcGlowing(MultiBarBottomLeftButton5), "Expose Prey should light Mongoose Bite")
WM.SetAura(1310726, false)
Check(not WM.ProcGlowing(MultiBarBottomLeftButton5), "Expose Prey gone")
-- Class procs: Eclipse lights a druid's Starfire (in any form); a warlock's Shadow Trance lights
-- Shadow Bolt.
WM.class = "DRUID"
WM.SetAction(68, ns.SpellIDs["Starfire"][1])
ns.Refresh()
WM.SetAura(1286115, true)
Check(WM.ProcGlowing(MultiBarBottomLeftButton8), "Eclipse should light Starfire")
WM.SetAura(1286115, false)
Check(not WM.ProcGlowing(MultiBarBottomLeftButton8), "Eclipse gone")
WM.class = "WARLOCK"
WM.SetAction(69, ns.SpellIDs["Shadow Bolt"][1])
ns.Refresh()
WM.SetAura(17941, true)
Check(WM.ProcGlowing(MultiBarBottomLeftButton9), "Shadow Trance should light Shadow Bolt")
WM.SetAura(17941, false)
