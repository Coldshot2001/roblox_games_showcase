--!strict

local FrNoise = require(game.ReplicatedStorage.FractalNoise)

local NORMAL_DIRECTIONS = {
	[Enum.NormalId.Top] = Vector3.new(0, 1, 0),
	[Enum.NormalId.Bottom] = Vector3.new(0, -1, 0),
	[Enum.NormalId.Back] = Vector3.new(0, 0, 1),
	[Enum.NormalId.Front] = Vector3.new(0, 0, -1),
	[Enum.NormalId.Right] = Vector3.new(1, 0, 0),
	[Enum.NormalId.Left] = Vector3.new(-1, 0, 0),
}

local CHUNK_SIZE_X = 60
local CHUNK_SIZE_Y = 60
local CHUNK_SIZE_Z = 60
local VOXEL_SIZE = 5
local ZOOM = 20
local WAIT_EVERY_PARTS = 1000

local SEED = 10
local AMPLITUDE = 0.6
local FREQUENCY = 2
local OCTAVES = 1
local LACUNARITY = nil
local PERSISTENCE = nil

local noise3D = FrNoise(SEED, AMPLITUDE, FREQUENCY, OCTAVES, LACUNARITY, PERSISTENCE)

local function resizePart(part: BasePart, normal: Enum.NormalId, delta: number)
	local direction = NORMAL_DIRECTIONS[normal]
	part.Size = part.Size + Vector3.new(math.abs(direction.X), math.abs(direction.Y), math.abs(direction.Z)) * delta
	part.CFrame = part.CFrame + NORMAL_DIRECTIONS[normal] * delta / 2
end

local function generateChunk(): (any, any)
	local chunk = {}
	local isVisited = {}

	for x = 0, CHUNK_SIZE_X do
		chunk[x] = {}
		isVisited[x] = {}
		for y = 0, CHUNK_SIZE_Y do
			chunk[x][y] = {}
			isVisited[x][y] = {}
			for z = 0, CHUNK_SIZE_Z do
				local value = noise3D(x / ZOOM, y / ZOOM, z / ZOOM)
				if value >= 0 then
					chunk[x][y][z] = value
					isVisited[x][y][z] = false
				end
			end
		end
	end

	return chunk, isVisited
end

local function greedyMesh(chunk: any, isVisited: any): { any }
	local voxels = {}

	for x = 0, CHUNK_SIZE_X do
		for y = 0, CHUNK_SIZE_Y do
			for z = 0, CHUNK_SIZE_Z do
				if isVisited[x] and isVisited[x][y] and isVisited[x][y][z] == false then
					isVisited[x][y][z] = true
					local startX = x
					local startY = y
					local startZ = z
					local endX = x
					local endY = y
					local endZ = z

					while endX < CHUNK_SIZE_X do
						local curX = endX + 1
						if chunk[curX][y][z] and isVisited[curX][y][z] == false then
							isVisited[curX][y][z] = true
							endX = curX
						else
							break
						end
					end

					while endZ < CHUNK_SIZE_Z do
						local curZ = endZ + 1
						if chunk[x][y][curZ] and isVisited[x][y][curZ] == false then
							local isRowUseable = true
							for curX = startX + 1, endX do
								if chunk[curX][y][curZ] == nil or isVisited[curX][y][curZ] == true then
									isRowUseable = false
									break
								end
							end
							if isRowUseable == true then
								endZ = curZ
								for curX = startX, endX do
									isVisited[curX][y][curZ] = true
								end
							else
								break
							end
						else
							break
						end
					end

					while endY < CHUNK_SIZE_Y do
						local curY = endY + 1
						if chunk[x][curY][z] and isVisited[x][curY][z] == false then
							local isRowUseable = true
							for curX = startX, endX do
								if
									isRowUseable == true
									and chunk[curX][curY][z]
									and isVisited[curX][curY][z] == false
								then
									for curZ = startZ + 1, endZ do
										if chunk[curX][curY][curZ] == nil or isVisited[curX][curY][curZ] == true then
											isRowUseable = false
											break
										end
									end
								else
									break
								end
							end
							if isRowUseable == true then
								endY = curY
								for curX = startX, endX do
									for curZ = startZ, endZ do
										isVisited[curX][curY][curZ] = true
									end
								end
							else
								break
							end
						else
							break
						end
					end

					table.insert(voxels, {
						{ startX, startY, startZ },
						{ endX, endY, endZ },
					})
				end
			end
		end
	end

	return voxels
end

local function renderVoxelModel(voxels: { any }): Model
	local model = Instance.new("Model")
	local partsSinceWait = 0

	for _, voxelData in pairs(voxels) do
		local startPos = voxelData[1]
		local endPos = voxelData[2]

		local voxel = Instance.new("Part")
		voxel.Size = Vector3.new(VOXEL_SIZE, VOXEL_SIZE, VOXEL_SIZE)
		voxel.CastShadow = false
		voxel.CanCollide = false
		voxel.Anchored = true
		voxel.CanTouch = false
		voxel.Material = Enum.Material.SmoothPlastic
		voxel.Position = Vector3.new(startPos[1] * VOXEL_SIZE, startPos[2] * VOXEL_SIZE, startPos[3] * VOXEL_SIZE)
		voxel.Color = Color3.fromRGB(math.random(0, 255), math.random(0, 255), math.random(0, 255))
		voxel.Parent = model

		local xScale = math.abs(startPos[1] - endPos[1])
		local yScale = math.abs(startPos[2] - endPos[2])
		local zScale = math.abs(startPos[3] - endPos[3])
		resizePart(voxel, Enum.NormalId.Right, xScale * VOXEL_SIZE)
		resizePart(voxel, Enum.NormalId.Top, yScale * VOXEL_SIZE)
		resizePart(voxel, Enum.NormalId.Back, zScale * VOXEL_SIZE)

		partsSinceWait = (partsSinceWait + 1) % WAIT_EVERY_PARTS
		if partsSinceWait == 0 then
			task.wait()
		end
	end

	model.Parent = workspace
	return model
end

local chunk, isVisited = generateChunk()
local voxels = greedyMesh(chunk, isVisited)
renderVoxelModel(voxels)
