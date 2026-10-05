--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local DataModule = require(script.GameDataMod)
local Packets = require(ReplicatedStorage.SharedModules.Packets)

DataModule:EnemySetup()

local LobbyMap = DataModule:LoadMap(ServerStorage.ServerStorage.Maps.Lobby)
task.spawn(function()
	DataModule:RoundIntermission()
end)

local function onPlayerAdded(player: Player)
	if DataModule:LoadData(player) == false then
		DataModule:CreateData(player)
	end
	DataModule:CreateSessionData(player)
	DataModule:PlayerSetUp(player)

	if LobbyMap then
		Packets.SendMapPacket:FireClient(player, LobbyMap.GridArray, 7, LobbyMap.originPosition, "Lobby")
	end
	if DataModule.RoundData["InProgress"] == true then
		local roundMap = DataModule.LoadedMaps[DataModule.RoundData.Map]
		if roundMap then
			Packets.SendMapPacket:FireClient(
				player,
				roundMap.GridArray,
				7,
				roundMap.originPosition,
				DataModule.RoundData.Map
			)
		end
	end
end

local function onPlayerRemoving(player: Player)
	DataModule:SaveData(player)
	DataModule:DeleteData(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

game:BindToClose(function()
	DataModule:SaveAll()
end)
