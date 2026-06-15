local Character = {}
local Abilities = require(game.ServerStorage.AbilitiesDatabase).Abilities
Character.__index = Character

local function shallowCopy(original)
	local copy = {}
	for key, value in pairs(original) do
		copy[key] = value
	end
	return copy
end

function Character.new(stat, model)
	local char = {}

	if type(stat) ~= "table" then
		warn(string.format("Stats are a %q, not a table!", tostring(type(stat))))
		return nil
	elseif not model.ClassName or model.ClassName ~= "Model" or not model then
		warn(string.format("%q is not a character model!", tostring(model)))
		return nil
	elseif type(stat) == "table" and model.ClassName == "Model" then
		for i, v in pairs(stat) do
			char[i] = v
		end
		char.Skills = Abilities[char.Name]
		char.Model = model
		--char.Name = nil
		setmetatable(char, Character)
		return char
	end
end

return Character
