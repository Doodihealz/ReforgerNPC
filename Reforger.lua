local ENABLE_RANDOM_ON_ACQUIRE = true
local RNG_SEEDED = false
local NPC_ID = 200004

local QUALITY_COST = { [0]=10000,[1]=20000,[2]=50000,[3]=100000,[4]=250000,[5]=1000000 }
local MAX_LEVEL = 80
local ENCHANT_CACHE_READY = false

local ALLOWED_IDS = { [18706]=true }
local EXCLUDED_IDS = { [4499]=true,[5571]=true,[5572]=true,[805]=true,[828]=true,[856]=true,[918]=true,[1939]=true,[4245]=true,[5764]=true,[5765]=true,[14155]=true,[14156]=true,[17966]=true,[19291]=true,[21841]=true,[41599]=true,[41729]=true,[43345]=true,[43575]=true,[43958]=true,[44751]=true,[45854]=true,[49295]=true,[38346]=true,[38347]=true,[38348]=true,[38349]=true,[39489]=true,[41600]=true,[34845]=true,[38225]=true,[20400]=true,[22243]=true,[22244]=true,[44447]=true }

local STAT_COLORS = { ["Agility"]="|cff00ff00Agility|r",["Strength"]="|cffff0000Strength|r",["Stamina"]="|cffffffffStamina|r",["Spirit"]="|cffff00ffSpirit|r",["Intellect"]="|cff00ffffIntellect|r",["Attack Power"]="|cff00ff00Attack Power|r",["Spell Power"]="|cffff7f00Spell Power|r",["Crit"]="|cffffff00Crit|r",["Haste"]="|cffffcc00Haste|r",["Hit"]="|cff9999ffHit|r",["Resilience"]="|cffff66ffResilience|r",["Dodge"]="|cffffcc99Dodge|r",["Parry"]="|cffffcc99Parry|r",["Block"]="|cffffcc99Block|r",["Armor Penetration"]="|cffff9999Armor Penetration|r",["Expertise"]="|cffdd8800Expertise|r",["Ranged Attack Power"]="|cff66ff66Ranged Attack Power|r" }

local STAT_DISPLAY_NAMES = {
    ["agility"] = "Agility",
    ["strength"] = "Strength",
    ["stamina"] = "Stamina",
    ["spirit"] = "Spirit",
    ["intellect"] = "Intellect",
    ["spell power"] = "Spell Power",
    ["attack power"] = "Attack Power",
    ["ranged attack power"] = "Ranged Attack Power",
    ["crit"] = "Crit",
    ["critical strike rating"] = "Crit",
    ["haste"] = "Haste",
    ["hit"] = "Hit",
    ["resilience"] = "Resilience",
    ["armor penetration"] = "Armor Penetration",
    ["expertise"] = "Expertise",
    ["nature resistance"] = "Nature Resistance",
    ["frost resistance"] = "Frost Resistance",
    ["shadow resistance"] = "Shadow Resistance",
    ["fire resistance"] = "Fire Resistance",
    ["arcane resistance"] = "Arcane Resistance",
    ["defense rating"] = "Defense Rating",
    ["mana every 5 sec"] = "MP5"
}

local RANGED_AP_IDS = { [2047]=true,[2048]=true,[2049]=true,[2050]=true,[2051]=true,[2052]=true,[2053]=true,[2054]=true,[2055]=true,[2056]=true,[2057]=true,[2058]=true,[2059]=true,[2060]=true,[2061]=true,[2062]=true,[2064]=true,[2065]=true,[2066]=true,[2067]=true,[2068]=true,[2069]=true,[2070]=true,[2071]=true,[2072]=true,[2073]=true,[2074]=true }
local OIL_IDS = { [2603]=true,[2604]=true,[2605]=true,[2606]=true,[2607]=true }

local STRENGTH_BLOCK_CLASSES = { [3]=true,[4]=true,[5]=true,[7]=true,[8]=true,[9]=true,[11]=true }
local CASTER_BLOCK_CLASSES   = { [1]=true,[4]=true,[6]=true }

local WEAPON_BIAS_SLOT1 = 0.4
local WEAPON_BIAS_SLOT2 = 0.7
local CASTER_OIL_WEIGHT = 3
local CASTER_SP_INT_WEIGHT = 2
local HUNTER_ROGUE_AGI_BONUS = 3
local WARRIOR_STR_BONUS = 2
local HUNTER_RAP_BONUS = 5
local ACQ_MAX_SLOTS = 2
local ACQ_ATTEMPTS_PER_SLOT = 8
local ACQ_ROLL_CHANCE_DENOM = 1
local ACQ_SKIP_IF_HAS_ENCHANT = true
local SAVE_ITEM_IMMEDIATELY = false

local WRITE_SLOTS_REFORGE  = {0, 1}
local WRITE_SLOTS_ACQUIRE  = {0, 1}

local SPELLPOWER_SYNERGY_BONUS = 0.35
local SAME_STAT_SYNERGY_BONUS = 1.25

local MANUAL_MODE_DEFAULT = false
local BAG_MAX_SLOT = 36

local t_insert, t_concat = table.insert, table.concat
local m_random = math.random
local s_format = string.format

local enchantCache = { ANY = {}, WEAPON = {}, ARMOR = {} }
local enchantNameCache = {}
local parsedStatCache = {}
local playerEligibleMap = {}
local colorizedCache = {}
local _isSPorIntCache = {}
local _hasRAPCache = {}
local slotOrderPrefs = {}
local statMenuCache = {}
local HandleClearKitCommand
local NormalizeKitKey
local EnsureKitTable
local safeSetEnchant
local safeGetEnchantId
local ENCHANT_KITS = {}
local ENCHANT_KIT_LABELS = {}
local ENCHANT_KIT_CLEAR_PENDING = {}
local CLEAR_KIT_CONFIRM_TIMEOUT = 10
local RESERVED_KIT_NAME = "all"
local KIT_TABLE_READY = false
local KIT_TABLE_NAME = "custom_enchant_kits"

local function CloneDefaultSlotOrder()
    local order = {}
    for i=1,#WRITE_SLOTS_REFORGE do
        order[i] = WRITE_SLOTS_REFORGE[i]
    end
    return order
end

local function GetSlotOrder(player)
    if not player then return WRITE_SLOTS_REFORGE end
    local g = player:GetGUIDLow()
    if not g then return WRITE_SLOTS_REFORGE end
    local order = slotOrderPrefs[g]
    local needsReset = false
    if not order or #order ~= #WRITE_SLOTS_REFORGE then
        needsReset = true
    else
        for i=1,#WRITE_SLOTS_REFORGE do
            if order[i] == nil then
                needsReset = true
                break
            end
        end
    end
    if needsReset then
        order = CloneDefaultSlotOrder()
        slotOrderPrefs[g] = order
    end
    return order
end

local function ToggleSlotOrder(player)
    local order = GetSlotOrder(player)
    if #order >= 2 then
        order[1], order[2] = order[2], order[1]
    end
end

local function SlotOrderLabel(player)
    local order = GetSlotOrder(player)
    local fmt
    if (order[1] or 0) == 0 and (order[2] or 1) == 1 then
        fmt = "Slot Order: Primary -> Secondary"
    else
        fmt = "Slot Order: Secondary -> Primary"
    end
    return "|cff00c0ff"..fmt.."|r"
end

-- Cache size limits to prevent memory leaks
local CACHE_MAX_SIZE = 1000
local CACHE_CLEANUP_SIZE = 800

-- Cache management functions
local function cleanupCache(cache, maxSize, cleanupSize)
    local count = 0
    for _ in pairs(cache) do count = count + 1 end
    if count > maxSize then
        local toRemove = count - cleanupSize
        for k, _ in pairs(cache) do
            if toRemove <= 0 then break end
            cache[k] = nil
            toRemove = toRemove - 1
        end
    end
end
local NO_OIL_CLASSES    = { [1]=true, [3]=true, [4]=true, [6]=true }
local NO_SPIRIT_CLASSES = { [1]=true, [4]=true, [6]=true }
local FORBID_ROCKBITER_OR_VENOMHIDE = { [1]=true, [1003]=true }

local function isRockbiterOrVenomhide(id)
    if FORBID_ROCKBITER_OR_VENOMHIDE[id] then return true end
    local n = enchantNameCache[id]
    if not n then return false end
    n = n:lower()
    return (n:find("rockbiter", 1, true) ~= nil) or (n:find("venomhide", 1, true) ~= nil)
end

local function IsItemSoulboundOrBoP(item)
    if not item then return false end
    if item.IsSoulBound and item:IsSoulBound() then
        return true
    end
    if item.GetBonding then
        local bonding = item:GetBonding()
        if bonding == 1 then -- Bind on pickup
            return true
        end
    end
    return false
end

local BL_STATE = {}
local function BL(p) local g=p:GetGUIDLow(); local s=BL_STATE[g]; if not s then s={tiers={}}; BL_STATE[g]=s end; return s end
local function BL_getFloor(p, tier, stat) local t=BL(p).tiers; t[tier]=t[tier] or {}; local c=t[tier][stat] or 0; if c>=6 then return 18 elseif c>=3 then return 16 else return 0 end end
local function BL_inc(p, tier, stat) local t=BL(p).tiers; t[tier]=t[tier] or {}; t[tier][stat]=(t[tier][stat] or 0)+1; for k,_ in pairs(t[tier]) do if k~=stat then t[tier][k]=0 end end end

local function seedRng() if RNG_SEEDED then return end RNG_SEEDED=true m_random(os.time()%2147483646) end

local function parseStatValue(name) 
    if not name then return nil, nil end 
    local num, rest = name:match("([%+%-]?%d+)%s+(.+)")
    if not num or not rest then return nil, nil end 
    local v = tonumber(num)
    if not v then return nil, nil end 
    rest = rest:match("^%s*(.-)%s*$")
    return rest, v 
end

local function getParsedStat(id) 
    local c = parsedStatCache[id]
    if c then return c.name, c.val end 
    local nm = enchantNameCache[id]
    if not nm then 
        parsedStatCache[id] = {}
        return nil, nil 
    end 
    local stat, val = parseStatValue(nm)
    parsedStatCache[id] = {name = stat, val = val}
    cleanupCache(parsedStatCache, CACHE_MAX_SIZE, CACHE_CLEANUP_SIZE)
    return stat, val 
end

local function canonicalStatKey(statName)
    if not statName or statName == "" then return nil end
    local lower = statName:lower()
    lower = lower:gsub("^%s+", ""):gsub("%s+$", "")
    if lower:find("spell power", 1, true) then return "spell power" end
    if lower:find("ranged attack power", 1, true) then return "ranged attack power" end
    if lower:find("attack power", 1, true) then return "attack power" end
    if lower:find("critical", 1, true) then return "critical strike rating" end
    if lower:find("crit", 1, true) then return "crit" end
    if lower:find("haste", 1, true) then return "haste" end
    if lower:find("hit", 1, true) then return "hit" end
    if lower:find("resilience", 1, true) then return "resilience" end
    if lower:find("armor penetration", 1, true) then return "armor penetration" end
    if lower:find("expertise", 1, true) then return "expertise" end
    if lower:find("stamina", 1, true) then return "stamina" end
    if lower:find("strength", 1, true) then return "strength" end
    if lower:find("agility", 1, true) then return "agility" end
    if lower:find("intellect", 1, true) then return "intellect" end
    if lower:find("spirit", 1, true) then return "spirit" end
    if lower:find("nature resistance", 1, true) then return "nature resistance" end
    if lower:find("frost resistance", 1, true) then return "frost resistance" end
    if lower:find("shadow resistance", 1, true) then return "shadow resistance" end
    if lower:find("fire resistance", 1, true) then return "fire resistance" end
    if lower:find("arcane resistance", 1, true) then return "arcane resistance" end
    if lower:find("defense rating", 1, true) then return "defense rating" end
    if lower:find("mana every 5 sec", 1, true) or lower:find("mana /5", 1, true) then return "mana every 5 sec" end
    return lower
end

local function getStatDisplayName(key, fallback)
    if not key or key == "" then return fallback end
    return STAT_DISPLAY_NAMES[key] or fallback or (key:sub(1,1):upper()..key:sub(2))
end

local function getStatKey(id) 
    local statName = getParsedStat(id)
    if not statName then return nil end 
    return canonicalStatKey(statName)
end

local function LoadEnchantCache()
    local q = WorldDBQuery("SELECT enchantID, tier, class, comment FROM item_enchantment_random_tiers")
    if not q then 
        print("ERROR: Failed to load enchantment cache from database")
        return false
    end
    
    local loadedCount = 0
    repeat
        local id = q:GetUInt32(0)
        local t = q:GetUInt8(1)
        local c = q:GetString(2)
        local comm = q:GetString(3)
        
        local isValid = true
        
        if not id or id <= 0 then
            print("WARNING: Invalid enchant ID in database: " .. tostring(id))
            isValid = false
        end
        
        if isValid and (not t or t < 1 or t > 5) then
            print("WARNING: Invalid tier for enchant " .. id .. ": " .. tostring(t))
            isValid = false
        end
        
        if isValid then
            c = (c and c:upper()) or "ANY"
            if c ~= "ANY" and c ~= "WEAPON" and c ~= "ARMOR" then c = "ANY" end
            
            local C = enchantCache[c]
            C[t] = C[t] or {}
            t_insert(C[t], id)
            enchantNameCache[id] = comm or ("Enchant " .. id)
            loadedCount = loadedCount + 1
        end
    until not q:NextRow()
    
    print("Loaded " .. loadedCount .. " enchantments into cache")
    return true
end

-- Initialize cache with error handling
ENCHANT_CACHE_READY = LoadEnchantCache()
if not ENCHANT_CACHE_READY then
    print("CRITICAL: Failed to initialize enchantment cache. Reforger functionality is disabled until resolved.")
end

local function IsValidEquipable(item)
    if not item then return false end
    if item:GetQuality() < 2 then return false end
    local entry = item:GetEntry()
    if ALLOWED_IDS[entry] then return true end
    if EXCLUDED_IDS[entry] then return false end
    local class = item:GetClass()
    local invType = item:GetInventoryType()
    return (class == 2 or class == 4) and ((invType > 0 and invType < 24) or invType == 25 or invType == 26 or invType == 28)
end

local function GetScaledCost(base, level)
    if not base or base <= 0 then return 0 end
    if not level or level <= 0 then level = 1 end
    
    local L = math.min(math.max(level, 1), MAX_LEVEL)
    local scale = L / MAX_LEVEL
    local cost = math.floor(base * scale)
    
    return math.max(cost, math.floor(base * 0.1))
end

local function FormatGold(cost)
    local g = math.floor(cost/10000); local s = math.floor((cost%10000)/100); local c = cost%100
    local parts = {}
    if g>0 then t_insert(parts, s_format("|cffffd700%dg|r", g)) end
    if s>0 then t_insert(parts, s_format("|cffc7c7cf%ds|r", s)) end
    if c>0 then t_insert(parts, s_format("|cffeda55f%dc|r", c)) end
    return (#parts>0) and t_concat(parts, " ") or "0c"
end

local function SendYellowMessage(player, msg) player:SendBroadcastMessage("|cffffff00"..msg.."|r") end
local function SendError(player, msg)
    if player then player:SendBroadcastMessage("|cffff5555"..msg.."|r") end
end
local function SendSuccess(player, msg)
    if player then player:SendBroadcastMessage("|cff33ff99"..msg.."|r") end
end

local function EnsureReforgerReady(player)
    if ENCHANT_CACHE_READY then return true end
    SendError(player, "[Reforger] Enchantment data unavailable. Please try again later.")
    return false
end

local function StatCacheKey(item, tier)
    local guid = (item and item.GetGUIDLow and item:GetGUIDLow()) or 0
    return tostring(guid) .. ":" .. tostring(tier or 0)
end

local function InvalidateStatCacheForItem(item)
    if not item then return end
    local guid = (item.GetGUIDLow and item:GetGUIDLow()) or 0
    if guid == 0 then
        statMenuCache = {}
        return
    end
    local prefix = tostring(guid) .. ":"
    for key in pairs(statMenuCache) do
        if key:sub(1, #prefix) == prefix then
            statMenuCache[key] = nil
        end
    end
end

local function EscapeSQL(str)
    if str == nil then return "" end
    return tostring(str):gsub("\\", "\\\\"):gsub("'", "''")
end

local function SerializeKit(kit)
    local parts = {}
    for _, entry in ipairs(kit) do
        parts[#parts+1] = string.format("%d:%d", entry.id, entry.slot)
    end
    return table.concat(parts, ",")
end

local function DeserializeKit(serialized)
    local kit = {}
    if not serialized or serialized == "" then return kit end
    for token in serialized:gmatch("([^,]+)") do
        local id, slot = token:match("^(%d+):(%d+)$")
        if id and slot then
            kit[#kit+1] = { id = tonumber(id), slot = tonumber(slot) }
        end
    end
    return kit
end

EnsureKitTable = function()
    local ok, err = pcall(function()
        CharDBExecute(string.format([[
            CREATE TABLE IF NOT EXISTS %s (
                kit_key VARCHAR(64) NOT NULL PRIMARY KEY,
                label   VARCHAR(64) NOT NULL,
                payload TEXT NOT NULL
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8;
        ]], KIT_TABLE_NAME))
    end)
    if not ok then
        print("[Reforger] Failed to ensure kit table: "..tostring(err))
        KIT_TABLE_READY = false
        return
    end
    KIT_TABLE_READY = true
end

local function LoadKitsFromDB()
    if not KIT_TABLE_READY then return end
    local q = CharDBQuery(string.format("SELECT kit_key, label, payload FROM %s", KIT_TABLE_NAME))
    if not q then return end
    repeat
        local key = q:GetString(0)
        local label = q:GetString(1)
        local payload = q:GetString(2)
        if key and payload then
            local kit = DeserializeKit(payload)
            if #kit > 0 then
                ENCHANT_KITS[key] = kit
                ENCHANT_KIT_LABELS[key] = label or key
            end
        end
    until not q:NextRow()
end

local function SaveKitToDB(kitKey, label, kit)
    if not KIT_TABLE_READY then return end
    local payload = SerializeKit(kit)
    local sql = string.format("REPLACE INTO %s (kit_key, label, payload) VALUES ('%s','%s','%s')",
        KIT_TABLE_NAME, EscapeSQL(kitKey), EscapeSQL(label or kitKey), EscapeSQL(payload))
    CharDBExecute(sql)
end

local function DeleteKitFromDB(kitKey)
    if not KIT_TABLE_READY then return end
    CharDBExecute(string.format("DELETE FROM %s WHERE kit_key = '%s'", KIT_TABLE_NAME, EscapeSQL(kitKey)))
end

local function DeleteAllKitsFromDB()
    if not KIT_TABLE_READY then return end
    CharDBExecute(string.format("TRUNCATE TABLE %s", KIT_TABLE_NAME))
end

local function DefineEnchantKit(player, args)
    args = args and args:gsub("^%s+", "") or ""
    if args == "" then
        SendError(player, "Usage: .enchant kit <enchantId> <slot> ... <kitId>")
        return false
    end
    local tokens = {}
    for token in args:gmatch("%S+") do
        tokens[#tokens+1] = token
    end
    if #tokens < 3 then
        SendError(player, "Kit requires at least one enchant/slot pair and an ID.")
        return false
    end
    local kitIdRaw = tokens[#tokens]
    if kitIdRaw:lower() == RESERVED_KIT_NAME then
        SendError(player, "Kit name 'all' is reserved.")
        return false
    end
    local kitKey = NormalizeKitKey(kitIdRaw)
    if not kitKey then
        SendError(player, "Invalid kit name.")
        return false
    end
    table.remove(tokens, #tokens)
    if #tokens % 2 ~= 0 then
        SendError(player, "Each enchant must be followed by a slot (0 or 1).")
        return false
    end
    local kit = {}
    for i=1,#tokens,2 do
        local enchantId = tonumber(tokens[i])
        local slotIndex = tonumber(tokens[i+1])
        if not enchantId or enchantId <= 0 then
            SendError(player, "Invalid enchant ID: "..tostring(tokens[i]))
            return false
        end
        if slotIndex ~= 0 and slotIndex ~= 1 then
            SendError(player, "Invalid slot: "..tostring(tokens[i+1]).." (use 0 or 1)")
            return false
        end
        kit[#kit+1] = { id = enchantId, slot = slotIndex }
    end
    ENCHANT_KITS[kitKey] = kit
    ENCHANT_KIT_LABELS[kitKey] = kitIdRaw
    SaveKitToDB(kitKey, kitIdRaw, kit)
    SendSuccess(player, string.format("Saved kit %s with %d enchant(s).", kitIdRaw, #kit))
    return false
end

local function ApplyEnchantKit(player, item, kitKeyRaw, suppressMessages)
    if kitKeyRaw and kitKeyRaw:lower() == RESERVED_KIT_NAME then
        SendError(player, "Kit name 'all' is reserved.")
        return 0
    end
    local kitKey = NormalizeKitKey(kitKeyRaw)
    if not kitKey then
        SendError(player, "Invalid kit name.")
        return 0
    end
    local kit = ENCHANT_KITS[kitKey]
    if not kit then
        SendError(player, "Unknown kit: "..tostring(kitKeyRaw))
        return 0
    end
    local applied = 0
    for _, entry in ipairs(kit) do
        if safeSetEnchant(item, entry.id, entry.slot) then
            applied = applied + 1
        end
    end
    if applied == 0 then
        if not suppressMessages then
            SendError(player, "No enchants from kit "..tostring(kitKeyRaw).." were applied.")
        end
        return 0
    end
    if not suppressMessages then
        local label = ENCHANT_KIT_LABELS[kitKey] or kitKeyRaw
        local itemLink = (item and item.GetItemLink and item:GetItemLink()) or (item and item.GetName and item:GetName()) or "item"
        SendSuccess(player, string.format("Applied kit %s to %s (%d enchant(s)).", label, itemLink, applied))
    end
    InvalidateStatCacheForItem(item)
    if SAVE_ITEM_IMMEDIATELY and item.SaveToDB then item:SaveToDB() end
    return applied
end

local function ApplyKitToAllEquipped(player, kitKeyRaw)
    if kitKeyRaw and kitKeyRaw:lower() == RESERVED_KIT_NAME then
        SendError(player, "Kit name 'all' is reserved.")
        return false
    end
    local kitKey = NormalizeKitKey(kitKeyRaw)
    if not kitKey or not ENCHANT_KITS[kitKey] then
        SendError(player, "Unknown kit: "..tostring(kitKeyRaw))
        return false
    end
    local affected = 0
    for slot=0,18 do
        local item = player:GetItemByPos(255, slot)
        if item and IsValidEquipable(item) and item:GetQuality() >= 2 then
            local applied = ApplyEnchantKit(player, item, kitKey, true)
            if applied > 0 then
                affected = affected + 1
            end
        end
    end
    if affected == 0 then
        SendError(player, "No eligible items to apply kit "..tostring(kitKeyRaw)..".")
    else
        local label = ENCHANT_KIT_LABELS[kitKey] or kitKeyRaw
        SendSuccess(player, string.format("Applied kit %s to %d item(s).", label, affected))
    end
    return false
end
local function CloneStatList(list)
    local out = {}
    for i=1,#list do
        local entry = list[i]
        out[i] = { key = entry.key, name = entry.name }
    end
    return out
end

local function SanitizeItemArg(arg)
    if not arg then return nil end
    arg = arg:gsub("^%s+", ""):gsub("%s+$", "")
    arg = arg:gsub("|c%x%x%x%x%x%x%x%x", "")
    arg = arg:gsub("|r", "")
    return arg
end

NormalizeKitKey = function(key)
    if not key then return nil end
    local trimmed = key:gsub("^%s+", ""):gsub("%s+$", "")
    if trimmed == "" then return nil end
    return trimmed:lower()
end

local function SplitItemAndRemainder(rest)
    if not rest then return nil, nil end
    rest = rest:gsub("^%s+", "")
    if rest == "" then return nil, nil end
    if rest:sub(1,2) == "|c" then
        local closing = rest:find("|r")
        if not closing then return nil, nil end
        local itemArg = rest:sub(1, closing+1)
        local remainder = rest:sub(closing+2)
        return itemArg, remainder
    else
        local closeBracket = rest:find("%]")
        if not closeBracket then return nil, nil end
        local itemArg = rest:sub(1, closeBracket)
        local remainder = rest:sub(closeBracket+1)
        return itemArg, remainder
    end
end

local function ShowEnchantHelp(player)
    local lines = {
        "|cffffcc00.enchant [itemLink] <enchantId> <slot>|r - apply a single enchant to slot 0 or 1.",
        "|cffffcc00.enchant kit <enchantId> <slot> ... <kitName>|r - save a kit (name can be words or numbers).",
        "|cffffcc00.enchant [itemLink] kit <kitName>|r - apply a saved kit to one item.",
        "|cffffcc00.enchant all kit <kitName>|r - apply a kit to every uncommon+ item you're wearing.",
        "|cffffcc00.clearkit <kitName>|r removes a kit, |cffffcc00.clearkit all|r then |cffffcc00.clearkit all confirm|r wipes them all.",
        "|cffffcc00.kitlist|r lists all saved kits and their enchants.",
        "Example: |cffffcc00.enchant kit 3854 0 2273 1 BIS|r defines kit 'BIS' with two enchants."
    }
    for _, line in ipairs(lines) do
        SendYellowMessage(player, line)
    end
end

local function ShowKitList(player)
    local entries = {}
    for key, kit in pairs(ENCHANT_KITS) do
        entries[#entries+1] = {
            key = key,
            label = ENCHANT_KIT_LABELS[key] or key,
            kit = kit,
        }
    end
    if #entries == 0 then
        SendYellowMessage(player, "No kits defined.")
        return
    end
    table.sort(entries, function(a, b)
        return tostring(a.label):lower() < tostring(b.label):lower()
    end)
    for _, entry in ipairs(entries) do
        local parts = {}
        for idx, spell in ipairs(entry.kit) do
            local name = enchantNameCache[spell.id] or ("Enchant "..spell.id)
            parts[#parts+1] = string.format("%s (slot %d)", name, spell.slot)
        end
        SendYellowMessage(player, string.format("Kit %s: %s", entry.label, table.concat(parts, " | ")))
    end
end

local function GetEligibleItems(player)
    if not player then return {} end
    
    local items, slotMap = {}, {}
    local playerGUID = player:GetGUIDLow()
    
    for slot = 0, 18 do
        local it = player:GetItemByPos(255, slot)
        if it and IsValidEquipable(it) then 
            t_insert(items, it)
            slotMap[it:GetGUIDLow()] = slot 
        end
    end
    
    playerEligibleMap[playerGUID] = slotMap
    cleanupCache(playerEligibleMap, CACHE_MAX_SIZE, CACHE_CLEANUP_SIZE)
    
    return items
end

-- Pre-computed lookup table for better performance
local ITEM_TYPE_LOOKUP = {
    [1] = "Armor", [2] = "Accessories", [3] = "Armor", [5] = "Armor", [6] = "Armor", [7] = "Armor", 
    [8] = "Armor", [9] = "Armor", [10] = "Armor", [11] = "Accessories", [12] = "Accessories", 
    [13] = "Weapons", [14] = "Weapons", [15] = "Weapons", [16] = "Armor", [17] = "Weapons", 
    [18] = "Weapons", [21] = "Weapons", [23] = "Weapons", [25] = "Accessories", [26] = "Weapons", 
    [28] = "Accessories"
}

local function ClassifyItem(item)
    if not item then return "Miscellaneous" end
    local invType = item:GetInventoryType()
    return ITEM_TYPE_LOOKUP[invType] or "Miscellaneous"
end

local STAT_COLORS_LC = {}
for k,v in pairs(STAT_COLORS) do STAT_COLORS_LC[k:lower()] = v end

local function ColorizeEnchantment(desc)
    if not desc or desc == "" then return "" end
    
    local cached = colorizedCache[desc]
    if cached then return cached end
    
    -- Remove existing color codes first
    local s = desc:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    
    -- Apply coloring to stat patterns
    s = s:gsub("([%+%-]?)(%d+)%s+(.+)$", function(sign, num, statName)
        statName = statName:match("^%s*(.-)%s*$")
        if not statName then return sign .. num .. " Unknown" end
        
        local coloredSign = (sign ~= "" and "|cffffff00" .. sign .. "|r") or ""
        local coloredNumber = "|cff00ff00" .. num .. "|r"
        local color = STAT_COLORS_LC[statName:lower()] or ("|cffffffff" .. statName .. "|r")
        return coloredSign .. coloredNumber .. " " .. color
    end)
    
    colorizedCache[desc] = s
    cleanupCache(colorizedCache, CACHE_MAX_SIZE, CACHE_CLEANUP_SIZE)
    return s
end

local function isCaster(p) local c=p:GetClass(); return c==8 or c==5 or c==9 end
local function isOil(id) return OIL_IDS[id]==true end
local function isWeaponTemporaryEnchant(id)
    if not id then return false end
    if isOil(id) then return true end
    local name = enchantNameCache[id]
    if not name then return false end
    name = name:lower()
    return (name:find("windfury", 1, true) ~= nil)
        or (name:find("rockbiter", 1, true) ~= nil)
        or (name:find("frostbrand", 1, true) ~= nil)
        or (name:find("flametongue", 1, true) ~= nil)
        or (name:find("venomhide", 1, true) ~= nil)
end
local function isSPorInt(id)
    if not id then return false end
    local v = _isSPorIntCache[id]
    if v ~= nil then return v end
    
    local n = enchantNameCache[id]
    v = n and (n:find("Spell Power", 1, true) or n:find("Intellect", 1, true)) and true or false
    _isSPorIntCache[id] = v
    cleanupCache(_isSPorIntCache, CACHE_MAX_SIZE, CACHE_CLEANUP_SIZE)
    return v
end

local function hasRangedAP(id)
    if not id then return false end
    local v = _hasRAPCache[id]
    if v ~= nil then return v end
    
    local n = enchantNameCache[id]
    v = (RANGED_AP_IDS[id] == true) or (n and n:lower():find("ranged attack power", 1, true) ~= nil) or false
    _hasRAPCache[id] = v
    cleanupCache(_hasRAPCache, CACHE_MAX_SIZE, CACHE_CLEANUP_SIZE)
    return v
end

local function isSpellPower(id)
    local n = enchantNameCache[id]
    return n and n:find("Spell Power", 1, true) ~= nil
end

local function hasChosenSpellPower(chosenSet)
    if not chosenSet then return false end
    for id,_ in pairs(chosenSet) do if isSpellPower(id) then return true end end
    return false
end

local function weaponBias(slotIndex) if slotIndex==0 then return WEAPON_BIAS_SLOT1 elseif slotIndex==1 then return WEAPON_BIAS_SLOT2 else return WEAPON_BIAS_SLOT2 end end
local function rollProb(p) return m_random() <= p end

local function buildPool(item, player, blacklist, tier, weaponBiasProb, restrictKey)
    local itemClass = (item:GetClass()==2 and "WEAPON") or (item:GetClass()==4 and "ARMOR") or "ANY"
    local caster = isCaster(player)
    local playerClass = player:GetClass()
    local pool, total = {}, 0

    local preferredStatKey = nil
    if blacklist and next(blacklist) ~= nil then for id,_ in pairs(blacklist) do preferredStatKey = getStatKey(id); if preferredStatKey then break end end end

    local spSynergyActive = hasChosenSpellPower(blacklist)

    local function consider(id, baseWeight)
        if blacklist[id] then return end
        if restrictKey and getStatKey(id) ~= restrictKey then return end
        if hasRangedAP(id) and playerClass ~= 3 then return end
        local statName = getParsedStat(id)
        local name = enchantNameCache[id] or ""
        if ((statName == "Strength") or name:find("Strength",1,true)) and (STRENGTH_BLOCK_CLASSES[playerClass] or playerClass==11) then return end
        if ((statName == "Intellect") or name:find("Intellect",1,true) or name:find("Spell Power",1,true)) and CASTER_BLOCK_CLASSES[playerClass] then return end
        if playerClass == 3 and isSPorInt(id) then return end
        if NO_SPIRIT_CLASSES[playerClass] and (statName == "Spirit" or name:find("Spirit", 1, true)) then return end
        -- Prevent priests and warlocks from rolling agility; warlocks also avoid armor penetration
        if playerClass == 5 and (statName == "Agility" or name:find("Agility", 1, true)) then return end
        if playerClass == 9 and (statName == "Agility" or name:find("Agility", 1, true)) then return end
        if playerClass == 9 and (statName == "Armor Penetration" or name:find("Armor Penetration", 1, true)) then return end
        if NO_OIL_CLASSES[playerClass] and isOil(id) then return end
        if (playerClass == 5 or playerClass == 8 or playerClass == 9) and isRockbiterOrVenomhide(id) then return end
        local w = baseWeight
        if caster then if itemClass == "WEAPON" and isOil(id) then w = w + CASTER_OIL_WEIGHT end; if isSPorInt(id) then w = w + CASTER_SP_INT_WEIGHT end end
        if (playerClass == 3 or playerClass == 4 or playerClass == 7) and statName == "Agility" then w = w + HUNTER_ROGUE_AGI_BONUS end
        if playerClass == 7 and statName == "Stamina" then w = w + HUNTER_ROGUE_AGI_BONUS end
        if playerClass == 1 and statName == "Strength" then w = w + WARRIOR_STR_BONUS end
        if playerClass == 3 and hasRangedAP(id) then w = w + HUNTER_RAP_BONUS end
        if spSynergyActive then if statName == "Intellect" or statName == "Spirit" or isSpellPower(id) then w = w * (1 + SPELLPOWER_SYNERGY_BONUS) end end
        if preferredStatKey then local k = (statName or ""):lower(); if k == preferredStatKey then w = w * (1 + SAME_STAT_SYNERGY_BONUS) end end
        if w > 0 then t_insert(pool, { id = id, w = w }); total = total + w end
    end

    local function add_from(classKey, t, baseWeight)
        local list = enchantCache[classKey] and enchantCache[classKey][t]
        if not list then return end
        for i=1,#list do consider(list[i], baseWeight) end
    end

    local function biased(base) if itemClass=="WEAPON" and weaponBiasProb and rollProb(weaponBiasProb) then return 3 end return base end

    add_from(itemClass,tier,biased(2)); add_from("ANY",tier,1)
    
    if tier >= 4 then
        local hasStamina = false
        for i=1,#pool do
            local stat = getParsedStat(pool[i].id)
            if stat == "Stamina" then hasStamina = true end
        end
        
        if not hasStamina then
            add_from(itemClass, 3, 1); add_from("ANY", 3, 1)
        end
    end

    pool.total = total
    return pool
end

local function pickWeighted(weighted)
    if not weighted or #weighted == 0 or not weighted.total or weighted.total <= 0 then 
        return nil 
    end
    
    for i = 1, #weighted do
        if not weighted[i] or not weighted[i].w or weighted[i].w <= 0 then
            print("WARNING: Invalid weight at index " .. i)
            return nil
        end
    end
    
    local r = m_random() * weighted.total
    local acc = 0
    for i = 1, #weighted do
        acc = acc + weighted[i].w
        if r <= acc then 
            return weighted[i].id 
        end
    end
    
    return weighted[#weighted].id
end

local function pickWithFloor(p, tier, weighted)
    if not weighted or #weighted==0 then return nil end
    for _=1,50 do
        local choice = pickWeighted(weighted)
        if not choice then return nil end
        local statName, val = getParsedStat(choice)
        if not statName or not val or val>=BL_getFloor(p,tier,statName) then return choice end
    end
    return pickWeighted(weighted)
end

local function levelToTier(level)
    if not level or level < 1 then return 1 end
    if level >= 80 then return 5 -- max-level characters should access tier 5 enchants
    elseif level >= 70 then return 4
    elseif level >= 60 then return 3
    elseif level >= 30 then return 2
    else return 1 end
end

local function RollEnchant(item, player, blacklist, weaponBiasProb, restrictKey)
    local tier = levelToTier(player:GetLevel())
    local pool = buildPool(item, player, blacklist, tier, weaponBiasProb, restrictKey)
    if not pool or pool.total<=0 then return nil end
    local id = pickWithFloor(player, tier, pool)
    if not id then return nil end
    local statName = getParsedStat(id)
    if statName then BL_inc(player, tier, statName) end
    return id
end


safeGetEnchantId = function(item, slot)
    if not item or not slot then return 0 end
    if item.GetEnchantmentId and type(item.GetEnchantmentId) == "function" then
        local success, result = pcall(item.GetEnchantmentId, item, slot)
        if success then return result or 0 end
    end
    return 0
end

safeSetEnchant = function(item, id, slot)
    if not item or not id or slot == nil then return false end
    if item.SetEnchantment and type(item.SetEnchantment) == "function" then
        local success, result = pcall(item.SetEnchantment, item, id, slot)
        if success then return result ~= false end
    end
    return false
end

local function ApplyEnchantsDirectly(item, player)
    seedRng()
    if not item or not player then 
        print("WARNING: ApplyEnchantsDirectly called with invalid parameters")
        return 0, {} 
    end
    
    local applied, appliedEnchants, descriptions = 0, {}, {}
    local isWeapon = (item:GetClass() == 2)
    local slotOrder = GetSlotOrder(player)
    
    for i = 1, #slotOrder do
        if applied >= 2 then break end
        local slotIndex = slotOrder[i] or WRITE_SLOTS_REFORGE[i]
        local attempt, maxAttempts = 0, 20
        local prefer = isWeapon and weaponBias(slotIndex) or nil
        local enchantId
        repeat 
            enchantId = RollEnchant(item, player, appliedEnchants, prefer)
            attempt = attempt + 1 
        until (enchantId and not appliedEnchants[enchantId]) or attempt >= maxAttempts
        
        if enchantId and not appliedEnchants[enchantId] and safeSetEnchant(item, enchantId, slotIndex) then
            appliedEnchants[enchantId] = true
            t_insert(descriptions, enchantNameCache[enchantId] or ("Unknown Enchant " .. enchantId))
            applied = applied + 1
        end
    end
    
    if SAVE_ITEM_IMMEDIATELY and applied > 0 and item.SaveToDB and type(item.SaveToDB) == "function" then 
        local success = pcall(item.SaveToDB, item)
        if not success then
            print("WARNING: Failed to save item to database")
        end
    end
    if applied > 0 then
        InvalidateStatCacheForItem(item)
    end
    return applied, descriptions
end

local function CollectTierStatEntries(item, player, statKey, tier)
    local pool = buildPool(item, player, {}, tier, nil, statKey)
    if not pool or #pool == 0 then return nil end
    local arr = {}
    for i = 1, #pool do
        local id = pool[i].id
        local _, val = getParsedStat(id)
        arr[#arr + 1] = { id = id, v = val or -1 }
    end
    table.sort(arr, function(a, b) return a.v > b.v end)
    return arr
end

local function TopEnchantsForStat(item, player, statKey, n)
    local maxTier = levelToTier(player:GetLevel())
    local out, used = {}, {}
    for tier = maxTier, 1, -1 do
        if #out >= n then break end
        local entries = CollectTierStatEntries(item, player, statKey, tier)
        if entries then
            for _, entry in ipairs(entries) do
                if not used[entry.id] then
                    t_insert(out, entry.id)
                    used[entry.id] = true
                    if #out >= n then break end
                end
            end
        end
    end
    return out
end

local function ApplyEnchantsDirectlyRestricted(item, player, statKey)
    seedRng()
    if not item or not player then return 0, {} end
    local ids = TopEnchantsForStat(item, player, statKey, 2)
    if #ids==0 then return 0, {} end
    local applied, descriptions = 0, {}
    local limit = math.min(2, #ids)
    if limit <= 0 then return 0, {} end
    local orderedIds = {}
    for idx = limit, 1, -1 do
        orderedIds[#orderedIds + 1] = ids[idx]
    end
    local slotOrder = GetSlotOrder(player)
    for i=1,limit do
        local slotIndex = slotOrder[i] or WRITE_SLOTS_REFORGE[i] or 0
        local enchantId = orderedIds[i]
        if enchantId and safeSetEnchant(item, enchantId, slotIndex) then
            t_insert(descriptions, enchantNameCache[enchantId] or "Unknown")
            applied = applied + 1
        end
    end
    if SAVE_ITEM_IMMEDIATELY and applied>0 and item.SaveToDB then item:SaveToDB() end
    if applied > 0 then
        InvalidateStatCacheForItem(item)
    end
    return applied, descriptions
end

local manualMode = {}
local pendingItem = {}
local pendingStats = {}

local function PlayerManual(p) local g=p:GetGUIDLow(); if manualMode[g]==nil then manualMode[g]=MANUAL_MODE_DEFAULT end return manualMode[g] end
local function ToggleManual(p) local g=p:GetGUIDLow(); manualMode[g]=not PlayerManual(p) end

local function BuildAvailableStats(item, player)
    local maxTier = levelToTier(player:GetLevel())
    local cacheKey = StatCacheKey(item, maxTier)
    if cacheKey and statMenuCache[cacheKey] then
        return CloneStatList(statMenuCache[cacheKey])
    end
    local uniq, list = {}, {}
    for tier = maxTier, 1, -1 do
        local pool = buildPool(item, player, {}, tier, nil, nil)
        if pool then
            for i=1,#pool do
                local id = pool[i].id
                local statName = getParsedStat(id)
                if statName then
                    local key = getStatKey(id)
                    if key and not uniq[key] then 
                        uniq[key] = getStatDisplayName(key, statName)
                        t_insert(list, key) 
                    end
                end
            end
        end
    end
    table.sort(list)
    local out = {}
    for i=1,#list do out[i] = { key=list[i], name=uniq[list[i]] } end
    if cacheKey then
        statMenuCache[cacheKey] = CloneStatList(out)
        cleanupCache(statMenuCache, CACHE_MAX_SIZE, CACHE_CLEANUP_SIZE)
    end
    return out
end

function Reforger_OnGossipHello(event, player, creature)
    if not EnsureReforgerReady(player) then
        player:GossipClearMenu()
        player:GossipMenuAddItem(0, "|cffff5555Reforger unavailable.|r", 7001, 0)
        player:GossipSendMenu(1, creature)
        return
    end
    local items = GetEligibleItems(player)
    player:GossipClearMenu()
    local modeTxt = PlayerManual(player) and "Manual Mode: On" or "Manual Mode: Off"
    player:GossipMenuAddItem(0, "|cff00c0ff"..modeTxt.."|r", 5000, 1)
    player:GossipMenuAddItem(0, SlotOrderLabel(player), 8000, 1)
    if #items==0 then SendYellowMessage(player, "You have no eligible equippable items."); player:GossipSendMenu(1, creature); return end
    local slotGroups = { Weapons={}, Armor={}, Accessories={}, Miscellaneous={} }
    for i=1,#items do local g=ClassifyItem(items[i]); slotGroups[g][#slotGroups[g]+1]=items[i] end
    local displayOrder = { "Weapons","Armor","Accessories","Miscellaneous" }
    for _, groupName in ipairs(displayOrder) do
        local groupItems = slotGroups[groupName]
        if #groupItems>0 then
            player:GossipMenuAddItem(9, "|cff000000["..groupName.."]|r", 9999, 0)
            for _, item in ipairs(groupItems) do
                local base = QUALITY_COST[item:GetQuality()] or 100000
                local cost = GetScaledCost(base, player:GetLevel())
                player:GossipMenuAddItem(0, "  "..item:GetItemLink().." - "..FormatGold(cost), 1, item:GetGUIDLow())
            end
        end
    end
    player:GossipSendMenu(1, creature)
end

local function OpenStatMenu(player, creature, item)
    local g = player:GetGUIDLow()
    pendingItem[g] = item:GetGUIDLow()
    local stats = BuildAvailableStats(item, player)
    pendingStats[g] = stats
    player:GossipClearMenu()
    player:GossipMenuAddItem(9, "|cff000000[Choose Stat]|r", 9999, 0)
    if #stats==0 then
        player:GossipMenuAddItem(0, "No applicable stats found", 7001, 0)
    else
        for i=1,#stats do
            local colored = STAT_COLORS[stats[i].name] or ("|cffffffff"..stats[i].name.."|r")
            player:GossipMenuAddItem(0, colored.." (best 2 rolls)", 6000, i)
        end
    end
    player:GossipMenuAddItem(0, "Back", 7000, 0)
    player:GossipSendMenu(1, creature)
end

function Reforger_OnGossipSelect(event, player, creature, sender, intid, code)
    if not EnsureReforgerReady(player) then
        player:GossipComplete()
        return
    end
    if sender==9999 then Reforger_OnGossipHello(nil, player, creature); return end
    if sender==5000 then ToggleManual(player); Reforger_OnGossipHello(nil, player, creature); return end
    if sender==8000 then ToggleSlotOrder(player); Reforger_OnGossipHello(nil, player, creature); return end
    if sender==7000 then Reforger_OnGossipHello(nil, player, creature); return end
    if sender==7001 then SendYellowMessage(player, "No valid stats."); Reforger_OnGossipHello(nil, player, creature); return end

    local manual = PlayerManual(player)

    if sender==1 then
        local pGUID = player:GetGUIDLow()
        local slotMap = playerEligibleMap[pGUID] or {}
        local slot = slotMap[intid]
        local selectedItem
        if slot then
            local it = player:GetItemByPos(255, slot)
            if it and it:GetGUIDLow()==intid and IsValidEquipable(it) then selectedItem = it end
        end
        if not selectedItem then for s=0,18 do local it=player:GetItemByPos(255,s); if it and it:GetGUIDLow()==intid and IsValidEquipable(it) then selectedItem=it; break end end end
        if not selectedItem then SendYellowMessage(player, "Item not found."); player:GossipComplete(); playerEligibleMap[pGUID]=nil; return end
        if (selectedItem.IsInTrade and selectedItem:IsInTrade()) or (selectedItem.IsBag and selectedItem:IsBag()) then SendYellowMessage(player, "That item cannot be reforged right now."); player:GossipComplete(); playerEligibleMap[pGUID]=nil; return end
        if manual then OpenStatMenu(player, creature, selectedItem); return end
        local base = QUALITY_COST[selectedItem:GetQuality()] or 100000
        local cost = GetScaledCost(base, player:GetLevel())
        if player:GetCoinage()<cost then SendYellowMessage(player, "You don't have enough gold."); player:GossipComplete(); playerEligibleMap[pGUID]=nil; return end
        player:ModifyMoney(-cost)
        local applied, descriptions = ApplyEnchantsDirectly(selectedItem, player)
        if applied==0 then player:ModifyMoney(cost); player:SendAreaTriggerMessage("Reforge failed: No enchantments applied."); player:GossipComplete(); playerEligibleMap[pGUID]=nil; return end
        for i=1,#descriptions do descriptions[i] = ColorizeEnchantment(descriptions[i]) end
        player:SendAreaTriggerMessage("Reforged: "..t_concat(descriptions, " | "))
        player:GossipComplete()
        playerEligibleMap[pGUID]=nil
        Reforger_OnGossipHello(nil, player, creature)
        return
    end

    if sender==6000 then
        local g = player:GetGUIDLow()
        local stats = pendingStats[g] or {}
        local sel = stats[intid]
        if not sel then SendYellowMessage(player, "Invalid stat."); Reforger_OnGossipHello(nil, player, creature); return end
        local itemGuid = pendingItem[g]
        local selectedItem
        for s=0,18 do local it=player:GetItemByPos(255,s); if it and it:GetGUIDLow()==itemGuid and IsValidEquipable(it) then selectedItem=it; break end end
        if not selectedItem then SendYellowMessage(player, "Item not found."); Reforger_OnGossipHello(nil, player, creature); return end
        local base = QUALITY_COST[selectedItem:GetQuality()] or 100000
        local cost = GetScaledCost(base, player:GetLevel())
        if player:GetCoinage()<cost then SendYellowMessage(player, "You don't have enough gold."); Reforger_OnGossipHello(nil, player, creature); return end
        player:ModifyMoney(-cost)
        local applied, descriptions = ApplyEnchantsDirectlyRestricted(selectedItem, player, sel.key)
        if applied==0 then player:ModifyMoney(cost); player:SendAreaTriggerMessage("Reforge failed: No enchantments applied."); Reforger_OnGossipHello(nil, player, creature); return end
        for i=1,#descriptions do descriptions[i] = ColorizeEnchantment(descriptions[i]) end
        player:SendAreaTriggerMessage("Reforged: "..t_concat(descriptions, " | "))
        pendingItem[g]=nil; pendingStats[g]=nil; playerEligibleMap[g]=nil
        Reforger_OnGossipHello(nil, player, creature)
        return
    end

    Reforger_OnGossipHello(nil, player, creature)
end

RegisterCreatureGossipEvent(NPC_ID, 1, Reforger_OnGossipHello)
RegisterCreatureGossipEvent(NPC_ID, 2, Reforger_OnGossipSelect)

local function ApplyRandomEnchantsOnAcquire(item, player, source, bypassBindingCheck)
    seedRng()
    if not ENABLE_RANDOM_ON_ACQUIRE or not item or not player or not IsValidEquipable(item) then return end
    if not bypassBindingCheck and not IsItemSoulboundOrBoP(item) then return end
    local applied, appliedEnchants = 0, {}
    local isWeapon = (item:GetClass() == 2)
    for i=1,#WRITE_SLOTS_ACQUIRE do
        if applied>=ACQ_MAX_SLOTS then break end
        local slotIndex = WRITE_SLOTS_ACQUIRE[i]
        if ACQ_ROLL_CHANCE_DENOM<=1 or m_random(1,ACQ_ROLL_CHANCE_DENOM)==1 then
            if not ACQ_SKIP_IF_HAS_ENCHANT or (safeGetEnchantId(item, slotIndex)==0) then
                local prefer = isWeapon and weaponBias(slotIndex) or nil
                local forbidFirstWeaponSlot = isWeapon and (i == 1)
                local slotBlacklist = appliedEnchants
                if forbidFirstWeaponSlot then
                    slotBlacklist = {}
                    for id,_ in pairs(appliedEnchants) do slotBlacklist[id] = true end
                end
                local enchantId
                for _=1,ACQ_ATTEMPTS_PER_SLOT do
                    enchantId = RollEnchant(item, player, slotBlacklist, prefer)
                    if forbidFirstWeaponSlot and enchantId and isWeaponTemporaryEnchant(enchantId) then
                        slotBlacklist[enchantId] = true
                        enchantId = nil
                    end
                    if enchantId and not appliedEnchants[enchantId] then break end
                end
                if enchantId and not appliedEnchants[enchantId] and safeSetEnchant(item, enchantId, slotIndex) then appliedEnchants[enchantId]=true; applied=applied+1 end
            end
        end
    end
    if SAVE_ITEM_IMMEDIATELY and applied>0 and item.SaveToDB then item:SaveToDB() end
end

local function OnLootItem(_, player, item, count) ApplyRandomEnchantsOnAcquire(item, player, "Looted") end
local function OnCreateItem(_, player, item, count) ApplyRandomEnchantsOnAcquire(item, player, "Crafted") end
local function OnQuestReward(_, player, item, count) ApplyRandomEnchantsOnAcquire(item, player, "Quest") end
local function OnStoreNewItem(_, player, item, count) ApplyRandomEnchantsOnAcquire(item, player, "Vendor") end
local function OnEquipItem(_, player, item, bag, slot)
    if not item or not player or not IsValidEquipable(item) then return end
    local bonding = item.GetBonding and item:GetBonding()
    if bonding ~= 2 then return end
    ApplyRandomEnchantsOnAcquire(item, player, "Equip", true)
end

RegisterPlayerEvent(32, OnLootItem)
RegisterPlayerEvent(52, OnCreateItem)
RegisterPlayerEvent(51, OnQuestReward)
RegisterPlayerEvent(53, OnStoreNewItem)
RegisterPlayerEvent(29, OnEquipItem)

--==========================================================
-- Manual .enchant command support
--==========================================================
local function ExtractItemDescriptor(arg)
    if not arg or arg == "" then return nil end
    local entry = arg:match("|Hitem:(%d+):")
    entry = entry and tonumber(entry)
    local name = arg:match("%[(.-)%]") or arg
    if entry then
        return { entry = entry, name = name }
    end
    if name and name ~= "" then
        return { name = name }
    end
    return nil
end

local function ItemMatchesDescriptor(item, descriptor)
    if not item or not descriptor then return false end
    if descriptor.entry and item:GetEntry() == descriptor.entry then
        return true
    end
    if descriptor.name then
        local link = item:GetItemLink()
        local itemName = link and link:match("%[(.-)%]") or (item.GetName and item:GetName()) or ""
        if itemName ~= "" and itemName:lower() == descriptor.name:lower() then
            return true
        end
    end
    return false
end

local function FindPlayerItem(player, descriptor)
    if not player or not descriptor then return nil end
    for slot = 0, 18 do
        local item = player:GetItemByPos(255, slot)
        if item and ItemMatchesDescriptor(item, descriptor) then
            return item
        end
    end
    for bag = 0, 4 do
        for slot = 0, BAG_MAX_SLOT do
            local item = player:GetItemByPos(bag, slot)
            if item and ItemMatchesDescriptor(item, descriptor) then
                return item
            end
        end
    end
    return nil
end

local function HandleEnchantCommand(player, rest)
    if not rest or rest == "" then
        SendError(player, "Usage: .enchant [itemLink] <enchantId> <slot>")
        return false
    end
    rest = rest:gsub("^%s+", ""):gsub("%s+$", "")
    local lowerRest = rest:lower()
    if lowerRest:sub(1,3) == "kit" and (rest:len() == 3 or rest:sub(4,4) == " ") then
        local kitArgs = rest:sub(4)
        return DefineEnchantKit(player, kitArgs)
    end
    if lowerRest:sub(1,3) == "all" and (rest:len() == 3 or rest:sub(4,4) == " ") then
        local kitIdStr = rest:match("^all%s+kit%s+(.+)$")
        if not kitIdStr then
            SendError(player, "Usage: .enchant all kit <kitName>")
            return false
        end
        kitIdStr = kitIdStr:gsub("^%s+", ""):gsub("%s+$", "")
        return ApplyKitToAllEquipped(player, kitIdStr)
    end
    local itemArg, remainder = SplitItemAndRemainder(rest)
    if not itemArg then
        SendError(player, "Unable to parse item link.")
        return false
    end
    itemArg = SanitizeItemArg(itemArg)
    local descriptor = ExtractItemDescriptor(itemArg)
    if not descriptor then
        SendError(player, "Unable to parse item link.")
        return false
    end
    remainder = remainder and remainder:gsub("^%s+", "") or ""
    local targetItem = FindPlayerItem(player, descriptor)
    if not targetItem then
        SendError(player, "Item not found in your equipment or bags.")
        return false
    end
    local kitMatch = remainder:match("^kit%s+(%S+)")
    if kitMatch then
        kitMatch = kitMatch:gsub("^%s+", ""):gsub("%s+$", "")
        ApplyEnchantKit(player, targetItem, kitMatch)
        return false
    end
    local trimmedToken = remainder:match("^(%S+)$")
    if trimmedToken and trimmedToken ~= "" then
        local normalized = NormalizeKitKey(trimmedToken)
        if normalized and ENCHANT_KITS[normalized] then
            ApplyEnchantKit(player, targetItem, trimmedToken)
            return false
        end
    end
    local enchantStr, slotStr = remainder:match("^(%d+)%s+(%d+)%s*$")
    if not enchantStr or not slotStr then
        SendError(player, "Usage: .enchant [itemLink] <enchantId> <slot>")
        return false
    end
    local enchantId = tonumber(enchantStr)
    local slotIndex = tonumber(slotStr)
    if not enchantId or enchantId <= 0 then
        SendError(player, "Invalid enchant ID.")
        return false
    end
    if slotIndex ~= 0 and slotIndex ~= 1 then
        SendError(player, "Slot must be 0 or 1.")
        return false
    end
    if not safeSetEnchant(targetItem, enchantId, slotIndex) then
        SendError(player, "Failed to apply enchantment.")
        return false
    end
    SendSuccess(player, string.format("Enchant %d applied to %s (slot %d).", enchantId, targetItem:GetItemLink() or "item", slotIndex))
    if SAVE_ITEM_IMMEDIATELY and targetItem.SaveToDB then targetItem:SaveToDB() end
    InvalidateStatCacheForItem(targetItem)
    return false
end

local function OnReforgerCommand(event, player, command)
    if not command or command == "" then return end
    local trimmed = command
    if trimmed:sub(1,1) == "." then trimmed = trimmed:sub(2) end
    trimmed = trimmed:match("^%s*(.-)%s*$")
    if not trimmed or trimmed == "" then return end
    local cmd, rest = trimmed:match("^(%S+)%s*(.*)$")
    if not cmd then return end
    local lowerCmd = cmd:lower()
    if lowerCmd ~= "enchant" and lowerCmd ~= "clearkit" then return end
    if not player:IsGM() then
        player:SendBroadcastMessage("|cffff5555You do not have permission to use ."..cmd.."|r")
        return false
    end
    if lowerCmd == "enchant" then
        if not EnsureReforgerReady(player) then
            return false
        end
        return HandleEnchantCommand(player, rest)
    elseif lowerCmd == "clearkit" then
        return HandleClearKitCommand(player, rest)
    end
end

local function OnEnchantHelpCommand(event, player, command)
    if not command or command == "" then return end
    local trimmed = command
    if trimmed:sub(1,1) == "." then trimmed = trimmed:sub(2) end
    trimmed = trimmed:match("^%s*(.-)%s*$")
    if not trimmed or trimmed == "" then return end
    local cmd = trimmed:lower()
    if cmd ~= "enchanthelp" and cmd ~= "enchantinghelp" then return end
    ShowEnchantHelp(player)
    return false
end

local function OnKitListCommand(event, player, command)
    if not command or command == "" then return end
    local trimmed = command
    if trimmed:sub(1,1) == "." then trimmed = trimmed:sub(2) end
    trimmed = trimmed:match("^%s*(.-)%s*$")
    if not trimmed or trimmed == "" then return end
    if trimmed:lower() ~= "kitlist" then return end
    ShowKitList(player)
    return false
end

RegisterPlayerEvent(42, OnReforgerCommand)
RegisterPlayerEvent(42, OnEnchantHelpCommand)
RegisterPlayerEvent(42, OnKitListCommand)
HandleClearKitCommand = function(player, rest)
    rest = rest and rest:gsub("^%s+", ""):gsub("%s+$", "") or ""
    if rest == "" then
        SendError(player, "Usage: .clearkit <kitName|all>")
        return false
    end
    local lower = rest:lower()
    local guid = player:GetGUIDLow()
    if lower == "all" then
        ENCHANT_KIT_CLEAR_PENDING[guid] = { ts = os.time() }
        SendYellowMessage(player, "Type '.clearkit all confirm' within 10 seconds to clear every kit.")
        return false
    elseif lower == "all confirm" then
        local pending = ENCHANT_KIT_CLEAR_PENDING[guid]
        if pending and os.time() - pending.ts <= CLEAR_KIT_CONFIRM_TIMEOUT then
            ENCHANT_KIT_CLEAR_PENDING[guid] = nil
            ENCHANT_KITS = {}
            ENCHANT_KIT_LABELS = {}
            DeleteAllKitsFromDB()
            SendSuccess(player, "All kits cleared.")
        else
            ENCHANT_KIT_CLEAR_PENDING[guid] = nil
            SendError(player, "No pending confirmation. Use .clearkit all first.")
        end
        return false
    end
    if lower == RESERVED_KIT_NAME then
        SendError(player, "Kit name 'all' is reserved.")
        return false
    end
    local kitKey = NormalizeKitKey(rest)
    if not kitKey or not ENCHANT_KITS[kitKey] then
        SendError(player, "Unknown kit: "..rest)
        return false
    end
    ENCHANT_KITS[kitKey] = nil
    ENCHANT_KIT_LABELS[kitKey] = nil
    DeleteKitFromDB(kitKey)
    SendSuccess(player, string.format("Cleared kit %s.", rest))
    return false
end

-- Final initialization for kit persistence
EnsureKitTable()
if KIT_TABLE_READY then
    LoadKitsFromDB()
else
    print("[Reforger] Kit persistence disabled; table creation failed.")
end
