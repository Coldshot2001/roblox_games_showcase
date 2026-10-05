--!strict

export type ItemInstance = { [string]: any }
export type NeighbourGroup = { count: number, items: { ItemInstance } }

local NeighbourLogic = {}

local ROUNDING_FACTOR = 100

local function roundToCents(value: number): number
	return math.floor(value * ROUNDING_FACTOR) / ROUNDING_FACTOR
end

NeighbourLogic.Rules = {}

NeighbourLogic.Rules.Generator = {
	Cooler = function(
		itemDefinition: any,
		group: NeighbourGroup,
		generateMana: boolean,
		_generateFlux: boolean
	): (boolean, boolean)
		local share = roundToCents(itemDefinition.Flux / group.count)
		for _, cooler in ipairs(group.items) do
			cooler.CurIntake += share
			cooler.CurCapacity = math.min(cooler.CurCapacity + share, cooler.MaxCapacity)
		end
		return generateMana, false
	end,
}

function NeighbourLogic.Check(itemDefinition: any, groups: { [string]: NeighbourGroup }): (boolean, boolean)
	local generateMana = true
	local generateFlux = true

	local rules = NeighbourLogic.Rules[itemDefinition.Type]
	if not rules then
		return generateMana, generateFlux
	end

	for neighbourType, group in pairs(groups) do
		local rule = rules[neighbourType]
		if rule then
			generateMana, generateFlux = rule(itemDefinition, group, generateMana, generateFlux)
		end
	end

	return generateMana, generateFlux
end

return NeighbourLogic
