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
    return (class == 2 or class == 4) and invType > 0 and invType < 24
end

local function RollEnchant(item)
    local itemClass = "ANY"
    if item:GetClass() == 2 then
        itemClass = "WEAPON"
    elseif item:GetClass() == 4 then
        itemClass = "ARMOR"
    end
    local query = WorldDBQuery("SELECT enchantID FROM item_enchantment_random_tiers WHERE tier=1 AND (exclusiveSubClass=1 AND class='" .. itemClass .. "' OR exclusiveSubClass=" .. item:GetSubClass() .. " OR class='ANY') ORDER BY RAND() LIMIT 1")
    if query then
        return query:GetUInt32(0)
    end
    return nil
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

local function ClassifyItem(item)
    local invType = item:GetInventoryType()
    if invType == 13 or invType == 14 or invType == 15 or invType == 17 or invType == 21 or invType == 23 then
        return "Weapons"
    elseif invType == 1 or invType == 3 or invType == 5 or invType == 6 or invType == 7 or invType == 8 or invType == 9 or invType == 10 then
        return "Armor"
    elseif invType == 2 or invType == 11 or invType == 12 or invType == 16 then
        return "Accessories"
    else
        return "Miscellaneous"
    end
end

function Reforger_OnGossipHello(event, player, creature)
    local items = GetEligibleItems(player)
    player:GossipClearMenu()

    if #items == 0 then
        SendYellowMessage(player, "You have no eligible equippable items.")
        player:GossipComplete()
        return
    end

    local intid_counter = 1
    local slotGroups = {
        ["Weapons"] = {},
        ["Armor"] = {},
        ["Accessories"] = {},
        ["Miscellaneous"] = {}
    }

    for _, item in ipairs(items) do
        local group = ClassifyItem(item)
        table.insert(slotGroups[group], item)
    end

    for groupName, groupItems in pairs(slotGroups) do
        if #groupItems > 0 then
            player:GossipMenuAddItem(9, "|cff000000[" .. groupName .. "]|r", 9999, 0)
            for _, item in ipairs(groupItems) do
                local entry = item:GetEntry()
                local quality = item:GetQuality()
                local cost = QUALITY_COST[quality] or 100000
                local costStr = FormatGold(cost)
                player:GossipMenuAddItem(0, "  " .. item:GetItemLink() .. " - " .. costStr, intid_counter, item:GetGUIDLow())
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

    local selectedItem = nil
    local equipSlot = nil

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

    player:RemoveItem(selectedItem:GetEntry(), 1)

    local newItem = player:AddItem(entry, 1)
    if not newItem then
        player:AddItem(entry, 1)
        SendYellowMessage(player, "Failed to return reforged item.")
        player:GossipComplete()
        return
    end

    local applied = 0
    for slotIndex = 0, 2 do
        if applied < 2 and math.random(5) >= 1 then
            local enchantId = RollEnchant(newItem)
            if enchantId then
                newItem:SetEnchantment(enchantId, slotIndex)
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
