local _, NS = ...
local KeybindProfiles = NS.KeybindProfiles

function KeybindProfiles:GetAvailableSpecializations()
	local specializations = {}
	local _, _, classID = UnitClass("player")

	if classID and type(GetNumSpecializationsForClassID) == "function" then
		local totalSpecs = GetNumSpecializationsForClassID(classID) or 0
		for index = 1, totalSpecs do
			local specializationID, name = GetSpecializationInfoForClassID(classID, index)
			if specializationID then
				specializations[#specializations + 1] = {
					index = index,
					specializationID = specializationID,
					name = name or string.format("Spec %d", index),
				}
			end
		end
	end

	if #specializations == 0 and type(GetNumSpecializations) == "function" then
		local totalSpecs = GetNumSpecializations() or 0
		for index = 1, totalSpecs do
			local specializationID, name = GetSpecializationInfo(index)
			if specializationID then
				specializations[#specializations + 1] = {
					index = index,
					specializationID = specializationID,
					name = name or string.format("Spec %d", index),
				}
			end
		end
	end

	return specializations
end

function KeybindProfiles:GetCurrentSpecializationID()
	if type(GetSpecialization) ~= "function" then
		return nil
	end

	local currentSpecIndex = GetSpecialization()
	if not currentSpecIndex then
		return nil
	end

	local specializationID = GetSpecializationInfo(currentSpecIndex)
	return specializationID
end

function KeybindProfiles:BuildContext()
	local _, instanceType, difficultyID, _, _, _, _, instanceMapID = GetInstanceInfo()

	return {
		specializationID = self:GetCurrentSpecializationID(),
		instanceType = instanceType ~= "" and instanceType or nil,
		difficultyID = difficultyID,
		mapID = instanceMapID,
	}
end
