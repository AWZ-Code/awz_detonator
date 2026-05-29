Config = {}

Config.Locale = 'en'

Config.UseItem = 'detonating_dynamite'
Config.DetonatorItem = 'detonator'

Config.DetonatorDurability = {
    enabled = true,
    default = 10,
    metadataKey = 'uses',
    showDescription = true,

    brokenTooltip = nil,
    brokenDescription = nil,
}
Config.CloseInventoryOnUse = true

Config.Command = 'awzdetonator'
Config.DevMode = false

Config.KeyUse = 0xE30CD707
Config.KeyGround = 0xCEFD9220
Config.KeyCancel = 0x156F7119

Config.RangeMin = {
    interior = 5.0,
    exterior = 15.0,
}
Config.RangeDamage = 5.0
Config.ExplosionType = 26
Config.CameraShake = 2.0

Config.Props = {
    standingDynamite = 'p_stickydymt_bundle',
    groundDynamite = 'p_dynamite04x',
    handDynamite = 'p_stickydymt_single',
    spool = 'p_cs_wirespool01x',
    detonator = 'p_detonator01x',
}

Config.WireMovement = {
    enabled = true,

    crouch = true,

    minerWalk = true,

    disableMinerWalkWhenCrouched = true,

    forceDuckControl = true,
    duckControl = 0xDB096B85,

    blockRun = true,

    maxMoveRate = 0.55,

    supportInterval = 1400,
}

Config.DestructibleProps = {
    enabled = true,
    databaseTable = 'detonator_destructibles',
    checkRadiusDefault = 5.0,
    spawnDistance = 150.0,

    zOffset = -1.0,
    list = {
        {
            id = '1',

            model = 'alp_rock_09',
            coords = vector4(-2666.02685546875, 690.2482299804688, 183.65350341796875, 106.43103790283203),
            radius = 6.0,
            persistent = true,
            placeOnGround = false,
        },
        {
            id = '2',

            model = 'alp_rock_02',
            coords = vector4(-2683.126220703125, 689.94189453125, 178.10023498535156, -94.98395538330078),
            radius = 6.0,
            persistent = true,
            placeOnGround = false,
        },
        {
            id = '3',

            model = 'alp_rock_09',
            coords = vector4(-2706.443115234375, 710.7402954101562, 173.8036346435547, 37.66058349609375),
            radius = 6.0,
            persistent = true,
            placeOnGround = false,
        },
        {
            id = '4',

            model = 'alp_rock_04',
            coords = vector4(-2713.310546875, 699.204833984375, 173.60675048828125, 106.06769561767578),
            radius = 6.0,
            persistent = true,
            placeOnGround = false,
        },
        {
            id = '5',

            model = 'bgv_rock_04',
            coords = vector4(-2327.851806640625, 100.26724243164062, 219.6724395751953, 34.63912582397461),
            radius = 6.0,
            persistent = true,
            placeOnGround = false,
        },
        {
            id = '6',

            model = 'alp_rock_09',
            coords = vector4(-1517.4410400390625, 727.207275390625, 125.34468078613281, -8.00374889373779),
            radius = 6.0,
            persistent = true,
            placeOnGround = false,
        },
    }
}

Config.RailBridgeCollapse = {
    enabled = true,
    coords = vector3(492.01, 1774.41, 182.5),
    radius = 50.0,
    rayfireObject = 'des_trn3_bridge',
    rayfireSearchRadius = 10000.0,
    explosions = {
        vector3(521.13, 1754.46, 187.65),
        vector3(507.28, 1762.30, 187.77),
        vector3(527.21, 1748.86, 187.80),
    },
    explosionType = 28,
    explosionDamageScale = 1.0,

    blockerTrain = {
        enabled = false,
        config = 'engine_config',
        coords = vector3(499.69, 1768.78, 188.77),
    },
}

Config.VaultBreaches = {
    enabled = true,

    radius = 5.0,
    smokeTime = 240000,
    explosionType = 25,
    explosionDamageScale = 5.0,
    banks = {
        {
            id = 'rhodes_bank_wall',
            label = 'Banca Rhodes - Muro',
            type = 'rhodes',
            coords = vector3(1289.2504882812, -1316.3029785156, 76.542404174804),
            radius = 5.0,
            persistent = false,
        },
        {
            id = 'saint_denis_bank_wall',
            label = 'Banca Saint Denis - Muro',
            type = 'saintdenis',
            coords = vector3(2653.995361328125, -1292.08447265625, 51.49860382080078),
            radius = 5.0,
            persistent = false,
        },
    }
}

Config.Notify = {
    useAwzLibs = true,
    awzEvent = 'awz_Notify:Bottom',
    awzExportResource = 'awz_libs',
    awzExport = 'ShowBottom',
    vorpEvent = 'vorp:TipRight',
    duration = 4000,
}