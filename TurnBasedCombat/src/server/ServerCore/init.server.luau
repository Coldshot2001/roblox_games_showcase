--!strict

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerRemotes = game.ServerScriptService.ServerRemotes
local SharedRemotes = ReplicatedStorage.SharedRemotes

local DataModule = require(script.GameDataMod)
local DataStorage = require(script.GameDataStorage)
local SharedRemotesMod = require(script.SharedRemotesHandler)
local EnemiesMod = require(ServerStorage:WaitForChild("EnemyTeamMod"))
local BattleModule = require(script.BattleMod)
local LootModule = require(script.LootHandler)

local COMBAT_RANGE = 8
local BATTLE_WIN_REWARD = { Gold = 50, Crystal = 50 }
local BATTLE_LOSS_PENALTY = { Gold = 10, Crystal = 10 }

local ALLOWED_DATA_KEYS = {
	InBattle = true,
	Zones = true,
	Currencies = true,
}

local function deepCopy(original: any): any
	if typeof(original) ~= "table" then
		return original
	end
	local copy = {}
	for key, value in pairs(original) do
		copy[deepCopy(key)] = deepCopy(value)
	end
	return copy
end

local function finishBattle(player: Player, outcome: string)
	local playerData = DataStorage.GameData[player.UserId]
	if not playerData or DataStorage.Battles[player.UserId] == nil then
		return
	end

	DataStorage.Battles[player.UserId] = nil
	playerData.InBattle[1] = false
	playerData.InBattle[2] = nil

	BattleModule:DestroyBattleModels(player.Name)

	if outcome == "BattleWon" then
		LootModule:AddCurrency(player, "Gold", BATTLE_WIN_REWARD.Gold)
		LootModule:AddCurrency(player, "Crystal", BATTLE_WIN_REWARD.Crystal)
	elseif outcome == "BattleLost" then
		LootModule:AddCurrency(player, "Gold", -BATTLE_LOSS_PENALTY.Gold)
		LootModule:AddCurrency(player, "Crystal", -BATTLE_LOSS_PENALTY.Crystal)
	end

	SharedRemotes.CombatHandle:FireClient(player, "End")
end

local function startBattle(player: Player, mob: BasePart, mobName: string): boolean
	local playerData = DataStorage.GameData[player.UserId]
	if not playerData or playerData.InBattle[1] then
		return false
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then
		return false
	end
	if (root.Position - mob.Position).Magnitude > COMBAT_RANGE then
		return false
	end

	local teamDefinition = EnemiesMod.Teams[mobName]
	if not teamDefinition then
		return false
	end
	local enemyTeam = EnemiesMod:GenerateTeam(teamDefinition)
	if #enemyTeam == 0 then
		return false
	end

	if workspace.Battles:FindFirstChild(player.Name) then
		warn(string.format("ServerCore: a battle for %s already exists", player.Name))
		return false
	end

	local battleTable = DataModule:BattleCreate(player, enemyTeam)
	if not battleTable then
		return false
	end

	playerData.InBattle[1] = true
	playerData.InBattle[2] = battleTable

	local sortedChars = BattleModule:SortTeams(deepCopy(playerData.Team), enemyTeam)
	if not sortedChars then
		playerData.InBattle[1] = false
		playerData.InBattle[2] = nil
		return false
	end

	DataStorage.Battles[player.UserId] = sortedChars
	BattleModule:GenerateBattleModels(player, sortedChars)
	return true
end

local function setUpMobs()
	local folder = workspace:FindFirstChild("Enemies")
	if not folder then
		warn("ServerCore: workspace.Enemies is missing")
		return
	end

	local mobNumber = 0
	for _, area in ipairs(folder:GetChildren()) do
		for _, mob in ipairs(area:GetChildren()) do
			if mob:IsA("Part") then
				local mobData = mob:FindFirstChild("MobData")
				local mobNameValue = mobData and mobData:FindFirstChild("MobName")
				if mobNameValue and mobNameValue:IsA("StringValue") then
					mob.Name = "Root" .. mobNumber
					mobNumber += 1
					mob.CanCollide = false
					mob.Transparency = 0.5
					mob.CastShadow = false
					mob.Anchored = true
					mob.Locked = true

					local combatRemote = Instance.new("RemoteFunction")
					combatRemote.Name = "Combat"
					combatRemote.OnServerInvoke = function(requestingPlayer)
						return startBattle(requestingPlayer, mob, mobNameValue.Value)
					end
					combatRemote.Parent = mob
				end
			end
		end
	end
end

local function setUpGachaRates()
	ReplicatedStorage.InvokesHandle.OnServerInvoke = function(_player, requestType, rarityName)
		if requestType ~= "GachaRates" then
			return nil
		end
		if typeof(rarityName) ~= "string" then
			return "Unknown"
		end

		local weight = 0
		local chosen = nil
		for _, entry in ipairs(LootModule.LootTables.Rarities) do
			if entry[1] == rarityName then
				chosen = entry
			end
			weight += entry[2]
		end

		if not chosen or weight <= 0 then
			return "Unknown"
		end
		return string.format("%s: %.1f%%", chosen[1], (chosen[2] / weight) * 100)
	end
end

local function makeDataRemote(player: Player)
	local dataRemote = Instance.new("RemoteFunction")
	dataRemote.Name = "Data"
	dataRemote.OnServerInvoke = function(requestingPlayer, ...)
		if requestingPlayer ~= player then
			return nil
		end

		local playerData = DataStorage.GameData[player.UserId]
		if not playerData then
			return nil
		end

		local keys = { ... }
		local returns = {}
		for index, key in ipairs(keys) do
			if typeof(key) == "string" and ALLOWED_DATA_KEYS[key] then
				returns[index] = deepCopy(playerData[key])
			end
		end
		return returns
	end
	dataRemote.Parent = player
end

local function refreshPlayerUi(player: Player)
	local playerData = DataStorage.GameData[player.UserId]
	if not playerData then
		return
	end

	SharedRemotes.VisualHandle:FireClient(player, "CurrencyUi", "Gold", playerData.Currencies.Gold)
	SharedRemotes.VisualHandle:FireClient(player, "CurrencyUi", "Crystal", playerData.Currencies.Crystal)
	SharedRemotes.VisualHandle:FireClient(player, "InventoryUi", "Unit", playerData.Inventory.Units)
	SharedRemotes.VisualHandle:FireClient(player, "TeamUi", playerData.Team)
end

local function onPlayerAdded(player: Player)
	local saved = DataStorage.LoadPlayer(player)
	local playerData = saved or DataModule:Create(player)
	DataStorage.GameData[player.UserId] = playerData

	makeDataRemote(player)
	refreshPlayerUi(player)
end

local function onPlayerRemoving(player: Player)
	local playerData = DataStorage.GameData[player.UserId]
	if playerData and playerData.InBattle[1] then
		finishBattle(player, "BattleLost")
	end

	DataStorage.SavePlayer(player)
	DataStorage.Battles[player.UserId] = nil
	DataStorage.GameData[player.UserId] = nil
end

SharedRemotesMod:SetUp()
setUpMobs()
setUpGachaRates()

ServerRemotes.BattlesEvent.Event:Connect(function(player: Player, eventType: string)
	if eventType == "BattleWon" or eventType == "BattleLost" then
		finishBattle(player, eventType)
	end
end)

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

game:BindToClose(function()
	DataStorage.SaveAll()
end)
