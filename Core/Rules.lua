local _, NS = ...
local KeybindProfiles = NS.KeybindProfiles

function KeybindProfiles:GetRules()
	local characterDB = self:GetCharacterDB()
	characterDB.rules = characterDB.rules or {}
	return characterDB.rules
end

function KeybindProfiles:GetRuleForSpecialization(specializationID)
	for index, rule in ipairs(self:GetRules()) do
		if
			type(rule) == "table"
			and type(rule.conditions) == "table"
			and rule.conditions.specializationID == specializationID
		then
			return rule, index
		end
	end

	return nil, nil
end

function KeybindProfiles:GetProfileForSpecialization(specializationID)
	local rule = self:GetRuleForSpecialization(specializationID)
	return rule and rule.profileName or nil
end

function KeybindProfiles:SetRuleForSpecialization(specializationID, profileName, silent)
	local rules = self:GetRules()
	local existingRule, existingIndex = self:GetRuleForSpecialization(specializationID)

	if not profileName then
		if existingIndex then
			table.remove(rules, existingIndex)
		end

		if not silent then
			self:RefreshOptions()
		end

		return true
	end

	if existingRule then
		existingRule.enabled = true
		existingRule.priority = existingRule.priority or self.DEFAULT_RULE_PRIORITY
		existingRule.profileName = profileName
		existingRule.conditions = existingRule.conditions or {}
		existingRule.conditions.specializationID = specializationID
	else
		rules[#rules + 1] = {
			id = string.format("spec-%d", specializationID),
			enabled = true,
			priority = self.DEFAULT_RULE_PRIORITY,
			profileName = profileName,
			conditions = {
				specializationID = specializationID,
			},
		}
	end

	if not silent then
		self:RefreshOptions()
	end

	return true
end

function KeybindProfiles:DoesRuleMatch(rule, context)
	if type(rule) ~= "table" or rule.enabled == false then
		return false
	end

	if not self:ProfileExists(rule.profileName) then
		return false
	end

	local conditions = rule.conditions
	if type(conditions) ~= "table" or next(conditions) == nil then
		return false
	end

	for _, key in ipairs(self.CONDITION_KEYS) do
		local expectedValue = conditions[key]
		if expectedValue ~= nil and context[key] ~= expectedValue then
			return false
		end
	end

	return true
end

function KeybindProfiles:ResolveRule(context)
	local winningRule
	local highestPriority

	for _, rule in ipairs(self:GetRules()) do
		if self:DoesRuleMatch(rule, context) then
			local priority = rule.priority or 0
			if not winningRule or priority > highestPriority then
				winningRule = rule
				highestPriority = priority
			end
		end
	end

	return winningRule
end

function KeybindProfiles:EvaluateRules(reason, force)
	local characterDB = self:GetCharacterDB()
	if not characterDB.autoLoadEnabled then
		self:RefreshOptions()
		return false
	end

	local matchedRule = self:ResolveRule(self:BuildContext())
	if not matchedRule then
		self:RefreshOptions()
		return false
	end

	local applied = self:LoadProfile(matchedRule.profileName, {
		force = force,
		reason = reason or matchedRule.id or "rule",
		silent = true,
	})

	self:RefreshOptions()
	return applied
end
