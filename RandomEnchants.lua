local RANGED_AP_IDS = {
    [2047]=true, [2048]=true, [2049]=true, [2050]=true, [2051]=true, [2052]=true, [2053]=true,
    [2054]=true, [2055]=true, [2056]=true, [2057]=true, [2058]=true, [2059]=true, [2060]=true,
    [2061]=true, [2062]=true, [2064]=true, [2065]=true, [2066]=true, [2067]=true, [2068]=true,
    [2069]=true, [2070]=true, [2071]=true, [2072]=true, [2073]=true, [2074]=true
}

local function RollEnchant(item, player, blacklist)
    if not item or not player then return nil end

    local itemClassId = item:GetClass()
    local itemClass   = (itemClassId == 2 and "WEAPON")
                     or (itemClassId == 4 and "ARMOR")
                     or "ANY"

    local level = player:GetLevel()
    local tier  = (level >= 80 and 5)
               or (level >= 70 and 4)
               or (level >= 60 and 3)
               or (level >= 30 and 2)
               or 1

    local tierSQL = (tier == 5) and "tier IN (4,5)" or ("tier = "..tier)
    local preferWeapon = (itemClass == "WEAPON") and (math.random(100) <= 10)

    local classSQL
    if itemClass == "WEAPON" then
        classSQL = preferWeapon and "class = 'WEAPON'"
                              or  "class IN ('WEAPON','ANY')"
    else
        classSQL = string.format("class IN ('%s','ANY')", itemClass)
    end

    local query = string.format(
        "SELECT enchantID FROM item_enchantment_random_tiers " ..
        "WHERE %s AND %s ORDER BY RAND()",
        tierSQL, classSQL)

    local res = WorldDBQuery(query)
    if not res then return nil end

    repeat
        local id = res:GetUInt32(0)
        if not blacklist[id] then
            if not RANGED_AP_IDS[id] or player:GetClass() == 4 then
                return id
            end
        end
    until not res:NextRow()

    return nil
end

local function DoEnchantOnItem(item, player)
    if not item or not player then return end
    if item:GetInventoryType() == 0 then return end

    if item:GetQuality() < 2 then return end

    local applied = 0
    local appliedEnchants = {}
    local maxAttempts = 5

    for slot = 0, 2 do
        if applied >= 2 then break end
        if math.random(5) < 1 then
        else
            local enchantId
            for _ = 1, maxAttempts do
                enchantId = RollEnchant(item, player, appliedEnchants)
                if enchantId and not appliedEnchants[enchantId] then
                    break
                end
            end
            if enchantId and not appliedEnchants[enchantId] then
                item:SetEnchantment(enchantId, slot)
                appliedEnchants[enchantId] = true
                applied = applied + 1
            end
        end
    end
end


local function OnLootItem(event, player, item, count)
    if not player or not item then return end
    DoEnchantOnItem(item, player)
end

RegisterPlayerEvent(32, OnLootItem)
