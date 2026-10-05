--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerRemotes = game.ServerScriptService.ServerRemotes

local DataStorage = require(script.Parent.GameDataStorage)
local LootModule = require(script.Parent.LootHandler)

local MAX_TEAM_SIZE = 4
local GACHA_PRICE = 10
local GACHA_COOLDOWN_SECONDS = 1

local Shared = {}

Shared.Variables = {
	["SetUp"] = false,
	["RemoteStatus"] = false,
}

local lastGachaAt: { [number]: number } = {}

local function fireTeamUi(player: Player)
	local playerData = DataStorage.GameData[player.UserId]
	if not playerData then
		return
	end
	ReplicatedStorage.SharedRemotes.VisualHandle:FireClient(player, "TeamUi", playerData.Team)
end

Shared.Events = {
	["AreaHandle"] = function(args)
		local player = args[1]
		local zone = args[2]
		if typeof(player) ~= "Instance" or not player:IsA("Player") or typeof(zone) ~= "string" then
			return
		end

		local playerData = DataStorage.GameData[player.UserId]
		if not playerData then
			return
		end
		if playerData.Zones[1] == zone then
			return
		end

		playerData.Zones[1] = zone
		if table.find(playerData.Zones[2], zone) == nil then
			table.insert(playerData.Zones[2], zone)
		end
		ReplicatedStorage.SharedRemotes.AreaHandle:FireClient(player)
	end,

	["CombatHandle"] = function(args)
		local player = args[1]
		local requestType = args[2]
		if typeof(player) ~= "Instance" or not player:IsA("Player") then
			return
		end
		if requestType ~= "Start" then
			return
		end
		if DataStorage.Battles[player.UserId] == nil then
			return
		end
		ServerRemotes.BattlesEvent:Fire(player, "BattleStarted")
	end,

	["GachaHandle"] = function(args)
		local player = args[1]
		if typeof(player) ~= "Instance" or not player:IsA("Player") then
			return
		end

		local playerData = DataStorage.GameData[player.UserId]
		if not playerData then
			return
		end

		local now = os.clock()
		if (lastGachaAt[player.UserId] or 0) + GACHA_COOLDOWN_SECONDS > now then
			return
		end
		lastGachaAt[player.UserId] = now

		if playerData.Currencies.Crystal < GACHA_PRICE then
			return
		end

		local rarity = LootModule:GetRandomItemFromLootTable(LootModule.LootTables.Rarities)
		if not rarity then
			return
		end
		local character = LootModule:GetRandomItemFromLootTable(LootModule.LootTables[rarity])
		if not character then
			return
		end

		LootModule:AddCurrency(player, "Crystal", -GACHA_PRICE)
		LootModule:AddUnit(player, character)
	end,

	["UnitHandle"] = function(args)
		local player = args[1]
		local action = args[2]
		if typeof(player) ~= "Instance" or not player:IsA("Player") or typeof(action) ~= "string" then
			return
		end

		local playerData = DataStorage.GameData[player.UserId]
		if not playerData then
			return
		end

		local unitIndex = args[4]
		if typeof(unitIndex) ~= "number" or unitIndex ~= math.floor(unitIndex) then
			return
		end
		local unit = playerData.Inventory.Units[unitIndex]
		if not unit then
			return
		end

		if action == "UnitEquip" then
			local unitName = args[3]
			if typeof(unitName) ~= "string" or unit.Name ~= unitName then
				return
			end
			if #playerData.Team >= MAX_TEAM_SIZE then
				return
			end
			if table.find(playerData.Team, unit) then
				return
			end
			table.insert(playerData.Team, unit)
			fireTeamUi(player)
		elseif action == "UnitUnequip" then
			local equippedIndex = table.find(playerData.Team, unit)
			if not equippedIndex or #playerData.Team <= 1 then
				return
			end
			table.remove(playerData.Team, equippedIndex)
			fireTeamUi(player)
		end
	end,
}

function Shared:CreateEvents()
	if Shared.Variables.SetUp ~= true or Shared.Variables.RemoteStatus ~= false then
		return
	end

	for _, remote in pairs(ReplicatedStorage.SharedRemotes:GetChildren()) do
		remote.OnServerEvent:Connect(function(...)
			local args = { ... }
			local Success, Error = pcall(function()
				local handler = Shared.Events[remote.Name]
				if handler then
					handler(args)
				end
			end)
			if not Success then
				warn(string.format("%s : %s", remote.Name, tostring(Error)))
			end
		end)
	end

	Shared.Variables.RemoteStatus = true
end

function Shared:SetUp()
	if Shared.Variables.SetUp == true then
		return false
	end

	Shared.Variables.SetUp = true
	Shared:CreateEvents()
	return Shared.Variables.RemoteStatus
end

return Shared
