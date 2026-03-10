local _, NS = ...
local KeybindProfiles = NS.KeybindProfiles
local L = NS.L

local BACKDROP_TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil
local PROFILE_BUTTON_HEIGHT = 24
local PROFILE_BUTTON_SPACING = 4
local DROPDOWN_WIDTH = 250
local SPEC_COLUMN_SPACING = 24
local SPEC_ROW_WIDTH = 286
local SPEC_DROPDOWN_WIDTH = 238
local CreateButton
local MEDIA_ROOT = "Interface\\AddOns\\KeybindProfiles\\media\\"
local ICON_BUTTON_ALPHA = 0.72
local ICON_BUTTON_DISABLED_ALPHA = 0.28
local PROFILE_ROW_NEUTRAL =
	{ bg = { 0.20, 0.20, 0.20, 0.32 }, border = { 0.34, 0.34, 0.34, 0.55 }, text = { 0.92, 0.92, 0.92 } }
local PROFILE_ROW_SELECTED =
	{ tint = { 0.10, 0.32, 0.74, 0.46 }, border = { 0.33, 0.61, 0.95, 0.95 }, text = { 1.00, 1.00, 1.00 } }

local DIALOG_PANEL_BACKDROP = {
	bgFile = "Interface\\Buttons\\WHITE8X8",
	edgeFile = "Interface\\Buttons\\WHITE8X8",
	tile = false,
	edgeSize = 1,
	insets = {
		left = 1,
		right = 1,
		top = 1,
		bottom = 1,
	},
}

local function CreateLabel(parent, text, template)
	local label = parent:CreateFontString(nil, "ARTWORK", template or "GameFontNormal")
	label:SetJustifyH("LEFT")
	label:SetText(text or "")
	return label
end

local function SetIconButtonEnabled(button, enabled)
	button:SetEnabled(enabled)
	if not button.icon then
		return
	end

	button.icon:SetDesaturated(not enabled)
	button.icon:SetAlpha(enabled and ICON_BUTTON_ALPHA or ICON_BUTTON_DISABLED_ALPHA)
end

local function CreateIconButton(parent, textureName, size, tooltipText)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(size, size)

	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints()
	icon:SetTexture(MEDIA_ROOT .. textureName .. ".png")
	icon:SetAlpha(ICON_BUTTON_ALPHA)
	button.icon = icon
	button.tooltipText = tooltipText

	button:SetScript("OnEnter", function(selfButton)
		if selfButton.icon and selfButton:IsEnabled() then
			selfButton.icon:SetAlpha(1)
		end

		if selfButton.tooltipText then
			GameTooltip:SetOwner(selfButton, "ANCHOR_RIGHT")
			GameTooltip:SetText(selfButton.tooltipText)
			GameTooltip:Show()
		end
	end)

	button:SetScript("OnLeave", function(selfButton)
		if selfButton.icon then
			selfButton.icon:SetAlpha(selfButton:IsEnabled() and ICON_BUTTON_ALPHA or ICON_BUTTON_DISABLED_ALPHA)
			selfButton.icon:SetTexCoord(0, 1, 0, 1)
		end
		GameTooltip:Hide()
	end)

	button:SetScript("OnMouseDown", function(selfButton)
		if selfButton:IsEnabled() and selfButton.icon then
			selfButton.icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
		end
	end)

	button:SetScript("OnMouseUp", function(selfButton)
		if selfButton.icon then
			selfButton.icon:SetTexCoord(0, 1, 0, 1)
		end
	end)

	SetIconButtonEnabled(button, true)
	return button
end

local function CreateModalOverlay(panel)
	local overlay = CreateFrame("Frame", nil, panel, BACKDROP_TEMPLATE)
	overlay:SetAllPoints()
	overlay:SetFrameStrata("TOOLTIP")
	overlay:SetFrameLevel(panel:GetFrameLevel() + 100)
	overlay:EnableMouse(true)
	overlay:Hide()

	local shade = overlay:CreateTexture(nil, "BACKGROUND")
	shade:SetAllPoints()
	shade:SetColorTexture(0, 0, 0, 0.5)
	overlay.shade = shade

	return overlay
end

local function ShowOverlay(overlay)
	if not overlay then
		return
	end

	overlay:SetFrameLevel(KeybindProfiles.optionsPanel:GetFrameLevel() + 100)
	overlay:Show()
	overlay:Raise()
end

local function ShowCreateProfilePopup()
	local panel = KeybindProfiles.optionsPanel
	if not panel or not panel.createProfileDialog then
		return
	end

	local dialog = panel.createProfileDialog
	ShowOverlay(dialog)
	dialog.editBox:SetText("")
	dialog.editBox:HighlightText()
	dialog.editBox:SetFocus()
end

local function ShowDeleteProfilePopup(profileName)
	local panel = KeybindProfiles.optionsPanel
	if not panel or not panel.deleteProfileDialog or not profileName then
		return
	end

	local dialog = panel.deleteProfileDialog
	dialog.profileName = profileName
	dialog.message:SetText(string.format(L.delete_profile_prompt, profileName))
	ShowOverlay(dialog)
end

local function ShowActionConfirmDialog(titleText, messageText, warningText, confirmText, onAccept)
	local panel = KeybindProfiles.optionsPanel
	if not panel or not panel.actionConfirmDialog then
		return
	end

	local dialog = panel.actionConfirmDialog
	dialog.title:SetText(titleText or "")
	dialog.message:SetText(messageText or "")
	dialog.warning:SetText(warningText or "")
	dialog.confirmButton:SetText(confirmText or ACCEPT)
	dialog.onAccept = onAccept
	ShowOverlay(dialog)
end

local function ShowSaveProfilePopup(profileName)
	if not profileName then
		return
	end

	ShowActionConfirmDialog(
		L.save_profile,
		string.format(L.save_profile_confirm, profileName),
		L.save_profile_warning,
		SAVE,
		function()
			KeybindProfiles:SaveProfile(profileName, {
				silent = false,
				setActive = true,
				reason = "row_save",
			})
		end
	)
end

local function ShowLoadProfilePopup(profileName)
	if not profileName then
		return
	end

	ShowActionConfirmDialog(
		L.load_profile,
		string.format(L.load_profile_confirm, profileName),
		L.load_profile_warning,
		LOAD or ACCEPT,
		function()
			KeybindProfiles:LoadProfile(profileName)
		end
	)
end

local function SetDropdownText(dropdown, text)
	if type(dropdown.OverrideText) == "function" then
		dropdown:OverrideText(text)
	elseif type(dropdown.SetDefaultText) == "function" then
		dropdown:SetDefaultText(text)
	elseif type(dropdown.SetText) == "function" then
		dropdown:SetText(text)
	end
end

local function CreateStyledPanel(parent, alpha)
	local panel = CreateFrame("Frame", nil, parent, BACKDROP_TEMPLATE)
	if panel.SetBackdrop then
		panel:SetBackdrop(DIALOG_PANEL_BACKDROP)
		panel:SetBackdropColor(0.11, 0.12, 0.14, alpha or 0.96)
		panel:SetBackdropBorderColor(0.34, 0.36, 0.40, 0.95)
	end

	local noise = panel:CreateTexture(nil, "BACKGROUND", nil, -1)
	noise:SetAllPoints()
	noise:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Background-Dark")
	noise:SetVertexColor(0.18, 0.19, 0.22, 0.10)
	panel.noise = noise

	local header = panel:CreateTexture(nil, "ARTWORK", nil, -1)
	header:SetPoint("TOPLEFT", 1, -1)
	header:SetPoint("TOPRIGHT", -1, -1)
	header:SetHeight(28)
	header:SetColorTexture(0.17, 0.19, 0.23, 0.85)
	panel.header = header

	local headerDivider = panel:CreateTexture(nil, "ARTWORK")
	headerDivider:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
	headerDivider:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, 0)
	headerDivider:SetHeight(1)
	headerDivider:SetColorTexture(1, 1, 1, 0.08)
	panel.headerDivider = headerDivider

	return panel
end

local function CreateContentPane(parent, shadeAlpha)
	local pane = CreateFrame("Frame", nil, parent)
	pane.bg = pane:CreateTexture(nil, "BACKGROUND")
	pane.bg:SetAllPoints()
	pane.bg:SetColorTexture(0, 0, 0, shadeAlpha or 0.04)
	return pane
end

local function CreateSection(parent, titleText, useBodyFill)
	local section = CreateFrame("Frame", nil, parent)

	section.title = CreateLabel(section, titleText, "GameFontHighlight")
	section.title:SetPoint("TOPLEFT", 0, -2)

	section.divider = section:CreateTexture(nil, "ARTWORK")
	section.divider:SetHeight(1)
	section.divider:SetPoint("TOPLEFT", section.title, "BOTTOMLEFT", 0, -8)
	section.divider:SetPoint("TOPRIGHT", section, "TOPRIGHT", 0, -22)
	section.divider:SetColorTexture(1, 1, 1, 0.10)

	if useBodyFill then
		section.bodyFill = section:CreateTexture(nil, "BACKGROUND")
		section.bodyFill:SetPoint("TOPLEFT", section, "TOPLEFT", 0, -30)
		section.bodyFill:SetPoint("BOTTOMRIGHT", section, "BOTTOMRIGHT", 0, 0)
		section.bodyFill:SetColorTexture(0, 0, 0, 0.12)
	end

	return section
end

local function CreateTextArea(parent, width, height)
	local container = CreateFrame("Frame", nil, parent, BACKDROP_TEMPLATE)
	container:SetSize(width, height)
	if container.SetBackdrop then
		container:SetBackdrop(DIALOG_PANEL_BACKDROP)
		container:SetBackdropColor(0.07, 0.08, 0.10, 0.98)
		container:SetBackdropBorderColor(0.30, 0.32, 0.36, 0.95)
	end

	local scrollFrame = CreateFrame("ScrollFrame", nil, container, "UIPanelScrollFrameTemplate")
	scrollFrame:SetPoint("TOPLEFT", 8, -8)
	scrollFrame:SetPoint("BOTTOMRIGHT", -28, 8)
	container.scrollFrame = scrollFrame

	local editBox = CreateFrame("EditBox", nil, scrollFrame)
	editBox:SetAutoFocus(false)
	editBox:SetMultiLine(true)
	editBox:SetFontObject(ChatFontNormal)
	editBox:SetWidth(width - 40)
	editBox:SetTextInsets(4, 4, 4, 4)
	editBox:SetJustifyH("LEFT")
	editBox:SetJustifyV("TOP")
	scrollFrame:SetScrollChild(editBox)
	container.editBox = editBox

	local function GetEditBoxContentHeight()
		if type(editBox.GetTextHeight) == "function" then
			return editBox:GetTextHeight()
		end

		if type(editBox.GetStringHeight) == "function" then
			return editBox:GetStringHeight()
		end

		return scrollFrame:GetHeight()
	end

	local function UpdateEditBoxHeight()
		editBox:SetHeight(math.max(scrollFrame:GetHeight(), GetEditBoxContentHeight() + 12))
		scrollFrame:UpdateScrollChildRect()
	end

	editBox:SetScript("OnTextChanged", UpdateEditBoxHeight)
	editBox:SetScript("OnEscapePressed", function(selfEditBox)
		selfEditBox:ClearFocus()
	end)
	container.UpdateEditBoxHeight = UpdateEditBoxHeight
	UpdateEditBoxHeight()

	return container
end

local function ShowExportProfilePopup(profileName)
	local panel = KeybindProfiles.optionsPanel
	if not panel or not panel.exportProfileDialog then
		return
	end

	local exportString = KeybindProfiles:ExportProfile(profileName)
	if not exportString then
		return
	end

	local dialog = panel.exportProfileDialog
	dialog.textArea.editBox:SetText(exportString)
	ShowOverlay(dialog)
	dialog.textArea.editBox:SetFocus()
	dialog.textArea.editBox:HighlightText()
end

local function ShowImportProfilePopup()
	local panel = KeybindProfiles.optionsPanel
	if not panel or not panel.importProfileDialog then
		return
	end

	local dialog = panel.importProfileDialog
	dialog.textArea.editBox:SetText("")
	ShowOverlay(dialog)
	dialog.textArea.editBox:SetFocus()
end

local function CreateCreateProfileDialog(panel)
	local dialog = CreateModalOverlay(panel)

	dialog.box = CreateStyledPanel(dialog, 0.98)
	dialog.box:SetSize(380, 148)
	dialog.box:SetPoint("CENTER")
	dialog.box:SetFrameLevel(dialog:GetFrameLevel() + 5)

	dialog.title = CreateLabel(dialog.box, L.create_profile, "GameFontNormalLarge")
	dialog.title:SetPoint("TOPLEFT", dialog.box, "TOPLEFT", 16, -7)

	dialog.prompt = CreateLabel(dialog.box, L.create_profile_prompt, "GameFontHighlight")
	dialog.prompt:SetPoint("TOPLEFT", dialog.box, "TOPLEFT", 16, -46)
	dialog.prompt:SetPoint("TOPRIGHT", dialog.box, "TOPRIGHT", -16, -46)
	dialog.prompt:SetJustifyH("LEFT")

	dialog.editBox = CreateFrame("EditBox", nil, dialog.box, "InputBoxTemplate")
	dialog.editBox:SetSize(240, 30)
	dialog.editBox:SetPoint("TOPLEFT", dialog.prompt, "BOTTOMLEFT", 0, -10)
	dialog.editBox:SetAutoFocus(false)

	local createButton = CreateButton(dialog.box, ACCEPT, 100)
	createButton:SetPoint("BOTTOMRIGHT", dialog.box, "BOTTOMRIGHT", -16, 12)
	createButton:SetScript("OnClick", function()
		if KeybindProfiles:SaveAsProfile(dialog.editBox:GetText()) then
			dialog:Hide()
		end
	end)
	dialog.createButton = createButton

	local cancelButton = CreateButton(dialog.box, CANCEL, 100)
	cancelButton:SetPoint("RIGHT", createButton, "LEFT", -8, 0)
	cancelButton:SetScript("OnClick", function()
		dialog:Hide()
	end)

	local function RefreshCreateButtonState()
		local hasName = KeybindProfiles:NormalizeProfileName(dialog.editBox:GetText()) ~= nil
		createButton:SetEnabled(hasName)
		createButton:SetAlpha(hasName and 1 or 0.5)
	end

	dialog.editBox:SetScript("OnEnterPressed", function(editBox)
		if createButton:IsEnabled() and KeybindProfiles:SaveAsProfile(editBox:GetText()) then
			dialog:Hide()
		end
	end)
	dialog.editBox:SetScript("OnTextChanged", RefreshCreateButtonState)
	dialog.editBox:SetScript("OnEscapePressed", function()
		dialog:Hide()
	end)

	dialog:SetScript("OnHide", function(selfDialog)
		selfDialog.editBox:ClearFocus()
		selfDialog.editBox:SetText("")
		RefreshCreateButtonState()
	end)

	RefreshCreateButtonState()

	return dialog
end

local function CreateDeleteProfileDialog(panel)
	local dialog = CreateModalOverlay(panel)

	dialog.box = CreateStyledPanel(dialog, 0.98)
	dialog.box:SetSize(380, 148)
	dialog.box:SetPoint("CENTER")
	dialog.box:SetFrameLevel(dialog:GetFrameLevel() + 5)

	dialog.title = CreateLabel(dialog.box, DELETE, "GameFontNormalLarge")
	dialog.title:SetPoint("TOPLEFT", dialog.box, "TOPLEFT", 16, -7)

	dialog.message = CreateLabel(dialog.box, "", "GameFontHighlight")
	dialog.message:SetPoint("TOPLEFT", dialog.box, "TOPLEFT", 16, -46)
	dialog.message:SetPoint("TOPRIGHT", dialog.box, "TOPRIGHT", -16, -46)
	dialog.message:SetJustifyH("LEFT")

	dialog.warning = CreateLabel(dialog.box, L.delete_profile_prompt_irreversible, "GameFontHighlightSmall")
	dialog.warning:SetPoint("TOPLEFT", dialog.message, "BOTTOMLEFT", 0, -8)
	dialog.warning:SetTextColor(0.9, 0.3, 0.3)

	local deleteButton = CreateButton(dialog.box, DELETE, 100)
	deleteButton:SetPoint("BOTTOMRIGHT", dialog.box, "BOTTOMRIGHT", -16, 12)
	deleteButton:SetScript("OnClick", function()
		if dialog.profileName then
			KeybindProfiles:DeleteProfile(dialog.profileName)
		end
		dialog:Hide()
	end)

	local cancelButton = CreateButton(dialog.box, CANCEL, 100)
	cancelButton:SetPoint("RIGHT", deleteButton, "LEFT", -8, 0)
	cancelButton:SetScript("OnClick", function()
		dialog:Hide()
	end)

	dialog:SetScript("OnHide", function(selfDialog)
		selfDialog.profileName = nil
	end)

	return dialog
end

local function CreateActionConfirmDialog(panel)
	local dialog = CreateModalOverlay(panel)

	dialog.box = CreateStyledPanel(dialog, 0.98)
	dialog.box:SetSize(400, 152)
	dialog.box:SetPoint("CENTER")
	dialog.box:SetFrameLevel(dialog:GetFrameLevel() + 5)

	dialog.title = CreateLabel(dialog.box, "", "GameFontNormalLarge")
	dialog.title:SetPoint("TOPLEFT", dialog.box, "TOPLEFT", 16, -7)

	dialog.message = CreateLabel(dialog.box, "", "GameFontHighlight")
	dialog.message:SetPoint("TOPLEFT", dialog.box, "TOPLEFT", 16, -46)
	dialog.message:SetPoint("TOPRIGHT", dialog.box, "TOPRIGHT", -16, -46)
	dialog.message:SetJustifyH("LEFT")

	dialog.warning = CreateLabel(dialog.box, "", "GameFontHighlightSmall")
	dialog.warning:SetPoint("TOPLEFT", dialog.message, "BOTTOMLEFT", 0, -8)
	dialog.warning:SetPoint("TOPRIGHT", dialog.box, "TOPRIGHT", -16, -76)
	dialog.warning:SetJustifyH("LEFT")
	dialog.warning:SetTextColor(0.9, 0.82, 0.55)

	local confirmButton = CreateButton(dialog.box, ACCEPT, 100)
	confirmButton:SetPoint("BOTTOMRIGHT", dialog.box, "BOTTOMRIGHT", -16, 12)
	confirmButton:SetScript("OnClick", function()
		if dialog.onAccept then
			dialog.onAccept()
		end
		dialog:Hide()
	end)
	dialog.confirmButton = confirmButton

	local cancelButton = CreateButton(dialog.box, CANCEL, 100)
	cancelButton:SetPoint("RIGHT", confirmButton, "LEFT", -8, 0)
	cancelButton:SetScript("OnClick", function()
		dialog:Hide()
	end)

	dialog:SetScript("OnHide", function(selfDialog)
		selfDialog.onAccept = nil
	end)

	return dialog
end

local function CreateExportProfileDialog(panel)
	local dialog = CreateModalOverlay(panel)

	dialog.box = CreateStyledPanel(dialog, 0.98)
	dialog.box:SetSize(500, 300)
	dialog.box:SetPoint("CENTER")
	dialog.box:SetFrameLevel(dialog:GetFrameLevel() + 5)

	dialog.title = CreateLabel(dialog.box, L.export_profile, "GameFontNormalLarge")
	dialog.title:SetPoint("TOPLEFT", dialog.box, "TOPLEFT", 16, -7)

	dialog.message = CreateLabel(dialog.box, L.export_profile_body, "GameFontHighlight")
	dialog.message:SetPoint("TOPLEFT", dialog.box, "TOPLEFT", 16, -46)
	dialog.message:SetPoint("TOPRIGHT", dialog.box, "TOPRIGHT", -16, -46)
	dialog.message:SetJustifyH("LEFT")

	dialog.textArea = CreateTextArea(dialog.box, 468, 170)
	dialog.textArea:SetPoint("TOPLEFT", dialog.message, "BOTTOMLEFT", 0, -12)

	local closeButton = CreateButton(dialog.box, CLOSE, 100)
	closeButton:SetPoint("BOTTOMRIGHT", dialog.box, "BOTTOMRIGHT", -16, 12)
	closeButton:SetScript("OnClick", function()
		dialog:Hide()
	end)

	dialog:SetScript("OnHide", function(selfDialog)
		selfDialog.textArea.editBox:ClearFocus()
	end)

	return dialog
end

local function CreateImportProfileDialog(panel)
	local dialog = CreateModalOverlay(panel)

	dialog.box = CreateStyledPanel(dialog, 0.98)
	dialog.box:SetSize(500, 320)
	dialog.box:SetPoint("CENTER")
	dialog.box:SetFrameLevel(dialog:GetFrameLevel() + 5)

	dialog.title = CreateLabel(dialog.box, L.import_profile, "GameFontNormalLarge")
	dialog.title:SetPoint("TOPLEFT", dialog.box, "TOPLEFT", 16, -7)

	dialog.message = CreateLabel(dialog.box, L.import_profile_body, "GameFontHighlight")
	dialog.message:SetPoint("TOPLEFT", dialog.box, "TOPLEFT", 16, -46)
	dialog.message:SetPoint("TOPRIGHT", dialog.box, "TOPRIGHT", -16, -46)
	dialog.message:SetJustifyH("LEFT")

	dialog.nameLabel = CreateLabel(dialog.box, L.import_profile_name, "GameFontHighlight")
	dialog.nameLabel:SetPoint("TOPLEFT", dialog.message, "BOTTOMLEFT", 0, -12)

	dialog.nameHint = CreateLabel(dialog.box, L.import_profile_name_body, "GameFontHighlightSmall")
	dialog.nameHint:SetPoint("LEFT", dialog.nameLabel, "RIGHT", 8, 0)
	dialog.nameHint:SetTextColor(0.80, 0.82, 0.86)

	dialog.nameEditBox = CreateFrame("EditBox", nil, dialog.box, "InputBoxTemplate")
	dialog.nameEditBox:SetSize(260, 30)
	dialog.nameEditBox:SetPoint("TOPLEFT", dialog.nameLabel, "BOTTOMLEFT", 0, -8)
	dialog.nameEditBox:SetAutoFocus(false)

	dialog.textArea = CreateTextArea(dialog.box, 468, 134)
	dialog.textArea:SetPoint("TOPLEFT", dialog.nameEditBox, "BOTTOMLEFT", 0, -14)

	local importButton = CreateButton(dialog.box, L.import_profile, 100)
	importButton:SetPoint("BOTTOMRIGHT", dialog.box, "BOTTOMRIGHT", -16, 12)
	dialog.importButton = importButton

	local cancelButton = CreateButton(dialog.box, CANCEL, 100)
	cancelButton:SetPoint("RIGHT", importButton, "LEFT", -8, 0)
	cancelButton:SetScript("OnClick", function()
		dialog:Hide()
	end)

	local function RefreshImportState()
		local hasText = KeybindProfiles:NormalizeString(dialog.textArea.editBox:GetText()) ~= nil
		importButton:SetEnabled(hasText)
		importButton:SetAlpha(hasText and 1 or 0.5)
	end

	importButton:SetScript("OnClick", function()
		if KeybindProfiles:ImportProfile(dialog.textArea.editBox:GetText(), dialog.nameEditBox:GetText()) then
			dialog:Hide()
		end
	end)

	dialog.textArea.editBox:SetScript("OnTextChanged", function(selfEditBox)
		dialog.textArea:UpdateEditBoxHeight()
		RefreshImportState()
	end)

	dialog.nameEditBox:SetScript("OnEscapePressed", function(selfEditBox)
		selfEditBox:ClearFocus()
	end)

	dialog:SetScript("OnHide", function(selfDialog)
		selfDialog.textArea.editBox:ClearFocus()
		selfDialog.textArea.editBox:SetText("")
		selfDialog.nameEditBox:ClearFocus()
		selfDialog.nameEditBox:SetText("")
		RefreshImportState()
	end)

	RefreshImportState()

	return dialog
end

local function CreateCheckbox(parent, text, tooltipText)
	local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	checkbox.text = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	checkbox.text:SetPoint("LEFT", checkbox, "RIGHT", 4, 0)
	checkbox.text:SetText(text)
	checkbox.tooltipText = tooltipText

	checkbox:SetScript("OnEnter", function(self)
		if not self.tooltipText then
			return
		end

		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(self.tooltipText)
		GameTooltip:Show()
	end)

	checkbox:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	return checkbox
end

CreateButton = function(parent, text, width)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetSize(width or 140, 24)
	button:SetText(text)
	return button
end

local function CreateDropdown(parent, width)
	local dropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
	dropdown:SetWidth(width or DROPDOWN_WIDTH)
	SetDropdownText(dropdown, L.none)
	return dropdown
end

local function CreateProfileListButton(parent)
	local button = CreateFrame("Button", nil, parent)
	button:SetHeight(PROFILE_BUTTON_HEIGHT)
	button:SetPoint("LEFT")
	button:SetPoint("RIGHT")

	button.background = button:CreateTexture(nil, "BACKGROUND")
	button.background:SetAllPoints()
	button.background:SetColorTexture(0.08, 0.05, 0.03, 0.78)

	button.stateTint = button:CreateTexture(nil, "BACKGROUND", nil, 1)
	button.stateTint:SetAllPoints()
	button.stateTint:SetColorTexture(0, 0, 0, 0)

	button.topBorder = button:CreateTexture(nil, "BORDER")
	button.topBorder:SetPoint("TOPLEFT")
	button.topBorder:SetPoint("TOPRIGHT")
	button.topBorder:SetHeight(1)

	button.bottomBorder = button:CreateTexture(nil, "BORDER")
	button.bottomBorder:SetPoint("BOTTOMLEFT")
	button.bottomBorder:SetPoint("BOTTOMRIGHT")
	button.bottomBorder:SetHeight(1)

	button.leftBorder = button:CreateTexture(nil, "BORDER")
	button.leftBorder:SetPoint("TOPLEFT")
	button.leftBorder:SetPoint("BOTTOMLEFT")
	button.leftBorder:SetWidth(1)

	button.rightBorder = button:CreateTexture(nil, "BORDER")
	button.rightBorder:SetPoint("TOPRIGHT")
	button.rightBorder:SetPoint("BOTTOMRIGHT")
	button.rightBorder:SetWidth(1)

	button.activeIcon = button:CreateTexture(nil, "ARTWORK")
	button.activeIcon:SetSize(14, 14)
	button.activeIcon:SetPoint("LEFT", 10, 0)
	button.activeIcon:SetTexture(MEDIA_ROOT .. "active.png")
	button.activeIcon:Hide()

	button.text = button:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	button.text:SetPoint("LEFT", 10, 0)
	button.text:SetPoint("RIGHT", -54, 0)
	button.text:SetJustifyH("LEFT")

	button.actionButton = CreateIconButton(button, "load", 18, L.load_profile_tooltip)
	button.actionButton:SetPoint("RIGHT", -28, 0)

	button.deleteButton = CreateIconButton(button, "delete", 18, DELETE)
	button.deleteButton:SetPoint("RIGHT", -6, 0)
	button.deleteButton:SetScript("OnClick", function(selfButton)
		local profileName = selfButton:GetParent().profileName
		if profileName and profileName ~= KeybindProfiles.DEFAULT_PROFILE_NAME then
			ShowDeleteProfilePopup(profileName)
		end
	end)

	button.selection = button:CreateTexture(nil, "OVERLAY")
	button.selection:SetPoint("TOPLEFT", 1, -1)
	button.selection:SetPoint("BOTTOMLEFT", 1, 1)
	button.selection:SetWidth(4)
	button.selection:SetColorTexture(1, 0.8, 0.2, 0.95)
	button.selection:Hide()

	button.highlight = button:CreateTexture(nil, "HIGHLIGHT")
	button.highlight:SetAllPoints()
	button.highlight:SetColorTexture(1, 0.82, 0.18, 0.08)

	function button:SetIndicatorColor(r, g, b, a)
		if r and g and b then
			self.stateTint:SetColorTexture(r, g, b, a or 0.18)
			self.hasIndicatorTint = true
		else
			self.stateTint:SetColorTexture(0, 0, 0, 0)
			self.hasIndicatorTint = false
		end
	end

	return button
end

local function SetProfileButtonState(button, isActive, isSelected)
	local palette = PROFILE_ROW_NEUTRAL
	if isSelected then
		palette = PROFILE_ROW_SELECTED
	end

	button.selection:Hide()
	button.background:SetColorTexture(unpack(PROFILE_ROW_NEUTRAL.bg))
	if palette.tint then
		button.stateTint:SetColorTexture(unpack(palette.tint))
	else
		button.stateTint:SetColorTexture(0, 0, 0, 0)
	end
	button.topBorder:SetColorTexture(unpack(palette.border))
	button.bottomBorder:SetColorTexture(unpack(palette.border))
	button.leftBorder:SetColorTexture(unpack(palette.border))
	button.rightBorder:SetColorTexture(unpack(palette.border))
	button.text:SetTextColor(unpack(palette.text))
	button.activeIcon:SetShown(isActive)
	button.text:ClearAllPoints()
	if isActive then
		button.text:SetPoint("LEFT", button.activeIcon, "RIGHT", 6, 0)
	else
		button.text:SetPoint("LEFT", 10, 0)
	end
	button.text:SetPoint("RIGHT", -54, 0)
end

local function CreateSpecRow(parent)
	local row = CreateFrame("Frame", nil, parent)
	row:SetSize(SPEC_ROW_WIDTH, 54)

	row.label = CreateLabel(row, "", "GameFontHighlight")
	row.label:SetPoint("TOPLEFT", 0, 0)

	row.dropdown = CreateDropdown(row, SPEC_DROPDOWN_WIDTH)
	row.dropdown:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -4)

	return row
end

local function RefreshDropdownEnabled(dropdown, enabled)
	if dropdown.SetEnabled then
		dropdown:SetEnabled(enabled)
	elseif dropdown.Enable and dropdown.Disable then
		if enabled then
			dropdown:Enable()
		else
			dropdown:Disable()
		end
	end
end

local function ConfigureProfileRowActions(button, profileName, isActive, isSelected, autosaveEnabled)
	button.actionButton:Hide()
	button.actionButton:SetScript("OnClick", nil)

	if isActive and isSelected and not autosaveEnabled then
		button.actionButton.icon:SetTexture(MEDIA_ROOT .. "save.png")
		button.actionButton.tooltipText = L.save_profile_tooltip
		button.actionButton:SetScript("OnClick", function()
			ShowSaveProfilePopup(profileName)
		end)
		button.actionButton:Show()
	elseif (not isActive) and isSelected then
		button.actionButton.icon:SetTexture(MEDIA_ROOT .. "load.png")
		button.actionButton.tooltipText = L.load_profile_tooltip
		button.actionButton:SetScript("OnClick", function()
			ShowLoadProfilePopup(profileName)
		end)
		button.actionButton:Show()
	end
end

function KeybindProfiles:InitializeOptions()
	if self.optionsPanel then
		if not self.settingsCategory and Settings and Settings.RegisterCanvasLayoutCategory then
			local launcherPanel = self.optionsLauncherPanel
			if launcherPanel then
				self.settingsCategory = Settings.RegisterCanvasLayoutCategory(launcherPanel, self.DISPLAY_NAME)
				Settings.RegisterAddOnCategory(self.settingsCategory)
			end
		end
		return
	end

	local panel = CreateFrame("Frame", self.NAME .. "Frame", UIParent, "SettingsFrameTemplate")
	panel:SetSize(980, 720)
	panel:SetPoint("CENTER")
	panel:SetClampedToScreen(true)
	panel:SetMovable(true)
	panel:SetToplevel(true)
	panel:SetFrameStrata("HIGH")
	panel:SetFrameLevel(100)
	panel:EnableMouse(true)
	panel:RegisterForDrag("LeftButton")
	panel:SetScript("OnDragStart", function(selfFrame)
		selfFrame:Raise()
		selfFrame:StartMoving()
	end)
	panel:SetScript("OnDragStop", function(selfFrame)
		selfFrame:StopMovingOrSizing()
	end)
	panel:Hide()
	self.optionsPanel = panel
	if panel.NineSlice and panel.NineSlice.Text then
		panel.NineSlice.Text:SetText(self.DISPLAY_NAME)
	end
	panel.name = self.DISPLAY_NAME

	if UISpecialFrames then
		local frameName = panel:GetName()
		local found = false
		for _, specialFrameName in ipairs(UISpecialFrames) do
			if specialFrameName == frameName then
				found = true
				break
			end
		end

		if not found then
			table.insert(UISpecialFrames, frameName)
		end
	end

	local body = CreateFrame("Frame", nil, panel)
	if panel.Bg then
		body:SetPoint("TOPLEFT", panel.Bg, "TOPLEFT", 10, -10)
		body:SetPoint("BOTTOMRIGHT", panel.Bg, "BOTTOMRIGHT", -10, 10)
	else
		body:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -30)
		body:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -10, 10)
	end
	panel.body = body

	panel.createProfileDialog = CreateCreateProfileDialog(panel)
	panel.deleteProfileDialog = CreateDeleteProfileDialog(panel)
	panel.actionConfirmDialog = CreateActionConfirmDialog(panel)
	panel.exportProfileDialog = CreateExportProfileDialog(panel)
	panel.importProfileDialog = CreateImportProfileDialog(panel)

	local bodyTint = body:CreateTexture(nil, "BACKGROUND")
	bodyTint:SetAllPoints()
	bodyTint:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Background-Dark")
	bodyTint:SetVertexColor(0.12, 0.08, 0.04, 0.08)

	local topRow = CreateFrame("Frame", nil, body)
	topRow:SetPoint("TOPLEFT", 12, -12)
	topRow:SetPoint("TOPRIGHT", -12, -12)
	topRow:SetHeight(28)
	panel.topRow = topRow

	local autosaveCheckbox = CreateCheckbox(topRow, L.autosave, L.autosave_desc)
	autosaveCheckbox:SetPoint("LEFT", 0, 0)
	panel.autosaveCheckbox = autosaveCheckbox

	local autoLoadCheckbox = CreateCheckbox(topRow, L.auto_loading, L.auto_loading_desc)
	autoLoadCheckbox:SetPoint("LEFT", autosaveCheckbox.text, "RIGHT", 28, 0)
	panel.autoLoadCheckbox = autoLoadCheckbox

	local notificationsCheckbox = CreateCheckbox(topRow, L.notifications, L.notifications_desc)
	notificationsCheckbox:SetPoint("LEFT", autoLoadCheckbox.text, "RIGHT", 28, 0)
	panel.notificationsCheckbox = notificationsCheckbox

	autosaveCheckbox:SetScript("OnClick", function(selfCheckbox)
		KeybindProfiles:GetCharacterDB().autosave = selfCheckbox:GetChecked() and true or false
		panel:Refresh()
	end)

	autoLoadCheckbox:SetScript("OnClick", function(selfCheckbox)
		KeybindProfiles:GetCharacterDB().autoLoadEnabled = selfCheckbox:GetChecked() and true or false
		panel:Refresh()
	end)

	notificationsCheckbox:SetScript("OnClick", function(selfCheckbox)
		KeybindProfiles.db.global.notifications = selfCheckbox:GetChecked() and true or false
		panel:Refresh()
	end)

	local primaryButton = CreateButton(body, L.open_quick_keybind, 220)
	primaryButton:SetPoint("TOPLEFT", topRow, "BOTTOMLEFT", 0, -12)
	primaryButton:SetPoint("TOPRIGHT", topRow, "BOTTOMRIGHT", 0, -12)
	primaryButton:SetScript("OnClick", function()
		KeybindProfiles:OpenQuickKeybindMode()
	end)
	panel.primaryButton = primaryButton

	local leftPane = CreateContentPane(body, 0)
	leftPane:SetPoint("TOPLEFT", primaryButton, "BOTTOMLEFT", 0, -14)
	leftPane:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT", 4, 4)
	leftPane:SetWidth(250)
	panel.leftPane = leftPane

	local columnDivider = body:CreateTexture(nil, "ARTWORK")
	columnDivider:SetWidth(1)
	columnDivider:SetPoint("TOPLEFT", leftPane, "TOPRIGHT", 7, 0)
	columnDivider:SetPoint("BOTTOMLEFT", leftPane, "BOTTOMRIGHT", 7, 0)
	columnDivider:SetColorTexture(1, 1, 1, 0.08)
	panel.columnDivider = columnDivider

	local listContainer = CreateSection(leftPane, "Saved Profiles", false)
	listContainer:SetPoint("TOPLEFT", leftPane, "TOPLEFT", 0, -2)
	listContainer:SetPoint("BOTTOMRIGHT", leftPane, "BOTTOMRIGHT", 0, 0)
	panel.listContainer = listContainer

	local addProfileButton = CreateIconButton(listContainer, "create", 20, L.create_profile)
	addProfileButton:SetPoint("TOPRIGHT", listContainer, "TOPRIGHT", 0, 0)
	addProfileButton:SetScript("OnClick", function()
		ShowCreateProfilePopup()
	end)
	panel.addProfileButton = addProfileButton

	local exportProfileButton = CreateIconButton(listContainer, "export", 20, L.export_profile_tooltip)
	exportProfileButton:SetPoint("RIGHT", addProfileButton, "LEFT", -6, 0)
	exportProfileButton:SetScript("OnClick", function()
		ShowExportProfilePopup(KeybindProfiles:GetSelectedProfileName())
	end)
	panel.exportProfileButton = exportProfileButton

	local importProfileButton = CreateIconButton(listContainer, "import", 20, L.import_profile_tooltip)
	importProfileButton:SetPoint("RIGHT", exportProfileButton, "LEFT", -6, 0)
	importProfileButton:SetScript("OnClick", function()
		ShowImportProfilePopup()
	end)
	panel.importProfileButton = importProfileButton

	local listScroll = CreateFrame("ScrollFrame", nil, listContainer, "UIPanelScrollFrameTemplate")
	listScroll:SetPoint("TOPLEFT", listContainer, "TOPLEFT", 8, -36)
	listScroll:SetPoint("BOTTOMRIGHT", listContainer, "BOTTOMRIGHT", -18, 8)
	panel.listScroll = listScroll

	local listContent = CreateFrame("Frame", nil, listScroll)
	listContent:SetPoint("TOPLEFT")
	listContent:SetPoint("TOPRIGHT")
	listContent:SetWidth(200)
	listContent:SetHeight(1)
	listScroll:SetScrollChild(listContent)
	panel.listContent = listContent
	panel.profileButtons = {}

	local rightPane = CreateContentPane(body, 0)
	rightPane:SetPoint("TOPLEFT", leftPane, "TOPRIGHT", 14, 0)
	rightPane:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -4, 4)
	panel.rightPane = rightPane

	local specSection = CreateSection(rightPane, "Specialization Auto-Load")
	specSection:SetPoint("TOPLEFT", rightPane, "TOPLEFT", 0, -2)
	specSection:SetPoint("TOPRIGHT", rightPane, "TOPRIGHT", 0, -2)
	specSection:SetPoint("BOTTOM", rightPane, "BOTTOM", 0, 36)
	panel.specSection = specSection

	local specDescription =
		CreateLabel(specSection, "Choose which profile should load for each specialization.", "GameFontHighlightSmall")
	specDescription:SetPoint("TOPLEFT", specSection.title, "BOTTOMLEFT", 0, -16)
	specDescription:SetPoint("TOPRIGHT", specSection, "TOPRIGHT", 0, -46)
	specDescription:SetTextColor(0.85, 0.78, 0.7)
	panel.specDescription = specDescription

	panel.specRows = {}
	local specs = self:GetAvailableSpecializations()
	for index, specInfo in ipairs(specs) do
		local row = CreateSpecRow(specSection)
		local column = ((index - 1) % 2)
		local rowIndex = math.floor((index - 1) / 2)
		row:SetPoint(
			"TOPLEFT",
			specDescription,
			"BOTTOMLEFT",
			column * (SPEC_ROW_WIDTH + SPEC_COLUMN_SPACING),
			-(14 + (rowIndex * 58))
		)
		row.specInfo = specInfo
		row.label:SetText(specInfo.name)

		row.dropdown:SetupMenu(function(_, rootDescription)
			local function IsSelected(profileName)
				return KeybindProfiles:GetProfileForSpecialization(specInfo.specializationID) == profileName
			end

			local function SetSelected(profileName)
				if profileName == false then
					KeybindProfiles:SetRuleForSpecialization(specInfo.specializationID, nil)
				else
					KeybindProfiles:SetRuleForSpecialization(specInfo.specializationID, profileName)
				end

				panel:Refresh()
			end

			rootDescription:CreateRadio(L.none, IsSelected, SetSelected, false)
			for _, profileName in ipairs(KeybindProfiles:ListProfiles()) do
				rootDescription:CreateRadio(profileName, IsSelected, SetSelected, profileName)
			end
		end)

		panel.specRows[#panel.specRows + 1] = row
	end

	local footer = CreateLabel(rightPane, "", "GameFontHighlightSmall")
	footer:SetPoint("BOTTOMLEFT", rightPane, "BOTTOMLEFT", 14, 12)
	footer:SetPoint("BOTTOMRIGHT", rightPane, "BOTTOMRIGHT", -14, 12)
	footer:SetJustifyH("LEFT")
	footer:SetTextColor(0.85, 0.78, 0.7)
	panel.footer = footer

	local function EnsureProfileButtons(profileCount)
		while #panel.profileButtons < profileCount do
			local button = CreateProfileListButton(listContent)
			local index = #panel.profileButtons + 1
			button:SetScript("OnClick", function(selfButton)
				KeybindProfiles:SetSelectedProfileName(selfButton.profileName)
				panel:Refresh()
			end)

			panel.profileButtons[index] = button
		end
	end

	local function RefreshProfileList(profileNames)
		local activeProfileName = KeybindProfiles:GetActiveProfileName()
		local selectedProfileName = KeybindProfiles:GetSelectedProfileName()
		local autosaveEnabled = KeybindProfiles:GetCharacterDB().autosave
		EnsureProfileButtons(#profileNames)

		local lastButton
		for index, button in ipairs(panel.profileButtons) do
			local profileName = profileNames[index]
			if profileName then
				button.profileName = profileName
				button.text:SetText(profileName)
				button:Show()
				button:ClearAllPoints()
				if lastButton then
					button:SetPoint("TOPLEFT", lastButton, "BOTTOMLEFT", 0, -PROFILE_BUTTON_SPACING)
					button:SetPoint("TOPRIGHT", lastButton, "BOTTOMRIGHT", 0, -PROFILE_BUTTON_SPACING)
				else
					button:SetPoint("TOPLEFT", listContent, "TOPLEFT")
					button:SetPoint("TOPRIGHT", listContent, "TOPRIGHT")
				end

				local isActive = activeProfileName == profileName
				local isSelected = selectedProfileName == profileName
				button:SetIndicatorColor(nil)
				SetProfileButtonState(button, isActive, isSelected)
				ConfigureProfileRowActions(button, profileName, isActive, isSelected, autosaveEnabled)
				SetIconButtonEnabled(button.deleteButton, profileName ~= KeybindProfiles.DEFAULT_PROFILE_NAME)
				lastButton = button
			else
				button:Hide()
			end
		end

		local totalHeight = math.max(
			1,
			(#profileNames * PROFILE_BUTTON_HEIGHT) + (math.max(#profileNames - 1, 0) * PROFILE_BUTTON_SPACING)
		)
		listContent:SetHeight(totalHeight)
	end

	function panel:Refresh()
		if not KeybindProfiles.db then
			return
		end

		local characterDB = KeybindProfiles:GetCharacterDB()
		local selectedProfile = KeybindProfiles:GetSelectedProfileName()
		local profileNames = KeybindProfiles:ListProfiles()

		self.autosaveCheckbox:SetChecked(characterDB.autosave)
		self.autoLoadCheckbox:SetChecked(characterDB.autoLoadEnabled)
		self.notificationsCheckbox:SetChecked(KeybindProfiles.db.global.notifications ~= false)

		self.footer:SetText(
			"Profiles are account-wide. Active profile selection and auto-load rules are saved per character."
		)

		listContent:SetWidth(math.max(1, listScroll:GetWidth() - 6))
		RefreshProfileList(profileNames)

		for _, row in ipairs(self.specRows) do
			local mappedProfile = KeybindProfiles:GetProfileForSpecialization(row.specInfo.specializationID)
			SetDropdownText(row.dropdown, mappedProfile or L.none)
			RefreshDropdownEnabled(row.dropdown, characterDB.autoLoadEnabled)
		end
	end

	panel:SetScript("OnShow", function(selfPanel)
		selfPanel:Raise()
		selfPanel:Refresh()
	end)

	if not self.optionsLauncherPanel then
		local launcherPanel = CreateFrame("Frame", nil, UIParent)
		launcherPanel.name = self.DISPLAY_NAME
		self.optionsLauncherPanel = launcherPanel

		local title = CreateLabel(launcherPanel, self.DISPLAY_NAME, "GameFontNormalHuge")
		title:SetPoint("TOPLEFT", 16, -16)

		local bodyText = CreateLabel(launcherPanel, L.launcher_body, "GameFontHighlight")
		bodyText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
		bodyText:SetWidth(680)
		bodyText:SetJustifyH("LEFT")
		bodyText:SetJustifyV("TOP")

		local openButton = CreateButton(launcherPanel, L.open_settings_window, 180)
		openButton:SetPoint("TOPLEFT", bodyText, "BOTTOMLEFT", 0, -18)
		openButton:SetScript("OnClick", function()
			KeybindProfiles:OpenSettings()
		end)

		local openHint = CreateLabel(launcherPanel, L.open_settings_window_desc, "GameFontHighlightSmall")
		openHint:SetPoint("LEFT", openButton, "RIGHT", 12, 0)
		openHint:SetTextColor(0.85, 0.78, 0.7)
	end

	if Settings and Settings.RegisterCanvasLayoutCategory then
		self.settingsCategory = Settings.RegisterCanvasLayoutCategory(self.optionsLauncherPanel, self.DISPLAY_NAME)
		Settings.RegisterAddOnCategory(self.settingsCategory)
	end
end
