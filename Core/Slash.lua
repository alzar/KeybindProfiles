local _, NS = ...
local KeybindProfiles = NS.KeybindProfiles
local L = NS.L

local function ParseCommand(message)
	local trimmed = strtrim(message or "")
	if trimmed == "" then
		return "", ""
	end

	local command, argument = trimmed:match("^(%S+)%s*(.-)$")
	return string.lower(command or ""), argument or ""
end

if not KeybindProfiles:IsElvUIKeybindModeAvailable() then
	SLASH_KBP_QUICKBINDS1 = "/kb"
	SlashCmdList.KBP_QUICKBINDS = function(message)
		KeybindProfiles:OpenSlashKeybindMode()
	end
end

SLASH_KEYBINDPROFILES1 = "/kbp"
SlashCmdList.KEYBINDPROFILES = function(message)
	local command, argument = ParseCommand(message)

	if command == "" or command == "config" then
		KeybindProfiles:OpenSettings()
		return
	elseif command == "load" then
		if argument == "" then
			KeybindProfiles:Print(L.error_profile_name_required)
		else
			KeybindProfiles:LoadProfile(argument)
		end
		return
	elseif command == "save" then
		KeybindProfiles:OverwriteActiveProfile()
		return
	elseif command == "saveas" then
		if argument == "" then
			KeybindProfiles:Print(L.error_profile_name_required)
		else
			KeybindProfiles:SaveAsProfile(argument)
		end
		return
	elseif command == "list" then
		KeybindProfiles:Print(string.format(L.profile_list_format, table.concat(KeybindProfiles:ListProfiles(), ", ")))
		return
	elseif command == "status" then
		KeybindProfiles:Print(KeybindProfiles:GetStatusText())
		return
	elseif command == "help" then
		KeybindProfiles:Print(L.slash_help_line_1)
		KeybindProfiles:Print(L.slash_help_line_2)
		return
	end

	KeybindProfiles:Print(L.error_invalid_command)
	KeybindProfiles:Print(L.slash_help_line_1)
	KeybindProfiles:Print(L.slash_help_line_2)
end
