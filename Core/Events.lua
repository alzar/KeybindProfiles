local _, NS = ...
local KeybindProfiles = NS.KeybindProfiles

local eventFrame = CreateFrame("Frame")

function eventFrame:PLAYER_LOGIN()
	KeybindProfiles:InitDB()
	KeybindProfiles:MigrateLegacyDB()
	KeybindProfiles:EnsureInitialProfileState()
	KeybindProfiles:RegisterRuntimeHooks()
	KeybindProfiles:InitializeOptions()
	KeybindProfiles:EnsureQuickKeybindHook()
	KeybindProfiles:ScheduleRuleEvaluation("player_login", 0)
	KeybindProfiles:RefreshOptions()
end

function eventFrame:PLAYER_ENTERING_WORLD()
	KeybindProfiles:ScheduleRuleEvaluation("player_entering_world_fast", 0.2)
	KeybindProfiles:ScheduleRuleEvaluation("player_entering_world_slow", 1.0)
end

function eventFrame:PLAYER_SPECIALIZATION_CHANGED(unitToken)
	if unitToken == "player" then
		KeybindProfiles:ScheduleRuleEvaluation("player_specialization_changed", 0.2)
	end
end

function eventFrame:PLAYER_REGEN_ENABLED()
	KeybindProfiles:ApplyPending("player_regen_enabled")
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
	local handler = eventFrame[event]
	if handler then
		handler(eventFrame, ...)
	end
end)

eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
if eventFrame.RegisterUnitEvent then
	eventFrame:RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
else
	eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
end
