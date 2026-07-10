local ResourceName = GetCurrentResourceName()
local DB_FILE = 'data/players.json'

local PlayerData = {}        -- [source] = { identifier, name, inventory, hunger, thirst, maxWeight }
local Drops = {}             -- [dropId] = { coords = {x,y,z}, items = { [slot] = {name, amount} } }
local DropIdCounter = 0

-- ===================== STORAGE =====================
local function LoadDatabase()
    local raw = LoadResourceFile(ResourceName, DB_FILE)
    if not raw or raw == '' then return {} end
    local ok, data = pcall(json.decode, raw)
    if ok and type(data) == 'table' then return data end
    return {}
end

local Database = LoadDatabase()

local function SaveDatabase()
    SaveResourceFile(ResourceName, DB_FILE, json.encode(Database), -1)
end

local function GetIdentifier(src)
    local ids = GetPlayerIdentifiers(src)
    for _, id in ipairs(ids) do
        if string.find(id, 'license:') then
            return id
        end
    end
    return ids[1] or ('unknown:' .. src)
end

-- ===================== HELPERS =====================
local function GetItemData(name)
    return Config.Items[name]
end

local function GetInventoryWeight(inv)
    local total = 0.0
    for _, item in pairs(inv) do
        local data = GetItemData(item.name)
        if data then
            total = total + (data.weight * item.amount)
        end
    end
    return total
end

local function FindEmptySlot(inv)
    for i = 1, Config.Slots do
        local key = tostring(i)
        if not inv[key] then
            return key
        end
    end
    return nil
end

local function Notify(src, message, kind)
    TriggerClientEvent('psinv:client:notify', src, message, kind or 'info')
end

local function SyncInventory(src)
    local pdata = PlayerData[src]
    if not pdata then return end
    TriggerClientEvent('psinv:client:update', src, {
        inventory = pdata.inventory,
        hunger = pdata.hunger,
        thirst = pdata.thirst,
        maxWeight = pdata.maxWeight,
    })
end

local function PersistPlayer(pdata)
    if not pdata then return end
    Database[pdata.identifier] = {
        inventory = pdata.inventory,
        hunger = pdata.hunger,
        thirst = pdata.thirst,
    }
end

-- ===================== PLAYER INIT =====================
local function InitPlayer(src)
    local identifier = GetIdentifier(src)
    local record = Database[identifier]

    if not record then
        record = { inventory = {}, hunger = 100, thirst = 100 }
        local slot = 1
        for _, starter in ipairs(Config.StarterItems) do
            record.inventory[tostring(slot)] = { name = starter.name, amount = starter.amount }
            slot = slot + 1
        end
        Database[identifier] = record
        SaveDatabase()
    end

    PlayerData[src] = {
        identifier = identifier,
        name = GetPlayerName(src),
        inventory = record.inventory or {},
        hunger = record.hunger or 100,
        thirst = record.thirst or 100,
        maxWeight = Config.MaxWeight,
    }

    return PlayerData[src]
end

RegisterServerEvent('psinv:server:init')
AddEventHandler('psinv:server:init', function()
    local src = source
    local data = InitPlayer(src)
    TriggerClientEvent('psinv:client:init', src, {
        inventory = data.inventory,
        hunger = data.hunger,
        thirst = data.thirst,
        maxWeight = data.maxWeight,
    })
end)

-- ===================== MOVE / STACK =====================
RegisterServerEvent('psinv:server:moveItem')
AddEventHandler('psinv:server:moveItem', function(fromSlot, toSlot)
    local src = source
    local pdata = PlayerData[src]
    if not pdata then return end

    fromSlot, toSlot = tostring(fromSlot), tostring(toSlot)
    if fromSlot == toSlot then return end

    local fromItem = pdata.inventory[fromSlot]
    if not fromItem then return end

    local toItem = pdata.inventory[toSlot]

    if toItem and toItem.name == fromItem.name then
        local data = GetItemData(fromItem.name)
        local maxStack = (data and data.stack) or 999
        local total = toItem.amount + fromItem.amount
        if total <= maxStack then
            toItem.amount = total
            pdata.inventory[fromSlot] = nil
        else
            toItem.amount = maxStack
            fromItem.amount = total - maxStack
        end
    else
        pdata.inventory[fromSlot] = toItem
        pdata.inventory[toSlot] = fromItem
    end

    SyncInventory(src)
end)

-- ===================== SPLIT (auto half) =====================
RegisterServerEvent('psinv:server:splitItem')
AddEventHandler('psinv:server:splitItem', function(slot)
    local src = source
    local pdata = PlayerData[src]
    if not pdata then return end

    slot = tostring(slot)
    local item = pdata.inventory[slot]
    if not item or item.amount < 2 then
        Notify(src, 'You need at least 2 items to split that stack.', 'error')
        return
    end

    local emptySlot = FindEmptySlot(pdata.inventory)
    if not emptySlot then
        Notify(src, 'No empty slot available.', 'error')
        return
    end

    local half = math.floor(item.amount / 2)
    item.amount = item.amount - half
    pdata.inventory[emptySlot] = { name = item.name, amount = half }

    SyncInventory(src)
end)

-- ===================== SEPARATE (manual amount) =====================
RegisterServerEvent('psinv:server:separateItem')
AddEventHandler('psinv:server:separateItem', function(slot, amount)
    local src = source
    local pdata = PlayerData[src]
    if not pdata then return end

    slot = tostring(slot)
    amount = tonumber(amount)
    local item = pdata.inventory[slot]
    if not item or not amount or amount <= 0 or amount >= item.amount then
        Notify(src, 'Invalid amount.', 'error')
        return
    end

    local emptySlot = FindEmptySlot(pdata.inventory)
    if not emptySlot then
        Notify(src, 'No empty slot available.', 'error')
        return
    end

    item.amount = item.amount - amount
    pdata.inventory[emptySlot] = { name = item.name, amount = amount }

    SyncInventory(src)
end)

-- ===================== USE ITEM =====================
RegisterServerEvent('psinv:server:useItem')
AddEventHandler('psinv:server:useItem', function(slot)
    local src = source
    local pdata = PlayerData[src]
    if not pdata then return end

    slot = tostring(slot)
    local item = pdata.inventory[slot]
    if not item then return end

    local data = GetItemData(item.name)
    if not data or (data.type ~= 'food' and data.type ~= 'drink' and data.type ~= 'medical') then
        Notify(src, 'You cannot use this item.', 'error')
        return
    end

    item.amount = item.amount - 1
    if item.amount <= 0 then pdata.inventory[slot] = nil end

    if data.hunger then pdata.hunger = math.min(100, pdata.hunger + data.hunger) end
    if data.thirst then pdata.thirst = math.min(100, pdata.thirst + data.thirst) end
    if data.health then TriggerClientEvent('psinv:client:heal', src, data.health) end

    Notify(src, ('You used %s.'):format(data.label), 'success')
    SyncInventory(src)
end)

-- ===================== DROP ON GROUND =====================
RegisterServerEvent('psinv:server:dropItem')
AddEventHandler('psinv:server:dropItem', function(slot, amount, coords)
    local src = source
    local pdata = PlayerData[src]
    if not pdata or type(coords) ~= 'table' then return end

    slot = tostring(slot)
    amount = tonumber(amount)
    local item = pdata.inventory[slot]
    if not item or not amount or amount <= 0 or amount > item.amount then return end

    item.amount = item.amount - amount
    if item.amount <= 0 then pdata.inventory[slot] = nil end

    DropIdCounter = DropIdCounter + 1
    local dropId = ('drop_%s_%s'):format(src, DropIdCounter)
    Drops[dropId] = {
        coords = { x = coords.x, y = coords.y, z = coords.z },
        items = { ['1'] = { name = item.name, amount = amount } },
    }

    TriggerClientEvent('psinv:client:createDrop', -1, dropId, Drops[dropId].coords)
    SyncInventory(src)
end)

RegisterServerEvent('psinv:server:openDrop')
AddEventHandler('psinv:server:openDrop', function(dropId)
    local src = source
    local drop = Drops[dropId]
    if not drop then
        Notify(src, 'That bag is empty.', 'error')
        return
    end
    TriggerClientEvent('psinv:client:openSecondary', src, {
        id = dropId,
        label = 'Ground',
        items = drop.items,
    })
end)

local function CleanupDropIfEmpty(dropId)
    local drop = Drops[dropId]
    if not drop then return end
    for _, item in pairs(drop.items) do
        if item then return end
    end
    Drops[dropId] = nil
    TriggerClientEvent('psinv:client:removeDrop', -1, dropId)
end

RegisterServerEvent('psinv:server:moveToDrop')
AddEventHandler('psinv:server:moveToDrop', function(dropId, fromSlot, toSlot, amount)
    local src = source
    local pdata = PlayerData[src]
    local drop = Drops[dropId]
    if not pdata or not drop then return end

    fromSlot, toSlot = tostring(fromSlot), tostring(toSlot)
    amount = tonumber(amount)
    local item = pdata.inventory[fromSlot]
    if not item or not amount or amount <= 0 or amount > item.amount then return end

    item.amount = item.amount - amount
    if item.amount <= 0 then pdata.inventory[fromSlot] = nil end

    local existing = drop.items[toSlot]
    if existing and existing.name == item.name then
        existing.amount = existing.amount + amount
    else
        drop.items[toSlot] = { name = item.name, amount = amount }
    end

    SyncInventory(src)
    TriggerClientEvent('psinv:client:updateSecondary', src, drop.items)
end)

RegisterServerEvent('psinv:server:moveFromDrop')
AddEventHandler('psinv:server:moveFromDrop', function(dropId, fromSlot, toSlot, amount)
    local src = source
    local pdata = PlayerData[src]
    local drop = Drops[dropId]
    if not pdata or not drop then return end

    fromSlot, toSlot = tostring(fromSlot), tostring(toSlot)
    amount = tonumber(amount)
    local item = drop.items[fromSlot]
    if not item or not amount or amount <= 0 or amount > item.amount then return end

    local data = GetItemData(item.name)
    local addWeight = (data and data.weight or 0) * amount
    if GetInventoryWeight(pdata.inventory) + addWeight > pdata.maxWeight then
        Notify(src, 'That is too heavy to carry.', 'error')
        return
    end

    item.amount = item.amount - amount
    if item.amount <= 0 then drop.items[fromSlot] = nil end

    local existing = pdata.inventory[toSlot]
    if existing and existing.name == item.name then
        existing.amount = existing.amount + amount
    else
        pdata.inventory[toSlot] = { name = item.name, amount = amount }
    end

    SyncInventory(src)
    TriggerClientEvent('psinv:client:updateSecondary', src, drop.items)
    CleanupDropIfEmpty(dropId)
end)

-- ===================== GIVE =====================
RegisterServerEvent('psinv:server:giveItem')
AddEventHandler('psinv:server:giveItem', function(slot, amount, targetId)
    local src = source
    targetId = tonumber(targetId)
    if not targetId or targetId == src then return end

    local pdata = PlayerData[src]
    local tdata = PlayerData[targetId]
    if not pdata or not tdata then return end

    local srcPed, tgtPed = GetPlayerPed(src), GetPlayerPed(targetId)
    if srcPed == 0 or tgtPed == 0 then return end

    local dist = #(GetEntityCoords(srcPed) - GetEntityCoords(tgtPed))
    if dist > Config.GiveDistance then
        Notify(src, 'That player is too far away.', 'error')
        return
    end

    slot = tostring(slot)
    amount = tonumber(amount)
    local item = pdata.inventory[slot]
    if not item or not amount or amount <= 0 or amount > item.amount then return end

    local data = GetItemData(item.name)
    if not data then return end

    local addWeight = data.weight * amount
    if GetInventoryWeight(tdata.inventory) + addWeight > tdata.maxWeight then
        Notify(src, ('%s cannot carry that much weight.'):format(tdata.name), 'error')
        return
    end

    local toSlot = nil
    for i = 1, Config.Slots do
        local s = tostring(i)
        local existing = tdata.inventory[s]
        if existing and existing.name == item.name and existing.amount + amount <= (data.stack or 999) then
            toSlot = s
            break
        end
    end
    if not toSlot then
        toSlot = FindEmptySlot(tdata.inventory)
    end
    if not toSlot then
        Notify(src, ('%s has no free inventory space.'):format(tdata.name), 'error')
        return
    end

    item.amount = item.amount - amount
    if item.amount <= 0 then pdata.inventory[slot] = nil end

    local existing = tdata.inventory[toSlot]
    if existing and existing.name == item.name then
        existing.amount = existing.amount + amount
    else
        tdata.inventory[toSlot] = { name = item.name, amount = amount }
    end

    SyncInventory(src)
    SyncInventory(targetId)
    Notify(src, ('You gave %sx %s to %s.'):format(amount, data.label, tdata.name), 'success')
    Notify(targetId, ('%s gave you %sx %s.'):format(pdata.name, amount, data.label), 'success')
end)

-- ===================== HUNGER / THIRST TICK =====================
CreateThread(function()
    while true do
        Wait(Config.StatusTickMs)

        local tickSeconds = Config.StatusTickMs / 1000
        local thirstStep = 100 / (Config.ThirstDepleteSeconds / tickSeconds)
        local hungerStep = 100 / (Config.HungerDepleteSeconds / tickSeconds)

        for src, pdata in pairs(PlayerData) do
            pdata.thirst = math.max(0, pdata.thirst - thirstStep)
            pdata.hunger = math.max(0, pdata.hunger - hungerStep)
            SyncInventory(src)
        end
    end
end)

-- ===================== PERSISTENCE =====================
AddEventHandler('playerDropped', function()
    local src = source
    local pdata = PlayerData[src]
    if pdata then
        PersistPlayer(pdata)
        SaveDatabase()
        PlayerData[src] = nil
    end
end)

CreateThread(function()
    while true do
        Wait(5 * 60000)
        for _, pdata in pairs(PlayerData) do
            PersistPlayer(pdata)
        end
        SaveDatabase()
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= ResourceName then return end
    for _, pdata in pairs(PlayerData) do
        PersistPlayer(pdata)
    end
    SaveDatabase()
end)

-- ===================== EXPORTS =====================
local function AddItemToInventory(src, itemName, amount)
    local pdata = PlayerData[src]
    local data = GetItemData(itemName)
    amount = tonumber(amount) or 1
    if not pdata or not data or amount <= 0 then return false end

    local addWeight = data.weight * amount
    if GetInventoryWeight(pdata.inventory) + addWeight > pdata.maxWeight then
        return false
    end

    for i = 1, Config.Slots do
        local s = tostring(i)
        local existing = pdata.inventory[s]
        if existing and existing.name == itemName and existing.amount + amount <= (data.stack or 999) then
            existing.amount = existing.amount + amount
            SyncInventory(src)
            return true
        end
    end

    local slot = FindEmptySlot(pdata.inventory)
    if not slot then return false end
    pdata.inventory[slot] = { name = itemName, amount = amount }
    SyncInventory(src)
    return true
end

local function RemoveItemFromInventory(src, itemName, amount)
    local pdata = PlayerData[src]
    amount = tonumber(amount) or 1
    if not pdata or amount <= 0 then return false end

    local remaining = amount
    for i = 1, Config.Slots do
        local s = tostring(i)
        local item = pdata.inventory[s]
        if item and item.name == itemName then
            local take = math.min(remaining, item.amount)
            item.amount = item.amount - take
            remaining = remaining - take
            if item.amount <= 0 then pdata.inventory[s] = nil end
            if remaining <= 0 then break end
        end
    end

    if remaining > 0 then return false end
    SyncInventory(src)
    return true
end

local function GetItemCount(src, itemName)
    local pdata = PlayerData[src]
    if not pdata then return 0 end
    local count = 0
    for _, item in pairs(pdata.inventory) do
        if item.name == itemName then count = count + item.amount end
    end
    return count
end

exports('AddItem', AddItemToInventory)
exports('RemoveItem', RemoveItemFromInventory)
exports('GetItemCount', GetItemCount)
exports('HasItem', function(src, itemName, amount)
    return GetItemCount(src, itemName) >= (tonumber(amount) or 1)
end)
exports('GetInventory', function(src)
    return PlayerData[src] and PlayerData[src].inventory or {}
end)

-- ===================== ADMIN COMMAND =====================
RegisterCommand('additem', function(source, args)
    if source ~= 0 and not IsPlayerAceAllowed(source, 'command.additem') then
        Notify(source, 'You do not have permission to use this command.', 'error')
        return
    end

    local targetId = tonumber(args[1])
    local itemName = args[2]
    local amount = tonumber(args[3]) or 1

    if not targetId or not itemName or not Config.Items[itemName] then
        print('Usage: additem [player id] [item name] [amount]')
        return
    end

    if AddItemToInventory(targetId, itemName, amount) then
        Notify(targetId, ('You received %sx %s.'):format(amount, Config.Items[itemName].label), 'success')
    else
        Notify(source, 'Could not add item (inventory full or too heavy).', 'error')
    end
end, false)
