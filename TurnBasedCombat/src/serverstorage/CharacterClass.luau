--!strict

local Abilities = require(game.ServerStorage.AbilitiesDatabase).Abilities

local Character = {}
Character.__index = Character

local function copySkills(skills: any): any
	local copy = {}
	for key, skill in pairs(skills or {}) do
		copy[key] = table.clone(skill)
	end
	return copy
end

function Character.new(stat: any, model: any): any
	if typeof(stat) ~= "table" then
		warn(string.format("CharacterClass: stats are a %s, not a table", typeof(stat)))
		return nil
	end
	if typeof(model) ~= "Instance" or not model:IsA("Model") then
		warn(string.format("CharacterClass: %s is not a character model", tostring(model)))
		return nil
	end

	local char = table.clone(stat)
	char.Skills = copySkills(Abilities[char.Name])
	char.Model = model
	return setmetatable(char, Character)
end

function Character.clone(template: any): any
	local char = table.clone(template)
	char.Skills = copySkills(template.Skills)
	char.Model = template.Model
	return setmetatable(char, Character)
end

return Character
