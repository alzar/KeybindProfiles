local _, NS = ...
local KeybindProfiles = NS.KeybindProfiles

KeybindProfiles.DB_VERSION = 2
KeybindProfiles.DEFAULT_PROFILE_NAME = "Default"
KeybindProfiles.DEFAULT_RULE_PRIORITY = 100
KeybindProfiles.MAX_BINDING_KEYS = 2
KeybindProfiles.CONDITION_KEYS = {
    "specializationID",
    "instanceType",
    "difficultyID",
    "mapID",
}

KeybindProfiles.DEFAULT_CHARACTER_DB = {
    activeProfile = KeybindProfiles.DEFAULT_PROFILE_NAME,
    autosave = false,
    autoLoadEnabled = true,
    rules = {},
}

KeybindProfiles.DEFAULT_DB = {
    version = KeybindProfiles.DB_VERSION,
    global = {
        notifications = true,
    },
    profiles = {
        [KeybindProfiles.DEFAULT_PROFILE_NAME] = {
            bindings = {},
        },
    },
    characters = {},
    migration = {
        legacyImported = false,
        pendingLegacySpecMaps = {},
    },
}

function KeybindProfiles:CopyTable(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for key, child in pairs(value) do
        copy[key] = self:CopyTable(child)
    end

    return copy
end

function KeybindProfiles:CopyDefaults(defaults, target)
    if type(defaults) ~= "table" then
        return defaults
    end

    if type(target) ~= "table" then
        target = {}
    end

    for key, value in pairs(defaults) do
        if type(value) == "table" then
            target[key] = self:CopyDefaults(value, target[key])
        elseif target[key] == nil then
            target[key] = value
        end
    end

    return target
end

function KeybindProfiles:NormalizeString(value)
    if type(value) ~= "string" then
        return nil
    end

    local trimmed = strtrim(value)
    if trimmed == "" then
        return nil
    end

    return trimmed
end
