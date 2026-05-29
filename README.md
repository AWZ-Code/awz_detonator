# AWZ Detonator

AWZ Detonator is a RedM resource for VORP servers that adds a complete wired dynamite and detonator system.

Players can place dynamite, walk away while pulling the wire, place a detonator at a configurable distance, and trigger the explosion manually. The resource also supports detonator durability metadata, multilingual prompts and notifications, destructible world props, optional bridge collapse logic, and configurable vault breach points.

## Features

- Wired dynamite placement flow
- Required detonator item
- Detonator durability stored in item metadata
- Automatic broken detonator metadata when uses reach zero
- Native prompt-based interaction flow
- Multilingual prompts and notifications
- Configurable language from `config/config.lua`
- Crouched movement while pulling the wire
- Sprint/run lock while pulling the wire
- Configurable minimum placement distance for interiors and exteriors
- Configurable explosion type, damage scale and camera shake
- Persistent destructible props through oxmysql
- Optional rail bridge collapse system
- Optional vault breach points for map/interior breach gameplay
- Optional AWZ Libs notification support with VORP notification fallback
- Client export for external resources
- Developer command fallback

## Requirements

- RedM server
- VORP Inventory
- oxmysql

`oxmysql` is required by the resource manifest. It is used for persistent destructible props. If you do not use persistent destructible props, you can disable that system in the config, but the dependency is still declared by default.

## Installation

1. Download or clone the resource.
2. Place the `awz_detonator` folder inside your server resources directory.
3. Import the SQL file:

```sql
sql/SQL.sql
```

4. Add the required items to your VORP Inventory items table.
5. Configure the resource in:

```txt
config/config.lua
```

6. Add the resource to your `server.cfg` after its dependencies:

```cfg
ensure oxmysql
ensure vorp_inventory
ensure awz_detonator
```

## Required Items

The default item names are:

```lua
Config.UseItem = 'detonating_dynamite'
Config.DetonatorItem = 'detonator'
```

`Config.UseItem` is the wired dynamite item consumed when the placement starts.

`Config.DetonatorItem` is the detonator item required to start the placement and used to trigger the final explosion.

Example item names can be changed freely, but they must match your VORP Inventory database item names.

## Basic Gameplay Flow

1. The player uses the configured wired dynamite item.
2. The server checks if the player has a valid detonator.
3. The wired dynamite item is removed from the inventory.
4. The player places the dynamite using the native prompt.
5. The player walks away while pulling the wire.
6. While pulling the wire, the player can be forced into crouched movement and prevented from running.
7. Once the minimum distance is reached, the player can place the detonator.
8. The player presses the prompt again to detonate.
9. The explosion is synchronized.
10. One detonator use is consumed only after a valid detonation.
11. If the player cancels before detonation, the wired dynamite is refunded.

## Language Configuration

The resource includes four locale files:

```txt
locales/it.lua
locales/en.lua
locales/fr.lua
locales/de.lua
```

Set the active language in `config/config.lua`:

```lua
Config.Locale = 'en'
```

Available languages:

| Code | Language |
| --- | --- |
| `it` | Italian |
| `en` | English |
| `fr` | French |
| `de` | German |

All prompts, notifications and default broken detonator metadata are loaded from the selected locale.

## Controls

Default controls:

| Action | Default Key |
| --- | --- |
| Place dynamite / place detonator / detonate | `R` |
| Choose ground placement mode | configured by `Config.KeyGround` |
| Cancel placement | `BACKSPACE` |

Control hashes are configured in `config/config.lua`:

```lua
Config.KeyUse = 0xE30CD707
Config.KeyGround = 0xCEFD9220
Config.KeyCancel = 0x156F7119
```

## Main Configuration

### Locale

```lua
Config.Locale = 'en'
```

Chooses the active language file.

### Items

```lua
Config.UseItem = 'detonating_dynamite'
Config.DetonatorItem = 'detonator'
```

Defines the inventory item used for wired dynamite and the required detonator item.

### Inventory Behavior

```lua
Config.CloseInventoryOnUse = true
```

When enabled, the player inventory is closed after using the wired dynamite item.

### Developer Command

```lua
Config.Command = 'awzdetonator'
Config.DevMode = false
```

The command is only useful when `Config.DevMode` is enabled. In production, keep `Config.DevMode = false`.

### Distance Settings

```lua
Config.RangeMin = {
    interior = 5.0,
    exterior = 15.0,
}
```

Defines the minimum distance required before the player can place the detonator.

`interior` is used when the player is inside an interior.

`exterior` is used outdoors.

### Explosion Settings

```lua
Config.RangeDamage = 5.0
Config.ExplosionType = 26
Config.CameraShake = 2.0
```

Controls the explosion radius/damage behavior, explosion type and camera shake intensity.

### Props

```lua
Config.Props = {
    standingDynamite = 'p_stickydymt_bundle',
    groundDynamite = 'p_dynamite04x',
    handDynamite = 'p_stickydymt_single',
    spool = 'p_cs_wirespool01x',
    detonator = 'p_detonator01x',
}
```

Defines the models used during placement.

## Detonator Durability

```lua
Config.DetonatorDurability = {
    enabled = true,
    default = 10,
    metadataKey = 'uses',
    showDescription = true,
    brokenTooltip = nil,
    brokenDescription = nil,
}
```

When enabled, each detonator has a limited number of uses.

- `default`: default number of uses for new detonators without metadata
- `metadataKey`: metadata key used to store remaining uses
- `showDescription`: updates the metadata description with current uses
- `brokenTooltip`: optional custom tooltip when the detonator reaches zero uses
- `brokenDescription`: optional custom description when the detonator reaches zero uses

If `brokenTooltip` or `brokenDescription` are `nil`, the selected locale is used.

The resource does not rename the item label. It only updates metadata such as tooltip and description.

## Wire Movement

```lua
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
```

This controls the player movement while pulling the wire.

- `enabled`: enables or disables the full movement system
- `crouch`: forces crouched movement
- `minerWalk`: applies the configured walking style support
- `disableMinerWalkWhenCrouched`: prevents the walk style from visually overriding the crouch state
- `forceDuckControl`: forces the native crouch control behavior
- `duckControl`: control hash used for crouch/duck behavior
- `blockRun`: disables running and sprinting while pulling the wire
- `maxMoveRate`: limits movement speed
- `supportInterval`: refresh interval for movement support logic

The movement state is automatically reset after detonation, cancellation, player stop, or resource stop.

## Destructible Props

```lua
Config.DestructibleProps = {
    enabled = true,
    databaseTable = 'detonator_destructibles',
    checkRadiusDefault = 5.0,
    spawnDistance = 150.0,
    zOffset = -1.0,
    list = {}
}
```

This system allows configured world props to be destroyed by explosions.

Each prop entry supports:

```lua
{
    id = 'unique_id',
    model = 'prop_model_name',
    coords = vector4(x, y, z, heading),
    radius = 6.0,
    persistent = true,
    placeOnGround = false,
}
```

Field explanation:

- `id`: unique prop identifier
- `model`: prop model to spawn
- `coords`: spawn coordinates and heading
- `radius`: explosion detection radius
- `persistent`: saves destroyed state to the database
- `placeOnGround`: places the object on the ground after spawning

Persistent props are saved in the configured database table.

## Rail Bridge Collapse

```lua
Config.RailBridgeCollapse = {
    enabled = true,
    coords = vector3(492.01, 1774.41, 182.5),
    radius = 50.0,
    rayfireObject = 'des_trn3_bridge',
    rayfireSearchRadius = 10000.0,
    explosions = {},
    explosionType = 28,
    explosionDamageScale = 1.0,
    blockerTrain = {
        enabled = false,
        config = 'engine_config',
        coords = vector3(499.69, 1768.78, 188.77),
    },
}
```

This optional system triggers a rail bridge collapse when dynamite explodes within the configured radius.

Disable it if you do not want bridge-related gameplay:

```lua
Config.RailBridgeCollapse.enabled = false
```

## Vault Breaches

```lua
Config.VaultBreaches = {
    enabled = true,
    radius = 5.0,
    smokeTime = 240000,
    explosionType = 25,
    explosionDamageScale = 5.0,
    banks = {}
}
```

Vault breach points allow specific bank or interior locations to react to detonator explosions.

Each breach entry supports:

```lua
{
    id = 'unique_breach_id',
    label = 'Display label',
    type = 'rhodes',
    coords = vector3(x, y, z),
    radius = 5.0,
    persistent = false,
}
```

Field explanation:

- `id`: unique breach identifier
- `label`: readable label for administration/configuration
- `type`: breach handler type
- `coords`: explosion detection coordinates
- `radius`: custom detection radius for this breach
- `persistent`: reserved for persistent breach behavior

Default configured breach types:

- `rhodes`
- `saintdenis`

The resource includes a streamed map file used by the Saint Denis breach setup:

```txt
stream/new_com_03_strm_0.ymap
```

Do not place `.txt`, `.md` or other non-streamable files inside the `stream` folder.

## Notifications

```lua
Config.Notify = {
    useAwzLibs = true,
    awzEvent = 'awz_Notify:Bottom',
    awzExportResource = 'awz_libs',
    awzExport = 'ShowBottom',
    vorpEvent = 'vorp:TipRight',
    duration = 4000,
}
```

When `useAwzLibs` is enabled, the resource first tries to use the configured AWZ Libs notification event.

If AWZ Libs is disabled or unavailable, the resource falls back to the configured VORP notification event.

To use only VORP notifications:

```lua
Config.Notify.useAwzLibs = false
```

## Public Client Events

Start placement from another resource:

```lua
TriggerEvent('awz_detonator:client:start', false)
```

Stop current placement:

```lua
TriggerEvent('awz_detonator:client:stopPlacement')
```

Show a localized/custom notification through this resource:

```lua
TriggerEvent('awz_detonator:client:notify', 'Message text', 4000)
```

## Public Server Events

Start placement for a player:

```lua
TriggerClientEvent('awz_detonator:client:start', source, true)
```

The server-side usable item registration already handles normal inventory usage. External resources should usually trigger the client start only when they have already handled their own item validation.

## Client Export

```lua
local detonator = exports.awz_detonator:AWZ_DETONATOR()
```

Available export methods:

```lua
detonator.Start(removeItem, skipServerCheck)
detonator.Stop()
detonator.IsActive()
detonator.IsInWires()
detonator.IsInDetonator()
```

Example:

```lua
local detonator = exports.awz_detonator:AWZ_DETONATOR()

if not detonator.IsActive() then
    detonator.Start(false, true)
end
```

## Database

The SQL file creates the default table for persistent destructible props:

```sql
CREATE TABLE IF NOT EXISTS `detonator_destructibles` (
  `prop_id` VARCHAR(80) NOT NULL,
  `destroyed` TINYINT(1) NOT NULL DEFAULT 0,
  `destroyed_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`prop_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

If you change this config value:

```lua
Config.DestructibleProps.databaseTable = 'detonator_destructibles'
```

make sure your SQL table name matches it.

## Recommended Production Setup

For a public server, recommended settings are:

```lua
Config.Locale = 'en'
Config.DevMode = false
Config.CloseInventoryOnUse = true
Config.DetonatorDurability.enabled = true
Config.WireMovement.enabled = true
Config.WireMovement.blockRun = true
```

Disable any gameplay modules you do not use:

```lua
Config.DestructibleProps.enabled = false
Config.RailBridgeCollapse.enabled = false
Config.VaultBreaches.enabled = false
```

## Troubleshooting

### The usable item does not start the placement

Check that:

- `vorp_inventory` is started before `awz_detonator`
- `Config.UseItem` exists in your inventory database
- the player has the configured wired dynamite item
- the player also has the configured detonator item

### The detonator says it is broken

The detonator has reached zero uses according to its metadata.

Give the player a new detonator or edit/remove the metadata depending on your inventory workflow.

### The player cannot place the detonator

The player must move away from the dynamite until the configured minimum distance is reached.

Check:

```lua
Config.RangeMin.interior
Config.RangeMin.exterior
```

### Destructible props do not save

Check that:

- `oxmysql` is running
- `sql/SQL.sql` has been imported
- `Config.DestructibleProps.databaseTable` matches the database table name
- the prop entry has `persistent = true`

### Saint Denis breach does not load correctly

Make sure this file exists:

```txt
stream/new_com_03_strm_0.ymap
```

Also make sure there are no invalid files inside the `stream` folder.

### The player remains crouched or movement feels locked

The resource resets movement on cancel, detonation and resource stop. If another resource also forces locomotion or crouch state, check for conflicts with movement/animation scripts.

## File Structure

```txt
awz_detonator/
├── client/client.lua
├── config/config.lua
├── fxmanifest.lua
├── locales/de.lua
├── locales/en.lua
├── locales/fr.lua
├── locales/it.lua
├── server/server.lua
├── shared/locale.lua
├── sql/SQL.sql
└── stream/new_com_03_strm_0.ymap
```
