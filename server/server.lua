local RESOURCE = GetCurrentResourceName()
local registeredUsable = false
local ActiveUse = {}
local BlastDestroyed = {}
local BlastDbReady = false
local BacchusBridgeDestroyed = false

local function dbg(msg)
    if Config.DevMode then
        print(('[%s:server] %s'):format(RESOURCE, msg))
    end
end

local function notify(src, msg)
    if not msg or msg == '' then return end

    local duration = tonumber((Config.Notify and Config.Notify.duration) or 4000) or 4000
    local text = tostring(msg or ' ')
    if text == '' then text = ' ' end

    -- IMPORTANT: do not also call awz_dynamite:client:notify after AWZ Bottom.
    -- Calling both creates a duplicate ShowBottom call, and RedM can throw a
    -- CreateVarString native exception inside awz_libs on the second call.
    if Config.Notify and Config.Notify.useAwzLibs and Config.Notify.awzEvent then
        TriggerClientEvent(Config.Notify.awzEvent, src, text, duration)
        return
    end

    TriggerClientEvent('awz_dynamite:client:notify', src, text, duration)
end



local function getBlastTableName()
    local name = Config.BlastProps and Config.BlastProps.databaseTable or 'awz_detonator_blast_props'
    name = tostring(name or 'awz_detonator_blast_props')
    if not name:match('^[%w_]+$') then
        name = 'awz_detonator_blast_props'
    end
    return name
end

local function hasOxmysql()
    return GetResourceState and GetResourceState('oxmysql') == 'started'
end

local function dbQuerySync(query, params)
    params = params or {}

    if MySQL and MySQL.query and MySQL.query.await then
        local ok, result = pcall(function()
            return MySQL.query.await(query, params)
        end)
        if ok then return result end
    end

    if MySQL and MySQL.Sync and MySQL.Sync.fetchAll then
        local ok, result = pcall(function()
            return MySQL.Sync.fetchAll(query, params)
        end)
        if ok then return result end
    end

    if hasOxmysql() then
        local ok, result = pcall(function()
            return exports.oxmysql:executeSync(query, params)
        end)
        if ok then return result end

        ok, result = pcall(function()
            return exports.oxmysql:query_async(query, params)
        end)
        if ok then return result end
    end

    return nil
end

local function dbExecute(query, params)
    params = params or {}

    if MySQL and MySQL.update and MySQL.update.await then
        local ok = pcall(function()
            MySQL.update.await(query, params)
        end)
        if ok then return true end
    end

    if MySQL and MySQL.query and MySQL.query.await then
        local ok = pcall(function()
            MySQL.query.await(query, params)
        end)
        if ok then return true end
    end

    if MySQL and MySQL.Async and MySQL.Async.execute then
        local ok = pcall(function()
            MySQL.Async.execute(query, params)
        end)
        if ok then return true end
    end

    if hasOxmysql() then
        local ok = pcall(function()
            exports.oxmysql:execute(query, params)
        end)
        if ok then return true end
    end

    return false
end

local function setupBlastProps()
    local cfg = Config.BlastProps
    if not (cfg and cfg.enabled) then return end

    BlastDestroyed = {}
    BlastDbReady = false

    local tableName = getBlastTableName()
    if not hasOxmysql() and not (MySQL and MySQL.query) then
        print(('^3[%s]^0 oxmysql non trovato: i props persistent funzioneranno solo in memoria fino al restart.'):format(RESOURCE))
        return
    end

    local createSql = ([[
        CREATE TABLE IF NOT EXISTS `%s` (
            `prop_id` VARCHAR(80) NOT NULL,
            `destroyed` TINYINT(1) NOT NULL DEFAULT 0,
            `destroyed_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`prop_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]]):format(tableName)

    dbExecute(createSql, {})

    local rows = dbQuerySync(('SELECT `prop_id` FROM `%s` WHERE `destroyed` = 1'):format(tableName), {}) or {}
    for _, row in ipairs(rows) do
        if row.prop_id then
            BlastDestroyed[tostring(row.prop_id)] = true
        end
    end

    BlastDbReady = true
    dbg(('loaded persistent destroyed blast props: %s'):format(json.encode(BlastDestroyed)))
end

local function saveDestroyedBlastProp(id)
    if not id then return false end
    local tableName = getBlastTableName()
    local sql = ([[
        INSERT INTO `%s` (`prop_id`, `destroyed`, `destroyed_at`)
        VALUES (?, 1, NOW())
        ON DUPLICATE KEY UPDATE `destroyed` = 1, `destroyed_at` = NOW()
    ]]):format(tableName)
    return dbExecute(sql, { tostring(id) })
end

local function getBlastPropCoords(entry)
    if not entry or not entry.coords then return nil end

    local cfg = Config.BlastProps or {}
    local zOffset = tonumber(cfg.zOffset)
    if zOffset == nil then zOffset = -1.0 end

    local baseZ = tonumber(entry.coords.z or entry.coords[3]) or 0.0

    return {
        x = entry.coords.x or entry.coords[1],
        y = entry.coords.y or entry.coords[2],
        z = baseZ + zOffset,
    }
end

local function distance3(a, b)
    if not (a and b) then return 999999.0 end
    local dx = (a.x or 0.0) - (b.x or 0.0)
    local dy = (a.y or 0.0) - (b.y or 0.0)
    local dz = (a.z or 0.0) - (b.z or 0.0)
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function checkBlastProps(coords)
    local cfg = Config.BlastProps
    if not (cfg and cfg.enabled and type(cfg.list) == 'table') then return end
    if not coords then return end

    for _, entry in ipairs(cfg.list) do
        local id = entry.id
        if id and not BlastDestroyed[id] then
            local c = getBlastPropCoords(entry)
            local radius = tonumber(entry.radius or cfg.checkRadiusDefault) or 5.0
            if c and distance3(coords, c) <= radius then
                BlastDestroyed[id] = true

                if entry.persistent then
                    saveDestroyedBlastProp(id)
                end

                TriggerClientEvent('awz_detonator:client:destroyBlastProp', -1, id)
                dbg(('blast prop destroyed: %s radius %.2f'):format(id, radius))
            end
        end
    end
end



local function checkBacchusBridge(coords)
    local cfg = Config.BacchusBridge
    if BacchusBridgeDestroyed then return end
    if not (cfg and cfg.enabled and cfg.coords and coords) then return end

    local radius = tonumber(cfg.radius) or 50.0
    if distance3(coords, cfg.coords) <= radius then
        BacchusBridgeDestroyed = true
        TriggerClientEvent('awz_detonator:client:bacchusBridgeFall', -1)
        dbg(('Bacchus bridge destroyed by dynamite inside %.2fm radius.'):format(radius))
    end
end

RegisterNetEvent('awz_detonator:server:requestBacchusBridge', function()
    local src = source
    if BacchusBridgeDestroyed then
        TriggerClientEvent('awz_detonator:client:bacchusBridgeFall', src)
    end
end)

RegisterNetEvent('awz_detonator:server:requestBlastProps', function()
    local src = source
    TriggerClientEvent('awz_detonator:client:syncBlastProps', src, BlastDestroyed)
end)

local function getVorpInventoryApi()
    local ok, api = pcall(function()
        if exports.vorp_inventory and exports.vorp_inventory.vorp_inventoryApi then
            return exports.vorp_inventory:vorp_inventoryApi()
        end
    end)
    if ok then return api end
    return nil
end

local function closeInventory(src)
    if not Config.CloseInventoryOnUse then return end
    pcall(function() exports.vorp_inventory:closeInventory(src) end)
    local api = getVorpInventoryApi()
    if api then pcall(function() api.closeInventory(src) end) end
end

local function copyTable(t)
    local out = {}
    if type(t) ~= 'table' then return out end
    for k, v in pairs(t) do out[k] = v end
    return out
end

local function getItemId(item)
    if type(item) ~= 'table' then return nil end
    if item.id then return item.id end
    if item.mainid then return item.mainid end
    if item.item_crafted_id then return item.item_crafted_id end
    local ok, id = pcall(function() return item:getId() end)
    if ok then return id end
    return nil
end

local function getItemMetadata(item)
    if type(item) ~= 'table' then return {} end
    if type(item.metadata) == 'table' then return item.metadata end
    local ok, metadata = pcall(function() return item:getMetadata() end)
    if ok and type(metadata) == 'table' then return metadata end
    return {}
end

local function getItem(src, item, metadata)
    local result = nil

    local ok, ret = pcall(function()
        return exports.vorp_inventory:getItem(src, item, function(res)
            result = res
        end, metadata)
    end)

    if ok and ret ~= nil then return ret end
    if ok and result ~= nil then return result end

    local api = getVorpInventoryApi()
    if api then
        ok, ret = pcall(function() return api.getItem(src, item, metadata) end)
        if ok and ret ~= nil then return ret end
        ok, ret = pcall(function() return api.GetItem(src, item, metadata) end)
        if ok and ret ~= nil then return ret end
    end

    return nil
end

local function addItem(src, item, count, metadata)
    local ok, ret = pcall(function() return exports.vorp_inventory:addItem(src, item, count, metadata or {}) end)
    if ok and ret ~= false then return true end
    ok, ret = pcall(function() return exports.vorp_inventory:addItem(src, item, count) end)
    if ok and ret ~= false then return true end

    local api = getVorpInventoryApi()
    if api then
        ok, ret = pcall(function() return api.addItem(src, item, count, metadata or {}) end)
        if ok and ret ~= false then return true end
        ok, ret = pcall(function() return api.AddItem(src, item, count, metadata or {}) end)
        if ok and ret ~= false then return true end
    end

    return false
end

local function removeItem(src, item, count, metadata)
    local ok, ret = pcall(function() return exports.vorp_inventory:subItem(src, item, count, metadata) end)
    if ok and ret ~= false then return true end
    ok, ret = pcall(function() return exports.vorp_inventory:removeItem(src, item, count, metadata) end)
    if ok and ret ~= false then return true end

    local api = getVorpInventoryApi()
    if api then
        ok, ret = pcall(function() return api.subItem(src, item, count, metadata) end)
        if ok and ret ~= false then return true end
        ok, ret = pcall(function() return api.removeItem(src, item, count, metadata) end)
        if ok and ret ~= false then return true end
        ok, ret = pcall(function() return api.RemoveItem(src, item, count, metadata) end)
        if ok and ret ~= false then return true end
    end

    return false
end

local function setItemMetadata(src, itemId, metadata, amount)
    if not itemId then return false end
    local ok, ret = pcall(function()
        return exports.vorp_inventory:setItemMetadata(src, itemId, metadata, amount or 1)
    end)
    return ok and ret ~= false
end

local function getDetonatorUses(item)
    local cfg = Config.DetonatorUses or {}
    local key = cfg.metadataKey or 'uses'
    local defaultUses = tonumber(cfg.default) or 20
    local metadata = getItemMetadata(item)
    local uses = tonumber(metadata[key])

    if uses == nil then
        uses = defaultUses
    end

    return uses, defaultUses, metadata, key
end

local function findUsableDetonator(src)
    local item = getItem(src, Config.DetonatorItem)
    if not item then
        return nil, 'missing'
    end

    if not (Config.DetonatorUses and Config.DetonatorUses.enabled) then
        return item, nil
    end

    local uses = getDetonatorUses(item)
    if uses <= 0 then
        return nil, 'empty'
    end

    return item, nil
end

local function consumeDetonatorUse(src)
    if not (Config.DetonatorUses and Config.DetonatorUses.enabled) then
        return true
    end

    local item, reason = findUsableDetonator(src)
    if not item then
        return false, reason
    end

    local itemId = getItemId(item)
    local uses, defaultUses, metadata, key = getDetonatorUses(item)
    uses = math.max(0, uses - 1)

    local newMetadata = copyTable(metadata)
    newMetadata[key] = uses

    if Config.DetonatorUses.showDescription then
        newMetadata.description = (Config.Language.detonatorUses or 'Utilizzi detonatore: %s/%s'):format(uses, defaultUses)
    end

    if not setItemMetadata(src, itemId, newMetadata, 1) then
        return false, 'metadata'
    end

    notify(src, (Config.Language.detonatorUses or 'Utilizzi detonatore: %s/%s'):format(uses, defaultUses))
    return true
end

local function registerUsableItem()
    if registeredUsable then return end

    local function onUse(data)
        local src = type(data) == 'table' and (data.source or data.src) or data
        src = tonumber(src)
        if not src then return end

        if ActiveUse[src] then
            notify(src, Config.Language.busy)
            return
        end

        closeInventory(src)

        local detonator, reason = findUsableDetonator(src)
        if not detonator then
            if reason == 'empty' then
                notify(src, Config.Language.detonatorEmpty)
            else
                notify(src, Config.Language.noDetonator)
            end
            return
        end

        -- VORP calls this callback only when the item exists. We remove immediately and refund on cancel.
        if not removeItem(src, Config.UseItem, 1) then
            notify(src, Config.Language.noItem)
            return
        end

        ActiveUse[src] = true
        TriggerClientEvent('awz_dynamite:client:start', src, true)
    end

    local ok = pcall(function()
        exports.vorp_inventory:registerUsableItem(Config.UseItem, onUse)
    end)
    if ok then
        registeredUsable = true
        dbg(('registered usable item through export: %s'):format(Config.UseItem))
        return
    end

    local api = getVorpInventoryApi()
    if api then
        ok = pcall(function() api.RegisterUsableItem(Config.UseItem, onUse) end)
        if ok then
            registeredUsable = true
            dbg(('registered usable item through legacy API: %s'):format(Config.UseItem))
            return
        end
    end

    print(('^3[%s]^0 unable to register usable item with vorp_inventory. Command fallback remains available.'):format(RESOURCE))
end

RegisterNetEvent('awz_dynamite:server:refund', function()
    local src = source
    if not ActiveUse[src] then return end
    ActiveUse[src] = nil
    if addItem(src, Config.UseItem, 1) then
        notify(src, Config.Language.refunded)
    end
end)

local function handleDetonate(src, coords)
    if not ActiveUse[src] then return end

    local consumed, reason = consumeDetonatorUse(src)
    if not consumed then
        ActiveUse[src] = nil
        addItem(src, Config.UseItem, 1)
        TriggerClientEvent('awz_dynamite:client:stopPlacement', src)

        if reason == 'empty' then
            notify(src, Config.Language.detonatorEmpty)
        else
            notify(src, Config.Language.noDetonator)
        end
        return
    end

    ActiveUse[src] = nil
    checkBlastProps(coords)
    checkBacchusBridge(coords)
    TriggerClientEvent('awz_detonator:client:worldExplosion', -1, coords, src)
    TriggerClientEvent('awz_dynamite:client:doExplosion', src, coords)

    if not Config.EnableLogs then return end
    local msg = ('**DYNAMITE EXPLODED**\nPlayer: %s\nPosition: %s'):format(src, json.encode(coords or {}))

    local ok = pcall(function()
        exports.JD_logsV3:createLog({
            EmbedMessage = msg,
            player_id = src,
            channel = Config.LogChannel,
            screenshot = false
        })
    end)

    if not ok then
        print(('[%s] %s'):format(RESOURCE, msg))
    end
end

RegisterNetEvent('awz_dynamite:server:detonate', function(coords)
    handleDetonate(source, coords)
end)

-- Legacy compatibility: old client event now routes through the secured detonator use flow.
RegisterNetEvent('awz_dynamite:server:explosionLog', function(coords)
    handleDetonate(source, coords)
end)

AddEventHandler('playerDropped', function()
    ActiveUse[source] = nil
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= RESOURCE then return end
    Wait(1500)
    setupBlastProps()
    registerUsableItem()
    print(('^2[%s]^0 started.'):format(RESOURCE))
end)
