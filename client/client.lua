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
    destructibleProps = {},
    destructibleDestroyed = {},
    railBlockerTrain = nil,
    breachedVaultWalls = {},
    vaultBreachObjects = {},
    vaultBreachFx = {},
    rhodesImapsDestroyedApplied = false,

    crouchWalkActive = false,
    crouchWalkToken = 0,
    crouchWalkLastSupportAt = 0,
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

RegisterNetEvent('awz_detonator:client:notify', notify)

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

local function getMovementConfig()
    local cfg = Config.WireMovement or {}
    return {
        enabled = cfg.enabled ~= false,
        crouch = cfg.crouch ~= false,
        minerWalk = cfg.minerWalk ~= false,
        maxMoveRate = tonumber(cfg.maxMoveRate or 0.55) or 0.55,
        supportInterval = tonumber(cfg.supportInterval or 1400) or 1400,
        blockRun = cfg.blockRun ~= false,
        forceDuckControl = cfg.forceDuckControl ~= false,
        duckControl = tonumber(cfg.duckControl or 0xDB096B85) or 0xDB096B85,

        disableMinerWalkWhenCrouched = cfg.disableMinerWalkWhenCrouched ~= false,
    }
end

local function getPedCrouchMovement(ped)
    local ok, result = pcall(function()
        return Citizen.InvokeNative(0xD5FE956C70FF370B, ped)
    end)
    return ok and result == true
end

local function setPedCrouchMovement(ped, state, immediately)
    pcall(function()
        Citizen.InvokeNative(0x7DE9692C6F64CFE8, ped, state and true or false, immediately ~= false)
    end)
end

local function forceNativeDuckThisFrame(ped)
    local cfg = getMovementConfig()
    if not cfg.enabled or not cfg.crouch then return end

    if cfg.forceDuckControl then
        pcall(function() SetControlNormal(0, cfg.duckControl or 0xDB096B85, 1.0) end)
    end
    setPedCrouchMovement(ped, true, true)
end

local function shouldUseMinerWireWalk(cfg)
    return cfg.enabled and cfg.minerWalk and not (cfg.crouch and cfg.disableMinerWalkWhenCrouched)
end

local function applyMinerWireWalk(ped, forceUpdate)
    local cfg = getMovementConfig()
    if not shouldUseMinerWireWalk(cfg) then return end

    pcall(function() Citizen.InvokeNative(-7911272635667285042, ped, 'arthur_healthy') end)
    pcall(function() Citizen.InvokeNative(-8505637587031116644, ped, 'carry_pitchfork') end)
    pcall(function() Citizen.InvokeNative(2452284214444829210, ped, true, true) end)
    pcall(function() Citizen.InvokeNative(4201987302474811675, ped, 'PITCH_FORKS') end)

    if forceUpdate then
        pcall(function() ForceEntityAiAndAnimationUpdate(ped, true) end)
    end
end

local function maintainMinerWireWalk(ped)
    local cfg = getMovementConfig()
    if not shouldUseMinerWireWalk(cfg) then return end

    pcall(function() Citizen.InvokeNative(-8505637587031116644, ped, 'carry_pitchfork') end)

    local now = GetGameTimer()
    if now - (State.crouchWalkLastSupportAt or 0) >= cfg.supportInterval then
        State.crouchWalkLastSupportAt = now
        pcall(function() Citizen.InvokeNative(2452284214444829210, ped, true, true) end)
        pcall(function() Citizen.InvokeNative(4201987302474811675, ped, 'PITCH_FORKS') end)
    end
end

local function blockWireRunControls(ped)
    local cfg = getMovementConfig()
    if not cfg.enabled or not cfg.blockRun then return end

    DisableControlAction(0, 0x8FFC75D6, true)
    DisableControlAction(0, 0xAC4BD4F1, true)
    DisableControlAction(0, 0xD9D0E1C0, true)

    pcall(function() SetPedMoveRateOverride(ped, cfg.maxMoveRate or 0.55) end)
    pcall(function() SetPedMaxMoveBlendRatio(ped, cfg.maxMoveRate or 0.55) end)
    pcall(function() SetPedDesiredMoveBlendRatio(ped, cfg.maxMoveRate or 0.55) end)
end

local function resetWireWalk(ped, clearTasks, reason)
    local cfg = getMovementConfig()
    ped = ped or PlayerPedId()
    if not ped or not DoesEntityExist(ped) then return end

    if cfg.crouch then

        setPedCrouchMovement(ped, false, true)
    end

    if cfg.minerWalk then

        pcall(function() Citizen.InvokeNative(0x58F7DB5BD8FA2288, ped) end)
        pcall(function() Citizen.InvokeNative(0x4FD80C3DD84B817B, ped) end)
        pcall(function() Citizen.InvokeNative(0x6A2F820452017EA2) end)
    end

    pcall(function() SetPedMoveRateOverride(ped, 1.0) end)

    if clearTasks then
        ClearPedSecondaryTask(ped)
        ClearPedTasks(ped)
    end

    pcall(function() ForceEntityAiAndAnimationUpdate(ped, true) end)
end

local function stopWireWalk(reason)
    if not State.crouchWalkActive then return end

    State.crouchWalkActive = false
    State.crouchWalkToken = (State.crouchWalkToken or 0) + 1
    local token = State.crouchWalkToken
    resetWireWalk(PlayerPedId(), false, reason or 'stop')

    CreateThread(function()
        Wait(250)
        if token ~= State.crouchWalkToken or State.crouchWalkActive then return end
        resetWireWalk(PlayerPedId(), false, 'delayed_250')

        Wait(650)
        if token ~= State.crouchWalkToken or State.crouchWalkActive then return end
        resetWireWalk(PlayerPedId(), false, 'delayed_900')
    end)
end

local function startWireWalk()
    local cfg = getMovementConfig()
    if not cfg.enabled then return end

    State.crouchWalkToken = (State.crouchWalkToken or 0) + 1
    local token = State.crouchWalkToken
    State.crouchWalkActive = true
    State.crouchWalkLastSupportAt = 0

    local ped = PlayerPedId()
    applyMinerWireWalk(ped, true)
    if cfg.crouch then
        forceNativeDuckThisFrame(ped)
        Wait(0)
        forceNativeDuckThisFrame(ped)
    end

    CreateThread(function()
        while State.crouchWalkActive and token == State.crouchWalkToken do
            local loopPed = PlayerPedId()
            if DoesEntityExist(loopPed) and not IsPedDeadOrDying(loopPed, true) then
                maintainMinerWireWalk(loopPed)
                blockWireRunControls(loopPed)

                if cfg.crouch then

                    forceNativeDuckThisFrame(loopPed)
                end

                if cfg.maxMoveRate and cfg.maxMoveRate > 0.0 and cfg.maxMoveRate < 1.15 then
                    pcall(function() SetPedMoveRateOverride(loopPed, cfg.maxMoveRate) end)
                    pcall(function() SetPedMaxMoveBlendRatio(loopPed, cfg.maxMoveRate) end)
                    pcall(function() SetPedDesiredMoveBlendRatio(loopPed, cfg.maxMoveRate) end)
                end
            else
                stopWireWalk('ped_dead_or_missing')
                break
            end
            Wait(0)
        end
    end)
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
    stopWireWalk('cleanup')
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
    TriggerServerEvent('awz_detonator:server:refund')
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

local function startWireStage()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    State.spool = createObject(Config.Props.spool, coords, true)
    if State.spool then
        AttachEntityToEntity(State.spool, ped, GetEntityBoneIndexByName(ped, 'PH_L_Hand'), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, false, false, false, 0, true, false, false)
        SetEntityVisible(State.spool, true)
        createRopeBetween(State.spool, State.dynamite)
    end

    State.stage = 'wire'
    startWireWalk()
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
    TriggerServerEvent('awz_detonator:server:detonate', { x = coords.x, y = coords.y, z = coords.z })
end

local function handleLocalExplosion(coords)
    if not coords then return end

    AddExplosion(coords.x, coords.y, coords.z, Config.ExplosionType or 26, Config.RangeDamage or 5.0, true, false, Config.CameraShake or 2.0)
    stopWireWalk('exploded')
    notify(Config.Language.exploded)

    deleteEntity(State.dynamite)
    State.dynamite = nil
    Wait(1800)
    cleanup(false)
end

RegisterNetEvent('awz_detonator:client:doExplosion', handleLocalExplosion)

local function handleStopPlacement()
    cleanup(false)
end

RegisterNetEvent('awz_detonator:client:stopPlacement', handleStopPlacement)

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

    local cars = Citizen.InvokeNative(0x635423D55CA84FC8, trainHash)
    if not cars or cars == 0 then
        dbg(('invalid train config for rail blocker train: %s'):format(tostring(trainHash)))
        return false
    end

    for index = 0, cars - 1 do
        local model = Citizen.InvokeNative(0x8DF5F6A19F99F0D5, trainHash, index)
        if model and model ~= 0 then
            RequestModel(model)
            local timeout = GetGameTimer() + 5000
            while not HasModelLoaded(model) do
                Wait(10)
                if GetGameTimer() > timeout then
                    dbg(('timeout loading rail blocker train car model: %s'):format(tostring(model)))
                    return false
                end
            end
        end
    end

    return true
end

local function deleteRailBlockerTrain()
    local train = State.railBlockerTrain
    if train and train ~= 0 and DoesEntityExist(train) then
        SetEntityAsMissionEntity(train, true, true)
        pcall(function() DeleteVehicle(train) end)
        pcall(function() DeleteEntity(train) end)
    end
    State.railBlockerTrain = nil
end

local function spawnRailBlockerTrain()
    local cfg = Config.RailBridgeCollapse and Config.RailBridgeCollapse.blockerTrain
    if not (cfg and cfg.enabled) then
        deleteRailBlockerTrain()
        return
    end

    if State.railBlockerTrain and State.railBlockerTrain ~= 0 and DoesEntityExist(State.railBlockerTrain) then
        return
    end

    local trainHash = joaat(cfg.config or 'engine_config')
    if not loadTrainCars(trainHash) then return end

    local c = cfg.coords or vector3(499.69, 1768.78, 188.77)
    local train = Citizen.InvokeNative(0xC239DBD9A57D2A71, trainHash, c.x, c.y, c.z, false, false, true, false)
    if train and train ~= 0 then
        State.railBlockerTrain = train
        Citizen.InvokeNative(0xDFBA6BBFF7CCAFBB, train, 0.0)
        Citizen.InvokeNative(0x01021EB2E96B793C, train, 0.0)
    end
end

RegisterNetEvent('awz_detonator:client:railBridgeCollapse', function()
    local cfg = Config.RailBridgeCollapse
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
    spawnRailBlockerTrain()
end)

local function getVaultBreachConfig(id)
    local cfg = Config.VaultBreaches
    if not (cfg and cfg.banks) then return nil end
    for _, bank in ipairs(cfg.banks) do
        if bank.id == id then return bank end
    end
    return nil
end

local function cleanupVaultBreachObjects(id)
    local objects = State.vaultBreachObjects[id]
    if type(objects) == 'table' then
        for _, ent in pairs(objects) do
            deleteEntity(ent)
        end
    end
    State.vaultBreachObjects[id] = {}
end

local function stopVaultBreachFx(id)
    local fxList = State.vaultBreachFx[id]
    if type(fxList) == 'table' then
        for _, fx in ipairs(fxList) do
            if fx then
                pcall(function()
                    Citizen.InvokeNative(0x459598F579C98929, fx, false)
                end)
            end
        end
    end
    State.vaultBreachFx[id] = {}
end

local function requestPtfxAsset(asset)
    if not asset or asset == '' then return false end
    local hash = GetHashKey(asset)

    if Citizen.InvokeNative(0x65BB72F29138F5D6, hash) then
        return true
    end

    Citizen.InvokeNative(-958645240002163057, hash)

    local timeout = GetGameTimer() + 5000
    while not Citizen.InvokeNative(0x65BB72F29138F5D6, hash) do
        Wait(0)
        if GetGameTimer() > timeout then
            dbg(('ptfx asset timeout: %s'):format(tostring(asset)))
            return false
        end
    end

    return true
end

local function startLoopedPtfx(asset, effect, x, y, z, rx, ry, rz, scale)
    if not requestPtfxAsset(asset) then return nil end

    Citizen.InvokeNative(-6841618196140335854, asset)
    return Citizen.InvokeNative(
        -5029809955846070982,
        effect,
        x, y, z,
        rx or 0.0, ry or 0.0, rz or 0.0,
        scale or 1.0,
        0.0, 0.0, 0.0,
        0, 0, 0
    )
end

local function runVaultBreachSmoke(id, effects)
    stopVaultBreachFx(id)

    local handles = {}
    for _, fx in ipairs(effects or {}) do
        local handle = startLoopedPtfx(
            fx.asset,
            fx.effect,
            fx.coords.x, fx.coords.y, fx.coords.z,
            fx.rotation and fx.rotation.x or 0.0,
            fx.rotation and fx.rotation.y or 0.0,
            fx.rotation and fx.rotation.z or 0.0,
            fx.scale or 1.0
        )
        if handle then handles[#handles + 1] = handle end
        Wait(100)
    end

    State.vaultBreachFx[id] = handles

    local smokeTime = tonumber((Config.VaultBreaches and Config.VaultBreaches.smokeTime) or 240000) or 240000
    if smokeTime > 0 and #handles > 0 then
        CreateThread(function()
            Wait(smokeTime)
            stopVaultBreachFx(id)
        end)
    end
end

local function refreshInteriorSafely(interior, forceToggle)
    pcall(function()
        if forceToggle then
            DisableInterior(interior, true)
            Wait(0)
            DisableInterior(interior, false)
        end

        if RefreshInterior then RefreshInterior(interior) end
    end)
end

local function activateInteriorEntitySets(interior, interiorName, sets, forceToggle)
    if not interior or type(sets) ~= 'table' then return end

    for _, setName in ipairs(sets) do
        pcall(function()
            ActivateInteriorEntitySet(interior, setName)
        end)
    end

    refreshInteriorSafely(interior, forceToggle == true)
end

local function deactivateInteriorEntitySets(interior, interiorName, sets, forceToggle)
    if not interior or type(sets) ~= 'table' then return end

    for _, setName in ipairs(sets) do
        pcall(function()
            DeactivateInteriorEntitySet(interior, setName)
        end)
    end

    refreshInteriorSafely(interior, forceToggle == true)
end

local function applyRhodesVaultStateDestroyed()
    local doorHash = 3483244267

    pcall(function()
        Citizen.InvokeNative(-2769104647502929274, doorHash, 1, 1, 0, 0, 0, 0)
        Citizen.InvokeNative(7758457796463198035, doorHash, 0)
    end)
end

local function applyRhodesVaultImapsBreached(force)

    if State.rhodesImapsDestroyedApplied and force ~= true then return end

    pcall(function() RemoveImap(518127510) end)
    pcall(function() RemoveImap(828093818) end)
    pcall(function() RequestImap(758684739) end)
    pcall(function() RequestImap(1570711119) end)
    pcall(function() RequestImap(-661825463) end)

    State.rhodesImapsDestroyedApplied = true
end

local function applyRhodesVaultInteriorBreached(forceToggle)

    activateInteriorEntitySets(29442, 'Rhodes vault', { 'rhobank_int_wallb' }, forceToggle)
    deactivateInteriorEntitySets(29442, 'Rhodes vault', { 'rhobank_int_walla' }, false)
    applyRhodesVaultStateDestroyed()
end

local function applyRhodesVaultBreached(playFx, reapplyOnly)
    if not reapplyOnly then
        applyRhodesVaultImapsBreached(false)
        applyRhodesVaultInteriorBreached(true)
    else

        applyRhodesVaultInteriorBreached(false)
    end

    if playFx then
        AddExplosion(1289.2504882812, -1316.3029785156, 76.542404174804, (Config.VaultBreaches and Config.VaultBreaches.explosionType) or 25, (Config.VaultBreaches and Config.VaultBreaches.explosionDamageScale) or 5.0, true, false, 0)
        runVaultBreachSmoke('rhodes_bank_wall', {
            {
                asset = 'scr_odr1',
                effect = 'scr_od1_camp_smoke',
                coords = vector3(1288.5512695312, -1317.103881836, 75.760139465332),
                rotation = vector3(-90.0, 0.0, 0.0),
                scale = 7.0,
            },
            {
                asset = 'scr_std1',
                effect = 'scr_nbd1_smoke_02',
                coords = vector3(1288.5512695312, -1317.103881836, 74.760139465332),
                rotation = vector3(90.0, 90.0, 90.0),
                scale = 1.0,
            },
            {
                asset = 'scr_net_moon5',
                effect = 'scr_net_moon5_player_smoke',
                coords = vector3(1288.5512695312, -1317.103881836, 72.760139465332),
                rotation = vector3(0.0, 0.0, 0.0),
                scale = 5.0,
            },
        })
    end
end

local function applySaintDenisVaultSealed()
    local id = 'saint_denis_bank_wall'
    if State.breachedVaultWalls[id] then return end

    if State.vaultBreachObjects[id] and State.vaultBreachObjects[id].wall and DoesEntityExist(State.vaultBreachObjects[id].wall) then
        return
    end

    cleanupVaultBreachObjects(id)

    pcall(function() RemoveImap(-1026473536) end)
    pcall(function() RequestImap(1017355491) end)
    pcall(function() RequestImap(-604091710) end)

    local wall = createObject('s_combankwall_b4', vector3(2653.2529296875, -1291.990966796875, 51.24435424804687), false)
    if wall then
        SetEntityRotation(wall, 0.0, 0.0, 0.0, 2, true)
        SetEntityCoords(wall, 2653.2529296875, -1291.990966796875, 51.24435424804687, false, false, false, false)
        FreezeEntityPosition(wall, true)
        SetEntityAsMissionEntity(wall, true, true)
    end

    State.vaultBreachObjects[id] = { wall = wall }
end

local function applySaintDenisVaultBreached(playFx)
    local id = 'saint_denis_bank_wall'
    cleanupVaultBreachObjects(id)

    pcall(function() RemoveImap(-1026473536) end)
    pcall(function() RemoveImap(1017355491) end)

    local wall = createObject('s_combankwall_after', vector3(2653.2529296875, -1291.990966796875, 51.24435424804687), false)
    local debris = createObject('des_nbd1_bankwall_int_end', vector3(2651.3271484375, -1292.99365234375, 49.35), false)

    if wall then
        SetEntityRotation(wall, 0.0, 0.0, 0.0, 2, true)
        SetEntityCoords(wall, 2653.2529296875, -1291.990966796875, 51.24435424804687, false, false, false, false)
        FreezeEntityPosition(wall, true)
        SetEntityAsMissionEntity(wall, true, true)
    end

    if debris then
        SetEntityRotation(debris, 0.0, 0.0, 0.0, 2, true)
        SetEntityCoords(debris, 2651.3271484375, -1292.99365234375, 54.23934555053711, false, false, false, false)
        FreezeEntityPosition(debris, true)
        SetEntityAsMissionEntity(debris, true, true)
    end

    State.vaultBreachObjects[id] = { wall = wall, debris = debris }

    if playFx then
        AddExplosion(2653.995361328125, -1292.08447265625, 51.49860382080078, (Config.VaultBreaches and Config.VaultBreaches.explosionType) or 25, (Config.VaultBreaches and Config.VaultBreaches.explosionDamageScale) or 5.0, true, false, 0)
        runVaultBreachSmoke(id, {
            {
                asset = 'scr_odr1',
                effect = 'scr_od1_camp_smoke',
                coords = vector3(2653.62939453125, -1291.9482421875, 51.95564270019531),
                rotation = vector3(-90.0, 0.0, 0.0),
                scale = 7.0,
            },
            {
                asset = 'scr_std1',
                effect = 'scr_nbd1_smoke_02',
                coords = vector3(2653.62939453125, -1291.9482421875, 50.95564270019531),
                rotation = vector3(90.0, 90.0, 90.0),
                scale = 1.0,
            },
            {
                asset = 'scr_net_moon5',
                effect = 'scr_net_moon5_player_smoke',
                coords = vector3(2653.62939453125, -1291.9482421875, 51.95564270019531),
                rotation = vector3(0.0, 0.0, 0.0),
                scale = 5.0,
            },
        })
    end
end

local function applyVaultBreachState(id, playFx)
    local bank = getVaultBreachConfig(id)
    if not bank then return end

    if bank.type == 'rhodes' then
        applyRhodesVaultBreached(playFx)
    elseif bank.type == 'saintdenis' then
        applySaintDenisVaultBreached(playFx)
    end
end

local function ensureVaultBreachStateReapplyThread()
    if State.vaultBreachReapplyThread then return end
    State.vaultBreachReapplyThread = true

    CreateThread(function()
        local lastNearRhodes = false
        local lastInterior = 0
        local lastPeriodic = 0
        local target = vector3(1289.2504882812, -1316.3029785156, 76.542404174804)

        while true do
            Wait(1000)

            if State.breachedVaultWalls and State.breachedVaultWalls.rhodes_bank_wall then
                local ped = PlayerPedId()
                local coords = GetEntityCoords(ped)
                local nearRhodes = vdist(coords, target) <= 90.0
                local interior = 0

                pcall(function()
                    interior = GetInteriorFromEntity(ped) or 0
                end)

                if nearRhodes and (not lastNearRhodes or interior ~= lastInterior) then
                    applyRhodesVaultBreached(false, true)
                    lastPeriodic = GetGameTimer()
                elseif nearRhodes and (GetGameTimer() - lastPeriodic) > 30000 then

                    applyRhodesVaultBreached(false, true)
                    lastPeriodic = GetGameTimer()
                end

                lastNearRhodes = nearRhodes
                lastInterior = interior
            end
        end
    end)
end

RegisterNetEvent('awz_detonator:client:syncVaultBreaches', function(destroyed)
    State.breachedVaultWalls = destroyed or {}

    if State.breachedVaultWalls.rhodes_bank_wall then
        applyRhodesVaultBreached(false)
        ensureVaultBreachStateReapplyThread()
    end

    if State.breachedVaultWalls.saint_denis_bank_wall then
        applySaintDenisVaultBreached(false)
    else
        applySaintDenisVaultSealed()
    end
end)

RegisterNetEvent('awz_detonator:client:vaultBreach', function(id)
    if not id then return end
    State.breachedVaultWalls[id] = true
    applyVaultBreachState(id, true)
    if id == 'rhodes_bank_wall' then
        ensureVaultBreachStateReapplyThread()
    end
end)

local function getDestructiblePropCoords(entry)
    if not entry or not entry.coords then return nil end

    local cfg = Config.DestructibleProps or {}
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

local function deleteDestructibleProp(id)
    local ent = State.destructibleProps[id]
    if ent and ent ~= 0 and DoesEntityExist(ent) then
        SetEntityAsMissionEntity(ent, true, true)
        DeleteEntity(ent)
    end
    State.destructibleProps[id] = nil
end

local function spawnDestructibleProp(entry)
    if not entry or not entry.id or State.destructibleProps[entry.id] then return end
    if State.destructibleDestroyed[entry.id] then return end

    local c = getDestructiblePropCoords(entry)
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
    State.destructibleProps[entry.id] = obj
end

local function refreshDestructibleProps()
    local cfg = Config.DestructibleProps
    if not (cfg and cfg.enabled and type(cfg.list) == 'table') then return end

    local ped = PlayerPedId()
    local pcoords = GetEntityCoords(ped)
    local spawnDistance = tonumber(cfg.spawnDistance) or 150.0

    for _, entry in ipairs(cfg.list) do
        if entry.id then
            if State.destructibleDestroyed[entry.id] then
                deleteDestructibleProp(entry.id)
            else
                local c = getDestructiblePropCoords(entry)
                if c then
                    local dist = vdist(pcoords, vector3(c.x, c.y, c.z))
                    if dist <= spawnDistance then
                        spawnDestructibleProp(entry)
                    else
                        deleteDestructibleProp(entry.id)
                    end
                end
            end
        end
    end
end

RegisterNetEvent('awz_detonator:client:syncDestructibleProps', function(destroyed)
    State.destructibleDestroyed = destroyed or {}
    refreshDestructibleProps()
end)

RegisterNetEvent('awz_detonator:client:destroyDestructibleProp', function(id)
    if not id then return end
    State.destructibleDestroyed[id] = true
    deleteDestructibleProp(id)
end)

CreateThread(function()
    Wait(2000)
    TriggerServerEvent('awz_detonator:server:requestDestructibleProps')
    TriggerServerEvent('awz_detonator:server:requestRailBridgeCollapse')
    TriggerServerEvent('awz_detonator:server:requestVaultBreaches')

    while true do
        Wait(2000)
        refreshDestructibleProps()
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

        setPrompt(State.prompts.cancel, false, false, Config.Language.cancel)

        if promptPressed(State.prompts.use) then
            if placeDynamite(false) then
                startWireStage()
                return true
            end
            refundAndStop(Config.Language.cancelled)
            return false
        end
    end

    return false
end

local function wireLoop()
    ensurePrompts()
    setPrompt(State.prompts.ground, false, false)

    while State.active and State.stage == 'wire' do
        Wait(0)
        local ped = PlayerPedId()
        blockWireRunControls(ped)
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
        blockWireRunControls(PlayerPedId())
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

local function runDetonatorPlacement(allowCancel)
    if State.active then
        notify(Config.Language.busy)
        return false
    end

    State.active = true
    State.allowCancel = allowCancel ~= false

    CreateThread(function()
        local ok = choosePlacementLoop()
        if ok then ok = wireLoop() end
        if ok then detonatorLoop() end
    end)

    return true
end

local function handleStartDetonatorPlacement(allowCancel)
    runDetonatorPlacement(allowCancel)
end

RegisterNetEvent('awz_detonator:client:start', handleStartDetonatorPlacement)

AWZ_DETONATOR = AWZ_DETONATOR or {}
function AWZ_DETONATOR.Start(standing, allowCancel)
    if State.active then return false end
    State.active = true
    State.allowCancel = allowCancel ~= false

    CreateThread(function()
        if placeDynamite(standing and true or false) then
            startWireStage()
            if wireLoop() then
                detonatorLoop()
            end
        else
            cleanup(false)
        end
    end)

    return true
end

function AWZ_DETONATOR.Stop()
    cleanup(false)
end

function AWZ_DETONATOR.IsActive()
    return State.active
end

function AWZ_DETONATOR.IsInWires()
    return State.stage == 'wire'
end

function AWZ_DETONATOR.IsInDetonator()
    return State.stage == 'detonator'
end

exports('AWZ_DETONATOR', function()
    return AWZ_DETONATOR
end)

if Config.Command then
    RegisterCommand(Config.Command, function()

        if Config.DevMode then
            runDetonatorPlacement(false)
        else
            notify('Comando dev disattivato. Usa item: ' .. Config.UseItem)
        end
    end, false)
end

AddEventHandler('onResourceStop', function(res)
    if res ~= RESOURCE then return end
    cleanup(false)
    for id in pairs(State.destructibleProps) do
        deleteDestructibleProp(id)
    end
    deleteRailBlockerTrain()
    for id in pairs(State.vaultBreachFx or {}) do stopVaultBreachFx(id) end
    for id in pairs(State.vaultBreachObjects or {}) do cleanupVaultBreachObjects(id) end
end)
