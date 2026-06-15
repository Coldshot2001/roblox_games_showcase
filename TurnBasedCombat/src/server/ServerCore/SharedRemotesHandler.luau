local Shared = {} --This handles client to server requests, no server to client
local DataStorage = require(script.Parent.GameDataStorage)
local LootModule = require(script.Parent.LootHandler)

Shared.Variables = {
	["SetUp"] = false,
	["RemoteStatus"] = false,
}

Shared.Events = {

	["AreaHandle"] = function(ArgsTable)
		--Arguments: player: Object, Zone: String
		local player = ArgsTable[1]
		if DataStorage.GameData[player.Name] then
			if DataStorage.GameData[player.Name]["Zones"][1] ~= ArgsTable[2] then
				DataStorage.GameData[player.Name]["Zones"][1] = ArgsTable[2]
				if table.find(DataStorage.GameData[player.Name]["Zones"][2], ArgsTable[2]) == nil then
					table.insert(DataStorage.GameData[player.Name]["Zones"][2], ArgsTable[2])
				end
				game.ReplicatedStorage.SharedRemotes.AreaHandle:FireClient(player)
			end
		end
	end,

	["CombatHandle"] = function(ArgsTable)
		--Arguments: player: Object, Type: String
		local player = ArgsTable[1]
		if ArgsTable[2] == "Start" then
			game.ServerScriptService.ServerRemotes.BattlesEvent:Fire(player, "BattleStarted", ArgsTable[3])
		end
	end,

	["GachaHandle"] = function(ArgsTable)
		--Arguments: player: Object
		local player = ArgsTable[1]
		if DataStorage.GameData[player.Name]["Currencies"]["Crystal"] >= 10 then --TODO: change to price of summon based on the type we chose
			LootModule:AddCurrency(player, "Crystal", -10)
			local ChosenRarity = LootModule:GetRandomItemFromLootTable(LootModule.LootTables.Rarities)
			local ChosenCharacter = LootModule:GetRandomItemFromLootTable(LootModule.LootTables[ChosenRarity])
			LootModule:AddUnit(player, ChosenCharacter)
		end
	end,

	["UnitHandle"] = function(ArgsTable)
		--Arguments: player: Object,Type: String, UnitName: String , Index: Integer
		local player = ArgsTable[1]
		if string.match(ArgsTable[2], "Unit") then
			local equippedunit = table.find(
				DataStorage.GameData[player.Name]["Team"],
				DataStorage.GameData[player.Name]["Inventory"]["Units"][ArgsTable[4]]
			)
			if ArgsTable[2] == "UnitEquip" then
				if
					#DataStorage.GameData[player.Name]["Team"] < 4
					and DataStorage.GameData[player.Name]["Inventory"]["Units"][ArgsTable[4]].Name == ArgsTable[3]
					and equippedunit == nil
				then
					table.insert(
						DataStorage.GameData[player.Name]["Team"],
						DataStorage.GameData[player.Name]["Inventory"]["Units"][ArgsTable[4]]
					)
					game.ReplicatedStorage.SharedRemotes.VisualHandle:FireClient(
						player,
						"TeamUi",
						DataStorage.GameData[player.Name]["Team"]
					)
				end
			elseif ArgsTable[2] == "UnitUnequip" then
				if #DataStorage.GameData[player.Name]["Team"] > 1 and equippedunit then
					table.remove(DataStorage.GameData[player.Name]["Team"], equippedunit)
					game.ReplicatedStorage.SharedRemotes.VisualHandle:FireClient(
						player,
						"TeamUi",
						DataStorage.GameData[player.Name]["Team"]
					)
				end
			end
		elseif string.match(ArgsTable[2], "Equipment") then
			--to do
		end
	end,
}

function Shared:CreateEvents()
	if Shared.Variables.SetUp == true and Shared.Variables.RemoteStatus == false then
		for _, v in pairs(game.ReplicatedStorage.SharedRemotes:GetChildren()) do
			v.OnServerEvent:Connect(function(...)
				local args = { ... } --turns all the arguments into one table so to access them we got to loop through it (first argument will always be player)
				local Success, Error = pcall(function()
					Shared.Events[v.Name](args)
				end)

				if not Success then
					warn(string.format("%s : %s", v.Name, Error))
				end
			end)
		end

		Shared.Variables.RemoteStatus = true
	end
end

function Shared:SetUp()
	if Shared.Variables.SetUp == false then
		Shared.Variables.SetUp = true

		Shared:CreateEvents()

		if Shared.Variables.RemoteStatus ~= true then
			return false
		end

		return true
	else
		return false
	end
end

return Shared
