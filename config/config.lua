Config = {}

Config.UseItem = 'detonating_dynamite'
Config.DetonatorItem = 'detonator'

-- Detonator metadata/uses
Config.DetonatorUses = {
    enabled = true,
    default = 10,
    metadataKey = 'uses',
    showDescription = true,
}
Config.CloseInventoryOnUse = true

-- Test command. Set false in production if you only want the usable item.
Config.Command = 'awzdynamite'
Config.DevMode = true

-- Controls
-- Default: R place dynamite / place detonator / detonate, BACKSPACE cancel. E is kept reserved/disabled for legacy ground prompt compatibility.
Config.KeyUse = 0xE30CD707      -- R
Config.KeyGround = 0xCEFD9220   -- E (disabled/reserved)
Config.KeyCancel = 0x156F7119   -- BACKSPACE

-- Distances
Config.RangeMin = {
    interior = 5.0,
    exterior = 15.0,
}
Config.RangeDamage = 5.0
Config.ExplosionType = 26
Config.CameraShake = 2.0

-- Props
Config.Props = {
    standingDynamite = 'p_stickydymt_bundle',
    groundDynamite = 'p_dynamite04x',
    handDynamite = 'p_stickydymt_single',
    spool = 'p_cs_fusespool01x',
    detonator = 'p_detonator01x',
}



-- Explodable world props.
-- persistent = true  -> saved in DB when destroyed, never respawns until DB reset.
-- persistent = false -> destroyed only for the current server session, respawns after restart.
Config.BlastProps = {
    enabled = true,
    databaseTable = 'awz_detonator_blast_props',
    checkRadiusDefault = 5.0,
    spawnDistance = 150.0,
    -- Global Z offset applied to every configured blast prop when spawning/checking explosion radius.
    -- Keep this at -1.0 to place props one meter below the configured coords.
    zOffset = -1.0,
    list = {
        {
            id = '1',
            -- label = 'Roccia ingresso miniera',
            model = 'alp_rock_09',
            coords = vector4(-2666.02685546875, 690.2482299804688, 183.65350341796875, 106.43103790283203),
            radius = 6.0,
            persistent = true,
            placeOnGround = false,
        },
        {
            id = '2',
            -- label = 'Roccia ingresso miniera',
            model = 'alp_rock_02',
            coords = vector4(-2683.126220703125, 689.94189453125, 178.10023498535156, -94.98395538330078),
            radius = 6.0,
            persistent = true,
            placeOnGround = false,
        },
    }
}



-- Bacchus Station bridge destruction.
-- If a dynamite explosion happens within radius of coords, all clients will
-- receive the same Rayfire bridge collapse used by bcc-train.
Config.BacchusBridge = {
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
    -- bcc-train spawns a visible ghost train to slow/stop trains near the destroyed bridge.
    -- It is disabled by default here because it is visible and ruins immersion.
    -- Set enabled = true only if you prefer the original bcc-train blocker behavior.
    ghostTrain = {
        enabled = false,
        config = 'engine_config',
        coords = vector3(499.69, 1768.78, 188.77),
    },
}

-- Optional notifications.
-- Supported fallback order: awz_libs event, vorp tip, print.
Config.Notify = {
    useAwzLibs = true,
    awzEvent = 'awz_Notify:Bottom',
    awzExportResource = 'awz_libs',
    awzExport = 'ShowBottom',
    vorpEvent = 'vorp:TipRight',
    duration = 4000,
}

-- Logs. Disabled by default because JD_logsV3 is not a hard dependency.
Config.EnableLogs = false
Config.LogChannel = 'dynamite'

Config.Language = {
    chooseTitle = 'Dinamite',
    chooseGround = 'Piazza la dinamite',
    placeDetonator = 'Piazza detonatore',
    detonate = 'Premi',
    cancel = 'Annulla',
    distance = 'Distanza: %sm',
    tooClose = 'Allontanati dalla dinamite per piazzare il detonatore.',
    cancelled = 'Piazzamento annullato.',
    noItem = 'Non possiedi la dinamite con filo.',
    noDetonator = 'Serve un detonatore per usare questa dinamite.',
    detonatorEmpty = 'Il detonatore non ha più utilizzi disponibili.',
    busy = 'Stai già usando una dinamite.',
    exploded = 'Dinamite esplosa.',
    detonatorUses = 'Utilizzi detonatore: %s/%s',
    refunded = 'Dinamite restituita.',
}
