local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local GridMap = require(ServerScriptService.Modules.GridMap2D)
local Solution = require(ServerScriptService.Modules.SolutionGen)
local EnemyLogic = require(ServerScriptService.Modules.EnemyLogic)
local GameMaps = ServerStorage.ServerStorage.Maps:GetChildren()

local Packets = require(ReplicatedStorage.SharedModules.Packets)
local SendMapPacket = Packets.SendMapPacket
local SendGameDataPacket = Packets.SendGameDataPacket

for i, v in pairs(GameMaps) do
	if v.Name == "Lobby" then
		table.remove(GameMaps, i)
		break
	end
end

local Data = {}

Data.GameData = {
	--tables with player save data
}

Data.SessionData = {
	--tables with current game data
}

Data.LoadedMaps = {
	--tables with gridmaps
}

Data.RoundData = {
	["InProgress"] = false,
	["Map"] = "", --string of model name
	["StartTime"] = 0,
	["EnemyObjects"] = {},
}

Data.MapsData = {
	["Lobby"] = {
		["SpawnLocations"] = {
			{ 1, 1 },
			{ 6, 6 },
		},
		--["Enemy Type"]
	},
	["Test"] = {
		["SpawnLocations"] = {
			{ 1, 4 },
		},
		["EnemyLocations"] = {
			{ 3, 4 },
		},
		["EnemyType"] = "Enemy",
	},
}

local function GetSpawnCFrame(mapName, gridPos, plateOffset)
	local map = Data.LoadedMaps[mapName]
	return CFrame.new((gridPos[1] - 1) * 7, map.GridArray[gridPos[1]][gridPos[2]]["Position"], (gridPos[2] - 1) * 7)
		* CFrame.new(map.originPosition.X, plateOffset, map.originPosition.Z)
		* CFrame.fromOrientation(0, math.rad(180), 0)
end

function Data:SaveData(Player: Player) end

function Data:LoadData(Player: Player)
	--check datastore
	---if exists Data.GameData[Player.UserId] = datastore data
	----return true
	---else if datastore data doesnt exist V
	return false
end

local PlayerData = {
	["Plates"] = { "Default" }, --Strings with the plates the plr owns
	["Poses"] = { "Default" }, --Strings with the character poses the plr owns
	["Animations"] = { "Default" }, --Strings with the animations the plr owns
	["MaxTime"] = 0, --How long the plr has survived for ever , in seconds?
	["Equipped"] = { --What items are equipped
		["Plate"] = "Default",
		["Poses"] = "Default",
		["Animations"] = "Default",
	},
	["Currencies"] = {
		["Gold"] = 0,
	},
}
function Data:CreateData(Player: Player)
	if Data.GameData[Player.UserId] == nil then
		Data.GameData[Player.UserId] = PlayerData
	end
end

function Data:CreateSessionData(Player: Player)
	if Data.SessionData[Player.UserId] == nil then
		local SessionData = {
			["InGame"] = false,
			["LobbyPosition"] = { 0, 0 },
			["GamePosition"] = { 0, 0 },
		}

		Data.SessionData[Player.UserId] = SessionData
	end
end

function Data:GetData(Player: Player)
	local plrdata = Data.GameData[Player.UserId] ~= nil and Data.GameData[Player.UserId] or nil
	return plrdata
end

function Data:DeleteData(Player: Player)
	if Data.GameData[Player.UserId] ~= nil then
		Data.GameData[Player.UserId] = nil
	end
	if Data.SessionData[Player.UserId] ~= nil then
		Data.SessionData[Player.UserId] = nil
	end
end

function Data:LoadMap(Map: Model)
	if Data.LoadedMaps[Map.Name] == nil then
		local MapClone = Map:Clone()
		if Map.Name == "Lobby" then
			MapClone:PivotTo(CFrame.new(-255.5, 50, 255.5))
		else
			MapClone:PivotTo(CFrame.new(155.5, 100, -255.5))
		end
		MapClone.Parent = workspace
		local MapGrid = GridMap.FromParts(MapClone.Tiles:GetChildren(), 7, MapClone:FindFirstChild("TopLeft").Position)
		local max = math.max(MapGrid.width, MapGrid.height)
		local gen_Sol = Solution.Generate(max, max)
		for i = 1, MapGrid.width do
			for j = 1, MapGrid.height do
				if MapGrid.GridArray[i][j] ~= -math.huge then
					MapGrid.GridArray[i][j]["Value"] = gen_Sol[i][j]
				end
			end
		end
		max = nil
		gen_Sol = nil
		Data.LoadedMaps[Map.Name] = MapGrid
		return MapGrid
	else
		return Data.LoadedMaps[Map.Name]
	end
end

function Data:UnloadMap(MapName: string)
	if Data.LoadedMaps[MapName] ~= nil then
		workspace:FindFirstChild(MapName):Destroy()
		Data.LoadedMaps[MapName] = nil
	end
end

Packets.MovePacket.OnServerEvent:Connect(function(plr, dir)
	if typeof(dir) ~= "number" then
		return
	end
	local session = Data.SessionData[plr.UserId]
	if session == nil then
		return
	end

	local isInGame = session["InGame"]
	local posKey = isInGame and "GamePosition" or "LobbyPosition"
	local mapName = isInGame and Data.RoundData.Map or "Lobby"
	local map = Data.LoadedMaps[mapName]
	if map == nil then
		return
	end

	local oldPos = session[posKey]
	local newPos = nil
	for _, v in pairs(map:GetNeighbours(oldPos[1], oldPos[2])) do
		if map.GridArray[v[1]][v[2]]["Value"] == dir then
			newPos = v
			break
		end
	end

	if newPos then
		if isInGame then
			for _, otherPlr in pairs(game:GetService("Players"):GetPlayers()) do
				if otherPlr ~= plr then
					local otherSession = Data.SessionData[otherPlr.UserId]
					if otherSession and otherSession["InGame"] == true then
						local otherPos = otherSession["GamePosition"]
						if otherPos[1] == newPos[1] and otherPos[2] == newPos[2] then
							-- Cell occupied by another player; reject
							Packets.MoveAckPacket:FireClient(plr, false, oldPos[1], oldPos[2], mapName)
							return
						end
					end
				end
			end
			-- Also check enemy positions
			for _, enemyObj in pairs(Data.RoundData["EnemyObjects"]) do
				local ePos = enemyObj.pos -- Vector3 with x,y as grid coords
				if ePos and ePos.X == newPos[1] and ePos.Y == newPos[2] then
					Packets.MoveAckPacket:FireClient(plr, false, oldPos[1], oldPos[2], mapName)
					return
				end
			end
		end

		session[posKey] = newPos
		-- Move the character on the server
		local char = plr.Character
		if char then
			local plateOffset = ServerStorage.ServerStorage.Plates
				:FindFirstChild(Data.GameData[plr.UserId]["Equipped"]["Plate"])
				:FindFirstChild("TerrainOffset").Value
			char:PivotTo(
				CFrame.new((newPos[1] - 1) * 7, map.GridArray[newPos[1]][newPos[2]]["Position"], (newPos[2] - 1) * 7)
					* CFrame.new(map.originPosition.X, plateOffset, map.originPosition.Z)
					* CFrame.fromOrientation(0, math.rad(180), 0)
			)
		end
		-- Confirm move to the moving player
		Packets.MoveAckPacket:FireClient(plr, true, newPos[1], newPos[2], mapName)
		-- Broadcast to everyone else on the same map
		for _, other in pairs(game:GetService("Players"):GetPlayers()) do
			if other ~= plr then
				local otherSession = Data.SessionData[other.UserId]
				if otherSession == nil then
					continue
				end
				local otherMap = otherSession["InGame"] and Data.RoundData.Map or "Lobby"
				if otherMap == mapName then
					Packets.EntityMovePacket:FireClient(
						other,
						tostring(plr.UserId),
						"player",
						newPos[1],
						newPos[2],
						mapName,
						dir
					)
				end
			end
		end
	else
		-- Reject: send back the actual current position
		Packets.MoveAckPacket:FireClient(plr, false, oldPos[1], oldPos[2], mapName)
	end
end)

function Data:PlayerSetUp(Player: Player)
	Packets.SendGameDataPacket:FireClient(Player, "TimerEnd", nil)
	Data:PlayerSpawn(Player)

	-- Tell everyone else what animation pack this player uses
	local myPack = Data.GameData[Player.UserId]["Equipped"]["Animations"]
	for _, other in pairs(Players:GetPlayers()) do
		if other ~= Player then
			Packets.AnimationPackPacket:FireClient(other, Player.UserId, myPack)
		end
	end

	-- Tell this player what pack everyone else is using
	for _, other in pairs(Players:GetPlayers()) do
		if other ~= Player then
			local theirPack = Data.GameData[other.UserId]["Equipped"]["Animations"]
			Packets.AnimationPackPacket:FireClient(Player, other.UserId, theirPack)
		end
	end
end

local EnemyAddedSignal
local EnemyRemovedSignal
function Data:EnemySetup()
	if EnemyAddedSignal == nil then
		EnemyAddedSignal = CollectionService:GetInstanceAddedSignal(EnemyLogic.TAG_NAME):Connect(function(Object)
			if Data.RoundData["InProgress"] == true then
				if Object:IsA("Model") and Data.RoundData["EnemyObjects"][Object] == nil then
					local enemyId = tostring(Object:GetAttribute("EnemyId") or HttpService:GenerateGUID(false))
					Object:SetAttribute("EnemyId", enemyId)
					Data.RoundData["EnemyObjects"][Object] = EnemyLogic.new(Object, enemyId)
				end
			end
		end)
	end
	if EnemyRemovedSignal == nil then
		EnemyRemovedSignal = CollectionService:GetInstanceRemovedSignal(EnemyLogic.TAG_NAME):Connect(function(Object)
			if Data.RoundData["EnemyObjects"][Object] ~= nil then
				Data.RoundData["EnemyObjects"][Object]:Cleanup()
				Data.RoundData["EnemyObjects"][Object] = nil
			end
		end)
	end
end

function Data:EnemySpawn()
	if Data.RoundData["InProgress"] == true then
		local CurMapData = Data.MapsData[Data.RoundData["Map"]]
		local EnemyMdl = ServerStorage.ServerStorage.Enemies:FindFirstChild(CurMapData["EnemyType"]):Clone()
		EnemyMdl:PivotTo(CFrame.new(10000, 10000, 10000))
		EnemyMdl.Parent = workspace
		CollectionService:AddTag(EnemyMdl, EnemyLogic.TAG_NAME)
		local SpawnPos = CurMapData["EnemyLocations"][math.random(1, #CurMapData["EnemyLocations"])]
		local AlivePlayers = {}
		for UserID, Data in pairs(Data.SessionData) do
			if Data["InGame"] == true then
				table.insert(AlivePlayers, Players:GetPlayerByUserId(UserID))
			end
		end

		Data.RoundData["EnemyObjects"][EnemyMdl]:UpdateTargets(AlivePlayers)
		Data.RoundData["EnemyObjects"][EnemyMdl]:Spawn(
			SpawnPos,
			Data.RoundData["Map"],
			Data.LoadedMaps[Data.RoundData["Map"]],
			-- getPlayerPos: looks up a player's current grid position from SessionData
			function(player)
				local session = Data.SessionData[player.UserId]
				if session == nil then
					return nil
				end
				return session["InGame"] and session["GamePosition"] or nil
			end,
			-- onMoved: broadcasts enemy position to all clients on the same map
			function(enemyId, gridX, gridY, mapName)
				for _, plr in pairs(Players:GetPlayers()) do
					local session = Data.SessionData[plr.UserId]
					if session == nil then
						continue
					end
					local plrMap = session["InGame"] and Data.RoundData.Map or "Lobby"
					if plrMap == mapName then
						Packets.EntityMovePacket:FireClient(plr, enemyId, "enemy", gridX, gridY, mapName, 0)
					end
				end
			end
		)
	end
end

function Data:PlayerSpawn(Player: Player)
	Data.SessionData[Player.UserId]["LobbyPosition"] = { 0, 0 }
	Data.SessionData[Player.UserId]["GamePosition"] = { 0, 0 }

	Player:LoadCharacterAsync()
	local chr = Player.Character or Player.CharacterAdded:Wait()

	-- Anchor HRP, disable collisions on everything else — no waits needed
	local hrp = chr:WaitForChild("HumanoidRootPart")
	hrp.Anchored = true
	for _, v in pairs(chr:GetChildren()) do
		if v:IsA("BasePart") and v ~= hrp then
			v.Anchored = false
			v.CanCollide = false
		end
	end

	-- Attach plate
	local Plate =
		ServerStorage.ServerStorage.Plates:FindFirstChild(Data.GameData[Player.UserId]["Equipped"]["Plate"]):Clone()
	Plate.Name = "Plate"
	local weld = Instance.new("Weld")
	weld.Part0 = hrp
	weld.Part1 = Plate
	weld.C1 = CFrame.new(0, Plate:FindFirstChild("Offset").Value, 0)
	weld.Parent = Plate
	Plate.Parent = chr

	-- Pick spawn position and move character immediately
	math.randomseed(os.clock())
	local isInGame = Data.SessionData[Player.UserId]["InGame"]
	local mapName = isInGame and Data.RoundData.Map or "Lobby"
	local spawns = Data.MapsData[mapName]["SpawnLocations"]
	local pos = spawns[math.random(1, #spawns)]
	local posKey = isInGame and "GamePosition" or "LobbyPosition"

	Data.SessionData[Player.UserId][posKey] = pos
	chr:PivotTo(GetSpawnCFrame(mapName, pos, Plate:FindFirstChild("TerrainOffset").Value))
	Packets.MoveAckPacket:FireClient(Player, true, pos[1], pos[2], mapName)
end

local function ChooseRandMap()
	math.randomseed(os.clock())
	return GameMaps[math.random(1, #GameMaps)]
end

local REQUIRED_PLRS = 1
local function EnoughPlayers()
	return #Players:GetPlayers() >= REQUIRED_PLRS and true or false
end

local INTERMISSION_TIME = 15 -- seconds
function Data:RoundIntermission()
	--do some gui stuff here
	task.wait(INTERMISSION_TIME)
	if EnoughPlayers() == true then
		--enough players have been found, tell on gui
		Data:RoundStart()
	else
		--not enough players, do gui stuff to tell players waiting again
		Data:RoundIntermission()
	end
end

function Data:RoundEnd()
	SendGameDataPacket:Fire("RoundOver", Data.RoundData["Map"])
	for _, plr in pairs(Players:GetPlayers()) do
		local plrSesDt = Data.SessionData[plr.UserId]
		if plrSesDt ~= nil then
			if plrSesDt["InGame"] == true then
				plrSesDt["InGame"] = false
			end
		end
		local chr = plr.Character or plr.CharacterAdded:Wait()
		chr:Destroy()
		task.wait()
		Data:PlayerSpawn(plr)
	end
	for i, _ in pairs(Data.RoundData["EnemyObjects"]) do
		CollectionService:RemoveTag(i, EnemyLogic.TAG_NAME) --Removes all enemies
	end
	--calculate everyone's times and send them
	--maybe show top 3 players
	local RoundMap = Data:UnloadMap(Data.RoundData["Map"])
	Data.RoundData["InProgress"] = false
	Data.RoundData["StartTime"] = 0
	Data.RoundData["Map"] = ""
	Data:RoundIntermission()
end

function Data:RoundStart()
	Data.RoundData["StartTime"] = tick() --this is done first to account for the delay to fetch
	local ChosenMap = ChooseRandMap()
	local RoundMap = Data:LoadMap(ChosenMap)
	Data.RoundData["Map"] = ChosenMap.Name
	Data.RoundData["InProgress"] = true
	SendMapPacket:Fire(RoundMap.GridArray, 7, RoundMap.originPosition, ChosenMap.Name)
	for _, plr in pairs(Players:GetPlayers()) do
		local plrSesDt = Data.SessionData[plr.UserId]
		--check their settings if playing
		if plrSesDt ~= nil then
			plrSesDt["InGame"] = true
		end
		local chr = plr.Character or plr.CharacterAdded:Wait()
		chr:Destroy()
		task.wait()
		Data:PlayerSpawn(plr)
	end
	SendGameDataPacket:Fire("TimerStart", Data.RoundData["StartTime"])
	while Data.RoundData["InProgress"] == true do
		Data:EnemySpawn()
		task.wait(30)
	end
end

return Data
