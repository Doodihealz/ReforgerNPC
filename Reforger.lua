local ENABLE_RANDOM_ON_ACQUIRE = true
local RNG_SEEDED = false
local NPC_ID = 200004

local QUALITY_COST = { [0]=10000,[1]=20000,[2]=50000,[3]=100000,[4]=250000,[5]=1000000 }
local MAX_LEVEL = 80

local ALLOWED_IDS = { [18706]=true }
local EXCLUDED_IDS = { [4499]=true,[5571]=true,[5572]=true,[805]=true,[828]=true,[856]=true,[918]=true,[1939]=true,[4245]=true,[5764]=true,[5765]=true,[14155]=true,[14156]=true,[17966]=true,[19291]=true,[21841]=true,[41599]=true,[41729]=true,[43345]=true,[43575]=true,[43958]=true,[44751]=true,[45854]=true,[49295]=true,[38346]=true,[38347]=true,[38348]=true,[38349]=true,[39489]=true,[41600]=true,[34845]=true,[38225]=true,[20400]=true,[22243]=true,[22244]=true,[44447]=true }

local STAT_COLORS = { ["Agility"]="|cff00ff00Agility|r",["Strength"]="|cffff0000Strength|r",["Stamina"]="|cffffffffStamina|r",["Spirit"]="|cffff00ffSpirit|r",["Intellect"]="|cff00ffffIntellect|r",["Attack Power"]="|cff00ff00Attack Power|r",["Spell Power"]="|cffff7f00Spell Power|r",["Crit"]="|cffffff00Crit|r",["Haste"]="|cffffcc00Haste|r",["Hit"]="|cff9999ffHit|r",["Resilience"]="|cffff66ffResilience|r",["Dodge"]="|cffffcc99Dodge|r",["Parry"]="|cffffcc99Parry|r",["Block"]="|cffffcc99Block|r",["Armor Penetration"]="|cffff9999Armor Penetration|r",["Expertise"]="|cffdd8800Expertise|r" }

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

local BL_STATE = {}
local function BL(p) local g=p:GetGUIDLow(); local s=BL_STATE[g]; if not s then s={tiers={}}; BL_STATE[g]=s end; return s end
local function BL_getFloor(p, tier, stat) local t=BL(p).tiers; t[tier]=t[tier] or {}; local c=t[tier][stat] or 0; if c>=6 then return 18 elseif c>=3 then return 16 else return 0 end end
local function BL_inc(p, tier, stat) local t=BL(p).tiers; t[tier]=t[tier] or {}; t[tier][stat]=(t[tier][stat] or 0)+1; for k,_ in pairs(t[tier]) do if k~=stat then t[tier][k]=0 end end end

local function seedRng() if RNG_SEEDED then return end RNG_SEEDED=true m_random(os.time()%2147483646) end

local function parseStatValue(name) if not name then return nil,nil end local num,rest=name:match("([%+%-]?%d+)%s+(.+)"); if not num or not rest then return nil,nil end local v=tonumber(num); if not v then return nil,nil end rest=rest:gsub("^%s+",""):gsub("%s+$",""); return rest,v end
local function getParsedStat(id) local c=parsedStatCache[id]; if c then return c.name,c.val end local nm=enchantNameCache[id]; if not nm then parsedStatCache[id]={}; return nil,nil end local stat,val=parseStatValue(nm); parsedStatCache[id]={name=stat,val=val}; return stat,val end
local function getStatKey(id) local statName = getParsedStat(id); if not statName then return nil end return (statName or ""):lower():gsub("^%s+"," "):gsub("%s+$","") end

local function LoadEnchantCache()
    local q = WorldDBQuery("SELECT enchantID, tier, class, comment FROM item_enchantment_random_tiers")
    if not q then return end
    repeat
        local id = q:GetUInt32(0)
        local t  = q:GetUInt8(1)
        local c  = q:GetString(2)
        local comm = q:GetString(3)
        local C = enchantCache[c] or enchantCache.ANY
        C[t] = C[t] or {}
        t_insert(C[t], id)
        enchantNameCache[id] = comm
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

local function GetScaledCost(base, level)
    local L = level or MAX_LEVEL
    if L < 1 then L = 1 end
    if L > MAX_LEVEL then L = MAX_LEVEL end
    local scale = L / MAX_LEVEL
    local cost = math.floor(base * scale)
    if cost < 0 then cost = 0 end
    return cost
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

local function GetEligibleItems(player)
    local items, slotMap = {}, {}
    for slot=0,18 do
        local it = player:GetItemByPos(255, slot)
        if it and IsValidEquipable(it) then t_insert(items, it); slotMap[it:GetGUIDLow()] = slot end
    end
    playerEligibleMap[player:GetGUIDLow()] = slotMap
    return items
end

local function ClassifyItem(item)
    local invType = item:GetInventoryType()
    if invType==13 or invType==14 or invType==15 or invType==17 or invType==18 or invType==21 or invType==23 or invType==26 then
        return "Weapons"
    elseif invType==25 or invType==28 then
        return "Accessories"
    elseif invType==1 or invType==3 or invType==5 or invType==6 or invType==7 or invType==8 or invType==9 or invType==10 or invType==16 then
        return "Armor"
    elseif invType==2 or invType==11 or invType==12 then
        return "Accessories"
    else
        return "Miscellaneous"
    end
end

local STAT_COLORS_LC = {}
for k,v in pairs(STAT_COLORS) do STAT_COLORS_LC[k:lower()] = v end

local function ColorizeEnchantment(desc)
    local cached = colorizedCache[desc]; if cached then return cached end
    local s = desc:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","")
    s = s:gsub("([%+%-]?)(%d+)%s+(.+)$", function(sign,num,statName)
        statName = statName:match("^%s*(.-)%s*$")
        local coloredSign = (sign~="" and "|cffffff00"..sign.."|r") or ""
        local coloredNumber = "|cff00ff00"..num.."|r"
        local color = STAT_COLORS_LC[statName:lower()] or ("|cffffffff"..statName.."|r")
        return coloredSign..coloredNumber.." "..color
    end)
    colorizedCache[desc]=s
    return s
end

local function isCaster(p) local c=p:GetClass(); return c==8 or c==5 or c==9 end
local function isOil(id) return OIL_IDS[id]==true end
local function isSPorInt(id)
    local v=_isSPorIntCache[id]; if v~=nil then return v end
    local n=enchantNameCache[id]
    v = n and (n:find("Spell Power",1,true) or n:find("Intellect",1,true)) and true or false
    _isSPorIntCache[id]=v
    return v
end
local function hasRangedAP(id)
    local v=_hasRAPCache[id]; if v~=nil then return v end
    local n=enchantNameCache[id]
    v = (RANGED_AP_IDS[id]==true) or (n and n:lower():find("ranged attack power",1,true)~=nil) or false
    _hasRAPCache[id]=v
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
        if NO_OIL_CLASSES[playerClass] and isOil(id) then return end
        if (playerClass == 5 or playerClass == 8 or playerClass == 9) and isRockbiterOrVenomhide(id) then return end
        local w = baseWeight
        if caster then if itemClass == "WEAPON" and isOil(id) then w = w + CASTER_OIL_WEIGHT end; if isSPorInt(id) then w = w + CASTER_SP_INT_WEIGHT end end
        if (playerClass == 3 or playerClass == 4) and statName == "Agility" then w = w + HUNTER_ROGUE_AGI_BONUS end
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

    if enchantCache[itemClass] then
        if tier==5 then
            add_from(itemClass,4,biased(2)); add_from("ANY",4,1)
            add_from(itemClass,5,biased(2)); add_from("ANY",5,1)
        else
            add_from(itemClass,tier,biased(2)); add_from("ANY",tier,1)
        end
    else
        add_from("ANY", tier, 1)
    end

    pool.total = total
    return pool
end

local function pickWeighted(weighted)
    if not weighted or #weighted==0 or not weighted.total or weighted.total<=0 then return nil end
    local r = m_random() * weighted.total
    local acc = 0
    for i=1,#weighted do acc=acc+weighted[i].w; if r<=acc then return weighted[i].id end end
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
    if level>=80 then return 5 elseif level>=70 then return 4 elseif level>=60 then return 3 elseif level>=30 then return 2 else return 1 end
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

local function safeGetEnchantId(item, slot) if item and item.GetEnchantmentId and type(item.GetEnchantmentId)=="function" then return item:GetEnchantmentId(slot) or 0 end return 0 end
local function safeSetEnchant(item, id, slot) if item and item.SetEnchantment and type(item.SetEnchantment)=="function" then return item:SetEnchantment(id, slot) end return false end

local function ApplyEnchantsDirectly(item, player)
    seedRng()
    if not item or not player then return 0, {} end
    local applied, appliedEnchants, descriptions = 0, {}, {}
    local isWeapon = (item:GetClass()==2)
    for i=1,#WRITE_SLOTS_REFORGE do
        if applied>=2 then break end
        local slotIndex = WRITE_SLOTS_REFORGE[i]
        local attempt, maxAttempts = 0, 20
        local prefer = isWeapon and weaponBias(slotIndex) or nil
        local enchantId
        repeat enchantId = RollEnchant(item, player, appliedEnchants, prefer); attempt = attempt + 1 until (enchantId and not appliedEnchants[enchantId]) or attempt>=maxAttempts
        if enchantId and not appliedEnchants[enchantId] and safeSetEnchant(item, enchantId, slotIndex) then
            appliedEnchants[enchantId]=true
            t_insert(descriptions, enchantNameCache[enchantId] or "Unknown")
            applied = applied + 1
        end
    end
    if SAVE_ITEM_IMMEDIATELY and applied>0 and item.SaveToDB then item:SaveToDB() end
    return applied, descriptions
end

local function TopEnchantsForStat(item, player, statKey, n)
    local tier = levelToTier(player:GetLevel())
    local pool = buildPool(item, player, {}, tier, nil, statKey)
    if not pool or #pool==0 then return {} end
    local arr = {}
    for i=1,#pool do
        local id = pool[i].id
        local _, val = getParsedStat(id)
        t_insert(arr, { id=id, v=val or -1 })
    end
    table.sort(arr, function(a,b) return a.v > b.v end)
    local out, used = {}, {}
    for i=1,#arr do
        local id = arr[i].id
        if not used[id] then t_insert(out, id); used[id]=true end
        if #out>=n then break end
    end
    return out
end

local function ApplyEnchantsDirectlyRestricted(item, player, statKey)
    seedRng()
    if not item or not player then return 0, {} end
    local ids = TopEnchantsForStat(item, player, statKey, 2)
    if #ids==0 then return 0, {} end
    local applied, descriptions = 0, {}
    for i=1,math.min(2, #ids) do
        local slotIndex = WRITE_SLOTS_REFORGE[i]
        if ids[i] and safeSetEnchant(item, ids[i], slotIndex) then
            t_insert(descriptions, enchantNameCache[ids[i]] or "Unknown")
            applied = applied + 1
        end
    end
    if SAVE_ITEM_IMMEDIATELY and applied>0 and item.SaveToDB then item:SaveToDB() end
    return applied, descriptions
end

local manualMode = {}
local pendingItem = {}
local pendingStats = {}

local function PlayerManual(p) local g=p:GetGUIDLow(); if manualMode[g]==nil then manualMode[g]=MANUAL_MODE_DEFAULT end return manualMode[g] end
local function ToggleManual(p) local g=p:GetGUIDLow(); manualMode[g]=not PlayerManual(p) end

local function BuildAvailableStats(item, player)
    local tier = levelToTier(player:GetLevel())
    local pool = buildPool(item, player, {}, tier, nil, nil)
    local uniq, list = {}, {}
    if pool then
        for i=1,#pool do
            local id = pool[i].id
            local statName = getParsedStat(id)
            if statName then
                local key = (statName or ""):lower():gsub("^%s+"," "):gsub("%s+$","")
                if not uniq[key] then uniq[key] = statName; t_insert(list, key) end
            end
        end
    end
    table.sort(list)
    local out = {}
    for i=1,#list do out[i] = { key=list[i], name=uniq[list[i]] } end
    return out
end

function Reforger_OnGossipHello(event, player, creature)
    local items = GetEligibleItems(player)
    player:GossipClearMenu()
    local modeTxt = PlayerManual(player) and "Manual Mode: On" or "Manual Mode: Off"
    player:GossipMenuAddItem(0, "|cff00c0ff"..modeTxt.."|r", 5000, 1)
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
    if sender==9999 then Reforger_OnGossipHello(nil, player, creature); return end
    if sender==5000 then ToggleManual(player); Reforger_OnGossipHello(nil, player, creature); return end
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

local function ApplyRandomEnchantsOnAcquire(item, player, source)
    seedRng()
    if not ENABLE_RANDOM_ON_ACQUIRE or not item or not player or not IsValidEquipable(item) then return end
    local applied, appliedEnchants = 0, {}
    for i=1,#WRITE_SLOTS_ACQUIRE do
        if applied>=ACQ_MAX_SLOTS then break end
        local slotIndex = WRITE_SLOTS_ACQUIRE[i]
        if ACQ_ROLL_CHANCE_DENOM<=1 or m_random(1,ACQ_ROLL_CHANCE_DENOM)==1 then
            if not ACQ_SKIP_IF_HAS_ENCHANT or (safeGetEnchantId(item, slotIndex)==0) then
                local prefer = (item:GetClass()==2) and weaponBias(slotIndex) or nil
                local enchantId
                for _=1,ACQ_ATTEMPTS_PER_SLOT do enchantId=RollEnchant(item, player, appliedEnchants, prefer); if enchantId and not appliedEnchants[enchantId] then break end end
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

RegisterPlayerEvent(32, OnLootItem)
RegisterPlayerEvent(52, OnCreateItem)
RegisterPlayerEvent(51, OnQuestReward)
RegisterPlayerEvent(53, OnStoreNewItem)
