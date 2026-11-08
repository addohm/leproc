local _, NS = ...

-- ProcGlow: glow action buttons for usable procs / reactive abilities.
-- Works with Blizzard bars, Bartender4, ElvUI and Dominos.
-- Type /pg to open the settings window (also under Options > AddOns).

local PG = CreateFrame("Frame")
NS.PG = PG


---------------------------------------------------------------------------
-- Defaults (all lowercase). Edit in game with /pg add, /pg remove, /pg buff
---------------------------------------------------------------------------
local DEFAULT_SPELLS = {
    "overpower", "revenge", "riposte", "counterattack", "mongoose bite",
    "execute", "victory rush", "hammer of wrath", "exorcism",
}
NS.DEFAULT_SPELLS = DEFAULT_SPELLS

-- buff name -> spell that should glow while the buff is up
local DEFAULT_BUFFS = {
    ["shadow trance"] = "shadow bolt",
    ["hot streak"] = "pyroblast",
    ["victorious"] = "victory rush",
    -- Mage / Shaman procs in WoW Forever (buff names are best guesses: check with /pg debug)
    ["heating up"] = "pyroblast",
    ["missile barrage"] = "arcane missiles",
    ["fingers of frost"] = "ice lance",
    ["maelstrom weapon"] = "lightning bolt",
    -- more talent procs (WoW Forever); the buff names follow the talent names, check with /pg auras
    ["infusion of light"] = "holy light",     -- Paladin: Holy Shock / Flash of Light crit, faster Holy Light
    ["searing light"] = "holy nova",          -- Priest: next Holy Nova costs no mana
    ["decimation"] = "soul fire",             -- Warlock: quicker, shard-free Soul Fire
    ["eclipse"] = "starfire",                 -- Druid: Wrath makes the next Starfires faster
    ["cutthroat"] = "ambush",                 -- Rogue: Ambush without stealth
    ["thousand cuts"] = "hemorrhage",         -- Rogue: Rupture ticks discount Hemorrhage (stacks)
    ["expose prey"] = "mongoose bite",        -- Hunter: Mongoose Bite enabled
    ["bloodthrill"] = "overpower",            -- Warrior: Overpower enabled
    -- popup-only procs: they affect more than one spell, so they never glow a button
    ["remorseless attacks"] = "remorseless attacks",   -- Rogue
    ["arcane blast"] = "arcane blast stacks",          -- Mage: icon with the stack count (never glows a button)
    ["rapid killing"] = "rapid killing",               -- Hunter
}
NS.DEFAULT_BUFFS = DEFAULT_BUFFS
-- Clearcasting is the same buff for three classes: Druid (Omen of Clarity), Mage (Arcane
-- Concentration) and Shaman (Elemental Focus); each class gets its own named popup entry
local CC_BY_CLASS = { DRUID = "omen of clarity", MAGE = "arcane concentration", SHAMAN = "elemental focus" }
NS.CC_BY_CLASS = CC_BY_CLASS
-- proc name -> default popup text (these entries only show text, never a glow)
local POPUP_ONLY = {
    ["omen of clarity"] = "Clearcasting!", ["arcane concentration"] = "Clearcasting!",
    ["elemental focus"] = "Clearcasting!", ["remorseless attacks"] = "Remorseless Attacks!",
    ["rapid killing"] = "Rapid Killing!", ["arcane blast stacks"] = "",
}
NS.POPUP_ONLY = POPUP_ONLY

-- shown in the Abilities window
local CLASS_ORDER = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
NS.CLASS_ORDER = CLASS_ORDER
local CLASS_SPELLS = {
    WARRIOR = { "Overpower", "Revenge", "Execute", "Victory Rush" },
    PALADIN = { "Hammer of Wrath", "Exorcism", "Holy Light" },
    HUNTER  = { "Counterattack", "Mongoose Bite", "Rapid Killing" },
    ROGUE   = { "Riposte", "Ambush", "Hemorrhage", "Remorseless Attacks" },
    PRIEST  = { "Holy Nova" },
    SHAMAN  = { "Lightning Bolt", "Elemental Focus" },
    MAGE    = { "Pyroblast", "Arcane Missiles", "Ice Lance", "Arcane Concentration", "Arcane Blast Stacks" },
    WARLOCK = { "Shadow Bolt", "Soul Fire" },
    DRUID   = { "Starfire", "Omen of Clarity" },
}
NS.CLASS_SPELLS = CLASS_SPELLS
local SPELL_NOTES = {
    ["Shadow Bolt"] = "Shadow Trance", ["Pyroblast"] = "Hot Streak",
    ["Arcane Missiles"] = "Missile Barrage", ["Ice Lance"] = "Fingers of Frost",
    ["Lightning Bolt"] = "Maelstrom Weapon",
    ["Exorcism"] = "undead / demon target", ["Holy Light"] = "Infusion of Light", ["Holy Nova"] = "Searing Light",
    ["Omen of Clarity"] = "Clearcasting", ["Arcane Concentration"] = "Clearcasting",
    ["Elemental Focus"] = "Clearcasting", ["Remorseless Attacks"] = "next attack",
    ["Rapid Killing"] = "next Shot", ["Arcane Blast Stacks"] = "Arcane Blast buff",
    ["Soul Fire"] = "Decimation", ["Starfire"] = "Eclipse", ["Ambush"] = "Cutthroat", ["Hemorrhage"] = "Thousand Cuts",
}
NS.SPELL_NOTES = SPELL_NOTES

-- ability names per class (from the WoW Forever trainer lists), used for the "Add ability" search
local ABILITY_DB = {
    WARRIOR = { "Victory Rush", "Battle Stance", "Heroic Strike", "Charge", "Rend", "Thunder Clap", "Hamstring", "Overpower",
        "Mocking Blow", "Retaliation", "Mortal Strike", "Spearing Strike", "Sweeping Strikes", "Battle Shout", "Demoralizing Shout",
        "Cleave", "Intimidating Shout", "Execute", "Challenging Shout", "Berserker Stance", "Intercept", "Slam", "Berserker Rage",
        "Whirlwind", "Pummel", "Bloodthirst", "Recklessness", "Piercing Howl", "Death Wish", "Bloodrage", "Defensive Stance",
        "Sunder Armor", "Taunt", "Shield Bash", "Revenge", "Shield Block", "Disarm", "Shield Wall", "Shield Slam", "Last Stand",
        "Concussion Blow" },
    PALADIN = { "Holy Strike", "Blessing of Might", "Judgement", "Seal of the Crusader", "Seal of Command", "Repentance",
        "Blessing of Kings", "Seal of Fury", "Devotion Aura", "Divine Protection", "Hammer of Justice", "Blessing of Protection",
        "Righteous Fury", "Blessing of Freedom", "Seal of Justice", "Divine Intervention", "Divine Shield",
        "Blessing of Sacrifice", "Holy Shield", "Swift Judgement", "Templar's Bulwark", "Holy Light", "Seal of Righteousness",
        "Purify", "Lay on Hands", "Redemption", "Blessing of Wisdom", "Exorcism", "Flash of Light", "Turn Undead", "Consecration",
        "Seal of Light", "Seal of Wisdom", "Cleanse", "Hammer of Wrath", "Holy Shock", "Holy Wrath",
        "Voice of Truth", "Divine Favor", "Light's Vigil" },
    HUNTER = { "Aspect of the Monkey", "Aspect of the Hawk", "Call Pet", "Dismiss Pet", "Feed Pet", "Revive Pet", "Tame Beast",
        "Mend Pet", "Scare Beast", "Aspect of the Cheetah", "Aspect of the Pack", "Aspect of the Wild", "Tranquilizing Shot",
        "Intimidation", "Bestial Wrath", "Raptor Strike", "Wing Clip", "Immolation Trap", "Mongoose Bite", "Disengage",
        "Freezing Trap", "Frost Trap", "Feign Death", "Explosive Trap", "Counterattack", "Wyvern Sting", "Deterrence",
        "Strider Kick", "Serpent Sting", "Arcane Shot", "Hunter's Mark", "Concussive Shot", "Distracting Shot", "Multi-Shot",
        "Scorpid Sting", "Rapid Fire", "Aimed Shot", "Flare", "Viper Sting", "Volley", "Trueshot Aura", "Scatter Shot",
        "Sniper Shot" },
    ROGUE = { "Sinister Strike", "Backstab", "Gouge", "Evasion", "Sprint", "Kick", "Feint", "Riposte", "Blade Flurry",
        "Adrenaline Rush", "Stealth", "Pick Pocket", "Sap", "Distract", "Vanish", "Blind", "Hemorrhage", "Ghostly Strike",
        "Premeditation", "Preparation", "Eviscerate", "Slice and Dice", "Expose Armor", "Garrote", "Ambush", "Rupture",
        "Cheap Shot", "Kidney Shot", "Cold Blood", "Mutilate", "Venom", "Coup de Grace", "Flawless Execution" },
    PRIEST = { "Lesser Heal", "Smite", "Renew", "Desperate Prayer", "Resurrection", "Cure Disease", "Heal", "Fear Ward",
        "Flash Heal", "Holy Fire", "Holy Nova", "Prayer of Healing", "Abolish Disease", "Greater Heal", "Lightwell", "Chastise",
        "Prayer of Mending", "Shadow Word: Pain", "Fade", "Mind Blast", "Psychic Scream", "Devouring Plague",
        "Mind Flay", "Mind Control", "Vampiric Embrace", "Silence", "Shadowform", "Shadow Word: Death", "Power Word: Fortitude",
        "Power Word: Shield", "Inner Fire", "Dispel Magic", "Shackle Undead", "Mana Burn", "Levitate", "Divine Spirit",
        "Inner Focus", "Penance", "Power Infusion" },
    SHAMAN = { "Rockbiter Weapon", "Lightning Shield", "Flametongue Weapon", "Frostbrand Weapon", "Ghost Wolf", "Windfury Weapon",
        "Stormstrike", "Healing Wave", "Ancestral Spirit", "Lesser Healing Wave", "Chain Heal", "Water Shield",
        "Nature's Swiftness", "Riptide", "Fire Nova", "Lightning Bolt", "Earth Shock", "Flame Shock", "Purge", "Frost Shock",
        "Chain Lightning", "Mana Tide Totem", "Grounding Totem", "Searing Totem", "Magma Totem" },
    MAGE = { "Frostbolt", "Frost Nova", "Blizzard", "Cone of Cold", "Ice Barrier", "Ice Lance", "Ice Block", "Cold Snap",
        "Fireball", "Fire Blast", "Flamestrike", "Scorch", "Pyroblast", "Blast Wave", "Combustion", "Arcane Missiles",
        "Polymorph", "Arcane Explosion", "Blink", "Evocation", "Mana Shield", "Counterspell", "Arcane Blast",
        "Presence of Mind", "Arcane Power" },
    WARLOCK = { "Summon Imp", "Summon Voidwalker", "Health Funnel", "Banish", "Fel Domination", "Soul Link", "Corruption",
        "Bane of Agony", "Fear", "Drain Soul", "Drain Life", "Drain Mana", "Siphon Life", "Howl of Terror", "Death Coil",
        "Bane of Doom", "Wrack", "Immolate", "Shadow Bolt", "Searing Pain", "Rain of Fire", "Shadowburn", "Hellfire",
        "Conflagrate", "Soul Fire", "Bane of Havoc", "Incinerate", "Life Tap" },
    DRUID = { "Bear Form", "Demoralizing Roar", "Growl", "Maul", "Enrage", "Bash", "Aquatic Form", "Swipe", "Cat Form", "Claw",
        "Prowl", "Rip", "Shred", "Rake", "Dash", "Challenging Roar", "Cower", "Travel Form", "Ferocious Bite", "Ravage",
        "Frenzied Regeneration", "Pounce", "Dire Bear Form", "Primal Bite", "Healing Touch", "Rejuvenation",
        "Regrowth", "Rebirth", "Insect Swarm", "Tranquility", "Innervate", "Swiftmend", "Wrath", "Moonfire", "Entangling Roots",
        "Faerie Fire", "Starfire", "Hurricane", "Barkskin", "Moonkin Form" },
}
NS.ABILITY_DB = ABILITY_DB

local STYLE_DEFAULTS = {
    -- glow layers: any combination can be switched on together
    haloOn = true,       -- soft halo around the button
    highlightOn = false, -- button highlight texture
    outlineOn = false,   -- solid frame
    fillOn = false,      -- tint over the whole icon
    burstOn = false,     -- rotating star
    antsOn = true,       -- marching dashes around the edge
    blizzardOn = true,   -- Blizzard's default golden proc glow (untick to customise)
    fillAlpha = 0.35,    -- fill opacity
    burstScale = 2.0,    -- burst size relative to the button
    r = 1, g = 0.85, b = 0.2,
    intensity = 1,    -- 0.2 .. 1
    scale = 1.85,     -- glow size relative to the button
    speed = 0.45,     -- seconds per pulse half-cycle
    thickness = 2,    -- outline thickness in pixels
    pulse = true,
    strength = 2,     -- halo brightness: 1..3 copies stacked
    hiStrength = 2,   -- highlight brightness: 1..3 copies stacked
    outset = 0,       -- outline pixels pushed outside the button
    minAlpha = 0.3,   -- how dim the pulse gets (0..1)
    antCount = 12,    -- marching ants: how many dashes
    antLen = 0.18,    -- dash length as a fraction of the button width
    antThick = 3,     -- dash thickness in pixels
    antSpeed = 2.5,   -- seconds for a dash to lap the button
    pop = true,       -- attention pop when the glow first appears
    popSize = 1.8,    -- how big the pop starts
    popTime = 0.35,   -- pop length in seconds
    flash = true,     -- white flash when the glow first appears
    timerOn = true,   -- countdown number on a glowing button
    timerSize = 16,   -- countdown font size
    timerPos = "center", timerX = 0, timerY = 0,        -- where the countdown sits on the button
    stackOn = true,   -- stack count on a glowing button (Fingers of Frost etc.)
    stackSize = 14,
    stackPos = "bottomright", stackX = 0, stackY = 0,
}
NS.STYLE_DEFAULTS = STYLE_DEFAULTS

-- how long (seconds) a proc stays usable, for procs the game gives no timer for
local PROC_SECONDS = {
    ["victory rush"] = 20, ["overpower"] = 5, ["revenge"] = 5, ["riposte"] = 5,
    ["counterattack"] = 5, ["mongoose bite"] = 5, ["surprise attack"] = 5,
}
NS.PROC_SECONDS = PROC_SECONDS

local TEXT_DEFAULTS = {
    font = "friz quattrocento", size = 34,
    r = 1, g = 0.82, b = 0,
    outline = true, thick = false, shadow = true,
    border = false, bg = false, bgAlpha = 0.5,
    throb = false, pulse = false, shake = false,
    throbPeriod = 0.8, throbSize = 1.2,
    pulsePeriod = 0.5, pulseMin = 0.35,
    shakePeriod = 0.3, shakeDist = 6,
    timer = false, tpos = "right",   -- countdown beside the text (each ability can override)
}
NS.TEXT_DEFAULTS = TEXT_DEFAULTS

local reactive = {}
NS.reactive = reactive   -- spell name -> true
local buffProcs = {}
NS.buffProcs = buffProcs  -- buff name -> spell name
NS.debugOn = false
NS.previewOn = false

NS.loginMsgDone = false
local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffffd100ProcGlow:|r " .. msg)
end
NS.Print = Print

local BUFFS = { state = {} }
NS.BUFFS = BUFFS   -- buff tracking (priest fortitude, paladin blessings, ...)
function BUFFS.Fmt(r, down)
    -- whole seconds rounded up, exactly like the game's own countdown (the one shown in combat), so nothing jumps when combat ends;
    -- the Arcane Blast icon follows the game's debuff icon instead, which rounds down
    r = down and math.max(1, math.floor(r)) or math.ceil(r)
    if r >= 600 then return string.format("%dm", math.ceil(r / 60)) end
    if r >= 60 then return string.format("%d:%02d", math.floor(r / 60), r % 60) end
    return string.format("%d", r)
end

local function LoadLists()
    wipe(reactive); wipe(buffProcs)
    for _, n in ipairs(DEFAULT_SPELLS) do reactive[n] = true end
    for b, s in pairs(DEFAULT_BUFFS) do buffProcs[b] = s end
    for n in pairs(NS.DB.removed) do reactive[n] = nil end
    for n in pairs(NS.DB.added) do reactive[n] = true end
    for b, s in pairs(NS.DB.buffs) do buffProcs[b] = s end
    local _, pc = UnitClass("player")
    if CC_BY_CLASS[pc] then buffProcs["clearcasting"] = CC_BY_CLASS[pc] end
    -- Omen of Clarity used to be a trackable buff: clear its old "missing" popup text
    local oc = NS.DB.alerts and NS.DB.alerts["omen of clarity"]
    if oc and type(oc.text) == "string" and oc.text:lower():find("missing") then oc.text = "" end
end
NS.LoadLists = LoadLists
