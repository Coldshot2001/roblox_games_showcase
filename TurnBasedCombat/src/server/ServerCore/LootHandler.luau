local ItemTables = require(game.ServerStorage.LootTables)
local DataStorage = require(script.Parent.GameDataStorage)

local ItemService = { LootTables = ItemTables }

local function getTotalWeightOfLootTable(lootTable)
	local weight = 0
	for _, v in ipairs(lootTable) do
		weight = weight + v[2]
	end
	return weight
end

local function shallowCopy(original)
	local copy = {}
	for key, value in pairs(original) do
		copy[key] = value
	end
	return copy
end

function ItemService:GetRandomItemFromLootTable(lootTable)
	local totalWeight = getTotalWeightOfLootTable(lootTable)
	local randomNumber = math.random(totalWeight)
	--[[ 
		loops through the lootTable, if an item is less or equal to the weight of the current entry
		it will return the item, otherwise it will subtract the weight and continue the process
		until an item is returned
	--]]
	for _, entry in ipairs(lootTable) do
		if randomNumber <= entry[2] then -- weight is less than random number so returns item
			return entry[1]
		else -- no item, subtracts the weight from randomNumber
			randomNumber = randomNumber - entry[2]
		end
	end
end

function ItemService:AddCurrency(player, Type, Amount)
	DataStorage.GameData[player.Name]["Currencies"][Type] += Amount
	if DataStorage.GameData[player.Name]["Currencies"][Type] < 0 then
		DataStorage.GameData[player.Name]["Currencies"][Type] = 0
	end
	game.ReplicatedStorage.SharedRemotes.VisualHandle:FireClient(
		player,
		"CurrencyUi",
		Type,
		DataStorage.GameData[player.Name]["Currencies"][Type]
	)
end

function ItemService:AddUnit(player, UnitData)
	table.insert(DataStorage.GameData[player.Name]["Inventory"]["Units"], shallowCopy(UnitData))
	game.ReplicatedStorage.SharedRemotes.VisualHandle:FireClient(
		player,
		"InventoryUi",
		"Unit",
		DataStorage.GameData[player.Name]["Inventory"]["Units"]
	)
end

return ItemService
