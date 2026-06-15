local ServerRemotes = game.ServerScriptService.ServerRemotes
local SharedRemotes = game.ReplicatedStorage.SharedRemotes
local DataModule = require(script.GameDataMod)
local DataStorage = require(script.GameDataStorage)
local SharedRemotesMod = require(script.SharedRemotesHandler)
local EnemiesMod = require(game.ServerStorage.EnemyTeamMod)
local BattleModule = require(script.BattleMod)
local LootModule = require(script.LootHandler)

local function shallowCopy(original)
	local copy = {}
	for key, value in pairs(original) do
		copy[key] = value
	end
	return copy
end

local function deepCopy(original)
	local copy = {}
	for k, v in pairs(original) do
		if type(v) == "table" then
			v = deepCopy(v)
		end
		copy[k] = v
	end
	return copy
end

--setting up the game
local MobNum = 0
local Folder = game.Workspace.Enemies
local Areas = Folder:GetChildren()
for _, v in next, Folder:GetChildren() do
	for _, Mob in next, v:GetChildren() do
		if Mob:IsA("Part") then
			if Mob:FindFirstChild("MobData") then
				Mob.Name = "Root" .. MobNum
				MobNum = MobNum + 1
				Mob.CanCollide = false
				Mob.Transparency = 0.5
				Mob.CastShadow = false
				Mob.Anchored = true
				Mob.Locked = true

				local re = Instance.new("RemoteFunction")
				re.Name = "Combat"
				re.OnServerInvoke = function(player, enemy)
					if player.Character and player.Character:FindFirstChild("Humanoid") then
						if player.Character.Humanoid.Health > 0 then
							if
								(player.Character.PrimaryPart.Position - enemy.Position).magnitude <= 8
								and DataStorage.GameData[player.Name]["InBattle"][1] == false
							then
								DataStorage.GameData[player.Name]["InBattle"][1] = true
								local EnemyTeam = EnemiesMod:GenerateTeam(EnemiesMod.Teams[Mob.MobData.MobName.Value])
								DataStorage.GameData[player.Name]["InBattle"][2] =
									DataModule:BattleCreate(player, EnemyTeam)
								--generating battle
								if not workspace.Battles:FindFirstChild(player.Name) then
									local SortedChars = BattleModule:SortTeams(
										deepCopy(DataStorage.GameData[player.Name]["Team"]),
										EnemyTeam
									)
									DataStorage.Battles[player.Name] = shallowCopy(SortedChars)
									BattleModule:GenerateBattleModels(player, SortedChars)
								else
									DataStorage.GameData[player.Name]["InBattle"][1] = false
									DataStorage.GameData[player.Name]["InBattle"][2] = nil
									DataStorage.Battles[player.Name] = nil
									warn("Player " .. player.Name .. " battle already exists!")
									return false
								end
								--
								return true
							else
								warn("Player " .. player.Name .. " not in range or in battle already!")
							end
						else
							warn("Player " .. player.Name .. " is dead!")
						end
					end
					return false
				end
				re.Parent = Mob
			end
		end
	end
end

SharedRemotesMod:SetUp()

game.ReplicatedStorage.InvokesHandle.OnServerInvoke = function(...)
	local args = { ... }
	local player = args[1]
	local Type = args[2]
	if Type == "GachaRates" then
		local weight = 0
		local chosen
		for _, v in ipairs(LootModule.LootTables.Rarities) do --TODO: Update so that we get the loot table of the type of summon
			if v[1] == args[3] then
				chosen = v
			end
			weight = weight + v[2]
		end
		return string.format("%s: %.1f%%", chosen[1], ((chosen[2] / weight) * 100))
	end
end

ServerRemotes.BattlesEvent.Event:Connect(function(player, Type)
	if Type == "BattleWon" then
		--test
		LootModule:AddCurrency(player, "Gold", 50)
		LootModule:AddCurrency(player, "Crystal", 50)
		--
		workspace.Battles[player.Name].Parent = nil
		DataStorage.GameData[player.Name]["InBattle"][1] = false
		DataStorage.GameData[player.Name]["InBattle"][2] = nil
		DataStorage.Battles[player.Name] = nil
	elseif Type == "BattleLost" then
		--test
		LootModule:AddCurrency(player, "Gold", -10)
		LootModule:AddCurrency(player, "Crystal", -10)
		--
		workspace.Battles[player.Name].Parent = nil
		DataStorage.GameData[player.Name]["InBattle"][1] = false
		DataStorage.GameData[player.Name]["InBattle"][2] = nil
		DataStorage.Battles[player.Name] = nil
	end
end)

function PlayerAdded(player)
	--data creation
	local data = DataModule:Create(player.Name) --TODO: Check if the player already has data (will have to be moved to the save slots stuff)

	if not DataStorage.GameData[player.Name] then
		DataStorage.GameData[player.Name] = data
	end
	local DataRemote = Instance.new("RemoteFunction")
	DataRemote.Name = "Data"
	DataRemote.OnServerInvoke = function(player, ...)
		local args = { ... }
		local returns = {}
		for _, v in pairs(args) do
			table.insert(returns, DataStorage.GameData[player.Name][v])
		end
		return returns
	end
	DataRemote.Parent = player

	--update the player's display on join
	game.ReplicatedStorage.SharedRemotes.VisualHandle:FireClient(
		player,
		"CurrencyUi",
		"Gold",
		DataStorage.GameData[player.Name]["Currencies"]["Gold"]
	)
	game.ReplicatedStorage.SharedRemotes.VisualHandle:FireClient(
		player,
		"CurrencyUi",
		"Crystal",
		DataStorage.GameData[player.Name]["Currencies"]["Crystal"]
	)
	game.ReplicatedStorage.SharedRemotes.VisualHandle:FireClient(
		player,
		"InventoryUi",
		"Unit",
		DataStorage.GameData[player.Name]["Inventory"]["Units"]
	)
	--equipment update function here
	game.ReplicatedStorage.SharedRemotes.VisualHandle:FireClient(
		player,
		"TeamUi",
		DataStorage.GameData[player.Name]["Team"]
	)
end

function PlayerRemoving(player)
	if DataStorage.GameData[player.Name]["InBattle"][1] == true then
		LootModule:AddCurrency(player, "Gold", -10)
		LootModule:AddCurrency(player, "Crystal", -10)
		workspace.Battles[player.Name].Parent = nil
		DataStorage.GameData[player.Name]["InBattle"][1] = false
		DataStorage.GameData[player.Name]["InBattle"][2] = nil
	end
	--save data here
	DataStorage.Battles[player.Name] = nil
	DataStorage.GameData[player.Name] = nil
end

game.Players.PlayerAdded:Connect(PlayerAdded)

game.Players.PlayerRemoving:Connect(PlayerRemoving)

--[[for _,player in next, game.Players:GetChildren() do
	coroutine.wrap(function()
		PlayerAdded(player)
	end)()
end]]
