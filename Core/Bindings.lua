local _, NS = ...
local KeybindProfiles = NS.KeybindProfiles

local function AddBindingKey(target, seen, value, maxKeys)
	if type(value) ~= "string" or value == "" or seen[value] or #target >= maxKeys then
		return
	end

	target[#target + 1] = value
	seen[value] = true
end

function KeybindProfiles:SanitizeCapturedBindingValues(bindingValues, startIndex)
	local sanitized = {}
	local seen = {}

	if type(bindingValues) ~= "table" then
		return sanitized
	end

	for index = startIndex or 1, #bindingValues do
		AddBindingKey(sanitized, seen, bindingValues[index], self.MAX_BINDING_KEYS)
	end

	return sanitized
end

function KeybindProfiles:CaptureCurrentBindings()
	local bindings = {}

	for bindingIndex = 1, GetNumBindings() do
		local bindingValues = { GetBinding(bindingIndex) }
		local command = bindingValues[1]
		local keys = self:SanitizeCapturedBindingValues(bindingValues, 3)

		if type(command) == "string" and #keys > 0 then
			bindings[command] = keys
		end
	end

	return bindings
end

function KeybindProfiles:GetCurrentBindingSetID()
	if type(GetCurrentBindingSet) == "function" then
		return GetCurrentBindingSet()
	end

	return 2
end

function KeybindProfiles:IsQuickKeybindModeShown()
	return QuickKeybindFrame and QuickKeybindFrame.IsShown and QuickKeybindFrame:IsShown() or false
end

function KeybindProfiles:GetApplyBlockReason()
	if InCombatLockdown() then
		return "combat"
	end

	if self:IsQuickKeybindModeShown() then
		return "quick_keybind"
	end

	return nil
end

function KeybindProfiles:ApplyBindings(bindings)
	local currentBindings = self:CaptureCurrentBindings()

	for _, keys in pairs(currentBindings) do
		for _, key in ipairs(keys) do
			SetBinding(key)
		end
	end

	for command, keys in pairs(bindings or {}) do
		for _, key in ipairs(keys) do
			SetBinding(key, command)
		end
	end

	SaveBindings(self:GetCurrentBindingSetID())
end
