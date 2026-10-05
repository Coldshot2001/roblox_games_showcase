--!strict

local LootTables = require(game.ServerStorage.LootTables)
local CharacterClass = require(game.ServerStorage.CharacterClass)
local DataStorage = require(script.Parent.GameDataStorage)

local ItemService = { LootTables = LootTables }

local function getTotalWeight(lootTable: any): number
	local weight = 0
	for _, entry in ipairs(lootTable) do
		weight += entry[2]
	end
	return weight
end

function ItemService:GetRandomItemFromLootTable(lootTable: any): any?
	local totalWeight = getTotalWeight(lootTable)
	if totalWeight <= 0 then
		return nil
	end

	local roll = math.random(totalWeight)
	for _, entry in ipairs(lootTable) do
		if roll <= entry[2] then
			return entry[1]
		end
		roll -= entry[2]
	end

	return nil
end

function ItemService:AddCurrency(player: Player, currencyType: string, amount: number)
	local playerData = DataStorage.GameData[player.UserId]
	if not playerData then
		return
	end

	local currencies = playerData.Currencies
	if currencies[currencyType] == nil then
		return
	end

	currencies[currencyType] = math.max(0, currencies[currencyType] + amount)
	game.ReplicatedStorage.SharedRemotes.VisualHandle:FireClient(
		player,
		"CurrencyUi",
		currencyType,
		currencies[currencyType]
	)
end

function ItemService:AddUnit(player: Player, unitData: any)
	local playerData = DataStorage.GameData[player.UserId]
	if not playerData or typeof(unitData) ~= "table" then
		return
	end

	local units = playerData.Inventory.Units
	table.insert(units, CharacterClass.clone(unitData))
	game.ReplicatedStorage.SharedRemotes.VisualHandle:FireClient(player, "InventoryUi", "Unit", units)
end

return ItemService
