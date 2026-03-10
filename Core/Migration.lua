local _, NS = ...
local KeybindProfiles = NS.KeybindProfiles

local function AddBindingKey(target, seen, value, maxKeys)
    if type(value) ~= "string" or value == "" or seen[value] or #target >= maxKeys then
        return
    end

    target[#target + 1] = value
    seen[value] = true
end

function KeybindProfiles:SanitizeLegacyBindingList(bindingList)
    local sanitized = {}
    local seen = {}

    if type(bindingList) ~= "table" then
        return sanitized
    end

    for index = 2, #bindingList do
        AddBindingKey(sanitized, seen, bindingList[index], self.MAX_BINDING_KEYS)
    end

    return sanitized
end

function KeybindProfiles:MigrateLegacyProfiles(legacyDB)
    if type(legacyDB.profiles) ~= "table" then
        return
    end

    for profileName, profileData in pairs(legacyDB.profiles) do
        local normalizedProfile = self:NormalizeProfileName(profileName)
        if normalizedProfile and type(profileData) == "table" and type(profileData.keybinds) == "table" then
            local profile = self:EnsureProfile(normalizedProfile)
            profile.bindings = {}

            for command, bindingList in pairs(profileData.keybinds) do
                local sanitizedKeys = self:SanitizeLegacyBindingList(bindingList)
                if type(command) == "string" and #sanitizedKeys > 0 then
                    profile.bindings[command] = sanitizedKeys
                end
            end
        end
    end
end

function KeybindProfiles:MigrateLegacyActiveProfiles(legacyDB)
    if type(legacyDB.profileKeys) ~= "table" then
        return
    end

    for characterKey, profileName in pairs(legacyDB.profileKeys) do
        if type(characterKey) == "string" then
            local characterDB = self:GetCharacterDB(characterKey)
            local normalizedProfile = self:NormalizeProfileName(profileName)
            if normalizedProfile then
                characterDB.activeProfile = normalizedProfile
            end
        end
    end
end

function KeybindProfiles:MigrateLegacySpecMaps(legacyDB)
    local namespaceData = legacyDB.namespaces and legacyDB.namespaces["LibDualSpec-1.0"]
    local characterMappings = namespaceData and namespaceData.char
    if type(characterMappings) ~= "table" then
        return
    end

    for characterKey, mappingData in pairs(characterMappings) do
        if type(characterKey) == "string" and type(mappingData) == "table" and mappingData.enabled then
            local pending = {
                enabled = true,
                mappings = {},
            }
            local hasMappings = false

            for specIndex, profileName in pairs(mappingData) do
                if type(specIndex) == "number" then
                    local normalizedProfile = self:NormalizeProfileName(profileName)
                    if normalizedProfile then
                        pending.mappings[specIndex] = normalizedProfile
                        hasMappings = true
                    end
                end
            end

            if hasMappings then
                self.db.migration.pendingLegacySpecMaps[characterKey] = pending
            end
        end
    end
end

function KeybindProfiles:ResolvePendingLegacySpecMap(characterKey)
    local pendingMap = self.db.migration.pendingLegacySpecMaps[characterKey]
    if type(pendingMap) ~= "table" or not pendingMap.enabled then
        return false
    end

    local specializations = self:GetAvailableSpecializations()
    if #specializations == 0 then
        return false
    end

    for _, specInfo in ipairs(specializations) do
        local profileName = pendingMap.mappings[specInfo.index]
        if profileName and self:ProfileExists(profileName) then
            self:SetRuleForSpecialization(specInfo.specializationID, profileName, true)
        end
    end

    self.db.migration.pendingLegacySpecMaps[characterKey] = nil
    return true
end

function KeybindProfiles:MigrateLegacyDB()
    local legacyDB = BindProfilesDB_Global
    if type(legacyDB) == "table" and not self.db.migration.legacyImported then
        self:MigrateLegacyProfiles(legacyDB)
        self:MigrateLegacyActiveProfiles(legacyDB)
        self:MigrateLegacySpecMaps(legacyDB)
        self.db.migration.legacyImported = true
    end

    self:ResolvePendingLegacySpecMap(self:GetCharacterKey())
end
