local ENABLE_RANDOM_ON_ACQUIRE = true

local NPC_ID = 200004
local QUALITY_COST = {
    [0] = 10000,
    [1] = 20000,
    [2] = 50000,
    [3] = 100000,
    [4] = 250000,
    [5] = 1000000,
}

local ALLOWED_IDS = {
    [18706] = true
}

local EXCLUDED_IDS = {
    [4499]=true,[5571]=true,[5572]=true,[805]=true,[828]=true,[856]=true,[918]=true,[1939]=true,
    [4245]=true,[5764]=true,[5765]=true,[14155]=true,[14156]=true,[17966]=true,[19291]=true,
    [21841]=true,[41599]=true,[41729]=true,[43345]=true,[43575]=true,[43958]=true,[44751]=true,
    [45854]=true,[49295]=true,[38346]=true,[38347]=true,[38348]=true,[38349]=true,[39489]=true,
    [41600]=true,[34845]=true,[38225]=true,[20400]=true,[22243]=true,[22244]=true,[44447]=true
}

local STAT_COLORS = {
    ["Agility"]             = "|cff00ff00Agility|r",
    ["Strength"]            = "|cffff0000Strength|r",
    ["Stamina"]             = "|cffffffffStamina|r",
    ["Spirit"]              = "|cffff00ffSpirit|r",
    ["Intellect"]           = "|cff00ffffIntellect|r",
    ["Attack Power"]        = "|cff00ff00Attack Power|r",
    ["Spell Power"]         = "|cffff7f00Spell Power|r",
    ["Crit"]                = "|cffffff00Crit|r",
    ["Haste"]               = "|cffffcc00Haste|r",
    ["Hit"]                 = "|cff9999ffHit|r",
    ["Resilience"]          = "|cffff66ffResilience|r",
    ["Dodge"]               = "|cffffcc99Dodge|r",
    ["Parry"]               = "|cffffcc99Parry|r",
    ["Block"]               = "|cffffcc99Block|r",
    ["Armor Penetration"]   = "|cffff9999Armor Penetration|r",
    ["Expertise"]           = "|cffdd8800Expertise|r"
}

local RANGED_AP_IDS = {
    [2047]=true,[2048]=true,[2049]=true,[2050]=true,[2051]=true,[2052]=true,[2053]=true,
    [2054]=true,[2055]=true,[2056]=true,[2057]=true,[2058]=true,[2059]=true,[2060]=true,
    [2061]=true,[2062]=true,[2064]=true,[2065]=true,[2066]=true,[2067]=true,[2068]=true,
    [2069]=true,[2070]=true,[2071]=true,[2072]=true,[2073]=true,[2074]=true
}

local OIL_IDS = {
    [2603]=true,[2604]=true,[2605]=true,[2606]=true,[2607]=true
}

local STRENGTH_BLOCK_CLASSES = { [3]=true,[4]=true,[5]=true,[7]=true,[8]=true,[9]=true }
local CASTER_BLOCK_CLASSES   = { [1]=true,[4]=true,[6]=true }

local WEAPON_BIAS_SLOT1 = 0.4
local WEAPON_BIAS_SLOT2 = 0.7
local CASTER_OIL_WEIGHT = 3
local CASTER_SP_INT_WEIGHT = 2
local HUNTER_ROGUE_AGI_BONUS = 3
local WARRIOR_STR_BONUS = 2
local ACQ_MAX_SLOTS = 2
local ACQ_ATTEMPTS_PER_SLOT = 8
local ACQ_ROLL_CHANCE_DENOM = 1
local ACQ_SKIP_IF_HAS_ENCHANT = true

local t_insert, t_concat = table.insert, table.concat
local m_random = math.random
local s_format = string.format

local enchantCache = { ANY = {}, WEAPON = {}, ARMOR = {} }
local enchantNameCache = {}
local parsedStatCache = {}
local playerEligibleMap = {}
local colorizedCache = {}

local bl = {}
local function BL(p)
    local g = p:GetGUIDLow()
    bl[g] = bl[g] or { tiers = {} }
    return bl[g]
end
local function BL_getFloor(p, tier, stat)
    local s = BL(p)
    local t = s.tiers
    t[tier] = t[tier] or {}
    local c = t[tier][stat] or 0
    if c >= 6 then return 18 end
    if c >= 3 then return 16 end
    return 0
end
local function BL_inc(p, tier, stat)
    local s = BL(p)
    local t = s.tiers
    t[tier] = t[tier] or {}
    t[tier][stat] = (t[tier][stat] or 0) + 1
    for k,_ in pairs(t[tier]) do
        if k ~= stat then t[tier][k] = 0 end
    end
end

local function parseStatValue(name)
    if not name then return nil,nil end
    local num, rest = name:match("([%+%-]?%d+)%s+(.+)")
    if not num or not rest then return nil,nil end
    local v = tonumber(num); if not v then return nil,nil end
    rest = rest:gsub("^%s+",""):gsub("%s+$","")
    return rest, v
end

local function getParsedStat(id)
    local cached = parsedStatCache[id]
    if cached ~= nil then return cached.name, cached.val end
    local name = enchantNameCache[id]
    if not name then
        parsedStatCache[id] = { name=nil, val=nil }
        return nil,nil
    end
    local stat, val = parseStatValue(name)
    parsedStatCache[id] = { name=stat, val=val }
    return stat, val
end

local function LoadEnchantCache()
    local q = WorldDBQuery("SELECT enchantID, tier, class, comment FROM item_enchantment_random_tiers")
    if not q then return end
    repeat
        local id = q:GetUInt32(0)
        local t  = q:GetUInt8(1)
        local c  = q:GetString(2)
        local comment = q:GetString(3)
        local C = enchantCache[c] or enchantCache.ANY
        C[t] = C[t] or {}
        t_insert(C[t], id)
        enchantNameCache[id] = comment
    until not q:NextRow()
end
LoadEnchantCache()

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

local function FormatGold(cost)
    local g = math.floor(cost / 10000)
    local s = math.floor((cost % 10000) / 100)
    local c = cost % 100
    local parts = {}
    if g > 0 then t_insert(parts, s_format("|cffffd700%dg|r", g)) end
    if s > 0 then t_insert(parts, s_format("|cffc7c7cf%ds|r", s)) end
    if c > 0 then t_insert(parts, s_format("|cffeda55f%dc|r", c)) end
    return t_concat(parts, " ")
end

local function SendYellowMessage(player, message)
    player:SendBroadcastMessage("|cffffff00" .. message .. "|r")
end

local function GetEligibleItems(player)
    local items, slotMap = {}, {}
    for slot = 0, 18 do
        local item = player:GetItemByPos(255, slot)
        if item and IsValidEquipable(item) then
            t_insert(items, item)
            slotMap[item:GetGUIDLow()] = slot
        end
    end
    playerEligibleMap[player:GetGUIDLow()] = slotMap
    return items
end

local function ClassifyItem(item)
    local invType = item:GetInventoryType()
    if invType == 13 or invType == 14 or invType == 15 or invType == 17 or invType == 18 or invType == 21 or invType == 23 or invType == 26 then
        return "Weapons"
    elseif invType == 25 or invType == 28 then
        return "Accessories"
    elseif invType == 1 or invType == 3 or invType == 5 or invType == 6 or invType == 7 or invType == 8 or invType == 9 or invType == 10 or invType == 16 then
        return "Armor"
    elseif invType == 2 or invType == 11 or invType == 12 then
        return "Accessories"
    else
        return "Miscellaneous"
    end
end

local function GetEnchantName(enchantId)
    return enchantNameCache[enchantId] or "Unknown"
end

local STAT_COLORS_LC = {}
for k,v in pairs(STAT_COLORS) do STAT_COLORS_LC[k:lower()] = v end

local function ColorizeEnchantment(desc)
    local cached = colorizedCache[desc]; if cached then return cached end
    desc = desc:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    local out = desc:gsub("([%+%-]?)(%d+)%s+([%w%s%p]-)$", function(sign, number, statName)
        statName = statName:match("^%s*(.-)%s*$")
        local coloredSign = (sign ~= "" and "|cffffff00"..sign.."|r") or ""
        local coloredNumber = "|cff00ff00"..number.."|r"
        local color = STAT_COLORS_LC[statName:lower()] or ("|cffffffff"..statName.."|r")
        return coloredSign .. coloredNumber .. " " .. color
    end)
    colorizedCache[desc] = out
    return out
end

local function isCaster(p)
    local c = p:GetClass()
    return c == 8 or c == 5 or c == 9
end

local function isOil(id) return OIL_IDS[id] == true end

local _isSPorIntCache = {}
local function isSPorInt(id)
    local v = _isSPorIntCache[id]
    if v ~= nil then return v end
    local n = enchantNameCache[id]
    v = n and (n:find("Spell Power", 1, true) or n:find("Intellect", 1, true)) and true or false
    _isSPorIntCache[id] = v
    return v
end

local function weaponBias(slotIndex)
    if slotIndex == 0 then return WEAPON_BIAS_SLOT1 end
    if slotIndex == 1 then return WEAPON_BIAS_SLOT2 end
    return WEAPON_BIAS_SLOT2
end

local function rollProb(p)
    return m_random(0,10000) <= math.floor(p*10000)
end

local function buildPool(item, player, blacklist, tier, weaponBiasProb)
    local itemClass = item:GetClass() == 2 and "WEAPON" or item:GetClass() == 4 and "ARMOR" or "ANY"
    local caster = isCaster(player)
    local playerClass = player:GetClass()
    local pool, total = {}, 0

    local function add_from(classKey, t, baseWeight)
        local list = enchantCache[classKey] and enchantCache[classKey][t]
        if not list then return end
        for i = 1, #list do
            local id = list[i]
            if not blacklist[id] and not (RANGED_AP_IDS[id] and playerClass ~= 3) then
                local statName = getParsedStat(id)
                if not (statName == "Strength" and STRENGTH_BLOCK_CLASSES[playerClass]) and
                   not ((statName == "Intellect" or statName == "Spell Power") and CASTER_BLOCK_CLASSES[playerClass]) then
                    local w = baseWeight
                    if caster then
                        if itemClass == "WEAPON" and isOil(id) then w = w + CASTER_OIL_WEIGHT end
                        if isSPorInt(id) then w = w + CASTER_SP_INT_WEIGHT end
                    end
                    if (playerClass == 3 or playerClass == 4) and statName == "Agility" then w = w + HUNTER_ROGUE_AGI_BONUS end
                    if playerClass == 1 and statName == "Strength" then w = w + WARRIOR_STR_BONUS end
                    if w > 0 then t_insert(pool, { id = id, w = w }); total = total + w end
                end
            end
        end
    end

    local function biased(base)
        if itemClass == "WEAPON" and weaponBiasProb and rollProb(weaponBiasProb) then return 3 end
        return base
    end

    if tier == 5 then
        add_from(itemClass, 4, biased(2)); add_from("ANY", 4, 1)
        add_from(itemClass, 5, biased(2)); add_from("ANY", 5, 1)
    else
        add_from(itemClass, tier, biased(2)); add_from("ANY", tier, 1)
    end

    pool.total = total
    return pool
end

local function pickWeighted(weighted)
    if not weighted or #weighted == 0 or not weighted.total or weighted.total <= 0 then return nil end
    local r, acc = m_random() * weighted.total, 0
    for i = 1, #weighted do
        acc = acc + weighted[i].w
        if r <= acc then return weighted[i].id end
    end
    return weighted[#weighted].id
end

local function pickWithFloor(p, tier, weighted)
    if not weighted or (#weighted == 0) then return nil end
    local tries = 50
    repeat
        local choice = pickWeighted(weighted)
        if not choice then return nil end
        local statName, val = getParsedStat(choice)
        if not statName or not val then return choice end
        if val >= BL_getFloor(p, tier, statName) then return choice end
        tries = tries - 1
    until tries <= 0
    return pickWeighted(weighted)
end

local function RollEnchant(item, player, blacklist, weaponBiasProb)
    local level = player:GetLevel()
    local tier = (level >= 80 and 5)
             or (level >= 70 and 4)
             or (level >= 60 and 3)
             or (level >= 30 and 2)
             or 1
    local pool = buildPool(item, player, blacklist, tier, weaponBiasProb)
    local id = pickWithFloor(player, tier, pool)
    if not id then return nil end
    local statName = getParsedStat(id)
    if statName then BL_inc(player, tier, statName) end
    return id
end

local function safeGetEnchantId(item, slot)
    return (item and item.GetEnchantmentId and type(item.GetEnchantmentId)=="function") and item:GetEnchantmentId(slot) or 0
end
local function safeSetEnchant(item, id, slot)
    if item and item.SetEnchantment and type(item.SetEnchantment)=="function" then
        item:SetEnchantment(id, slot)
        return true
    end
    return false
end

local function ApplyEnchantsDirectly(item, player)
    if not item or not player then return 0, {} end
    local applied, appliedEnchants, appliedDescriptions = 0, {}, {}
    local isWeapon = item:GetClass() == 2
    for slotIndex = 0, 2 do
        if applied >= 2 then break end
        local attempt, maxAttempts = 0, 20
        local prefer = isWeapon and weaponBias(slotIndex) or nil
        local enchantId
        repeat
            enchantId = RollEnchant(item, player, appliedEnchants, prefer)
            attempt = attempt + 1
        until (enchantId and not appliedEnchants[enchantId]) or attempt >= maxAttempts
        if enchantId and not appliedEnchants[enchantId] and safeSetEnchant(item, enchantId, slotIndex) then
            appliedEnchants[enchantId] = true
            t_insert(appliedDescriptions, GetEnchantName(enchantId))
            applied = applied + 1
        end
    end
    return applied, appliedDescriptions
end

function Reforger_OnGossipHello(event, player, creature)
    local items = GetEligibleItems(player)
    player:GossipClearMenu()
    if #items == 0 then
        SendYellowMessage(player, "You have no eligible equippable items.")
        player:GossipComplete()
        return
    end
    local slotGroups = { Weapons = {}, Armor = {}, Accessories = {}, Miscellaneous = {} }
    for i = 1, #items do
        t_insert(slotGroups[ClassifyItem(items[i])], items[i])
    end
    local displayOrder = { "Weapons", "Armor", "Accessories", "Miscellaneous" }
    local intid_counter = 1
    for _, groupName in ipairs(displayOrder) do
        local groupItems = slotGroups[groupName]
        if #groupItems > 0 then
            player:GossipMenuAddItem(9, "|cff000000[" .. groupName .. "]|r", 9999, 0)
            for _, item in ipairs(groupItems) do
                local cost = QUALITY_COST[item:GetQuality()] or 100000
                player:GossipMenuAddItem(0, "  " .. item:GetItemLink() .. " - " .. FormatGold(cost), intid_counter, item:GetGUIDLow())
                intid_counter = intid_counter + 1
            end
        end
    end
    player:GossipSendMenu(1, creature)
end

function Reforger_OnGossipSelect(event, player, creature, sender, intid, code)
    if sender == 9999 then
        Reforger_OnGossipHello(nil, player, creature)
        return
    end
    if type(intid) ~= "number" then
        SendYellowMessage(player, "Invalid selection.")
        player:GossipComplete()
        playerEligibleMap[player:GetGUIDLow()] = nil
        return
    end

    local selectedItem
    local itemGUID = intid
    local pGUID = player:GetGUIDLow()
    local slotMap = playerEligibleMap[pGUID]
    if slotMap and slotMap[itemGUID] then
        local slot = slotMap[itemGUID]
        local item = player:GetItemByPos(255, slot)
        if item and item:GetGUIDLow() == itemGUID and IsValidEquipable(item) then
            selectedItem = item
        end
    end
    if not selectedItem then
        for slot = 0, 18 do
            local item = player:GetItemByPos(255, slot)
            if item and item:GetGUIDLow() == itemGUID and IsValidEquipable(item) then
                selectedItem = item
                break
            end
        end
    end
    if not selectedItem then
        SendYellowMessage(player, "Item not found.")
        player:GossipComplete()
        playerEligibleMap[pGUID] = nil
        return
    end
    local quality = selectedItem:GetQuality()
    local cost = QUALITY_COST[quality] or 100000

    local applied, descriptions = ApplyEnchantsDirectly(selectedItem, player)
    if applied == 0 then
        player:SendAreaTriggerMessage("Reforge failed: No enchantments applied.")
        player:GossipComplete()
        playerEligibleMap[pGUID] = nil
        return
    end
    if player:GetCoinage() < cost then
        SendYellowMessage(player, "You don't have enough gold.")
        player:GossipComplete()
        playerEligibleMap[pGUID] = nil
        return
    end

    player:ModifyMoney(-cost)
    local lines = {}
    for i = 1, #descriptions do
        lines[i] = ColorizeEnchantment(descriptions[i])
    end
    player:SendAreaTriggerMessage("Reforged: " .. t_concat(lines, " | "))
    player:GossipComplete()
    playerEligibleMap[pGUID] = nil
    Reforger_OnGossipHello(nil, player, creature)
end

RegisterCreatureGossipEvent(NPC_ID, 1, Reforger_OnGossipHello)
RegisterCreatureGossipEvent(NPC_ID, 2, Reforger_OnGossipSelect)

local function ApplyRandomEnchantsOnAcquire(item, player, source)
    if not ENABLE_RANDOM_ON_ACQUIRE then return end
    if not item or not player then return end
    if not IsValidEquipable(item) then return end

    local applied = 0
    local appliedEnchants = {}

    for slotIndex = 0, 2 do
        if applied >= ACQ_MAX_SLOTS then break end
        if (ACQ_ROLL_CHANCE_DENOM <= 1) or (m_random(1, ACQ_ROLL_CHANCE_DENOM) == 1) then
            if not ACQ_SKIP_IF_HAS_ENCHANT or (safeGetEnchantId(item, slotIndex) == 0) then
                local prefer = (item:GetClass() == 2) and weaponBias(slotIndex) or nil
                local enchantId
                for _ = 1, ACQ_ATTEMPTS_PER_SLOT do
                    enchantId = RollEnchant(item, player, appliedEnchants, prefer)
                    if enchantId and not appliedEnchants[enchantId] then break end
                end
                if enchantId and not appliedEnchants[enchantId] and safeSetEnchant(item, enchantId, slotIndex) then
                    appliedEnchants[enchantId] = true
                    applied = applied + 1
                end
            end
        end
    end
end

local function OnLootItem(_, player, item, count)
    ApplyRandomEnchantsOnAcquire(item, player, "Looted")
end
local function OnCreateItem(_, player, item, count)
    ApplyRandomEnchantsOnAcquire(item, player, "Crafted")
end
local function OnQuestReward(_, player, item, count)
    ApplyRandomEnchantsOnAcquire(item, player, "Quest")
end

RegisterPlayerEvent(32, OnLootItem)
RegisterPlayerEvent(52, OnCreateItem)
RegisterPlayerEvent(51, OnQuestReward)
