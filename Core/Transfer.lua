local _, NS = ...
local KeybindProfiles = NS.KeybindProfiles
local L = NS.L

local EXPORT_PREFIX = "KBP1"
local EXPORT_ENCODING_VERSION = 1

local function IsEncodingAvailable()
	return C_EncodingUtil
		and C_EncodingUtil.SerializeCBOR
		and C_EncodingUtil.DeserializeCBOR
		and C_EncodingUtil.CompressString
		and C_EncodingUtil.DecompressString
		and C_EncodingUtil.EncodeBase64
		and C_EncodingUtil.DecodeBase64
		and Enum
		and Enum.CompressionMethod
		and Enum.CompressionMethod.Deflate
end

local function AddUniqueString(values, seenValues, value)
	if type(value) ~= "string" then
		return
	end

	local normalized = strtrim(value)
	if normalized == "" or seenValues[normalized] then
		return
	end

	seenValues[normalized] = true
	values[#values + 1] = normalized
end

function KeybindProfiles:SanitizeImportedBindings(bindings)
	local sanitizedBindings = {}
	if type(bindings) ~= "table" then
		return sanitizedBindings
	end

	for commandName, keyList in pairs(bindings) do
		if type(commandName) == "string" and type(keyList) == "table" then
			local sanitizedKeys = {}
			local seenKeys = {}

			for _, keyValue in ipairs(keyList) do
				AddUniqueString(sanitizedKeys, seenKeys, keyValue)
				if #sanitizedKeys >= self.MAX_BINDING_KEYS then
					break
				end
			end

			if #sanitizedKeys > 0 then
				sanitizedBindings[commandName] = sanitizedKeys
			end
		end
	end

	return sanitizedBindings
end

function KeybindProfiles:CreateImportedProfileName(baseName)
	local baseProfileName = self:NormalizeProfileName(baseName) or L.imported_profile_name
	if not self:ProfileExists(baseProfileName) then
		return baseProfileName
	end

	local firstCandidate = string.format(L.imported_profile_copy_name, baseProfileName)
	if not self:ProfileExists(firstCandidate) then
		return firstCandidate
	end

	local suffix = 2
	while true do
		local candidate = string.format(L.imported_profile_copy_numbered_name, baseProfileName, suffix)
		if not self:ProfileExists(candidate) then
			return candidate
		end

		suffix = suffix + 1
	end
end

function KeybindProfiles:ExportProfile(name)
	if not IsEncodingAvailable() then
		self:Print(L.error_transfer_unavailable)
		return nil
	end

	local profileName = self:NormalizeProfileName(name) or self:GetSelectedProfileName()
	local profile = self:GetProfile(profileName)
	if not profile then
		self:Print(string.format(L.error_profile_missing, tostring(profileName)))
		return nil
	end

	local exportPayload = {
		formatVersion = 1,
		profileName = profileName,
		profile = {
			bindings = self:SanitizeImportedBindings(profile.bindings),
		},
	}

	local serialized = C_EncodingUtil.SerializeCBOR(exportPayload)
	if type(serialized) ~= "string" then
		self:Print(L.error_export_failed)
		return nil
	end

	local compressed = C_EncodingUtil.CompressString(serialized, Enum.CompressionMethod.Deflate)
	if type(compressed) ~= "string" then
		self:Print(L.error_export_failed)
		return nil
	end

	local encoded = C_EncodingUtil.EncodeBase64(compressed)
	if type(encoded) ~= "string" then
		self:Print(L.error_export_failed)
		return nil
	end

	return string.format("%s:%d|%s", EXPORT_PREFIX, EXPORT_ENCODING_VERSION, encoded), profileName
end

function KeybindProfiles:ImportProfile(text, overrideName)
	if not IsEncodingAvailable() then
		self:Print(L.error_transfer_unavailable)
		return nil
	end

	local importText = self:NormalizeString(text)
	if not importText then
		self:Print(L.error_import_string_required)
		return nil
	end

	local prefix, encodingVersionText, payload = importText:match("^([A-Z0-9]+):(%d+)|(.+)$")
	if prefix ~= EXPORT_PREFIX or not payload then
		self:Print(L.error_import_invalid)
		return nil
	end

	local encodingVersion = tonumber(encodingVersionText)
	if encodingVersion ~= EXPORT_ENCODING_VERSION then
		self:Print(L.error_import_unsupported_version)
		return nil
	end

	local decoded = C_EncodingUtil.DecodeBase64(payload)
	if type(decoded) ~= "string" then
		self:Print(L.error_import_invalid)
		return nil
	end

	local decompressed = C_EncodingUtil.DecompressString(decoded, Enum.CompressionMethod.Deflate)
	if type(decompressed) ~= "string" then
		self:Print(L.error_import_invalid)
		return nil
	end

	local importedData = C_EncodingUtil.DeserializeCBOR(decompressed)
	if type(importedData) ~= "table" or type(importedData.profile) ~= "table" then
		self:Print(L.error_import_invalid)
		return nil
	end

	local importedBindings = self:SanitizeImportedBindings(importedData.profile.bindings)
	local requestedProfileName = self:NormalizeProfileName(overrideName)
	local importedProfileName = self:CreateImportedProfileName(requestedProfileName or importedData.profileName)
	local profile = self:EnsureProfile(importedProfileName)
	if not profile then
		self:Print(L.error_import_invalid)
		return nil
	end

	profile.bindings = importedBindings
	self.selectedProfileName = importedProfileName
	self:RefreshOptions()
	self:Notify(string.format(L.profile_imported, importedProfileName))
	self:LoadProfile(importedProfileName, {
		reason = "import",
		silent = true,
	})

	return importedProfileName
end
