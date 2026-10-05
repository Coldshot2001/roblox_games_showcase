--!strict

export type ItemInstance = { [string]: any }
export type ItemDefinition = { [string]: any }

local Economy = {}

function Economy.getSellRefund(item: ItemInstance, definition: ItemDefinition): number
	local cost = definition.Cost
	if typeof(cost) ~= "number" or cost <= 0 then
		return 0
	end

	if definition.Type ~= "Generator" then
		return cost
	end

	local maxDurability = item.MaxDurability
	local curDurability = item.CurDurability
	if typeof(maxDurability) ~= "number" or maxDurability <= 0 then
		return 0
	end
	if typeof(curDurability) ~= "number" then
		return 0
	end

	curDurability = math.clamp(curDurability, 0, maxDurability)
	return cost * (curDurability / maxDurability)
end

return Economy
