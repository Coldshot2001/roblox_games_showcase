local Visuals = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local AnimationHandler = require(script.Parent.AnimationHandler)

Visuals.SetUp = false
Visuals.ARROW_FADE_IN = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
Visuals.ARROW_FADE_OUT = TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
Visuals.MOVE_TWEEN = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
Visuals.ARROW_SIZE = Vector3.new(6.855, 0.096, 6.855)
Visuals.CURRENT_MAP = ""

Visuals.CACHED_MAPS = {}
local localPlayerPos = { x = 0, y = 0 }
local EXISTING_NEIGHBOURS = {}
local TRACKED_ENTITIES = {}
local OCCUPIED_CELLS = {}
local TileModel = nil
local pendingSpawns = {}
local LocalPlayer = Players.LocalPlayer
local activeTweens = {}

local function CellExists(mapName, x, y)
	local cache = Visuals.CACHED_MAPS[mapName]
	if cache == nil then
		return false
	end
	local row = cache.GridArray[x]
	if row == nil then
		return false
	end
	local cell = row[y]
	return cell ~= nil
end

local function SetOccupied(mapName, x, y, occupied)
	if x == 0 or y == 0 then
		return
	end
	OCCUPIED_CELLS[mapName] = OCCUPIED_CELLS[mapName] or {}
	OCCUPIED_CELLS[mapName][x] = OCCUPIED_CELLS[mapName][x] or {}
	if occupied then
		OCCUPIED_CELLS[mapName][x][y] = true
	else
		OCCUPIED_CELLS[mapName][x][y] = nil
	end
end

local function BuildCellCFrame(mapName, gridX, gridY, plateOffset)
	local cache = Visuals.CACHED_MAPS[mapName]
	if cache == nil then
		return nil
	end
	local cell = cache.GridArray[gridX] and cache.GridArray[gridX][gridY]
	if cell == nil then
		return nil
	end
	local origin = cache.originPosition
	local cs = cache.cellSize
	return CFrame.new((gridX - 1) * cs, cell["Position"], (gridY - 1) * cs)
		* CFrame.new(origin.X, plateOffset - 1.5, origin.Z)
		* CFrame.fromOrientation(0, math.rad(180), 0)
end

local function TweenPart(part, targetCFrame)
	local existing = activeTweens[part]
	if existing then
		existing:Cancel()
		activeTweens[part] = nil
	end

	local tween = TweenService:Create(part, Visuals.MOVE_TWEEN, { CFrame = targetCFrame })
	activeTweens[part] = tween
	tween.Completed:Connect(function()
		if activeTweens[part] == tween then
			activeTweens[part] = nil
		end
	end)
	tween:Play()

	return tween
end

local function GetPlateOffset(character)
	if character == nil then
		return 0
	end
	local plate = character:FindFirstChild("Plate")
	if plate == nil then
		return 0
	end
	local offsetVal = plate:FindFirstChild("TerrainOffset")
	return offsetVal and offsetVal.Value or 0
end

local function MoveCharacterToCell(character, mapName, gridX, gridY)
	if character == nil then
		return
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp == nil then
		return
	end
	local target = BuildCellCFrame(mapName, gridX, gridY, GetPlateOffset(character))
	if target == nil then
		return
	end
	TweenPart(hrp, target)
end

local function GetNeighbourParts(mapName, x, y, allowOccupied)
	local cache = Visuals.CACHED_MAPS[mapName]
	if cache == nil then
		return {}
	end
	local result = {}
	local offsets = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
	for _, off in ipairs(offsets) do
		local nx, ny = x + off[1], y + off[2]
		if CellExists(mapName, nx, ny) then
			local blocked = not allowOccupied
				and OCCUPIED_CELLS[mapName]
				and OCCUPIED_CELLS[mapName][nx]
				and OCCUPIED_CELLS[mapName][nx][ny]
			local part = cache.GridArray[nx][ny]["Part"]
			if part then
				table.insert(result, {
					part = part,
					gridX = nx,
					gridY = ny,
					blocked = blocked or false,
				})
			end
		end
	end
	return result
end

local function ClearArrowsImmediate()
	for _, entry in ipairs(EXISTING_NEIGHBOURS) do
		local outline = entry.part:FindFirstChild("Outline")
		if outline then
			outline.Size = Vector3.new(0, 0, 0)
			outline.Transparency = 1
		end
	end
	EXISTING_NEIGHBOURS = {}
end

local function UpdateArrows(mapName, gridX, gridY, allowOccupied)
	local newNeighbours = GetNeighbourParts(mapName, gridX, gridY, allowOccupied)

	for _, entry in ipairs(EXISTING_NEIGHBOURS) do
		local outline = entry.part:FindFirstChild("Outline")
		if outline then
			TweenService:Create(outline, Visuals.ARROW_FADE_IN, {
				Size = Vector3.new(0, 0, 0),
				Transparency = 1,
			}):Play()
		end
	end

	for _, entry in ipairs(newNeighbours) do
		local outline = entry.part:FindFirstChild("Outline")
		if outline then
			TweenService:Create(outline, Visuals.ARROW_FADE_OUT, {
				Size = Visuals.ARROW_SIZE,
				Transparency = entry.blocked and 0.55 or 0,
			}):Play()
		end
	end

	EXISTING_NEIGHBOURS = newNeighbours
end

local function ApplyPosition(gridX, gridY, mapName, dir, isCorrection)
	if Visuals.CACHED_MAPS[mapName] == nil then
		return false
	end

	if localPlayerPos.x ~= 0 then
		SetOccupied(Visuals.CURRENT_MAP, localPlayerPos.x, localPlayerPos.y, false)
	end

	localPlayerPos.x = gridX
	localPlayerPos.y = gridY
	SetOccupied(mapName, gridX, gridY, true)

	if Visuals.CURRENT_MAP ~= mapName then
		if Visuals.CURRENT_MAP ~= "" then
			ClearArrowsImmediate()
			OCCUPIED_CELLS[Visuals.CURRENT_MAP] = nil
			Visuals.CACHED_MAPS[Visuals.CURRENT_MAP].model.Parent = nil
		end
		Visuals.CACHED_MAPS[mapName].model.Parent = workspace
		Visuals.CURRENT_MAP = mapName
	end

	MoveCharacterToCell(LocalPlayer.Character, mapName, gridX, gridY)

	if isCorrection then
		AnimationHandler:PlayCorrection("local")
	elseif dir then
		AnimationHandler:PlayMove("local", dir)
	end

	local isLobby = (mapName == "Lobby")
	UpdateArrows(mapName, gridX, gridY, isLobby)
	return true
end

function Visuals:StartUp()
	if Visuals.SetUp == false then
		TileModel = ReplicatedStorage.Assets.Models:WaitForChild("Tile", 15)
		if TileModel == nil then
			return
		end
		Visuals.SetUp = true
	end
end

function Visuals:CacheMap(GridArray, cellSize, originPosition, Name)
	repeat
		task.wait()
	until Visuals.SetUp == true
	if Visuals.CACHED_MAPS[Name] ~= nil then
		return
	end

	local mapModel = Instance.new("Model")
	mapModel.Name = Name

	Visuals.CACHED_MAPS[Name] = {
		GridArray = GridArray,
		model = mapModel,
		cellSize = cellSize,
		originPosition = originPosition,
	}

	for x, tb in pairs(GridArray) do
		for y, v in pairs(tb) do
			if v ~= nil then
				local part = TileModel:Clone()
				local worldX = (x - 1) * cellSize + originPosition.X
				local worldZ = (y - 1) * cellSize + originPosition.Z

				part:PivotTo(
					CFrame.new(worldX, v["Position"], worldZ) * CFrame.fromOrientation(0, math.rad(90 * v["Value"]), 0)
				)

				local outline = part:FindFirstChild("Outline")
				if outline then
					local colours = {
						[1] = Color3.fromRGB(229, 68, 75),
						[2] = Color3.fromRGB(128, 238, 95),
						[3] = Color3.fromRGB(73, 131, 232),
						[4] = Color3.fromRGB(233, 203, 74),
					}
					outline.Color = colours[v["Value"]] or Color3.new(1, 1, 1)
					outline.Size = Vector3.new(0, 0, 0)
					outline.Transparency = 1
				end

				v["Part"] = part
				part.Parent = mapModel
			end
		end
	end

	local pending = pendingSpawns[Name]
	if pending then
		pendingSpawns[Name] = nil
		ApplyPosition(pending[1], pending[2], Name, nil, false)
	end
end

function Visuals:OnSpawnAck(gridX, gridY, mapName)
	if localPlayerPos.x == gridX and localPlayerPos.y == gridY and Visuals.CURRENT_MAP == mapName then
		return
	end
	if not ApplyPosition(gridX, gridY, mapName, nil, false) then
		pendingSpawns[mapName] = { gridX, gridY }
	end
end

function Visuals:OnLocalPlayerMoved(accepted, gridX, gridY, mapName, dir)
	ApplyPosition(gridX, gridY, mapName, dir, not accepted)
end

function Visuals:OnEntityMoved(entityId, entityType, gridX, gridY, mapName, dir)
	local record = TRACKED_ENTITIES[entityId]
	if record and record.mapName and record.gridX and record.gridY then
		SetOccupied(record.mapName, record.gridX, record.gridY, false)
	end

	TRACKED_ENTITIES[entityId] = TRACKED_ENTITIES[entityId] or {}
	record = TRACKED_ENTITIES[entityId]
	record.gridX = gridX
	record.gridY = gridY
	record.mapName = mapName

	local isLobby = (mapName == "Lobby")
	if entityType == "enemy" or not isLobby then
		SetOccupied(mapName, gridX, gridY, true)
	end

	local model = record.model
	if model and model.Parent ~= nil then
		local plateOffset = entityType == "player" and GetPlateOffset(model) or 0
		local target = BuildCellCFrame(mapName, gridX, gridY, plateOffset)
		if target then
			local primaryPart = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
			if primaryPart then
				TweenPart(primaryPart, target)
			end
		end
	end

	if dir and dir > 0 and entityType == "player" then
		AnimationHandler:PlayMove(entityId, dir)
	end

	if mapName == Visuals.CURRENT_MAP then
		UpdateArrows(Visuals.CURRENT_MAP, localPlayerPos.x, localPlayerPos.y, isLobby)
	end
end

function Visuals:RegisterEntityModel(entityId, model)
	TRACKED_ENTITIES[entityId] = TRACKED_ENTITIES[entityId] or {}
	TRACKED_ENTITIES[entityId].model = model
end

function Visuals:UnregisterEntity(entityId)
	local record = TRACKED_ENTITIES[entityId]
	if record then
		local model = record.model
		if model then
			local primaryPart = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
			if primaryPart and activeTweens[primaryPart] then
				activeTweens[primaryPart]:Cancel()
				activeTweens[primaryPart] = nil
			end
		end
		SetOccupied(record.mapName, record.gridX, record.gridY, false)
		TRACKED_ENTITIES[entityId] = nil
		if record.mapName == Visuals.CURRENT_MAP and localPlayerPos.x ~= 0 then
			UpdateArrows(Visuals.CURRENT_MAP, localPlayerPos.x, localPlayerPos.y, Visuals.CURRENT_MAP == "Lobby")
		end
	end
end

function Visuals:IsOccupied(mapName, x, y)
	return OCCUPIED_CELLS[mapName] ~= nil
		and OCCUPIED_CELLS[mapName][x] ~= nil
		and OCCUPIED_CELLS[mapName][x][y] == true
end

function Visuals:GetLocalPosition()
	return localPlayerPos.x, localPlayerPos.y
end

function Visuals:PredictMove(mapName, fromX, fromY, dir)
	local cache = Visuals.CACHED_MAPS[mapName]
	if cache == nil then
		return nil
	end
	local offsets = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
	for _, off in ipairs(offsets) do
		local nx, ny = fromX + off[1], fromY + off[2]
		if CellExists(mapName, nx, ny) then
			local cell = cache.GridArray[nx][ny]
			if cell ~= nil and cell["Value"] == dir then
				return nx, ny
			end
		end
	end
	return nil
end

function Visuals:ReleaseMap(Name)
	if Visuals.CACHED_MAPS[Name] == nil then
		return
	end
	if Visuals.CURRENT_MAP == Name then
		ClearArrowsImmediate()
		OCCUPIED_CELLS[Name] = nil
		Visuals.CACHED_MAPS[Name].model.Parent = nil
		Visuals.CURRENT_MAP = ""
	end
	Visuals.CACHED_MAPS[Name].model:Destroy()
	Visuals.CACHED_MAPS[Name] = nil
	pendingSpawns[Name] = nil
end

return Visuals
