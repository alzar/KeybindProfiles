local _, NS = ...
local KeybindProfiles = NS.KeybindProfiles
local L = NS.L

local function SafeCancelTimer(timer)
	if timer and type(timer.Cancel) == "function" then
		timer:Cancel()
	end
end

function KeybindProfiles:RegisterRuntimeHooks()
	if self.saveBindingsHooked then
		return
	end

	hooksecurefunc("SaveBindings", function()
		KeybindProfiles:OnBindingsSaved()
	end)

	self.saveBindingsHooked = true
end

function KeybindProfiles:OnBindingsSaved()
	if self.isApplyingProfile then
		return
	end

	local characterDB = self:GetCharacterDB()
	if not characterDB.autosave then
		return
	end

	self:SaveProfile(self:GetActiveProfileName(), {
		silent = true,
		setActive = true,
		reason = "autosave",
	})
end

function KeybindProfiles:EnsureQuickKeybindHook()
	if self.quickKeybindHooked then
		return true
	end

	if not QuickKeybindFrame or not QuickKeybindFrame.HookScript then
		return false
	end

	QuickKeybindFrame:HookScript("OnHide", function()
		KeybindProfiles:ApplyPending("quick_keybind_closed")
	end)

	self.quickKeybindHooked = true
	return true
end

function KeybindProfiles:GetElvUIActionBarsModule()
	local elvUI = _G.ElvUI
	if type(elvUI) ~= "table" then
		return nil
	end

	local engine = unpack(elvUI)
	if not engine or type(engine.GetModule) ~= "function" then
		return nil
	end

	if not (engine.private and engine.private.actionbar and engine.private.actionbar.enable) then
		return nil
	end

	local ok, actionBars = pcall(engine.GetModule, engine, "ActionBars")
	if not ok or not actionBars or type(actionBars.ActivateBindMode) ~= "function" then
		return nil
	end

	return actionBars
end

function KeybindProfiles:IsElvUIKeybindModeAvailable()
	return self:GetElvUIActionBarsModule() ~= nil
end

function KeybindProfiles:OpenSlashKeybindMode()
	local actionBars = self:GetElvUIActionBarsModule()
	if actionBars then
		if InCombatLockdown() then
			self:Print(L.error_keybind_mode_combat)
			return false
		end

		if SettingsPanel and SettingsPanel.IsShown and SettingsPanel:IsShown() then
			HideUIPanel(SettingsPanel)
		end

		self:CloseSettings()
		actionBars:ActivateBindMode()
		return true
	end

	return self:OpenQuickKeybindMode()
end

function KeybindProfiles:ScheduleRuleEvaluation(reason, delay)
	self.scheduledEvaluations = self.scheduledEvaluations or {}

	local safeReason = reason or "evaluate"
	local safeDelay = tonumber(delay) or 0
	local key = string.format("%s:%.1f", safeReason, safeDelay)

	SafeCancelTimer(self.scheduledEvaluations[key])
	self.scheduledEvaluations[key] = C_Timer.NewTimer(safeDelay, function()
		self.scheduledEvaluations[key] = nil
		self:EvaluateRules(safeReason)
	end)
end

function KeybindProfiles:QueueProfileApply(profileName, reason, force, options)
	self.pendingApply = {
		profileName = profileName,
		reason = reason,
		force = force and true or false,
		options = options,
	}

	self:RefreshOptions()
end

function KeybindProfiles:ApplyPending(reason)
	if not self.pendingApply then
		return false
	end

	local pendingApply = self.pendingApply
	return self:ApplyProfile(
		pendingApply.profileName,
		reason or pendingApply.reason or "pending",
		true,
		pendingApply.options or { silent = true }
	)
end

function KeybindProfiles:EnsureInitialProfileState()
	local activeProfile = self:GetActiveProfileName()
	if not self:ProfileExists(activeProfile) then
		self:SetActiveProfileName(self.DEFAULT_PROFILE_NAME)
		activeProfile = self.DEFAULT_PROFILE_NAME
	end

	if not self:HasStoredBindings() then
		self:SaveProfile(activeProfile, {
			silent = true,
			setActive = true,
			reason = "initial_capture",
		})
	end

	self.selectedProfileName = self.selectedProfileName or activeProfile
end

function KeybindProfiles:OverwriteActiveProfile()
	return self:SaveProfile(self:GetActiveProfileName(), {
		silent = false,
		setActive = true,
		reason = "overwrite_active",
	})
end

function KeybindProfiles:SaveAsProfile(name)
	local normalized = self:NormalizeProfileName(name)
	if not normalized then
		self:Print(L.error_profile_name_required)
		return false
	end

	if self:ProfileExists(normalized) then
		self:Print(string.format(L.error_profile_exists, normalized))
		return false
	end

	return self:SaveProfile(normalized, {
		silent = false,
		setActive = true,
		reason = "save_as",
	})
end

function KeybindProfiles:SaveProfile(name, options)
	local opts = options or {}
	local targetName = self:NormalizeProfileName(name) or self:GetActiveProfileName()
	if not targetName then
		self:Print(L.error_profile_name_required)
		return false
	end

	local profile = self:EnsureProfile(targetName)
	if not profile then
		self:Print(L.error_profile_name_required)
		return false
	end

	profile.bindings = self:CaptureCurrentBindings()

	if opts.setActive ~= false then
		self:SetActiveProfileName(targetName)
	end

	self.selectedProfileName = targetName
	self:RefreshOptions()

	if not opts.silent then
		self:Notify(string.format(L.profile_saved, targetName))
	end

	return true
end

function KeybindProfiles:ApplyProfile(profileName, reason, force, options)
	local opts = options or {}
	local normalizedProfile = self:NormalizeProfileName(profileName)
	if not normalizedProfile then
		self:Print(L.error_profile_name_required)
		return false
	end

	local profile = self:GetProfile(normalizedProfile)
	if not profile then
		self:Print(string.format(L.error_profile_missing, normalizedProfile))
		return false
	end

	if not force and self:GetActiveProfileName() == normalizedProfile then
		self.pendingApply = nil
		self:RefreshOptions()
		return true
	end

	local blockReason = self:GetApplyBlockReason()
	if blockReason then
		self:QueueProfileApply(normalizedProfile, reason, true, opts)

		if not opts.silent then
			if blockReason == "combat" then
				self:Print(L.error_apply_combat)
			else
				self:Print(L.error_apply_quick_keybind)
			end
		end

		return false
	end

	self.pendingApply = nil
	self.isApplyingProfile = true
	local ok, err = pcall(function()
		self:ApplyBindings(profile.bindings or {})
	end)
	self.isApplyingProfile = false

	if not ok then
		self:Print(string.format(L.error_apply_failed, tostring(err)))
		self:RefreshOptions()
		return false
	end

	self:SetActiveProfileName(normalizedProfile)
	self.selectedProfileName = normalizedProfile
	self:RefreshOptions()

	if not opts.silent then
		self:Notify(string.format(L.profile_loaded, normalizedProfile))
	end

	return true
end

function KeybindProfiles:LoadProfile(name, options)
	local normalizedProfile = self:NormalizeProfileName(name)
	if not normalizedProfile then
		self:Print(L.error_profile_name_required)
		return false
	end

	if not self:ProfileExists(normalizedProfile) then
		self:Print(string.format(L.error_profile_missing, normalizedProfile))
		return false
	end

	return self:ApplyProfile(
		normalizedProfile,
		options and options.reason or "manual",
		options and options.force,
		options
	)
end

function KeybindProfiles:Load(name)
	return self:LoadProfile(name)
end

function KeybindProfiles:DeleteProfile(name)
	local normalizedProfile = self:NormalizeProfileName(name) or self:GetSelectedProfileName()
	if not normalizedProfile then
		self:Print(L.error_profile_name_required)
		return false
	end

	local ok, errorCode = self:DeleteStoredProfile(normalizedProfile)
	if not ok then
		if errorCode == "default" then
			self:Print(L.error_delete_default)
		else
			self:Print(string.format(L.error_profile_missing, normalizedProfile))
		end

		return false
	end

	self.selectedProfileName = self:GetActiveProfileName()
	self:RefreshOptions()
	self:Notify(string.format(L.profile_deleted, normalizedProfile))
	return true
end

function KeybindProfiles:OpenQuickKeybindMode()
	if InCombatLockdown() then
		self:Print(L.error_keybind_mode_combat)
		return false
	elseif not QuickKeybindFrame then
		self:Print(L.error_keybind_mode_unavailable)
		return false
	end

	self:EnsureQuickKeybindHook()

	if SettingsPanel and SettingsPanel.IsShown and SettingsPanel:IsShown() then
		HideUIPanel(SettingsPanel)
	end

	self:CloseSettings()
	ShowUIPanel(QuickKeybindFrame)
	return true
end

function KeybindProfiles:CloseSettings()
	if not self.optionsPanel then
		return
	end

	self.optionsPanel:Hide()
end

function KeybindProfiles:OpenSettings()
	if not self.optionsPanel then
		self:InitializeOptions()
	end

	if not self.optionsPanel then
		self:Print(L.error_settings_unavailable)
		return false
	end

	if SettingsPanel and SettingsPanel.IsShown and SettingsPanel:IsShown() then
		HideUIPanel(SettingsPanel)
	end

	self.optionsPanel:Show()
	if self.optionsPanel.Refresh then
		self.optionsPanel:Refresh()
	end

	if self.optionsPanel.Raise then
		self.optionsPanel:Raise()
	end

	return true
end

function KeybindProfiles:OpenSettingsLauncher()
	if not (Settings and self.settingsCategory) then
		self:Print(L.error_settings_unavailable)
		return false
	end

	Settings.OpenToCategory(self.settingsCategory:GetID())
	return true
end

function KeybindProfiles:GetStatusText()
	local characterDB = self:GetCharacterDB()
	local pendingProfile = self.pendingApply and self.pendingApply.profileName or L.none

	return string.format(
		L.status_format,
		self:GetActiveProfileName(),
		characterDB.autoLoadEnabled and L.enabled or L.disabled,
		characterDB.autosave and L.enabled or L.disabled,
		pendingProfile
	)
end
