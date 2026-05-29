Locales = Locales or {}
Config = Config or {}

local DEFAULT_LOCALE = 'it'
local selectedLocale = tostring(Config.Locale or DEFAULT_LOCALE):lower()

local function copyMissing(target, fallback)
    if type(target) ~= 'table' then target = {} end
    if type(fallback) ~= 'table' then return target end

    for key, value in pairs(fallback) do
        if target[key] == nil then
            target[key] = value
        end
    end

    return target
end

local fallbackLanguage = Locales[DEFAULT_LOCALE] or {}
local selectedLanguage = Locales[selectedLocale]

if type(selectedLanguage) ~= 'table' then
    print(('^3[awz_detonator]^0 Locale "%s" not found. Falling back to "%s".'):format(selectedLocale, DEFAULT_LOCALE))
    selectedLocale = DEFAULT_LOCALE
    selectedLanguage = fallbackLanguage
end

Config.Locale = selectedLocale
Config.Language = copyMissing(selectedLanguage, fallbackLanguage)

-- Metadata labels/descriptions are translated too, but metadata.label is never touched.
Config.DetonatorDurability = Config.DetonatorDurability or {}
Config.DetonatorDurability.brokenTooltip = Config.Language.brokenTooltip or Config.DetonatorDurability.brokenTooltip or 'Guasto'
Config.DetonatorDurability.brokenDescription = Config.Language.brokenDescription or Config.DetonatorDurability.brokenDescription or 'Il detonatore è guasto.'
