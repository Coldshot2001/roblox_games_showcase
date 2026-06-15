local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local DataModule = require(script.GameDataMod)
local Packets = require(ReplicatedStorage.SharedModules.Packets)

DataModule:EnemySetup()

local LobbyMap = DataModule:LoadMap(ServerStorage.ServerStorage.Maps.Lobby)
coroutine.wrap(function()
	DataModule:RoundIntermission()
end)()

function PlayerAdded(player)
	if DataModule:LoadData(player) == false then
		DataModule:CreateData(player)
	end
	DataModule:CreateSessionData(player)
	DataModule:PlayerSetUp(player)

	Packets.SendMapPacket:FireClient(player, LobbyMap.GridArray, 7, LobbyMap.originPosition, "Lobby")
	if DataModule.RoundData["InProgress"] == true then
		local roundMap = DataModule.LoadedMaps[DataModule.RoundData.Map]
		Packets.SendMapPacket:FireClient(
			player,
			roundMap.GridArray,
			7,
			roundMap.originPosition,
			DataModule.RoundData.Map
		)
	end
end

function PlayerRemoving(player)
	DataModule:SaveData(player)
	DataModule:DeleteData(player)
end

Players.PlayerAdded:Connect(PlayerAdded)
Players.PlayerRemoving:Connect(PlayerRemoving)
