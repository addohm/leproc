local _, NS = ...
local BUFFS, CLASS_SPELLS, buffProcs = NS.BUFFS, NS.CLASS_SPELLS, NS.buffProcs

---------------------------------------------------------------------------
-- Compat helpers
---------------------------------------------------------------------------
---------------------------------------------------------------------------
-- Localisation
-- The game gives spell and buff names in the client's language ("Zerhäckseln"), but everything in
-- here is keyed by the lowercase English name ("slice and dice"). Blizzard's own advice is to identify
-- spells by ID, which is the same in every language: ProcGlow_IDs.lua lists the spell IDs behind each
-- English name, and on a non-English client those IDs give the client's own name for each one.
-- Names and IDs coming IN from the game are turned into the English key; lookups going OUT to the
-- game (icons, aura queries, cooldowns) use the client's name. On an English client LOC.on is false and
-- every helper below hands its input straight back, so nothing changes there.
---------------------------------------------------------------------------
local LOC = { on = false, k2ids = {}, i2k = {}, l2k = {}, k2l = {}, conf = {}, nres = 0, nkeys = 0 }
NS.LOC = LOC
do
    local function RawName(id)
        local n
        if C_Spell and C_Spell.GetSpellName then n = C_Spell.GetSpellName(id)
        elseif GetSpellInfo then n = (GetSpellInfo(id)) end
        if type(n) == "string" and n ~= "" and not (issecretvalue and issecretvalue(n)) then return n end
    end
    LOC.RawName = RawName

    -- string.lower only handles plain A-Z, so "Überwältigen" or a Russian name keep their capitals;
    -- this also lowercases the accented Latin and Cyrillic letters (two-byte UTF-8), so names compare
    -- the same however a macro or a settings box spells them
    local function ulower(s)
        s = s:lower()
        if s:find("[\195\208]") then
            s = s:gsub("\195([\128-\158])", function(c)
                if c == "\151" then return nil end                      -- the multiplication sign has no case
                return "\195" .. string.char(c:byte() + 32)
            end)
            s = s:gsub("\208([\144-\159])", function(c) return "\208" .. string.char(c:byte() + 32) end)
            s = s:gsub("\208([\160-\175])", function(c) return "\209" .. string.char(c:byte() - 32) end)
            s = s:gsub("\208([\128-\143])", function(c) return "\209" .. string.char(c:byte() + 16) end)
        end
        return s
    end
    LOC.Lower = ulower

    -- build the lookups from the ID table: id -> key, client name -> key, key -> client name
    function LOC.Build()
        wipe(LOC.k2ids); wipe(LOC.i2k); wipe(LOC.l2k); wipe(LOC.k2l); wipe(LOC.conf)
        LOC.nres, LOC.nkeys = 0, 0
        local ids = ProcGlowIDs
        if type(ids) ~= "table" then return end
        for key, list in pairs(ids) do
            if type(key) == "string" and type(list) == "table" then
                LOC.nkeys = LOC.nkeys + 1
                LOC.k2ids[key] = list
                for _, id in ipairs(list) do
                    LOC.i2k[id] = key
                    local nm = RawName(id)
                    if nm then
                        local low = ulower(nm)
                        if not LOC.k2l[key] then LOC.k2l[key] = nm; LOC.nres = LOC.nres + 1 end
                        local prev = LOC.l2k[low]
                        if prev and prev ~= key then LOC.conf[low] = true else LOC.l2k[low] = key end
                    end
                end
            end
        end
    end

    -- turned on for any client that is not English (or by hand with /pg locale on, to test the layer)
    function LOC.Init()
        LOC.locale = GetLocale and GetLocale() or "enUS"
        LOC.on = (LOC.locale ~= "enUS") or (NS.DB and NS.DB.locForce == true) or false
        if LOC.on then LOC.Build() end
    end

    -- a lowercase name the game gave us -> the English key (typed = the player typed it, so an English key wins)
    function LOC.Key(low, typed)
        if not LOC.on or type(low) ~= "string" then return low end
        if typed and LOC.k2ids[low] then return low end
        return LOC.l2k[ulower(low)] or LOC.l2k[low] or low
    end
    -- a spell ID the game gave us -> the English key
    function LOC.IDKey(id)
        if LOC.on and type(id) == "number" then return LOC.i2k[id] end
    end
    -- English key -> the client's name for it (nil when unknown)
    function LOC.Local(key)
        if LOC.on and type(key) == "string" then return LOC.k2l[key:lower()] end
    end
    -- the name to show the player: the client's own when we know it
    function LOC.Disp(key)
        return LOC.Local(key)
    end
    -- the spell's icon, found through its IDs (works in any language, and for spells you have not learned)
    function LOC.Icon(name, anyId)
        if not LOC.on or type(name) ~= "string" then return nil end
        local ids = LOC.k2ids[name:lower()]
        if not ids then return nil end
        -- several IDs share a name (old ranks, unrelated test spells): prefer one this character knows
        for _, id in ipairs(ids) do
            local okK, known = pcall(function()
                if IsPlayerSpell then return IsPlayerSpell(id) end
                if IsSpellKnown then return IsSpellKnown(id) end
            end)
            if okK and known and not (issecretvalue and issecretvalue(known)) then
                local t
                if GetSpellTexture then t = GetSpellTexture(id)
                elseif C_Spell and C_Spell.GetSpellTexture then t = C_Spell.GetSpellTexture(id) end
                if t and not (issecretvalue and issecretvalue(t)) then return t end
            end
        end
        if not anyId then return nil end
        -- none known: take the highest rank first (the first ID listed can be an unrelated spell with the same name)
        for i = #ids, 1, -1 do
            local t
            if GetSpellTexture then t = GetSpellTexture(ids[i])
            elseif C_Spell and C_Spell.GetSpellTexture then t = C_Spell.GetSpellTexture(ids[i]) end
            if t and not (issecretvalue and issecretvalue(t)) then return t end
        end
    end
end

local function SpellNameByID(id)
    if not id then return nil end
    if LOC.on then
        local k = LOC.i2k[id]
        if k then return k end                      -- the English key for that spell ID
    end
    local n
    if C_Spell and C_Spell.GetSpellName then n = C_Spell.GetSpellName(id)
    elseif GetSpellInfo then n = (GetSpellInfo(id)) end
    if LOC.on and type(n) == "string" and not (issecretvalue and issecretvalue(n)) then
        return LOC.Key(n:lower())                   -- an ID we do not list: match it by its name instead
    end
    return n
end
NS.SpellNameByID = SpellNameByID

-- the icon of a spell found through its listed IDs: one you know first, otherwise the highest rank. A bare name lookup can land
-- on an unrelated spell that happens to share the name (Ice Armor does), so this is tried before the name on every client.
function LOC.IconByIDs(name)
    local ids = type(ProcGlowIDs) == "table" and ProcGlowIDs[name]
    if type(ids) ~= "table" then return nil end
    local function Tex(id)
        local t
        if GetSpellTexture then t = GetSpellTexture(id)
        elseif C_Spell and C_Spell.GetSpellTexture then t = C_Spell.GetSpellTexture(id) end
        if t and not (issecretvalue and issecretvalue(t)) then return t end
    end
    for _, id in ipairs(ids) do
        local okK, known = pcall(function()
            if IsPlayerSpell then return IsPlayerSpell(id) end
            if IsSpellKnown then return IsSpellKnown(id) end
        end)
        if okK and known and not (issecretvalue and issecretvalue(known)) then
            local t = Tex(id)
            if t then return t end
        end
    end
    for i = #ids, 1, -1 do
        local t = Tex(ids[i])
        if t then return t end
    end
end

local iconCache = {}
NS.iconCache = iconCache
local function SpellIcon(name)
    local t = iconCache[name]
    if t then return t end
    if LOC.on then t = LOC.Icon(name) else t = LOC.IconByIDs(name) end
    local lookup = name
    if not t and LOC.on then lookup = LOC.Local(name) or name end
    if not t then
        if GetSpellTexture then
            t = GetSpellTexture(lookup)
        elseif C_Spell and C_Spell.GetSpellTexture then
            t = C_Spell.GetSpellTexture(lookup)
        end
    end
    if not t and LOC.on then t = LOC.Icon(name, true) end   -- last resort: any ID with that name
    if t then iconCache[name] = t end
    return t
end
NS.SpellIcon = SpellIcon

-- an icon from your own class for the previews (first spell you actually know)
local PREVIEW_SPELLS = {
    WARRIOR = { "Overpower", "Heroic Strike", "Battle Shout" },
    PALADIN = { "Hammer of Wrath", "Judgement", "Holy Light" },
    HUNTER  = { "Counterattack", "Raptor Strike", "Arcane Shot" },
    ROGUE   = { "Riposte", "Sinister Strike", "Eviscerate" },
    PRIEST  = { "Mind Blast", "Smite", "Lesser Heal" },
    SHAMAN  = { "Lightning Bolt", "Rockbiter Weapon", "Healing Wave" },
    MAGE    = { "Pyroblast", "Fireball", "Frostbolt" },
    WARLOCK = { "Shadow Bolt", "Corruption", "Immolate" },
    DRUID   = { "Ferocious Bite", "Wrath", "Moonfire", "Healing Touch" },
}
NS.PREVIEW_SPELLS = PREVIEW_SPELLS
local function PreviewIcon()
    local _, pc = UnitClass("player")
    for _, n in ipairs(PREVIEW_SPELLS[pc] or {}) do
        local t = SpellIcon(n)
        if t then return t end
    end
    return "Interface\\Icons\\Ability_MeleeDamage"
end
NS.PreviewIcon = PreviewIcon

local function IsOverlayed(id)
    if not id then return false end
    if C_SpellActivationOverlay and C_SpellActivationOverlay.IsSpellOverlayed then
        return C_SpellActivationOverlay.IsSpellOverlayed(id) and true or false
    end
    if IsSpellOverlayed then return IsSpellOverlayed(id) and true or false end
    return false
end
NS.IsOverlayed = IsOverlayed

-- read a spell name out of a macro's text: #showtooltip <spell>, else the first /cast spell
local function MacroSpellName(macroID)
    local body
    local gb = GetMacroBody or (C_Macro and C_Macro.GetMacroBody)
    if gb then body = gb(macroID) end
    if not body then
        local gi = GetMacroInfo or (C_Macro and C_Macro.GetMacroInfo)
        if gi then
            local a, b, c = gi(macroID)
            if type(a) == "table" then body = a.body else body = c end
        end
    end
    if type(body) ~= "string" or (issecretvalue and issecretvalue(body)) then return nil end
    local lower = body:lower()
    local function clean(t)
        if not t then return nil end
        t = t:gsub("%b[]", ""):gsub("%(.-%)", "")      -- drop [conditions] and (Rank 1)
        t = t:match("^[%s!]*([^;,\n]-)%s*$")
        if t and t ~= "" then return t end
    end
    local st = lower:match("#showtooltip[ \t]+([^\n]+)") or lower:match("#show[ \t]+([^\n]+)")
    local n = clean(st)
    if n then return n end
    for line in lower:gmatch("[^\n]+") do
        local c = line:match("^%s*/cast%s+(.+)") or line:match("^%s*/use%s+(.+)")
        if c then
            -- take the last clause of the first condition set, e.g. "[@mouseover,help] Spell; Other"
            local first = c:match("^[^;]+")
            n = clean(first)
            if n then return n end
        end
    end
end
NS.MacroSpellName = MacroSpellName

-- lower-case spelling of a spell name, remembered (this runs for every action button, many times a second)
local lowerMemo = {}
local function Lower(n)
    local l = lowerMemo[n]
    if not l then l = n:lower(); lowerMemo[n] = l end
    return l
end

-- returns lowercase spell name, spell id for an action slot
local function ResolveSlot(slot)
    local kind, id, sub = GetActionInfo(slot)
    if kind == "spell" then
        local n = SpellNameByID(id)
        return n and Lower(n), id
    elseif kind == "macro" then
        -- on this client a macro slot can report the spell it casts (a spell id, not a macro index)
        if type(id) == "number" and (sub == "spell" or id > 1000) then
            local n = SpellNameByID(id)
            if n then return n:lower(), id end
        end
        local gs = GetMacroSpell or (C_Macro and C_Macro.GetMacroSpell)
        if gs then
            local a, b, c = gs(id)
            if type(a) == "number" then
                local n = SpellNameByID(a)
                if n then return n:lower(), a end
            elseif type(a) == "string" then
                return LOC.IDKey(c) or LOC.Key(a:lower()), c
            end
        end
        local okm, mn = pcall(MacroSpellName, id)    -- conditional macros: read the macro text
        if okm and mn then return LOC.Key(mn), nil end
        local nm = GetActionText and GetActionText(slot)    -- or look the macro up by its name
        if type(nm) == "string" and nm ~= "" and not (issecretvalue and issecretvalue(nm)) then
            okm, mn = pcall(MacroSpellName, nm)
            if okm and mn then return LOC.Key(mn), nil end
        end
    end
end
NS.ResolveSlot = ResolveSlot

-- ---- class buffs you cast on yourself (or others), tracked like Battle Shout -----
-- one entry per buff: spell, dur = full length (s), th = default warn time (s),
-- auras = other aura names that count as the same buff, self = only ever cast on you
do
local CLASS_BUFFS = {
    PRIEST = { singles = {
        { spell = "Power Word: Fortitude", dur = 3600, th = 300, auras = { "Prayer of Fortitude", "First Aid Kit" } },
        { spell = "Divine Spirit", dur = 1800, th = 300, auras = { "Prayer of Spirit", "Faction Banner" } },
        { spell = "Shadow Protection", dur = 600, th = 60, auras = { "Prayer of Shadow Protection" } },
        { spell = "Inner Fire", dur = 600, th = 60, self = true },
        { spell = "Fear Ward", dur = 600, th = 60 },
    } },
    MAGE = { singles = {
        { spell = "Arcane Intellect", dur = 1800, th = 300, auras = { "Arcane Brilliance", "Incense Candle" } },
    }, groups = {
        { key = "mage_armor", label = "Armor", th = 300, members = {
            { spell = "Frost Armor", dur = 1800, self = true }, { spell = "Ice Armor", dur = 1800, self = true },
            { spell = "Mage Armor", dur = 1800, self = true }, { spell = "Molten Armor", dur = 1800, self = true },
        } },
    } },
    DRUID = { singles = {
        { spell = "Mark of the Wild", dur = 3600, th = 300, auras = { "Gift of the Wild", "Enchanted Lute" } },
        { spell = "Thorns", dur = 600, th = 60 },
    } },
    WARLOCK = { singles = {
        { spell = "Unending Breath", dur = 600, th = 60 },
    }, groups = {
        { key = "lock_armor", label = "Armor", th = 300, members = {
            { spell = "Demon Skin", dur = 1800, self = true }, { spell = "Demon Armor", dur = 1800, self = true },
            { spell = "Fel Armor", dur = 1800, self = true },
        } },
    } },
    HUNTER = { groups = {
        { key = "hunter_aspect", label = "Aspect", members = {
            { spell = "Aspect of the Hawk", self = true }, { spell = "Aspect of the Monkey", self = true },
            { spell = "Aspect of the Cheetah", self = true }, { spell = "Aspect of the Pack", self = true },
            { spell = "Aspect of the Beast", self = true }, { spell = "Aspect of the Wild", self = true },
            { spell = "Aspect of the Viper", self = true },
        } },
    } },
    SHAMAN = { groups = {
        { key = "shaman_shield", label = "Shield", th = 60, members = {
            { spell = "Lightning Shield", dur = 600, self = true }, { spell = "Water Shield", dur = 600, self = true },
        } },
    } },
    PALADIN = { singles = {
        { spell = "Righteous Fury", dur = 1800, th = 120, self = true, tankOnly = true },
    }, groups = {
        { key = "pal_blessing", label = "Blessing", th = 60, members = {
            { spell = "Blessing of Might", dur = 300, auras = { "Greater Blessing of Might" } },
            { spell = "Blessing of Wisdom", dur = 300, auras = { "Greater Blessing of Wisdom", "Mana Well" } },
            { spell = "Blessing of Kings", dur = 300, auras = { "Greater Blessing of Kings", "Fishing Bowl" } },
            { spell = "Blessing of Protection", dur = 10 },
            { spell = "Blessing of Freedom", dur = 16 },
            { spell = "Blessing of Sacrifice", dur = 30 },
        } },
        { key = "pal_aura", label = "Aura", members = {
            { spell = "Devotion Aura", self = true }, { spell = "Retribution Aura", self = true },
            { spell = "Concentration Aura", self = true }, { spell = "Shadow Resistance Aura", self = true },
            { spell = "Frost Resistance Aura", self = true }, { spell = "Fire Resistance Aura", self = true },
            { spell = "Sanctity Aura", self = true },
        } },
    } },
}
BUFFS.class = CLASS_BUFFS
BUFFS.tracked, BUFFS.auraOf, BUFFS.members, BUFFS.groups = {}, {}, {}, {}
-- Buffs worth tracking with "Track a buff", by class (aura name = spell name, lower case). Only buffs
-- confirmed in the WoW Forever database are listed (theforeverera.com spell and talent pages), plus the
-- racials from Method / wow.gg. Anything else you have had on you is added to the list automatically
-- (DB.seen), so buffs whose exact name is not published still turn up with their real icon.
-- d = usual length in seconds (only used to time it in combat before it has been measured);
-- no d = lasts until used or cancelled, or comes from a proc (an icon without a timer).
-- Class buffs that already have their own tracking (armors, blessings, Fortitude...) are left out.
-- racial abilities: only the ones for the race you are playing are offered
BUFFS.racials = {
    orc = { { "blood fury", d = 15 } }, troll = { { "berserking", d = 15 } }, dwarf = { { "stoneform", d = 8 } },
    human = { { "perception", d = 20 } }, nightelf = { { "elune's light", d = 15 } },
    skyborne = { { "walk on air", d = 10 }, { "read leyline", d = 15 }, { "skysight", d = 15 } }, gnome = { { "eureka!", d = 8 } },
}
function BUFFS.RaceKey()
    local loc, file = UnitRace("player")
    file = type(file) == "string" and file:lower():gsub("[%s_]", "") or ""
    loc = type(loc) == "string" and loc:lower():gsub("[%s_]", "") or ""
    for k in pairs(BUFFS.racials) do
        if file == k or loc == k or file:find(k, 1, true) then return k end
    end
    return file
end
BUFFS.list = {
    WARRIOR = {
        { "berserker rage", d = 10 }, { "bloodrage", d = 10 }, { "death wish", d = 30 }, { "last stand", d = 20 },
        { "recklessness", d = 15 }, { "retaliation", d = 15 }, { "shield block", d = 7 }, { "shield wall", d = 12 },
        { "sweeping strikes", d = 20 }, { "reckless swings", d = 8 }, { "enrage" }, { "flurry" },
    },
    ROGUE = {
        { "adrenaline rush", d = 15 }, { "blade flurry", d = 15 }, { "cold blood" }, { "evasion", d = 15 },
        { "ghostly strike", d = 7 }, { "slice and dice" }, { "sprint", d = 15 }, { "vanish", d = 10 }, { "venom" },
    },
    MAGE = {
        { "arcane blast", d = 18 }, { "arcane power", d = 15 }, { "combustion" }, { "evocation", d = 8 },
        { "fire ward", d = 30 }, { "frost ward", d = 30 }, { "ice barrier", d = 60 }, { "ice block", d = 10 },
        { "mana shield", d = 60 }, { "presence of mind" }, { "slow fall", d = 30 },
        { "minor evocation" }, { "rat familiar" },     -- mage scrolls added in WoW Forever
    },
    WARLOCK = {
        { "amplify curse", d = 30 }, { "demonic sacrifice", d = 7200 }, { "fel domination", d = 15 },
        { "shadow ward", d = 30 }, { "soul link" },
    },
    PRIEST = {
        { "elune's grace", d = 15, race = "nightelf" }, { "fade", d = 10 },
        { "feedback", d = 15, race = "human" }, { "inner focus" }, { "levitate", d = 120 },
        { "power infusion", d = 15 }, { "power word: shield", d = 30 }, { "renew", d = 15 }, { "spirit tap" },
        { "touch of weakness", d = 600, race = "scourge" },
    },
    HUNTER = {
        { "deterrence", d = 10 }, { "feign death", d = 360 }, { "rapid fire", d = 15 }, { "strider kick", d = 3 },
        { "trueshot aura", d = 1800 },
    },
    SHAMAN = {
        { "flametongue weapon", d = 3600 }, { "flurry" }, { "frostbrand weapon", d = 3600 }, { "nature's swiftness" },
        { "rage of the farseer", d = 25 }, { "rockbiter weapon", d = 3600 }, { "water breathing", d = 600 },
        { "water walking", d = 600 }, { "windfury weapon", d = 3600 },
    },
    PALADIN = {
        { "divine favor" }, { "divine protection", d = 8 }, { "divine shield", d = 12 }, { "holy shield", d = 10 },
        { "redoubt" }, { "templar's bulwark", d = 8 }, { "vengeance" }, { "voice of truth", d = 6 },
    },
    DRUID = {
        { "barkskin", d = 15 }, { "dash", d = 15 }, { "enrage", d = 10 },
        { "frenzied regeneration", d = 10 }, { "innervate", d = 20 }, { "nature's grasp", d = 45 },
        { "nature's swiftness" }, { "regrowth", d = 21 }, { "rejuvenation", d = 12 },
    },
}
-- Cooldown abilities that are not buffs (Blink, Frost Nova...). Tracking one shows an icon while it is on cooldown
-- (greyed, with the time left). Only the ones in YOUR spellbook are offered in the suggestions, so an ability that
-- does not exist in WoW Forever, or that you have not learned yet, never shows up.
BUFFS.abilities = {
    WARRIOR = { "charge", "intercept", "intimidating shout", "taunt", "challenging shout", "concussion blow", "disarm",
        "shield bash", "pummel", "revenge", "shield slam", "mortal strike", "bloodthirst", "whirlwind", "mocking blow",
        "intervene", "spell reflection", "reckless swings" },
    ROGUE = { "kick", "gouge", "blind", "kidney shot", "distract", "riposte", "preparation", "premeditation",
        "cloak of shadows", "shadowstep", "shank", "death mark" },
    MAGE = { "blink", "frost nova", "counterspell", "cold snap", "cone of cold", "fire blast", "blast wave",
        "dragon's breath", "summon water elemental", "mirror image" },
    WARLOCK = { "death coil", "howl of terror", "shadowburn", "conflagrate", "shadowfury", "soulshatter", "inferno" },
    PRIEST = { "psychic scream", "mind blast", "shadow word: death", "desperate prayer", "silence", "pain suppression",
        "prayer of mending", "circle of healing", "lightwell" },
    HUNTER = { "freezing trap", "frost trap", "immolation trap", "explosive trap", "snake trap", "misdirection",
        "readiness", "bestial wrath", "intimidation", "scatter shot", "wyvern sting", "silencing shot", "disengage",
        "flare", "kill command", "aimed shot", "multi-shot" },
    SHAMAN = { "earth shock", "frost shock", "grounding totem", "mana tide totem", "fire nova totem", "stormstrike",
        "bloodlust", "heroism", "lightning mastery", "totemic call", "wind shear", "reincarnation",
        "tremor totem", "earth elemental totem", "fire elemental totem", "feral spirit", "chain lightning" },
    PALADIN = { "hammer of justice", "lay on hands", "divine intervention", "consecration", "holy wrath", "exorcism",
        "judgement", "avenger's shield", "crusader strike", "divine storm", "holy shock", "repentance",
        "hammer of wrath", "avenging wrath", "hand of reckoning", "righteous defense" },
    DRUID = { "bash", "feral charge", "growl", "challenging roar", "tranquility", "hurricane", "rebirth",
        "tiger's fury", "swiftmend", "starfall", "force of nature", "survival instincts" },
}
-- racial abilities with a cooldown, by race (same keys as BUFFS.racials / BUFFS.RaceKey)
BUFFS.racialAbil = {
    tauren = { "war stomp" }, scourge = { "will of the forsaken", "cannibalize" }, gnome = { "escape artist" },
    nightelf = { "shadowmeld" }, draenei = { "gift of the naaru" }, bloodelf = { "arcane torrent" },
    goblin = { "rocket jump" },
}
BUFFS.abil = {}
for _, list in pairs(BUFFS.abilities) do for _, n in ipairs(list) do BUFFS.abil[n] = true end end
for _, list in pairs(BUFFS.racialAbil) do for _, n in ipairs(list) do BUFFS.abil[n] = true end end
-- tracked buffs whose ability has a cooldown of its own (so "keep showing the cooldown" can be offered). Anything
-- not listed here is offered too once its cooldown has been seen (DB.cdLearned). First Aid is special: its
-- "cooldown" is the Recently Bandaged debuff (see IC.BandagedLeft).
BUFFS.hasCD = {}
for _, n in ipairs({
    "berserker rage", "bloodrage", "death wish", "last stand", "recklessness", "retaliation", "shield block", "shield wall", "reckless swings",
    "adrenaline rush", "blade flurry", "cold blood", "evasion", "ghostly strike", "sprint", "vanish",
    "arcane power", "combustion", "evocation", "fire ward", "frost ward", "ice barrier", "ice block", "presence of mind",
    "amplify curse", "fel domination", "shadow ward",
    "fade", "fear ward", "inner focus", "power infusion", "elune's grace", "feedback",
    "deterrence", "feign death", "rapid fire",
    "nature's swiftness", "divine favor", "divine protection", "divine shield", "holy shield",
    "barkskin", "dash", "enrage", "frenzied regeneration", "innervate", "nature's grasp",
    "blood fury", "berserking", "stoneform", "perception",
    "first aid",
}) do BUFFS.hasCD[n] = true end
function BUFFS.CanCD(name)
    if type(name) ~= "string" then return false end
    if BUFFS.abil[name] then return false end     -- an ability is its own cooldown icon, nothing extra to tick
    if BUFFS.hasCD[name] then return true end
    local l = NS.DB and NS.DB.cdLearned
    return (l and l[name]) and true or false
end
-- length used to time a buff you cast in combat before its real length has been measured
BUFFS.defDur = {}
for _, list in pairs(BUFFS.racials) do
    for _, e in ipairs(list) do BUFFS.defDur[e[1]] = e.d end
end
for _, list in pairs(BUFFS.list) do
    for _, e in ipairs(list) do
        if e.d and not BUFFS.defDur[e[1]] then BUFFS.defDur[e[1]] = e.d end
    end
end
BUFFS.LINGER = 120   -- seconds without any buff of a group before it reverts to the chosen one
do
    local function Add(def, group, gth, cls)
        local key = def.spell:lower()
        local auras = { key }
        BUFFS.auraOf[key] = key
        for _, a in ipairs(def.auras or {}) do
            auras[#auras + 1] = a:lower(); BUFFS.auraOf[a:lower()] = key
        end
        BUFFS.tracked[key] = { name = def.spell, dur = def.dur or 0, th = group and gth or def.th, auras = auras,
            self = def.self, group = group, class = cls }
        return key
    end
    for cls, cd in pairs(CLASS_BUFFS) do
        for _, d in ipairs(cd.singles or {}) do Add(d, nil, nil, cls) end
        for _, g in ipairs(cd.groups or {}) do
            local mem = {}
            for _, d in ipairs(g.members) do mem[#mem + 1] = Add(d, g.key, g.th, cls) end
            BUFFS.members[g.key] = mem
            BUFFS.groups[g.key] = { label = g.label, th = g.th, default = mem[1], class = cls }
        end
    end
end
end

-- what a stance-bar button holds: lowercase spell name, and whether it wants a glow
function BUFFS.StanceGlow(index)
    if not GetShapeshiftFormInfo then return nil end
    local _, _, _, sid = GetShapeshiftFormInfo(index)
    if not sid then return nil end
    local n = SpellNameByID(sid)
    if type(n) ~= "string" then return nil end
    n = n:lower()
    local tk = BUFFS.auraOf[n]
    if tk then n = tk end
    return n, (BUFFS.tracked[n] and BUFFS.Low(n)) and true or false
end

-- how many stacks of the buff behind this proc do you have (only for buffs that stack), or nil
function BUFFS.Stacks(name, buffs)
    for buff, spell in pairs(buffProcs) do
        if spell == name and buffs[buff] then
            local c = BUFFS.stack[buff]
            if c and c >= 1 and (BUFFS.stacky[buff] or BUFFS.seen[buff]) then return c end
        end
    end
end

-- does this spell / buff belong to the class you are logged in on?
-- (spells with no known class, e.g. ones you added by hand to "Custom / other", count for everyone)
function BUFFS.Allowed(spell)
    local map = BUFFS.spellClass
    if not map then
        map = { ["battle shout"] = "WARRIOR", ["commanding shout"] = "WARRIOR" }
        for c, list in pairs(CLASS_SPELLS) do
            for _, sp in ipairs(list) do map[sp:lower()] = c end
        end
        map["seals"] = "PALADIN"        -- the one icon that follows whichever seal is up
        BUFFS.spellClass = map
    end
    local cls
    local td = BUFFS.tracked[spell]
    if td then cls = td.class
    elseif BUFFS.groups[spell] then cls = BUFFS.groups[spell].class
    else
        cls = map[spell]
        if not cls and NS.DB and NS.DB.customClass then cls = NS.DB.customClass[spell] end
    end
    if not cls or cls == "OTHER" then return true end
    local _, pc = UnitClass("player")
    return cls == pc
end

-- does this character know the spell? Read from the spellbook, so a buff you have not trained
-- yet is never tracked; it starts working the moment you learn it
BUFFS.kc = {}
function BUFFS.Book()
    local set, n = {}, 0
    -- the game's current spellbook functions (C_SpellBook): this is what the live WoW Forever client has
    local CS = C_SpellBook
    if CS and CS.GetNumSpellBookSkillLines and CS.GetSpellBookSkillLineInfo and (CS.GetSpellBookItemName or CS.GetSpellBookItemInfo) then
        local bank = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0
        local future = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.FutureSpell
        pcall(function()
            for line = 1, CS.GetNumSpellBookSkillLines() do
                local li = CS.GetSpellBookSkillLineInfo(line)
                if type(li) == "table" then
                    local off, num = li.itemIndexOffset or 0, li.numSpellBookItems or 0
                    for i = off + 1, off + num do
                        local nm, skip
                        if CS.GetSpellBookItemInfo then
                            local info = CS.GetSpellBookItemInfo(i, bank)
                            if type(info) == "table" then
                                nm = info.name
                                if future and info.itemType == future then skip = true end   -- not learned yet
                            end
                        end
                        if not nm and CS.GetSpellBookItemName then nm = CS.GetSpellBookItemName(i, bank) end
                        if not skip and type(nm) == "string" then set[LOC.Key(nm:lower())] = true; n = n + 1 end
                    end
                end
            end
        end)
        if n > 0 then return set end
    end
    -- older spellbook functions
    local nameOf = GetSpellBookItemName or GetSpellName
    if not (GetNumSpellTabs and GetSpellTabInfo and nameOf) then return nil end
    local ok = pcall(function()
        for t = 1, GetNumSpellTabs() do
            local _, _, offset, num = GetSpellTabInfo(t)
            for i = (offset or 0) + 1, (offset or 0) + (num or 0) do
                local nm = nameOf(i, "spell")
                if type(nm) == "string" then set[LOC.Key(nm:lower())] = true; n = n + 1 end
            end
        end
    end)
    if ok and n > 0 then return set end
    return nil
end
-- is any spell ID listed under this name known to the character? (a second opinion for names the book read missed)
local function IdKnown(id)
    local ok, r = pcall(function()
        if C_SpellBook and C_SpellBook.IsSpellKnown then return C_SpellBook.IsSpellKnown(id) end
        if IsSpellKnown then return IsSpellKnown(id) end
        return false
    end)
    return ok and r and true or false
end
local function KnownById(k, name)
    local ids = type(ProcGlowIDs) == "table" and ProcGlowIDs[k]
    for _, id in ipairs(ids or {}) do
        if IdKnown(id) then return true end
    end
    -- the table keeps only some of the IDs for a name: also ask the game which ID the name means right now
    if name and C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, LOC.Local(name) or name)
        if ok and type(info) == "table" and type(info.spellID) == "number" and IdKnown(info.spellID) then return true end
    end
    return false
end
function BUFFS.Known(name)
    local k = name:lower()
    local c = BUFFS.kc[k]
    if c ~= nil then return c end
    local book = BUFFS.Book()
    if book then
        for nm in pairs(book) do BUFFS.kc[nm] = true end   -- cache every known name at once
        if BUFFS.kc[k] == nil then BUFFS.kc[k] = KnownById(k, name) end
        return BUFFS.kc[k]
    end
    -- spellbook not readable: ask the game about each of the spell's IDs instead
    if type(ProcGlowIDs) == "table" and ProcGlowIDs[k] and ((C_SpellBook and C_SpellBook.IsSpellKnown) or IsSpellKnown) then
        BUFFS.kc[k] = KnownById(k, name)
        return BUFFS.kc[k]
    end
    -- nothing readable (or unsupported): fall back to a name lookup
    local ok, r
    local lookup = LOC.Local(name) or name
    if C_Spell and C_Spell.GetSpellInfo then ok, r = pcall(C_Spell.GetSpellInfo, lookup)
    elseif GetSpellInfo then ok, r = pcall(GetSpellInfo, lookup) end
    return ok and r ~= nil and r ~= false
end
-- the chosen member of a group, or the first one this character actually knows
function BUFFS.Selected(g)
    local sel = NS.DB.track and NS.DB.track.sel[g]
    if sel and BUFFS.tracked[sel] then return sel end
    for _, m in ipairs(BUFFS.members[g]) do
        if BUFFS.Known(BUFFS.tracked[m].name) then return m end
    end
    return BUFFS.groups[g].default
end

local SHOUTS = { ["battle shout"] = true, ["commanding shout"] = true }
NS.SHOUTS = SHOUTS
for n in pairs(BUFFS.tracked) do SHOUTS[n] = true end
local shoutSpellID = {}
NS.shoutSpellID = shoutSpellID     -- shout name -> spell id seen on the action bars
local learnedDuration = {}
NS.learnedDuration = learnedDuration  -- shout name -> buff length (seconds) read when it was readable
NS.haveGoodRead = false  -- true once we have successfully read our buffs at least once

local buffSet = {}
BUFFS.auraIcon = {}   -- buff name -> icon texture, as last seen on you
BUFFS.cache = {}      -- seals and tracked buffs: last known { expires, count }, used while auras are hidden (combat)
BUFFS.learnedDur = {} -- tracked buff name -> length (s) seen the last time it could be read
BUFFS.sdur = {}       -- scratch: aura durations from the current read
BUFFS.castCP = {}     -- buff name -> { cp =, t = } combo points spent on the latest cast (finishers like Slice and Dice)
-- Buffs on you whose length depends on the combo points spent (WoW Forever matches Classic Era):
--   Slice and Dice 9/12/15/18/21 s for 1-5 points, lengthened by Improved Slice and Dice (+15/30/45%)
--   Venom (Assassination finisher) 9/12/15/18/21 s
-- The other combo point finishers (Rupture, Kidney Shot, Expose Armor, Rip, Ferocious Bite) put their effect
-- on the enemy rather than on you, so there is no buff of yours to time.
BUFFS.cpBuffs = {
    ["slice and dice"] = { base = 9, per = 3, talent = "improved slice and dice", pct = 0.15 },
    ["venom"] = { base = 9, per = 3 },
}
BUFFS.trank, BUFFS.trankT = {}, 0
function BUFFS.TalentRank(name)
    local now = GetTime()
    if now - BUFFS.trankT > 20 then
        BUFFS.trankT = now
        wipe(BUFFS.trank)
        pcall(function()
            if not (GetNumTalentTabs and GetTalentInfo) then return end
            for tab = 1, GetNumTalentTabs() do
                for i = 1, (GetNumTalents and GetNumTalents(tab) or 0) do
                    local nm, _, _, _, rank = GetTalentInfo(tab, i)
                    if type(nm) == "string" and type(rank) == "number" then BUFFS.trank[LOC.Key(nm:lower())] = rank end
                end
            end
        end)
    end
    return BUFFS.trank[name] or 0
end
-- length of a combo point buff cast with cp points: what we measured for that many points, else the
-- formula scaled by a measured (or talent based) multiplier
function BUFFS.CPDuration(n, cp)
    local def = BUFFS.cpBuffs[n]
    if not def or not cp or cp < 1 then return nil end
    local L = NS.DB and NS.DB.learned
    local exact = L and L[n .. "@" .. cp]
    if exact then return exact end
    local mult = L and L[n .. "@x"]
    if not mult then
        mult = 1
        if def.talent then mult = 1 + def.pct * BUFFS.TalentRank(def.talent) end
    end
    return (def.base + def.per * (cp - 1)) * mult
end
BUFFS.dAny = false  -- true once any by-name lookup has answered while auras were hidden
BUFFS.dworks = {}     -- buff name -> true once a by-name lookup has answered during combat (so "no answer" means gone)
BUFFS.live = {}       -- buff name -> { t =, obj = } duration object from the latest combat lookup
local buffExpire = {}
NS.buffExpire = buffExpire -- buff name -> time it runs out (when readable)
local buffInfo = {}
NS.buffInfo = buffInfo   -- shout buff name -> { mine = bool, expires = number }
-- While buff data is restricted, some individual auras may still be readable.
-- Try a direct lookup per shout; if it gives usable data, trust it.
local function DirectShout(name, id)
    if not (C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID) then return end
    local ok, d = pcall(C_UnitAuras.GetPlayerAuraBySpellID, id)
    if not ok or type(d) ~= "table" then return end
    if issecretvalue and (issecretvalue(d.expirationTime) or issecretvalue(d.sourceUnit)) then return end
    local mine = (d.sourceUnit ~= nil and UnitIsUnit(d.sourceUnit, "player")) and true or false
    buffInfo[name] = { mine = mine, expires = d.expirationTime or 0 }
end

local scratchSet, scratchInfo, scratchExp = {}, {}, {}
NS.auraRestricted = false

-- While combat hides the aura list, a lookup of one buff by name can still be readable. Try it for
-- every buff we care about (tracked class buffs, buffs added with "Track a buff", seals) and use the
-- real expiry when it comes back; otherwise the cast-based estimate keeps going.
do
local lastDirect = 0
local properName = {}
-- inside a battleground or arena the game hides your auras for the whole match, not only in combat
function NS.InBG()
    local ok, inInst, it = pcall(IsInInstance)
    return ok and (it == "pvp" or it == "arena") and true or false
end
local function ProperName(key)
    local n = properName[key]
    if n then return n end
    local ln = LOC.Local(key)
    if ln then properName[key] = ln; return ln end
    local ok, r = pcall(function()
        local i = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(key)
        if type(i) == "table" then return i.name end
        if GetSpellInfo then return (GetSpellInfo(key)) end
    end)
    n = (ok and type(r) == "string" and not (issecretvalue and issecretvalue(r))) and r or key
    properName[key] = n
    return n
end
function BUFFS.DirectAll()
    local now = GetTime()
    if now - lastDirect < 0.5 then return end
    lastDirect = now
    local get = C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName
    if not get then return end
    local _, pc = UnitClass("player")
    local function look(key, asCache, asInfo)
        local ok, d = pcall(get, "player", ProperName(key), "HELPFUL")
        if not ok then return end
        if type(d) ~= "table" then
            -- no answer: if this buff has answered in combat before, that means it is not on me
            if BUFFS.dworks[key] then
                if asCache then BUFFS.cache[key] = nil end
                BUFFS.live[key] = nil
                if asInfo then
                    local bi = buffInfo[key]
                    if not (bi and bi.t and now - bi.t < 1.5) then buffInfo[key] = nil end   -- not just noted from a cast
                end
            end
            return
        end
        BUFFS.dworks[key] = true
        BUFFS.dAny = true
        local exp, dur, cnt, src = d.expirationTime, d.duration, d.applications, d.sourceUnit
        local secret = issecretvalue and (issecretvalue(exp) or issecretvalue(dur) or issecretvalue(cnt))
        if secret then
            -- present, but the numbers are hidden: let the game's own countdown draw the time
            if asCache then
                local c = BUFFS.cache[key]
                if not c then BUFFS.cache[key] = { expires = 0 } else c.guess = nil end
                local id = d.auraInstanceID
                local gd = C_UnitAuras.GetAuraDuration
                if gd and id and not (issecretvalue and issecretvalue(id)) then
                    local okd, obj = pcall(gd, "player", id)
                    if okd and obj then BUFFS.live[key] = { t = now, obj = obj } end
                end
            end
            -- it is on me but its owner and time are hidden: that is still "present" (no timer, so no low-time warning)
            if asInfo and not buffInfo[key] then buffInfo[key] = { mine = true, expires = 0, hidden = true } end
            return
        end
        if type(exp) ~= "number" then exp = 0 end
        if asCache then
            if type(dur) == "number" and dur > 0 then BUFFS.learnedDur[key] = dur end
            BUFFS.cache[key] = { expires = exp, count = (type(cnt) == "number") and cnt or nil }
            BUFFS.live[key] = nil
        end
        if asInfo then
            local mine = false
            if not (issecretvalue and issecretvalue(src)) then
                mine = (src ~= nil and UnitIsUnit(src, "player")) and true or false
            end
            buffInfo[key] = { mine = mine, expires = exp }
        end
    end
    if NS.DB and NS.DB.watch then
        for k in pairs(NS.DB.watch) do
            if not BUFFS.imbueKey[k] then look(k, true, false) end
        end
    end
    for k in pairs(BUFFS.cache) do
        if k:find("^seal of ") then look(k, true, false) end
    end
    for _, def in pairs(BUFFS.tracked) do
        if def.class == pc and ((def.group and NS.DB.track and NS.DB.track.groupOn[def.group]) or (not def.group and NS.DB.track and NS.DB.track.on[def.auras[1]])
            or (NS.DB.icons and NS.DB.icons[def.auras[1]])) then
            for _, a in ipairs(def.auras) do look(a, false, true) end
        end
    end
end

-- Proc buffs (Clearcasting, Missile Barrage, Hot Streak ...) while combat hides the aura list:
-- ask for each one directly, by spell ID first (the same in every language) and then by name.
-- Whether it is on you is remembered between looks, so the glow does not flicker.
BUFFS.procLive = {}   -- proc buff -> time it should be gone by (renewed by every apply / refresh seen)
function BUFFS.ProcOn(key, exp)
    -- an effect that is counted from your own casts (Arcane Blast) goes by its real end time
    local e = BUFFS.castStack[key] and buffExpire[key]
    -- otherwise by the buff's own end time when we have it (a proc already half used up as the fight starts must
    -- not be held for its whole length again); only if that is not known, by the length seen before
    if not e and type(exp) == "number" and exp > GetTime() then e = exp + 0.3 end
    BUFFS.procLive[key] = e or (GetTime() + (BUFFS.learnedDur[key] or 30) + 1)
end
BUFFS.lastProc = 0
BUFFS.dpWorks, BUFFS.dpMiss = {}, {}   -- buff -> its direct lookup has answered this fight / empty answers in a row
function BUFFS.CapKey(k)
    return (k:gsub("(%a)([%w']*)", function(a, b) return a:upper() .. b end))
end
function BUFFS.DirectProcs()
    local now = GetTime()
    if now - BUFFS.lastProc < 0.2 then return end
    BUFFS.lastProc = now
    local byID = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
    local byName = C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName
    if not (byID or byName) then return end
    for key in pairs(buffProcs) do
        local d
        local ids = (LOC.k2ids and LOC.k2ids[key]) or (ProcGlowIDs and ProcGlowIDs[key])
        if byID and ids then
            for _, id in ipairs(ids) do
                local ok, r = pcall(byID, id)
                if ok and type(r) == "table" then d = r; break end
            end
        end
        if not d and byName then
            local ok, r = pcall(byName, "player", ProperName(key), "HELPFUL")
            if ok and type(r) == "table" then d = r end
            if not d then
                ok, r = pcall(byName, "player", BUFFS.CapKey(key), "HELPFUL")
                if ok and type(r) == "table" then d = r end
            end
        end
        if d then
            local ex = d.expirationTime
            if issecretvalue and issecretvalue(ex) then ex = nil end
            BUFFS.ProcOn(key, ex)
            BUFFS.dpWorks[key], BUFFS.dpMiss[key] = true, 0
            local c = d.applications
            if type(c) == "number" and not (issecretvalue and issecretvalue(c)) then BUFFS.stack[key] = c end
        elseif BUFFS.dpWorks[key] and BUFFS.procLive[key] and not BUFFS.castStack[key] then
            -- this lookup has answered for this buff during this fight, so "nothing there" means it is gone: after two
            -- misses in a row (not one, so a stray empty answer cannot blink it off) stop holding it for its full length
            BUFFS.dpMiss[key] = (BUFFS.dpMiss[key] or 0) + 1
            if BUFFS.dpMiss[key] >= 2 then BUFFS.procLive[key] = nil; BUFFS.dpMiss[key] = 0 end
        end
    end
end
end

-- throws if aura data is secret/restricted (caught by PlayerBuffs)
BUFFS.mineSet = {}      -- buffs on you that you cast yourself (the "Track a buff" list offers only those)
local function ReadAuras()
    wipe(scratchSet); wipe(scratchInfo); wipe(scratchExp); wipe(BUFFS.scratch); wipe(BUFFS.sdur); wipe(BUFFS.mineSet)
    for i = 1, 64 do
        local name, expires, source, duration, count, icon, sid
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            local d = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
            if d then name, expires, source, duration, count, icon, sid = d.name, d.expirationTime, d.sourceUnit, d.duration, d.applications, d.icon, d.spellId end
        else
            local n, ic, cnt, _, dur, exp, caster, _, _, spid = UnitBuff("player", i)
            name, expires, source, duration, count, icon, sid = n, exp, caster, dur, cnt, ic, spid
        end
        if not name then break end
        if issecretvalue and issecretvalue(name) then error("secret aura") end
        local key = name:lower()
        if LOC.on then
            -- the game names it in its own language: use the spell ID (else the name) to find our English key
            local ik = (type(sid) == "number" and not (issecretvalue and issecretvalue(sid))) and LOC.i2k[sid] or nil
            key = ik or LOC.Key(key)
        end
        if icon and not (issecretvalue and issecretvalue(icon)) then BUFFS.auraIcon[key] = icon end
        if type(duration) == "number" and not (issecretvalue and issecretvalue(duration)) then BUFFS.sdur[key] = duration end
        scratchSet[key] = true
        if source ~= nil and not (issecretvalue and issecretvalue(source)) and UnitIsUnit(source, "player") then BUFFS.mineSet[key] = true end
        if type(count) == "number" and not (issecretvalue and issecretvalue(count)) then BUFFS.scratch[key] = count end
        if type(expires) == "number" and expires > 0 and not (issecretvalue and issecretvalue(expires)) then
            scratchExp[key] = expires
        end
        if SHOUTS[key] or BUFFS.auraOf[key] then
            local unknown = issecretvalue and (issecretvalue(expires) or issecretvalue(source) or issecretvalue(duration))
            local mine = false
            if not unknown then
                mine = (source ~= nil and UnitIsUnit(source, "player")) and true or false
            end
            local cur = scratchInfo[key]
            if not cur or (mine and not cur.mine) then
                scratchInfo[key] = {
                    mine = mine,
                    expires = (not unknown and expires) or 0,
                    duration = (not unknown and duration) or nil,
                    unknown = unknown and true or nil,
                }
            end
        end
    end
end

-- a few of your own effects (Arcane Blast) are shown by the game among your debuffs: read those too, for the keys listed
BUFFS.harmful = { ["arcane blast"] = true }
local function ReadHarmful()
    for i = 1, 40 do
        local name, expires, count, sid
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            local d = C_UnitAuras.GetAuraDataByIndex("player", i, "HARMFUL")
            if d then name, expires, count, sid = d.name, d.expirationTime, d.applications, d.spellId end
        end
        if not name then break end
        if issecretvalue and issecretvalue(name) then error("secret aura") end
        local key = name:lower()
        if LOC.on then
            local ik = (type(sid) == "number" and not (issecretvalue and issecretvalue(sid))) and LOC.i2k[sid] or nil
            key = ik or LOC.Key(key)
        end
        if BUFFS.harmful[key] then
            scratchSet[key] = true
            if type(count) == "number" and not (issecretvalue and issecretvalue(count)) then BUFFS.scratch[key] = count end
            if type(expires) == "number" and expires > 0 and not (issecretvalue and issecretvalue(expires)) then scratchExp[key] = expires end
        end
    end
end

-- Shaman weapon imbues are enchants on the weapon, not auras, so they are read from the weapon itself:
-- GetWeaponEnchantInfo gives the time left, and the weapon's tooltip says which imbue it is.
BUFFS.imbueKey = { ["rockbiter weapon"] = "rockbiter", ["flametongue weapon"] = "flametongue",
    ["frostbrand weapon"] = "frostbrand", ["windfury weapon"] = "windfury" }
BUFFS.imb = {}      -- imbue name -> seconds left, for the imbues on your weapons right now
do
local imbSig, imbNames = {}, {}
local scanTip
local function ImbueName(slot)
    if not scanTip then scanTip = CreateFrame("GameTooltip", "ProcGlowScanTip", UIParent, "GameTooltipTemplate") end
    scanTip:SetOwner(UIParent, "ANCHOR_NONE")
    scanTip:ClearLines()
    if not pcall(scanTip.SetInventoryItem, scanTip, "player", slot) then return nil end
    for i = 1, scanTip:NumLines() do
        local fs = _G["ProcGlowScanTipTextLeft" .. i]
        local t = fs and fs:GetText()
        if type(t) == "string" and not (issecretvalue and issecretvalue(t)) then
            t = t:lower()
            for name, key in pairs(BUFFS.imbueKey) do
                if t:find(key, 1, true) then return name end
                if LOC.on then
                    local ln = LOC.Local(name)
                    if ln and t:find(ln:lower(), 1, true) then return name end
                end
            end
        end
    end
end
function BUFFS.ImbueUpdate()
    wipe(BUFFS.imb)
    if not (NS.DB and NS.DB.watch and GetWeaponEnchantInfo) then return end
    local any
    for name in pairs(BUFFS.imbueKey) do if NS.DB.watch[name] then any = true; break end end
    if not any then return end
    local ok, hm, me, _, mid, ho, oe, _, oid = pcall(GetWeaponEnchantInfo)
    if not ok then return end
    local function slot(i, has, exp, id, sk)
        if not has or type(exp) ~= "number" then imbNames[i] = nil; imbSig[i] = nil; return end
        local sig = tostring(id)
        local prev = imbSig[i]
        -- a different imbue, or the same one renewed (its time jumped up): look at the weapon again
        if not imbNames[i] or not prev or prev.id ~= sig or exp > prev.exp + 2000 then
            local nm = ImbueName(sk)
            if LOC.on and NS.DB then
                -- the tooltip is in the client's language: fall back on what an enchant id was last seen as,
                -- or on the imbue you cast a moment ago, and remember it (enchant ids are the same in every language)
                NS.DB.imbueIds = NS.DB.imbueIds or {}
                if nm then
                    NS.DB.imbueIds[sig] = nm
                else
                    nm = NS.DB.imbueIds[sig]
                    local c = BUFFS.imbCast
                    if not nm and c and GetTime() - c.t < 8 then
                        nm = c.name; NS.DB.imbueIds[sig] = nm; BUFFS.imbCast = nil
                    end
                end
            end
            imbNames[i] = nm
        end
        imbSig[i] = { id = sig, exp = exp }
        local nm = imbNames[i]
        if nm and not BUFFS.imb[nm] then BUFFS.imb[nm] = exp / 1000 end
    end
    slot(1, hm, me, mid, 16)
    slot(2, ho, oe, oid, 17)
end
end

local sealMemo = {}
function BUFFS.IsSeal(k)
    local v = sealMemo[k]
    if v == nil then v = k:find("^seal of ") ~= nil; sealMemo[k] = v end
    return v
end

local function PlayerBuffs()
    pcall(BUFFS.ImbueUpdate)
    local restricted = false
    -- remember the combo points you hold, so a finisher cast in combat can be timed (its length depends on them)
    do
        local v
        if GetComboPoints then
            local okc, r = pcall(GetComboPoints, "player", "target")
            if okc then v = r end
        end
        if (not v or v == 0) and UnitPower then
            local okp, r = pcall(UnitPower, "player", (Enum and Enum.PowerType and Enum.PowerType.ComboPoints) or 4)
            if okp then v = r end
        end
        if type(v) == "number" and not (issecretvalue and issecretvalue(v)) and v > 0 then
            BUFFS.cpLast, BUFFS.cpT = v, GetTime()
        end
    end
    if C_Secrets and C_Secrets.ShouldAurasBeSecret then
        local ok, r = pcall(C_Secrets.ShouldAurasBeSecret)
        if ok and r then restricted = true end
    end
    if not restricted then
        if pcall(ReadAuras) and (pcall(ReadHarmful) or true) then
            wipe(buffSet); wipe(buffInfo); wipe(buffExpire)
            wipe(BUFFS.dpWorks); wipe(BUFFS.dpMiss)      -- the direct lookups are proven again each time the auras are hidden
            for k in pairs(scratchSet) do buffSet[k] = true end
            for k, v in pairs(scratchExp) do buffExpire[k] = v end
            wipe(BUFFS.stack)
            for k, v in pairs(BUFFS.scratch) do
                BUFFS.stack[k] = v
                if v > 1 then BUFFS.seen[k] = true end
            end
            for k, v in pairs(scratchInfo) do
                buffInfo[k] = v
                if v.mine and v.duration and v.duration > 0 then
                    learnedDuration[k] = v.duration
                    if NS.DB and NS.DB.learned then NS.DB.learned[k] = v.duration end
                end
            end
            -- a cast counted a moment ago may not have reached the aura list yet: keep it for a beat
            for k, ck in pairs(BUFFS.castKeep) do
                if not buffSet[k] and GetTime() - ck.t < 0.6 then
                    buffSet[k] = true; BUFFS.stack[k] = ck.stack; buffExpire[k] = ck.exp
                end
            end
            NS.haveGoodRead = true
            -- remember which proc buffs you have as combat starts (combat log updates them from there)
            wipe(BUFFS.procLive)
            for k in pairs(buffProcs) do if buffSet[k] then BUFFS.ProcOn(k, buffExpire[k]) end end
            -- remember every buff you have had (per class), so "Track a buff" can offer it with its real icon
            if NS.DB and NS.DB.seen then
                local _, pcl = UnitClass("player")
                local t = NS.DB.seen[pcl]
                if not t then t = {}; NS.DB.seen[pcl] = t end
                for k in pairs(scratchSet) do
                    if not BUFFS.mineSet[k] then
                        -- someone else's buff on you (a priest's Renew, a campfire...): not a buff of this class
                    elseif not t[k] and not k:find("^seal of ") and not k:find("^greater blessing") then
                        t[k] = BUFFS.auraIcon[k] or true
                    elseif t[k] == true and BUFFS.auraIcon[k] then
                        t[k] = BUFFS.auraIcon[k]
                    end
                end
            end
            -- remember seals and tracked buffs, so their icons keep working once combat hides the auras
            for k in pairs(BUFFS.cache) do if not buffSet[k] then BUFFS.cache[k] = nil end end
            for k in pairs(buffSet) do
                if BUFFS.IsSeal(k) or (NS.DB and NS.DB.watch and NS.DB.watch[k]) then
                    local d = BUFFS.sdur[k]
                    if d and d > 0 then
                        BUFFS.learnedDur[k] = d
                        if NS.DB and NS.DB.learned then NS.DB.learned[k] = d end
                        -- a fresh cast: remember how long that many combo points gave
                        local cc = BUFFS.castCP[k]
                        if cc and GetTime() - cc.t < 3 then
                            if NS.DB and NS.DB.learned then
                                NS.DB.learned[k .. "@" .. cc.cp] = d
                                local def = BUFFS.cpBuffs[k]
                                if def then NS.DB.learned[k .. "@x"] = d / (def.base + def.per * (cc.cp - 1)) end
                            end
                            BUFFS.castCP[k] = nil
                        end
                    end
                    local ce = BUFFS.cache[k]
                    if ce then ce.expires, ce.count = buffExpire[k] or 0, BUFFS.stack[k]
                    else BUFFS.cache[k] = { expires = buffExpire[k] or 0, count = BUFFS.stack[k] } end
                end
            end
        else
            restricted = true
        end
    end
    -- when restricted, buff procs are unknown; shout info keeps its last known values,
    -- refreshed by a direct lookup when the client allows it for that spell
    if restricted then
        wipe(buffSet)
        for name, id in pairs(shoutSpellID) do pcall(DirectShout, name, id) end
        pcall(BUFFS.DirectAll)
        pcall(BUFFS.DirectProcs)
        local nowT = GetTime()
        for k, t in pairs(BUFFS.procLive) do
            if t < nowT then
                BUFFS.procLive[k] = nil
                if BUFFS.castStack[k] then BUFFS.stack[k] = nil; buffExpire[k] = nil end
            elseif buffProcs[k] then buffSet[k] = true end
        end
    end
    NS.auraRestricted = restricted
    pcall(BUFFS.Update)
    return buffSet
end
NS.PlayerBuffs = PlayerBuffs

-- current stance / form name (lowercase), nil when in none
local function CurrentForm()
    if not GetShapeshiftForm then return nil end
    local idx = GetShapeshiftForm()
    if not idx or idx == 0 then return nil end
    local _, b, _, d = GetShapeshiftFormInfo(idx)
    if type(b) == "string" then return LOC.Key(b:lower()) end
    local n = SpellNameByID(d)
    return n and n:lower()
end
NS.CurrentForm = CurrentForm

-- all stance / form names available to this character (lowercase)
local function StanceList()
    local list = {}
    if GetNumShapeshiftForms then
        for i = 1, GetNumShapeshiftForms() do
            local _, b, _, d = GetShapeshiftFormInfo(i)
            local n = type(b) == "string" and LOC.Key(b:lower()) or SpellNameByID(d)
            if n then list[#list + 1] = n:lower() end
        end
    end
    return list
end
NS.StanceList = StanceList

local function CondOK(spell, form)
    local c = NS.DB.redirectCond[spell]
    if not c then return true end
    if c.stances then
        if next(c.stances) == nil then return true end
        return c.stances[form] and true or false
    end
    if not c.stance then return true end
    if c.mode == "in" then return form == c.stance end
    if c.mode == "notin" then return form ~= c.stance end
    return true
end
NS.CondOK = CondOK
