local ADDON_NAME, NS = ...

local KeybindProfiles = {}
NS.KeybindProfiles = KeybindProfiles
_G.KeybindProfiles = KeybindProfiles

KeybindProfiles.NAME = ADDON_NAME
KeybindProfiles.VERSION = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "0"
KeybindProfiles.DISPLAY_NAME = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Title") or ADDON_NAME
KeybindProfiles.L = NS.L or {}

function KeybindProfiles:FormatMessage(message)
	return string.format("|cff33ff99%s|r: %s", self.DISPLAY_NAME, tostring(message))
end

function KeybindProfiles:Print(message)
	if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
		DEFAULT_CHAT_FRAME:AddMessage(self:FormatMessage(message))
	else
		print(self:FormatMessage(message))
	end
end

function KeybindProfiles:Notify(message)
	if self.db and self.db.global and self.db.global.notifications == false then
		return
	end

	self:Print(message)
end

function KeybindProfiles:RefreshOptions()
	if self.optionsPanel and self.optionsPanel.Refresh then
		self.optionsPanel:Refresh()
	end
end
