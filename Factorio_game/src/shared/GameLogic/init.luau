--!strict

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemsDatabase = require(ReplicatedStorage:WaitForChild("ItemsDatabase"))
local NeighbourLogic = require(script:WaitForChild("NeighbourLogic"))

export type ItemInstance = { [string]: any }
export type PlayerData = {
	Stats: { [string]: number },
	GameGrid: any,
	BoughtUpgrades: any,
	SavedLayouts: any,
	CurrentLayout: any,
}

local FLUX_DECAY_PER_TICK = 0.1

local GameLogic = {}

local createItem: { [string]: (itemID: string) -> ItemInstance } = {}

createItem.Generator = function(itemID: string): ItemInstance
	local definition = ItemsDatabase[itemID]
	return {
		ItemID = itemID,
		MaxDurability = definition.Durability,
		CurDurability = definition.Durability,
	}
end

createItem.Cooler = function(itemID: string): ItemInstance
	local definition = ItemsDatabase[itemID]
	return {
		ItemID = itemID,
		MaxCapacity = definition.Capacity,
		CurCapacity = 0,
		CurIntake = 0,
	}
end

createItem.Amplifier = function(itemID: string): ItemInstance
	return { ItemID = itemID }
end

createItem.ManaUpgrade = function(itemID: string): ItemInstance
	return { ItemID = itemID }
end

createItem.FluxStorage = function(itemID: string): ItemInstance
	return { ItemID = itemID }
end

createItem.FluxUpgrade = function(itemID: string): ItemInstance
	return { ItemID = itemID }
end

createItem.FluxInlet = function(itemID: string): ItemInstance
	return { ItemID = itemID }
end

createItem.FluxOutlet = function(itemID: string): ItemInstance
	return { ItemID = itemID }
end

createItem.Exchanger = function(itemID: string): ItemInstance
	return { ItemID = itemID }
end

local function getItemModelTemplate(modelName: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local models = assets and assets:FindFirstChild("Models")
	local template = models and models:FindFirstChild(modelName)
	if template and template:IsA("Model") then
		return template
	end
	return nil
end

local function copyMatchingFields(target: ItemInstance, source: { [string]: any })
	for key, defaultValue in pairs(target) do
		local sourceValue = source[key]
		if sourceValue ~= nil and typeof(sourceValue) == typeof(defaultValue) then
			target[key] = sourceValue
		end
	end
end

local function buildItem(itemID: string, savedData: any): ItemInstance?
	local definition = ItemsDatabase[itemID]
	if typeof(definition) ~= "table" then
		return nil
	end

	local constructor = createItem[definition.Type]
	if not constructor then
		return nil
	end

	local item = constructor(itemID)

	if savedData ~= nil then
		if typeof(savedData) ~= "table" then
			return nil
		end
		copyMatchingFields(item, savedData)
	end

	if typeof(item.MaxDurability) == "number" and item.MaxDurability > 0 then
		item.CurDurability = math.clamp(item.CurDurability, 0, item.MaxDurability)
	end
	if typeof(item.MaxCapacity) == "number" and item.MaxCapacity > 0 then
		item.CurCapacity = math.clamp(item.CurCapacity, 0, item.MaxCapacity)
		item.CurIntake = math.max(0, item.CurIntake)
	end

	return item
end

local function attachClientModel(x: number, y: number, grid: any, item: ItemInstance)
	if RunService:IsServer() then
		return
	end

	local definition = ItemsDatabase[item.ItemID]
	local template = getItemModelTemplate(definition.Model)
	if not template then
		return
	end

	local clone = template:Clone()
	clone:PivotTo(CFrame.new(grid:GetWorldPosition(x, y)) * CFrame.new(0, 3, 0))
	clone:SetAttribute("x", x)
	clone:SetAttribute("y", y)
	clone.Parent = workspace
	item.Model = clone
end

local ItemsLogic: { [string]: (number, number, ItemInstance, PlayerData, any) -> () } = {}

ItemsLogic.Generator = function(x, y, item, playerData, grid)
	if item.CurDurability <= 0 then
		GameLogic:DestroyItem(x, y, grid)
		return
	end
	item.CurDurability -= 1

	local definition = ItemsDatabase[item.ItemID]
	local stats = playerData.Stats
	local neighbours = grid:GetNeighbours(x, y)

	local generateMana, generateFlux = true, true
	if #neighbours > 0 then
		local groups: { [string]: NeighbourLogic.NeighbourGroup } = {}
		for _, position in ipairs(neighbours) do
			local neighbourCell = grid:GetValue(position[1], position[2])
			local neighbourItem = neighbourCell and neighbourCell[1]
			if neighbourItem then
				local neighbourDefinition = ItemsDatabase[neighbourItem.ItemID]
				if neighbourDefinition then
					local group = groups[neighbourDefinition.Type]
					if group then
						group.count += 1
						table.insert(group.items, neighbourItem)
					else
						groups[neighbourDefinition.Type] = { count = 1, items = { neighbourItem } }
					end
				end
			end
		end
		generateMana, generateFlux = NeighbourLogic.Check(definition, groups)
	end

	if generateMana then
		stats.CurMana = math.min(stats.CurMana + (definition.Mana or 0), stats.MaxMana)
	end
	if generateFlux then
		stats.CurFlux = math.min(stats.CurFlux + (definition.Flux or 0), stats.MaxFlux)
	end
end

ItemsLogic.Cooler = function(x, y, item, _playerData, grid)
	if item.CurCapacity >= item.MaxCapacity then
		GameLogic:DestroyItem(x, y, grid)
		return
	end

	if item.CurCapacity > 0 then
		local definition = ItemsDatabase[item.ItemID]
		item.CurCapacity = math.max(0, item.CurCapacity - definition.Transfer)
		item.CurIntake = 0
	end
end

ItemsLogic.Amplifier = function() end
ItemsLogic.ManaUpgrade = function() end
ItemsLogic.FluxStorage = function() end
ItemsLogic.FluxUpgrade = function() end
ItemsLogic.FluxInlet = function() end
ItemsLogic.FluxOutlet = function() end
ItemsLogic.Exchanger = function() end

function GameLogic:Tick(playerData: PlayerData)
	local stats = playerData.Stats
	local grid = playerData.GameGrid

	for y = 1, stats.LayoutHeight do
		for x = 1, stats.LayoutWidth do
			local cell = grid:GetValue(x, y)
			local item = cell and cell[1]
			if item then
				local definition = ItemsDatabase[item.ItemID]
				assert(definition, string.format("Unknown item id %q on the grid", tostring(item.ItemID)))
				local logic = ItemsLogic[definition.Type]
				assert(logic, string.format("No tick logic for item type %q", tostring(definition.Type)))
				logic(x, y, item, playerData, grid)
			end
		end
	end

	stats.CurFlux = math.max(0, stats.CurFlux - FLUX_DECAY_PER_TICK)
	stats.CurFlux = math.min(stats.CurFlux, stats.MaxFlux)
	stats.CurMana = math.min(stats.CurMana, stats.MaxMana)
end

function GameLogic:AddItem(x: number, y: number, itemID: string, grid: any, savedData: any?): boolean
	local cell = grid:GetValue(x, y)
	if cell ~= nil and cell[1] ~= nil then
		return false
	end

	local item = buildItem(itemID, savedData)
	if not item then
		return false
	end

	attachClientModel(x, y, grid, item)
	return grid:SetValue(x, y, { item })
end

function GameLogic:UpdateItem(x: number, y: number, grid: any, updatedData: any)
	if updatedData == nil or typeof(updatedData) ~= "table" or typeof(updatedData.ItemID) ~= "string" then
		GameLogic:DestroyItem(x, y, grid)
		return
	end

	local cell = grid:GetValue(x, y)
	local oldItem = cell and cell[1]

	local item = buildItem(updatedData.ItemID, updatedData)
	if not item then
		return
	end

	if oldItem and oldItem.Model then
		item.Model = oldItem.Model
	end
	if item.Model == nil then
		attachClientModel(x, y, grid, item)
	end

	grid:SetValue(x, y, { item })
end

function GameLogic:DestroyItem(x: number, y: number, grid: any): boolean
	local cell = grid:GetValue(x, y)
	local item = cell and cell[1]
	if not item then
		return false
	end

	if not RunService:IsServer() and item.Model then
		item.Model:Destroy()
	end

	grid:SetValue(x, y, nil)
	return true
end

function GameLogic:ClearAllItems(grid: any)
	for y = 1, grid.height do
		for x = 1, grid.width do
			local cell = grid:GetValue(x, y)
			local item = cell and cell[1]
			if item then
				if not RunService:IsServer() and item.Model then
					item.Model:Destroy()
				end
				grid:SetValue(x, y, nil)
			end
		end
	end
end

for _, definition in pairs(ItemsDatabase) do
	assert(
		createItem[definition.Type],
		string.format("Item type %q has no constructor", tostring(definition.Type))
	)
	assert(ItemsLogic[definition.Type], string.format("Item type %q has no tick logic", tostring(definition.Type)))
end

return GameLogic
