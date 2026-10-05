--!strict

local TurnLogic = {}

function TurnLogic.getUsableSkill(character: any, skillIndex: any): any?
	if typeof(skillIndex) ~= "number" or skillIndex ~= math.floor(skillIndex) then
		return nil
	end
	local skills = character.Skills
	if typeof(skills) ~= "table" then
		return nil
	end
	local skill = skills[skillIndex]
	if typeof(skill) ~= "table" then
		return nil
	end
	if skill.Type == "Passive" or (skill.CurCD or 0) > 0 then
		return nil
	end
	return skill
end

function TurnLogic.getTarget(entries: any, targetName: any, targetIndex: any): any?
	if typeof(targetName) ~= "string" or typeof(targetIndex) ~= "number" then
		return nil
	end
	if targetIndex ~= math.floor(targetIndex) then
		return nil
	end
	local entry = entries[targetIndex]
	if typeof(entry) ~= "table" then
		return nil
	end
	local character = entry[1]
	if typeof(character) ~= "table" or character.Name ~= targetName then
		return nil
	end
	return entry
end

function TurnLogic.sideMatchesType(skillType: any, targetSide: any): boolean
	if skillType == "Attack" then
		return targetSide == "Enemy"
	end
	if skillType == "Support" then
		return targetSide == "Ally"
	end
	return false
end

function TurnLogic.getUsableSkills(character: any): { any }
	local usable = {}
	for _, skill in pairs(character.Skills or {}) do
		if typeof(skill) == "table" and skill.Type ~= "Passive" and (skill.CurCD or 0) == 0 then
			table.insert(usable, skill)
		end
	end
	return usable
end

function TurnLogic.getFirstEntry(entries: any, side: string): any?
	for _, entry in pairs(entries) do
		if entry[2] == side then
			return entry
		end
	end
	return nil
end

function TurnLogic.teamHealth(entries: any, side: string): number
	local total = 0
	for _, entry in pairs(entries) do
		if entry[2] == side then
			total += entry[1]["Current Health"] or 0
		end
	end
	return total
end

return TurnLogic
