local RunService = game:GetService("RunService")
local ItemsDatabase = require(game:GetService("ReplicatedStorage"):WaitForChild("ItemsDatabase", 10))
local NeighbourLogic = require(script.NeighbourLogic)

local GameLogic = {}

local createItem = {
	["Generator"] = function(ItemID)
		local ItemObject = {
			["MaxDurability"] = ItemsDatabase[ItemID]["Durability"],
			["CurDurability"] = ItemsDatabase[ItemID]["Durability"],
			["ItemID"] = ItemID
		}
		return ItemObject
	end,
	["Cooler"] = function(ItemID)
		local ItemObject = {
			["MaxCapacity"] = ItemsDatabase[ItemID]["Capacity"],
			["CurCapacity"] = 0,
			["CurIntake"] = 0,
			["ItemID"] = ItemID
		}
		return ItemObject
	end,
	["Amplifier"] = function()
		return {}
	end,
	["ManaUpgrade"] = function()
		return {}
	end,
	["FluxStorage"] = function()
		return {}
	end,
	["FluxUpgrade"] = function()
		return {}
	end,
	["FluxInlet"] = function()
		return {}
	end,
	["FluxOutlet"] = function()
		return {}
	end,
	["Exchanger"] = function()
		return {}
	end,
}

local ItemsLogic = {
	["Generator"] = function(x, y, selfData, PlayerData, GridObject)
		local ServerMode = RunService:IsServer()
		local NeighbourTypeCount = {}
		local GenerateMana = true
		local GenerateFlux = true
		
		if selfData["CurDurability"] <= 0 then
			GameLogic:DestroyItem(x, y, GridObject)
			if ServerMode == false then
				selfData["Model"]:Destroy()
			end
			return
		else
			selfData["CurDurability"] -= 1
		end
		
		--apply player upgrades here
		local ItemData = ItemsDatabase[ selfData["ItemID"] ]
		
		local PlayerStats = PlayerData["Stats"]
		
		--check neighbours
		local Neighbours = GridObject:GetNeighbours(x, y)
		
		if #Neighbours ~= 0 then
			for i,Neighbour in ipairs(Neighbours) do
				local x,y = Neighbour[2],Neighbour[1]
				local NeighbourData = GridObject:GetValue(x,y)
				local NeighbourType = ItemsDatabase[ NeighbourData[1]["ItemID"] ]["Type"]
				
				if not NeighbourTypeCount[NeighbourType] then
					NeighbourTypeCount[NeighbourType] = { Count = 1, Data = { [1] = { NeighbourData[1] } } }
				else
					NeighbourTypeCount[NeighbourType]["Count"] += 1
					table.insert(NeighbourTypeCount[NeighbourType]["Data"],{ NeighbourData[1] })
				end
			end
			
			GenerateMana,GenerateFlux = NeighbourLogic.Check(ItemData,PlayerStats,NeighbourTypeCount)
		end
		
		if GenerateMana then PlayerStats["CurMana"] = PlayerStats["CurMana"] < PlayerStats["MaxMana"] and PlayerStats["CurMana"] + ItemData["Mana"] or PlayerStats["MaxMana"] end
		if GenerateFlux then PlayerStats["CurFlux"] = PlayerStats["CurFlux"] < PlayerStats["MaxFlux"] and PlayerStats["CurFlux"] + ItemData["Flux"] or PlayerStats["MaxFlux"] end
	end,
	["Cooler"] = function(x, y, selfData, PlayerData, GridObject)
		local ServerMode = RunService:IsServer()
		if selfData["CurCapacity"] >= selfData["MaxCapacity"] then
			
			GameLogic:DestroyItem(x, y, GridObject)
			if ServerMode == false then
				selfData["Model"]:Destroy()
			end
			return
		elseif selfData["CurCapacity"] > 0 then
			local ItemData = ItemsDatabase[ selfData["ItemID"] ]
			selfData["CurCapacity"] = selfData["CurCapacity"] - ItemData["Transfer"] < 0 and 0 or selfData["CurCapacity"] - ItemData["Transfer"]
			selfData["CurIntake"] = 0
		end
	end,
	["Amplifier"] = function()
		print("i dont wanna code this yet :(")
	end,
	["ManaUpgrade"] = function()
		print("i dont wanna code this yet :(")
	end,
	["FluxStorage"] = function()
		print("i dont wanna code this yet :(")
	end,
	["FluxUpgrade"] = function()
		print("i dont wanna code this yet :(")
	end,
	["FluxInlet"] = function()
		print("i dont wanna code this yet :(")
	end,
	["FluxOutlet"] = function()
		print("i dont wanna code this yet :(")
	end,
	["Exchanger"] = function()
		print("i dont wanna code this yet :(")
	end,
}

function GameLogic:Tick(PlayerData)
	local PlayerStats = PlayerData["Stats"]
	local Width = PlayerStats["LayoutWidth"]
	local Height = PlayerStats["LayoutHeight"]
	local Grid = PlayerData["GameGrid"]

	for y = 1, Height do
		for x = 1, Width do
			local itemObj = Grid:GetValue(x, y)
			if itemObj[1] == nil then continue end --no item to process here!
			local itemData = ItemsDatabase[ itemObj[1]["ItemID"] ]
			local ItemType = itemData["Type"]
			assert(ItemsLogic[ItemType], string.format("The item type %s doesn't exist!", ItemType))
			ItemsLogic[ItemType](x, y, itemObj[1], PlayerData, Grid)
		end
	end

	--idk how stats affect this yet
	PlayerStats["CurFlux"] = PlayerStats["CurFlux"] <= 0 and 0 or PlayerStats["CurFlux"] - 0.1
	PlayerStats["CurFlux"] = PlayerStats["CurFlux"] > PlayerStats["MaxFlux"] and PlayerStats["MaxFlux"] or PlayerStats["CurFlux"]
	PlayerStats["CurMana"] = PlayerStats["CurMana"] > PlayerStats["MaxMana"] and PlayerStats["MaxMana"] or PlayerStats["CurMana"]
end

local ItemsModels = game:GetService("ReplicatedStorage"):WaitForChild("Assets"):WaitForChild("Models")

function GameLogic:AddItem(x, y, ItemID, GridObject, ExistingData)
	ExistingData = ExistingData or nil
	
	local ServerMode = RunService:IsServer()
	
	local PositionData = GridObject:GetValue(x, y)
	if PositionData[1] == nil then
		local ItemData = ItemsDatabase[ItemID]
		local ItemType = ItemData["Type"]
		assert(createItem[ItemType], string.format("The item type %s doesn't exist!", ItemType))
		local ItemObj
		if ExistingData then --TODO: stop assuming its good and check the data being given!
			ItemObj = ExistingData
		else
			ItemObj = createItem[ItemType](ItemID)
		end
		
		if next(ItemObj) == nil then return end 
		
		if ServerMode == false then
			local ItemClone = ItemsModels:FindFirstChild(ItemData["Model"]):Clone() 
			ItemClone:PivotTo(CFrame.new(GridObject:GetWorldPosition(x, y)) * CFrame.new(0, 3, 0))
			ItemClone:SetAttribute("x",x)
			ItemClone:SetAttribute("y",y)
			ItemClone.Parent = workspace
			ItemObj["Model"] = ItemClone
		end
		GridObject:SetValue(x, y, ItemObj)
	else
		warn(string.format("Position %i %i contains an object already, type of object: %s (DEBUG INFORMATION)", x, y, typeof(PositionData[1])))
	end
end

function GameLogic:ClearAllItems(GridObject)
	local ServerMode = RunService:IsServer()
		
	for y=1, GridObject.height do
		for x=1,GridObject.width do
			local PositionData = GridObject:GetValue(x, y)
			if typeof(PositionData) == "table" and PositionData[1] ~= nil then
				if ServerMode == false then
					PositionData[1]["Model"]:Destroy()
				end
				GridObject:SetValue(x, y, nil, 1)
			end
		end
	end
end

function GameLogic:DestroyItem(x, y, GridObject)
	local ServerMode = RunService:IsServer()
	
	local PositionData = GridObject:GetValue(x, y)
	if typeof(PositionData) == "table" and PositionData[1] ~= nil then
		if ServerMode == false then
			PositionData[1]["Model"]:Destroy()
		end
		GridObject:SetValue(x, y, nil, 1)
	else
		warn(string.format("Position %i %i does NOT contain an object! (DEBUG INFORMATION)", x, y))
	end
end

function GameLogic:UpdateItem(x, y, GridObject, UpdatedData)
	--TODO: STOP ASSUMING ITS ALL CORRECT
	local ServerMode = RunService:IsServer()
	
	local PositionData = GridObject:GetValue(x, y)
	if typeof(PositionData) == "table" and PositionData[1] ~= nil then
		if UpdatedData == nil then
			if ServerMode == false then
				PositionData[1]["Model"]:Destroy()
			end
			GridObject:SetValue(x, y, nil, 1)
		else
			if ServerMode == false then
				UpdatedData["Model"] = PositionData[1]["Model"]
			end
			GridObject:SetValue(x, y, UpdatedData, 1)
		end
	elseif PositionData[1] == nil and UpdatedData ~= nil then
		GameLogic:AddItem(x, y, UpdatedData["ItemID"], GridObject, UpdatedData)
	end
end

return GameLogic
