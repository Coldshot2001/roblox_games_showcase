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

local Packets = require(ReplicatedStorage.SharedModules.Packets)
local SendMapPacket = Packets.SendMapPacket
local SendGameDataPacket = Packets.SendGameDataPacket

local GameMaps = {}
for _, map in ipairs(ServerStorage.ServerStorage.Maps:GetChildren()) do
	if map.Name ~= "Lobby" then
		table.insert(GameMaps, map)
	end
end

local random = Random.new()

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
	if not map then
		return nil
	end
	local column = map.GridArray[gridPos[1]]
	local cell = column and column[gridPos[2]]
	local height = cell and cell["Position"] or 0
	return CFrame.new((gridPos[1] - 1) * 7, height, (gridPos[2] - 1) * 7)
		* CFrame.new(map.originPosition.X, plateOffset, map.originPosition.Z)
		* CFrame.fromOrientation(0, math.rad(180), 0)
end

local STORE_NAME = "BackOffBarbarianPlayerData_v1"
local MAX_ATTEMPTS = 3
local RETRY_BASE_SECONDS = 2

local store: any = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn(string.format("GameDataMod: DataStore %q is not available (%s)", STORE_NAME, tostring(result)))
	end
end

local function retry(operation: () -> any): (boolean, any)
	local lastError: any = "DataStore is not available"
	for attempt = 1, MAX_ATTEMPTS do
		if store ~= nil then
			local ok, result = pcall(operation)
			if ok then
				return true, result
			end
			lastError = result
		end
		if attempt < MAX_ATTEMPTS then
			task.wait(RETRY_BASE_SECONDS * attempt)
		end
	end
	return false, lastError
end

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

local DefaultPlayerData = {
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

local function sanitizeSaved(saved: any): any
	local data = deepCopy(DefaultPlayerData)

	if typeof(saved["Currencies"]) == "table" then
		for key, _ in pairs(data["Currencies"]) do
			local savedValue = saved["Currencies"][key]
			if typeof(savedValue) == "number" and savedValue == savedValue then
				data["Currencies"][key] = math.max(0, savedValue)
			end
		end
	end

	for _, key in ipairs({ "Plates", "Poses", "Animations" }) do
		local savedList = saved[key]
		if typeof(savedList) == "table" then
			local list = {}
			for _, item in ipairs(savedList) do
				if typeof(item) == "string" then
					table.insert(list, item)
				end
			end
			if #list > 0 then
				data[key] = list
			end
		end
	end

	if typeof(saved["MaxTime"]) == "number" and saved["MaxTime"] == saved["MaxTime"] then
		data["MaxTime"] = math.max(0, saved["MaxTime"])
	end

	if typeof(saved["Equipped"]) == "table" then
		for key, _ in pairs(data["Equipped"]) do
			local savedValue = saved["Equipped"][key]
			if typeof(savedValue) == "string" then
				data["Equipped"][key] = savedValue
			end
		end
	end

	return data
end

function Data:SaveData(player: Player): boolean
	local playerData = Data.GameData[player.UserId]
	if not playerData then
		return false
	end

	local payload = deepCopy(playerData)
	local ok, err = retry(function()
		store:UpdateAsync(string.format("player_%d", player.UserId), function()
			return payload
		end)
	end)
	if not ok then
		warn(string.format("GameDataMod: could not save %d (%s)", player.UserId, tostring(err)))
	end
	return ok
end

function Data:LoadData(player: Player): boolean
	local ok, saved = retry(function()
		return store:GetAsync(string.format("player_%d", player.UserId))
	end)
	if not ok or typeof(saved) ~= "table" then
		return false
	end

	Data.GameData[player.UserId] = sanitizeSaved(saved)
	return true
end

function Data:CreateData(player: Player)
	if Data.GameData[player.UserId] == nil then
		Data.GameData[player.UserId] = deepCopy(DefaultPlayerData)
	end
end

function Data:SaveAll()
	for userId in pairs(Data.GameData) do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			Data:SaveData(player)
		end
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
				if MapGrid.GridArray[i][j] ~= nil then
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
			local plate = ServerStorage.ServerStorage.Plates:FindFirstChild(Data.GameData[plr.UserId]["Equipped"]["Plate"])
			local terrainOffset = plate and plate:FindFirstChild("TerrainOffset")
			if terrainOffset then
				char:PivotTo(
					CFrame.new((newPos[1] - 1) * 7, map.GridArray[newPos[1]][newPos[2]]["Position"], (newPos[2] - 1) * 7)
						* CFrame.new(map.originPosition.X, terrainOffset.Value, map.originPosition.Z)
						* CFrame.fromOrientation(0, math.rad(180), 0)
				)
			end
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
		local enemyTemplate = CurMapData and ServerStorage.ServerStorage.Enemies:FindFirstChild(CurMapData["EnemyType"])
		if not enemyTemplate then
			return
		end
		local EnemyMdl = enemyTemplate:Clone()
		EnemyMdl:PivotTo(CFrame.new(10000, 10000, 10000))
		EnemyMdl.Parent = workspace
		CollectionService:AddTag(EnemyMdl, EnemyLogic.TAG_NAME)
		local spawnPoints = CurMapData["EnemyLocations"]
		if not spawnPoints or #spawnPoints == 0 then
			return
		end
		local SpawnPos = spawnPoints[random:NextInteger(1, #spawnPoints)]
		local AlivePlayers = {}
		for userId, sessionData in pairs(Data.SessionData) do
			if sessionData["InGame"] == true then
				table.insert(AlivePlayers, Players:GetPlayerByUserId(userId))
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

	local hrp = chr:WaitForChild("HumanoidRootPart")
	hrp.Anchored = true
	for _, v in pairs(chr:GetChildren()) do
		if v:IsA("BasePart") and v ~= hrp then
			v.Anchored = false
			v.CanCollide = false
		end
	end

	-- Attach plate
	local playerData = Data.GameData[Player.UserId]
	local plateTemplate = playerData
		and ServerStorage.ServerStorage.Plates:FindFirstChild(playerData["Equipped"]["Plate"])
	if not plateTemplate then
		warn(string.format("GameDataMod: no plate for %s", Player.Name))
		return
	end
	local Plate = plateTemplate:Clone()
	Plate.Name = "Plate"
	local offset = Plate:FindFirstChild("Offset")
	local weld = Instance.new("Weld")
	weld.Part0 = hrp
	weld.Part1 = Plate
	weld.C1 = CFrame.new(0, offset and offset.Value or 0, 0)
	weld.Parent = Plate
	Plate.Parent = chr

	-- Pick spawn position
	local isInGame = Data.SessionData[Player.UserId]["InGame"]
	local mapName = isInGame and Data.RoundData.Map or "Lobby"
	local mapSpawns = Data.MapsData[mapName] and Data.MapsData[mapName]["SpawnLocations"]
	if not mapSpawns or #mapSpawns == 0 then
		warn(string.format("GameDataMod: no spawn points on %s", mapName))
		return
	end
	local pos = mapSpawns[random:NextInteger(1, #mapSpawns)]
	local posKey = isInGame and "GamePosition" or "LobbyPosition"

	Data.SessionData[Player.UserId][posKey] = pos

	local terrainOffset = Plate:FindFirstChild("TerrainOffset")
	local spawnCFrame = GetSpawnCFrame(mapName, pos, terrainOffset and terrainOffset.Value or 0)
	if spawnCFrame then
		chr:PivotTo(spawnCFrame)
	end
	Packets.MoveAckPacket:FireClient(Player, true, pos[1], pos[2], mapName)
end

local function ChooseRandMap()
	return GameMaps[random:NextInteger(1, #GameMaps)]
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
	Data:UnloadMap(Data.RoundData["Map"])
	Data.RoundData["InProgress"] = false
	Data.RoundData["StartTime"] = 0
	Data.RoundData["Map"] = ""
	Data:RoundIntermission()
end

function Data:RoundStart()
	Data.RoundData["StartTime"] = workspace:GetServerTimeNow() --this is done first to account for the delay to fetch
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
