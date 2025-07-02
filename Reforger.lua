print("[Reforger] Loaded successfully.")

local NPC_ID = 200004

local QUALITY_COST = {
    [0] = 10000,
    [1] = 20000,
    [2] = 50000,
    [3] = 100000,
    [4] = 250000,
    [5] = 1000000
}

local EXCLUDED_IDS = {
    [4499]=true,[5571]=true,[5572]=true,[805]=true,[828]=true,[856]=true,[918]=true,[1939]=true,
    [4245]=true,[5764]=true,[5765]=true,[14155]=true,[14156]=true,[17966]=true,[19291]=true,
    [21841]=true,[41599]=true,[41729]=true,[43345]=true,[43575]=true,[43958]=true,[44751]=true,
    [45854]=true,[49295]=true,[38346]=true,[38347]=true,[38348]=true,[38349]=true,[39489]=true,
    [41600]=true,[34845]=true,[38225]=true,[20400]=true,[22243]=true,[22244]=true,[44447]=true
}

local function IsValidEquipable(item)
    if not item then return false end
    if EXCLUDED_IDS[item:GetEntry()] then return false end
    local class = item:GetClass()
    local invType = item:GetInventoryType()
    return (class == 2 or class == 4) and (invType > 0 and invType < 24 or invType == 25 or invType == 26 or invType == 28)
end

local function FormatGold(cost)
    local gold = math.floor(cost / 10000)
    local silver = math.floor((cost % 10000) / 100)
    local copper = cost % 100
    local parts = {}
    if gold > 0 then table.insert(parts, string.format("|cffffd700%dg|r", gold)) end
    if silver > 0 then table.insert(parts, string.format("|cffc7c7cf%ds|r", silver)) end
    if copper > 0 then table.insert(parts, string.format("|cffeda55f%dc|r", copper)) end
    return table.concat(parts, " ")
end

local function SendYellowMessage(player, message)
    player:SendBroadcastMessage("|cffffff00" .. message .. "|r")
end

local function GetEligibleItems(player)
    local items = {}
    for slot = 0, 18 do
        local item = player:GetItemByPos(255, slot)
        if item and IsValidEquipable(item) then
            table.insert(items, item)
        end
    end
    return items
end

local function ClassifyItem(item)
    local invType = item:GetInventoryType()
    if invType == 13 or invType == 14 or invType == 15 or invType == 17 or invType == 21 or invType == 23 then
        return "Weapons"
    elseif invType == 25 or invType == 26 or invType == 28 then
        return "Accessories"
    elseif invType == 1 or invType == 3 or invType == 5 or invType == 6 or invType == 7
        or invType == 8 or invType == 9 or invType == 10 or invType == 16 then
        return "Armor"
    elseif invType == 2 or invType == 11 or invType == 12 then
        return "Accessories"
    else
        return "Miscellaneous"
    end
end

local RANGED_AP_IDS = {
    [2047]=true,[2048]=true,[2049]=true,[2050]=true,[2051]=true,[2052]=true,[2053]=true,
    [2054]=true,[2055]=true,[2056]=true,[2057]=true,[2058]=true,[2059]=true,[2060]=true,
    [2061]=true,[2062]=true,[2064]=true,[2065]=true,[2066]=true,[2067]=true,[2068]=true,
    [2069]=true,[2070]=true,[2071]=true,[2072]=true,[2073]=true,[2074]=true
}

local function RollEnchant(item, player, blacklist)
    local itemClass = item:GetClass() == 2 and "WEAPON" or item:GetClass() == 4 and "ARMOR" or "ANY"
    local tier = player:GetLevel() >= 80 and 5 or player:GetLevel() >= 70 and 4 or player:GetLevel() >= 60 and 3 or player:GetLevel() >= 40 and 2 or 1

    local preferWeapon = (itemClass == "WEAPON") and (math.random(100) <= 10)

    local baseQuery

    if itemClass == "WEAPON" then
        if preferWeapon then
            baseQuery = "SELECT enchantID FROM item_enchantment_random_tiers WHERE tier <= "..tier.." AND class = 'WEAPON'"
        else
            baseQuery = "SELECT enchantID FROM item_enchantment_random_tiers WHERE tier <= "..tier.." AND (class = 'WEAPON' OR class = 'ANY')"
        end
    else
        baseQuery = "SELECT enchantID FROM item_enchantment_random_tiers WHERE tier = "..tier.." AND (class = '"..itemClass.."' OR class = 'ANY')"
    end

    local query = WorldDBQuery(baseQuery .. " ORDER BY RAND()")
    if not query then return nil end

    repeat
        local enchantId = query:GetUInt32(0)
        if not blacklist[enchantId] then
            if RANGED_AP_IDS[enchantId] and player:GetClass() ~= 4 then
            else
                return enchantId
            end
        end
    until not query:NextRow()

    return nil
end

function Reforger_OnGossipHello(event, player, creature)
    local items = GetEligibleItems(player)
    player:GossipClearMenu()

    if #items == 0 then
        SendYellowMessage(player, "You have no eligible equippable items.")
        player:GossipComplete()
        return
    end

    local slotGroups = {
        Weapons = {},
        Armor = {},
        Accessories = {},
        Miscellaneous = {}
    }

    for _, item in ipairs(items) do
        local group = ClassifyItem(item)
        table.insert(slotGroups[group], item)
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

    local selectedItem
    local equipSlot
    local itemGUID = intid

    for slot = 0, 18 do
        local item = player:GetItemByPos(255, slot)
        if item and item:GetGUIDLow() == itemGUID and IsValidEquipable(item) then
            selectedItem = item
            equipSlot = slot
            break
        end
    end

    if not selectedItem then
        SendYellowMessage(player, "Item not found.")
        player:GossipComplete()
        return
    end

    local entry = selectedItem:GetEntry()
    local quality = selectedItem:GetQuality()
    local cost = QUALITY_COST[quality] or 100000

    if player:GetItemCount(entry) < 1 then
        SendYellowMessage(player, "You no longer have the item.")
        player:GossipComplete()
        return
    end

    if player:GetCoinage() < cost then
        SendYellowMessage(player, "You don't have enough gold.")
        player:GossipComplete()
        return
    end

    player:RemoveItem(entry, 1)

    local newItem = player:AddItem(entry, 1)
    if not newItem then
        player:AddItem(entry, 1)
        SendYellowMessage(player, "Failed to return reforged item.")
        player:GossipComplete()
        return
    end

    local applied = 0
    local appliedEnchants = {}

    for slotIndex = 0, 2 do
        if applied < 2 and math.random(5) >= 1 then
            local attempt = 0
            local maxAttempts = 10
            local enchantId

            repeat
                enchantId = RollEnchant(newItem, player, appliedEnchants)
                attempt = attempt + 1
            until (enchantId and not appliedEnchants[enchantId]) or attempt >= maxAttempts

            if enchantId and not appliedEnchants[enchantId] then
                newItem:SetEnchantment(enchantId, slotIndex)
                appliedEnchants[enchantId] = true
                applied = applied + 1
            end
        end
    end

    player:ModifyMoney(-cost)

    if equipSlot then
        player:EquipItem(newItem, equipSlot)
    end

    SendYellowMessage(player, "Item reforged with new enchantments!")
    Reforger_OnGossipHello(nil, player, creature)
end

RegisterCreatureGossipEvent(NPC_ID, 1, Reforger_OnGossipHello)
RegisterCreatureGossipEvent(NPC_ID, 2, Reforger_OnGossipSelect)
