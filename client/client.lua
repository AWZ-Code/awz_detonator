local RESOURCE = GetCurrentResourceName()

local State = {
    active = false,
    stage = nil,
    allowCancel = true,
    standing = false,
    dynamite = nil,
    spool = nil,
    detonator = nil,
    rope = nil,
    prompts = {},
    group = GetRandomIntInRange(0, 0xffffff),
    blastProps = {},
    blastDestroyed = {},
    bacchusGhostTrain = nil,
}

local function dbg(msg)
    if Config.DevMode then
        print(('[%s:client] %s'):format(RESOURCE, msg))
    end
end

local function notify(msg, customDuration)
    if not msg or msg == '' then return end

    local duration = tonumber(customDuration or (Config.Notify and Config.Notify.duration) or 4000) or 4000
    local text = tostring(msg or ' ')
    if text == '' then text = ' ' end

    -- AWZ Bottom must be called through its event only.
    -- Direct exports.awz_libs:ShowBottom from this resource can trigger a
    -- CreateVarString native exception on some RedM builds, especially when
    -- the same notification is already being fired by awz_libs.
    if Config.Notify and Config.Notify.useAwzLibs and Config.Notify.awzEvent then
        TriggerEvent(Config.Notify.awzEvent, text, duration)
        return
    end

    if Config.Notify and Config.Notify.vorpEvent then
        TriggerEvent(Config.Notify.vorpEvent, text, duration)
    else
        print(('[%s] %s'):format(RESOURCE, text))
    end
end

RegisterNetEvent('awz_dynamite:client:notify', notify)

local function vdist(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function requestModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelValid(hash) then
        dbg(('invalid model %s'):format(tostring(model)))
        return nil
    end
    RequestModel(hash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) do
        Wait(0)
        if GetGameTimer() > timeout then
            dbg(('model timeout %s'):format(tostring(model)))
            return nil
        end
    end
    return hash
end

local function createObject(model, coords, networked)
    local hash = requestModel(model)
    if not hash then return nil end
    local obj = CreateObject(hash, coords.x, coords.y, coords.z, networked ~= false, true, false)
    SetModelAsNoLongerNeeded(hash)
    if obj and obj ~= 0 then
        return obj
    end
    return nil
end

local function deleteEntity(ent)
    if ent and ent ~= 0 and DoesEntityExist(ent) then
        SetEntityAsMissionEntity(ent, true, true)
        DeleteEntity(ent)
    end
end

local function loadAnimDict(dict)
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) do
        Wait(0)
        if GetGameTimer() > timeout then return false end
    end
    return true
end

local function playAnim(ped, dict, anim, duration, flag)
    if loadAnimDict(dict) then
        TaskPlayAnim(ped, dict, anim, 4.0, -4.0, duration or -1, flag or 1, 0.0, false, false, false)
        return true
    end
    return false
end

local function makePrompt(key, text)
    local prompt = PromptRegisterBegin()
    PromptSetControlAction(prompt, key)
    PromptSetText(prompt, CreateVarString(10, 'LITERAL_STRING', text))
    PromptSetEnabled(prompt, true)
    PromptSetVisible(prompt, true)
    PromptSetStandardMode(prompt, true)
    PromptSetGroup(prompt, State.group)
    PromptRegisterEnd(prompt)
    return prompt
end

local function ensurePrompts()
    if State.prompts.use then return end
    State.prompts.use = makePrompt(Config.KeyUse, Config.Language.detonate)
    State.prompts.ground = makePrompt(Config.KeyGround, Config.Language.chooseGround)
    State.prompts.cancel = makePrompt(Config.KeyCancel, Config.Language.cancel)
end

local function setPrompt(prompt, visible, enabled, text)
    if not prompt then return end
    PromptSetVisible(prompt, visible and true or false)
    PromptSetEnabled(prompt, enabled and true or false)
    if text then
        PromptSetText(prompt, CreateVarString(10, 'LITERAL_STRING', text))
    end
end

local function showPromptGroup(title)
    PromptSetActiveGroupThisFrame(State.group, CreateVarString(10, 'LITERAL_STRING', title or ''))
end

local function promptPressed(prompt)
    return prompt and PromptHasStandardModeCompleted(prompt)
end

local function cleanup(keepDynamite)
    local ped = PlayerPedId()
    ClearPedTasks(ped)
    FreezeEntityPosition(ped, false)

    if not keepDynamite then
        deleteEntity(State.dynamite)
        State.dynamite = nil
    end

    deleteEntity(State.spool)
    deleteEntity(State.detonator)
    State.spool = nil
    State.detonator = nil

    if State.rope then
        pcall(function() DeleteRope(State.rope) end)
        State.rope = nil
    end

    State.active = false
    State.stage = nil
    State.allowCancel = true
    State.standing = false
end

local function refundAndStop(message)
    cleanup(false)
    TriggerServerEvent('awz_dynamite:server:refund')
    if message then notify(message) end
end

local function createRopeBetween(a, b)
    if State.rope then
        pcall(function() DeleteRope(State.rope) end)
        State.rope = nil
    end

    if not (a and b and DoesEntityExist(a) and DoesEntityExist(b)) then return end

    local ca = GetEntityCoords(a)
    local cb = GetEntityCoords(b)
    local length = math.max(1.0, vdist(ca, cb))

    local ok, rope = pcall(function()
        return AddRope(ca.x, ca.y, ca.z, 0.0, 0.0, 0.0, length, 2, length, 0.5, 0.5, false, true, false, 1.0, false, 0)
    end)

    if ok and rope then
        State.rope = rope
        pcall(function()
            AttachEntitiesToRope(rope, a, b, ca.x, ca.y, ca.z, cb.x, cb.y, cb.z, length, false, false, nil, nil)
        end)
    end
end

local function placeDynamite(standing)
    local ped = PlayerPedId()
    local pedCoords = GetEntityCoords(ped)
    State.standing = standing

    if standing then
        ClearPedTasks(ped)
        playAnim(ped, 'script_story@mud5@ig@ig_19_safe_navigation', 'ig19_plant_dynamite_med_rf', 2200, 1)
        Wait(500)

        local handObj = createObject(Config.Props.standingDynamite, pedCoords, true)
        if not handObj then return false end
        State.dynamite = handObj
        AttachEntityToEntity(handObj, ped, GetEntityBoneIndexByName(ped, 'PH_R_Hand'), -0.01, 0.04, 0.0, 0.0, 0.0, 0.0, true, false, false, false, 0, true, false, false)
        Wait(1700)
        ClearPedTasks(ped)

        local final = GetEntityCoords(handObj)
        DetachEntity(handObj, true, true)
        SetEntityCoords(handObj, final.x, final.y, final.z, false, false, false, false)
        FreezeEntityPosition(handObj, true)
        SetEntityInvincible(handObj, true)
    else
        playAnim(ped, 'script_proc@robberies@coach@comp1', 'plant_dynamite', 3000, 1)
        Wait(1800)
        local pos = GetOffsetFromEntityInWorldCoords(ped, 0.0, 0.75, -0.98)
        local obj = createObject(Config.Props.groundDynamite, pos, true)
        if not obj then return false end
        State.dynamite = obj
        SetEntityHeading(obj, GetEntityHeading(ped))
        pcall(function() PlaceObjectOnGroundProperly(obj) end)
        FreezeEntityPosition(obj, true)
        SetEntityInvincible(obj, true)
        Wait(1200)
        ClearPedTasks(ped)
    end

    return true
end

local function startFuseStage()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    State.spool = createObject(Config.Props.spool, coords, true)
    if State.spool then
        AttachEntityToEntity(State.spool, ped, GetEntityBoneIndexByName(ped, 'PH_L_Hand'), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, false, false, false, 0, true, false, false)
        SetEntityVisible(State.spool, true)
        createRopeBetween(State.spool, State.dynamite)
    end

    State.stage = 'fuse'
end

local function placeDetonator()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local pos = GetOffsetFromEntityInWorldCoords(ped, -0.45, 0.35, -0.9)

    DetachEntity(State.spool, true, true)
    ClearPedTasks(ped)
    playAnim(ped, 'script_ca@cachr@ig@ig4_detonate', 'wire_detonator_player_zero', 3800, 1)
    Wait(900)

    State.detonator = createObject(Config.Props.detonator, coords, true)
    if not State.detonator then return false end

    SetEntityCoords(State.detonator, pos.x, pos.y, pos.z, false, false, false, false)
    SetEntityHeading(State.detonator, GetEntityHeading(ped) + 25.0)
    pcall(function() PlaceObjectOnGroundProperly(State.detonator) end)
    FreezeEntityPosition(State.detonator, true)
    SetEntityInvincible(State.detonator, true)

    Wait(2200)
    deleteEntity(State.spool)
    State.spool = nil
    createRopeBetween(State.detonator, State.dynamite)

    playAnim(ped, 'script_ca@cachr@ig@ig4_detonate', 'arthur_detonator_enter_back_player_zero', 1800, 1)
    Wait(1200)
    AttachEntityToEntity(State.detonator, ped, GetEntityBoneIndexByName(ped, 'PH_L_Hand'), 0.12, 0.01, 0.53, 186.0, 0.0, 61.0, true, false, false, false, 0, true, false, false)
    playAnim(ped, 'script_ca@cachr@ig@ig4_detonate', 'idle_ready_player_zero', -1, 1)
    PlayEntityAnim(State.detonator, 'idle_ready_p_detonator01x', 'script_ca@cachr@ig@ig4_detonate', 8.0, false, false, false, 0.0, 0)

    State.stage = 'detonator'
    return true
end

local function explode()
    local ped = PlayerPedId()
    if not (State.dynamite and DoesEntityExist(State.dynamite)) then
        cleanup(false)
        return
    end

    local coords = GetEntityCoords(State.dynamite)
    DetachEntity(State.detonator, true, true)
    playAnim(ped, 'script_ca@cachr@ig@ig4_detonate', 'explosion_react_a_player_zero', 1800, 1)

    if State.detonator and DoesEntityExist(State.detonator) then
        PlayEntityAnim(State.detonator, 'explosion_react_a_p_detonator01x', 'script_ca@cachr@ig@ig4_detonate', 8.0, false, true, true, 0.0, 0)
    end

    State.stage = 'exploding'
    Wait(850)
    TriggerServerEvent('awz_dynamite:server:detonate', { x = coords.x, y = coords.y, z = coords.z })
end

RegisterNetEvent('awz_dynamite:client:doExplosion', function(coords)
    if not coords then return end

    AddExplosion(coords.x, coords.y, coords.z, Config.ExplosionType or 26, Config.RangeDamage or 5.0, true, false, Config.CameraShake or 2.0)
    notify(Config.Language.exploded)

    deleteEntity(State.dynamite)
    State.dynamite = nil
    Wait(1800)
    cleanup(false)
end)

RegisterNetEvent('awz_dynamite:client:stopPlacement', function()
    cleanup(false)
end)

local function getServerId()
    return GetPlayerServerId(PlayerId())
end

RegisterNetEvent('awz_detonator:client:worldExplosion', function(coords, ownerServerId)
    if not coords then return end
    if tonumber(ownerServerId) == getServerId() then return end
    AddExplosion(coords.x, coords.y, coords.z, Config.ExplosionType or 26, Config.RangeDamage or 5.0, true, false, Config.CameraShake or 2.0)
end)



local function loadTrainCars(trainHash)
    if not trainHash or trainHash == 0 then return false end

    local cars = Citizen.InvokeNative(0x635423D55CA84FC8, trainHash) -- GetNumCarsFromTrainConfig
    if not cars or cars == 0 then
        dbg(('invalid train config for Bacchus ghost train: %s'):format(tostring(trainHash)))
        return false
    end

    for index = 0, cars - 1 do
        local model = Citizen.InvokeNative(0x8DF5F6A19F99F0D5, trainHash, index) -- GetTrainModelFromTrainConfigByCarIndex
        if model and model ~= 0 then
            RequestModel(model)
            local timeout = GetGameTimer() + 5000
            while not HasModelLoaded(model) do
                Wait(10)
                if GetGameTimer() > timeout then
                    dbg(('timeout loading Bacchus ghost train car model: %s'):format(tostring(model)))
                    return false
                end
            end
        end
    end

    return true
end

local function deleteBacchusGhostTrain()
    local train = State.bacchusGhostTrain
    if train and train ~= 0 and DoesEntityExist(train) then
        SetEntityAsMissionEntity(train, true, true)
        pcall(function() DeleteVehicle(train) end)
        pcall(function() DeleteEntity(train) end)
    end
    State.bacchusGhostTrain = nil
end

local function spawnBacchusGhostTrain()
    local cfg = Config.BacchusBridge and Config.BacchusBridge.ghostTrain
    if not (cfg and cfg.enabled) then
        deleteBacchusGhostTrain()
        return
    end

    if State.bacchusGhostTrain and State.bacchusGhostTrain ~= 0 and DoesEntityExist(State.bacchusGhostTrain) then
        return
    end

    local trainHash = joaat(cfg.config or 'engine_config')
    if not loadTrainCars(trainHash) then return end

    local c = cfg.coords or vector3(499.69, 1768.78, 188.77)
    local train = Citizen.InvokeNative(0xC239DBD9A57D2A71, trainHash, c.x, c.y, c.z, false, false, true, false) -- CreateMissionTrain
    if train and train ~= 0 then
        State.bacchusGhostTrain = train
        Citizen.InvokeNative(0xDFBA6BBFF7CCAFBB, train, 0.0) -- SetTrainSpeed
        Citizen.InvokeNative(0x01021EB2E96B793C, train, 0.0) -- SetTrainCruiseSpeed
    end
end

RegisterNetEvent('awz_detonator:client:bacchusBridgeFall', function()
    local cfg = Config.BacchusBridge
    if not (cfg and cfg.enabled) then return end

    local rayfireName = cfg.rayfireObject or 'des_trn3_bridge'
    local searchRadius = tonumber(cfg.rayfireSearchRadius) or 10000.0
    local playerCoords = GetEntityCoords(PlayerPedId())

    for _ = 1, 2 do
        local object = GetRayfireMapObject(playerCoords.x, playerCoords.y, playerCoords.z, searchRadius, rayfireName)
        if object and object ~= 0 then
            SetStateOfRayfireMapObject(object, 4)
        end

        Wait(100)

        local explosions = cfg.explosions or {}
        for _, coords in ipairs(explosions) do
            AddExplosion(coords.x, coords.y, coords.z, cfg.explosionType or 28, cfg.explosionDamageScale or 1.0, true, false, 0)
        end

        Wait(100)

        if object and object ~= 0 then
            SetStateOfRayfireMapObject(object, 6)
        end
    end

    Wait(1000)
    spawnBacchusGhostTrain()
end)


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
        w = entry.coords.w or entry.coords[4] or entry.heading or 0.0,
    }
end

local function deleteBlastProp(id)
    local ent = State.blastProps[id]
    if ent and ent ~= 0 and DoesEntityExist(ent) then
        SetEntityAsMissionEntity(ent, true, true)
        DeleteEntity(ent)
    end
    State.blastProps[id] = nil
end

local function spawnBlastProp(entry)
    if not entry or not entry.id or State.blastProps[entry.id] then return end
    if State.blastDestroyed[entry.id] then return end

    local c = getBlastPropCoords(entry)
    if not c then return end

    local obj = createObject(entry.model, vector3(c.x, c.y, c.z), false)
    if not obj then return end

    SetEntityHeading(obj, c.w or 0.0)
    if entry.placeOnGround then
        pcall(function() PlaceObjectOnGroundProperly(obj) end)
    end
    FreezeEntityPosition(obj, true)
    SetEntityInvincible(obj, true)
    SetEntityAsMissionEntity(obj, true, true)
    State.blastProps[entry.id] = obj
end

local function refreshBlastProps()
    local cfg = Config.BlastProps
    if not (cfg and cfg.enabled and type(cfg.list) == 'table') then return end

    local ped = PlayerPedId()
    local pcoords = GetEntityCoords(ped)
    local spawnDistance = tonumber(cfg.spawnDistance) or 150.0

    for _, entry in ipairs(cfg.list) do
        if entry.id then
            if State.blastDestroyed[entry.id] then
                deleteBlastProp(entry.id)
            else
                local c = getBlastPropCoords(entry)
                if c then
                    local dist = vdist(pcoords, vector3(c.x, c.y, c.z))
                    if dist <= spawnDistance then
                        spawnBlastProp(entry)
                    else
                        deleteBlastProp(entry.id)
                    end
                end
            end
        end
    end
end

RegisterNetEvent('awz_detonator:client:syncBlastProps', function(destroyed)
    State.blastDestroyed = destroyed or {}
    refreshBlastProps()
end)

RegisterNetEvent('awz_detonator:client:destroyBlastProp', function(id)
    if not id then return end
    State.blastDestroyed[id] = true
    deleteBlastProp(id)
end)

CreateThread(function()
    Wait(2000)
    TriggerServerEvent('awz_detonator:server:requestBlastProps')
    TriggerServerEvent('awz_detonator:server:requestBacchusBridge')

    while true do
        Wait(2000)
        refreshBlastProps()
    end
end)


local function choosePlacementLoop()
    State.stage = 'choose'
    ensurePrompts()

    while State.active and State.stage == 'choose' do
        Wait(0)
        showPromptGroup(Config.Language.chooseTitle)
        setPrompt(State.prompts.use, true, true, Config.Language.chooseGround)
        setPrompt(State.prompts.ground, false, false)
        setPrompt(State.prompts.cancel, true, true, Config.Language.cancel)

        if promptPressed(State.prompts.use) then
            if placeDynamite(false) then
                startFuseStage()
                return true
            end
            refundAndStop(Config.Language.cancelled)
            return false
        elseif promptPressed(State.prompts.cancel) then
            refundAndStop(Config.Language.cancelled)
            return false
        end
    end

    return false
end

local function fuseLoop()
    ensurePrompts()
    setPrompt(State.prompts.ground, false, false)

    while State.active and State.stage == 'fuse' do
        Wait(0)
        local ped = PlayerPedId()
        local pcoords = GetEntityCoords(ped)
        local dcoords = GetEntityCoords(State.dynamite)
        local dist = vdist(pcoords, dcoords)
        local interior = GetInteriorFromEntity(ped)
        local minRange = interior == 0 and Config.RangeMin.exterior or Config.RangeMin.interior
        local canPlace = dist >= minRange

        showPromptGroup(('%s\n%s'):format(Config.Language.placeDetonator, Config.Language.distance:format(math.floor(dist))))
        setPrompt(State.prompts.use, true, canPlace, Config.Language.placeDetonator)
        setPrompt(State.prompts.cancel, true, true, Config.Language.cancel)

        if canPlace and promptPressed(State.prompts.use) then
            if placeDetonator() then
                return true
            end
            refundAndStop(Config.Language.cancelled)
            return false
        elseif promptPressed(State.prompts.cancel) then
            refundAndStop(Config.Language.cancelled)
            return false
        end
    end

    return false
end

local function detonatorLoop()
    ensurePrompts()
    setPrompt(State.prompts.ground, false, false)

    while State.active and State.stage == 'detonator' do
        Wait(0)
        showPromptGroup(Config.Language.chooseTitle)
        setPrompt(State.prompts.use, true, true, Config.Language.detonate)
        setPrompt(State.prompts.cancel, true, State.allowCancel, Config.Language.cancel)

        if promptPressed(State.prompts.use) then
            explode()
            return true
        elseif State.allowCancel and promptPressed(State.prompts.cancel) then
            refundAndStop(Config.Language.cancelled)
            return false
        end
    end

    return false
end

local function runDynamite(allowCancel)
    if State.active then
        notify(Config.Language.busy)
        return false
    end

    State.active = true
    State.allowCancel = allowCancel ~= false

    CreateThread(function()
        local ok = choosePlacementLoop()
        if ok then ok = fuseLoop() end
        if ok then detonatorLoop() end
    end)

    return true
end

RegisterNetEvent('awz_dynamite:client:start', function(allowCancel)
    runDynamite(allowCancel)
end)

DYNAMITE = DYNAMITE or {}
function DYNAMITE.Start(standing, allowCancel)
    if State.active then return false end
    State.active = true
    State.allowCancel = allowCancel ~= false

    CreateThread(function()
        if placeDynamite(standing and true or false) then
            startFuseStage()
            if fuseLoop() then
                detonatorLoop()
            end
        else
            cleanup(false)
        end
    end)

    return true
end

function DYNAMITE.Stop()
    cleanup(false)
end

function DYNAMITE.IsInDynamite()
    return State.active
end

function DYNAMITE.IsInFuses()
    return State.stage == 'fuse'
end

function DYNAMITE.IsInDetonator()
    return State.stage == 'detonator'
end

exports('DYNAMITE', function()
    return DYNAMITE
end)

if Config.Command then
    RegisterCommand(Config.Command, function()
        -- Direct client fallback for local tests without inventory removal.
        if Config.DevMode then
            runDynamite(false)
        else
            notify('Comando dev disattivato. Usa item: ' .. Config.UseItem)
        end
    end, false)
end

AddEventHandler('onResourceStop', function(res)
    if res ~= RESOURCE then return end
    cleanup(false)
    for id in pairs(State.blastProps) do
        deleteBlastProp(id)
    end
    deleteBacchusGhostTrain()
end)
