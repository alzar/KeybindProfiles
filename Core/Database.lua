local _, NS = ...
local KeybindProfiles = NS.KeybindProfiles

function KeybindProfiles:GetCharacterKey()
    if self.characterKey then
        return self.characterKey
    end

    local name = UnitName("player") or UNKNOWNOBJECT
    local realm = GetRealmName() or UNKNOWNOBJECT
    self.characterKey = string.format("%s - %s", name, realm)
    return self.characterKey
end

function KeybindProfiles:NormalizeProfileName(name)
    return self:NormalizeString(name)
end

function KeybindProfiles:InitDB()
    KeybindProfilesDB = self:CopyDefaults(self.DEFAULT_DB, KeybindProfilesDB)
    KeybindProfilesDB.version = self.DB_VERSION
    KeybindProfilesDB.global = KeybindProfilesDB.global or {}
    KeybindProfilesDB.profiles = KeybindProfilesDB.profiles or {}
    KeybindProfilesDB.characters = KeybindProfilesDB.characters or {}
    KeybindProfilesDB.migration = KeybindProfilesDB.migration or {}
    KeybindProfilesDB.migration.pendingLegacySpecMaps = KeybindProfilesDB.migration.pendingLegacySpecMaps or {}

    if not KeybindProfilesDB.profiles[self.DEFAULT_PROFILE_NAME] then
        KeybindProfilesDB.profiles[self.DEFAULT_PROFILE_NAME] = { bindings = {} }
    end

    self.db = KeybindProfilesDB
    self.characterKey = self:GetCharacterKey()
    self:EnsureCharacterDB(self.characterKey)
end

function KeybindProfiles:EnsureCharacterDB(characterKey)
    local key = self:NormalizeString(characterKey)
    if not key then
        key = self:GetCharacterKey()
    end

    self.db.characters[key] = self:CopyDefaults(self.DEFAULT_CHARACTER_DB, self.db.characters[key])
    return self.db.characters[key]
end

function KeybindProfiles:GetCharacterDB(characterKey)
    return self:EnsureCharacterDB(characterKey or self:GetCharacterKey())
end

function KeybindProfiles:ProfileExists(name)
    local normalized = self:NormalizeProfileName(name)
    return normalized and self.db.profiles[normalized] ~= nil or false
end

function KeybindProfiles:GetProfile(name)
    local normalized = self:NormalizeProfileName(name)
    if not normalized then
        return nil
    end

    return self.db.profiles[normalized]
end

function KeybindProfiles:EnsureProfile(name)
    local normalized = self:NormalizeProfileName(name)
    if not normalized then
        return nil
    end

    if not self.db.profiles[normalized] then
        self.db.profiles[normalized] = { bindings = {} }
    end

    self.db.profiles[normalized].bindings = self.db.profiles[normalized].bindings or {}
    return self.db.profiles[normalized], normalized
end

function KeybindProfiles:ListProfiles()
    local profileNames = {}
    for profileName in pairs(self.db.profiles) do
        profileNames[#profileNames + 1] = profileName
    end

    table.sort(profileNames, function(left, right)
        return string.lower(left) < string.lower(right)
    end)

    return profileNames
end

function KeybindProfiles:GetActiveProfileName()
    local characterDB = self:GetCharacterDB()
    local activeProfile = self:NormalizeProfileName(characterDB.activeProfile) or self.DEFAULT_PROFILE_NAME

    if not self:ProfileExists(activeProfile) then
        local profileNames = self:ListProfiles()
        activeProfile = profileNames[1] or self.DEFAULT_PROFILE_NAME
        characterDB.activeProfile = activeProfile
    end

    return activeProfile
end

function KeybindProfiles:SetActiveProfileName(name)
    local normalized = self:NormalizeProfileName(name)
    if not normalized or not self:ProfileExists(normalized) then
        return false
    end

    self:GetCharacterDB().activeProfile = normalized
    return true
end

function KeybindProfiles:GetSelectedProfileName()
    local selectedProfile = self:NormalizeProfileName(self.selectedProfileName)
    if selectedProfile and self:ProfileExists(selectedProfile) then
        return selectedProfile
    end

    selectedProfile = self:GetActiveProfileName()
    self.selectedProfileName = selectedProfile
    return selectedProfile
end

function KeybindProfiles:SetSelectedProfileName(name)
    local normalized = self:NormalizeProfileName(name)
    if normalized and self:ProfileExists(normalized) then
        self.selectedProfileName = normalized
        return true
    end

    return false
end

function KeybindProfiles:IsProfileEmpty(name)
    local profile = self:GetProfile(name)
    if not profile or type(profile.bindings) ~= "table" then
        return true
    end

    return next(profile.bindings) == nil
end

function KeybindProfiles:HasStoredBindings()
    for _, profile in pairs(self.db.profiles) do
        if type(profile) == "table" and type(profile.bindings) == "table" and next(profile.bindings) ~= nil then
            return true
        end
    end

    return false
end

function KeybindProfiles:RemoveRulesReferencingProfile(profileName)
    for _, characterDB in pairs(self.db.characters) do
        if type(characterDB.rules) == "table" then
            for index = #characterDB.rules, 1, -1 do
                if characterDB.rules[index].profileName == profileName then
                    table.remove(characterDB.rules, index)
                end
            end
        end
    end
end

function KeybindProfiles:DeleteStoredProfile(name)
    local normalized = self:NormalizeProfileName(name)
    if not normalized then
        return false, "missing"
    end

    if normalized == self.DEFAULT_PROFILE_NAME then
        return false, "default"
    end

    if not self:ProfileExists(normalized) then
        return false, "missing"
    end

    self.db.profiles[normalized] = nil
    self:RemoveRulesReferencingProfile(normalized)

    for _, characterDB in pairs(self.db.characters) do
        if characterDB.activeProfile == normalized then
            characterDB.activeProfile = self.DEFAULT_PROFILE_NAME
        end
    end

    if not self:ProfileExists(self.DEFAULT_PROFILE_NAME) then
        self.db.profiles[self.DEFAULT_PROFILE_NAME] = { bindings = {} }
    end

    return true
end
