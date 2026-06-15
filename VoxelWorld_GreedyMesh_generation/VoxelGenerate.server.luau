local FrNoise = require(game.ReplicatedStorage.FractalNoise)
local NORMAL_DIRECTIONS = {
	[Enum.NormalId.Top] = Vector3.new(0, 1, 0),
	[Enum.NormalId.Bottom] = Vector3.new(0, -1, 0),
	[Enum.NormalId.Back] = Vector3.new(0, 0, 1),
	[Enum.NormalId.Front] = Vector3.new(0, 0, -1),
	[Enum.NormalId.Right] = Vector3.new(1, 0, 0),
	[Enum.NormalId.Left] = Vector3.new(-1, 0, 0),
}
local function Resize(part, normal, delta)
	--delta = studs (to increase size)
	local Direction = NORMAL_DIRECTIONS[normal]
	part.Size = part.Size + Vector3.new(math.abs(Direction.X), math.abs(Direction.Y), math.abs(Direction.Z)) * delta
	part.CFrame = part.CFrame + NORMAL_DIRECTIONS[normal] * delta / 2
end

local ChunkCount = 0
local function ChunkWait()
	ChunkCount = (ChunkCount + 1) % 1000
	if ChunkCount == 0 then
		task.wait()
	end
end

local seed = 10
local amplitude = 0.6
local frequency = 2
local octaves = 1
local lacunarity = nil
local persistence = nil
local noise3D = FrNoise(seed, amplitude, frequency, octaves, lacunarity, persistence)

local CHUNK_SIZE_X = 60
local CHUNK_SIZE_Y = 60
local CHUNK_SIZE_Z = 60
local VOXEL_SIZE = 5
local ZOOM = 20

--generating voxels
local Chunk = {}
local isVisited = {}
local Voxels = {}

for x = 0, CHUNK_SIZE_X do
	Chunk[x] = {}
	isVisited[x] = {}
	for y = 0, CHUNK_SIZE_Y do
		Chunk[x][y] = {}
		isVisited[x][y] = {}
		for z = 0, CHUNK_SIZE_Z do
			local value = noise3D(x / ZOOM, y / ZOOM, z / ZOOM)
			if value >= 0 then
				Chunk[x][y][z] = value
				isVisited[x][y][z] = false
			end
		end
	end
end
--

--greedy meshing
for x = 0, CHUNK_SIZE_X do
	for y = 0, CHUNK_SIZE_Y do
		for z = 0, CHUNK_SIZE_Z do
			if isVisited[x] then
				if isVisited[x][y] then
					if isVisited[x][y][z] == false then
						isVisited[x][y][z] = true
						local startX = x
						local startY = y
						local startZ = z
						local endX = x
						local endY = y
						local endZ = z

						while endX < CHUNK_SIZE_X do
							local curX = endX + 1
							if Chunk[curX][y][z] and isVisited[curX][y][z] == false then
								isVisited[curX][y][z] = true
								endX = curX
							else
								break
							end
						end

						while endZ < CHUNK_SIZE_Z do
							local curZ = endZ + 1
							if Chunk[x][y][curZ] and isVisited[x][y][curZ] == false then
								local isRowUseable = true
								for curX = startX + 1, endX do
									if Chunk[curX][y][curZ] == nil or isVisited[curX][y][curZ] == true then
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
							if Chunk[x][curY][z] and isVisited[x][curY][z] == false then
								local isRowUseable = true
								for curX = startX, endX do
									if
										isRowUseable == true
										and Chunk[curX][curY][z]
										and isVisited[curX][curY][z] == false
									then
										for curZ = startZ + 1, endZ do
											if
												Chunk[curX][curY][curZ] == nil
												or isVisited[curX][curY][curZ] == true
											then
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

						local VoxelData = {
							{ startX, startY, startZ },
							{ endX, endY, endZ },
						}

						table.insert(Voxels, VoxelData)
					end
				end
			end
		end
	end
end
--

--rendering voxels
local st = os.clock()
print("START")
local m = Instance.new("Model")
for _, v in pairs(Voxels) do
	local voxel = Instance.new("Part")
	voxel.Size = Vector3.new(VOXEL_SIZE, VOXEL_SIZE, VOXEL_SIZE)
	voxel.CastShadow = false
	voxel.CanCollide = false
	voxel.Anchored = true
	voxel.CanTouch = false
	voxel.Material = Enum.Material.SmoothPlastic
	voxel.Position = Vector3.new(v[1][1] * VOXEL_SIZE, v[1][2] * VOXEL_SIZE, v[1][3] * VOXEL_SIZE)
	local xScale = math.abs(v[1][1] - v[2][1])
	local yScale = math.abs(v[1][2] - v[2][2])
	local zScale = math.abs(v[1][3] - v[2][3])
	Resize(voxel, Enum.NormalId.Right, xScale * VOXEL_SIZE)
	Resize(voxel, Enum.NormalId.Top, yScale * VOXEL_SIZE)
	Resize(voxel, Enum.NormalId.Back, zScale * VOXEL_SIZE)
	voxel.Parent = m
	voxel.Color = Color3.fromRGB(math.random(0, 255), math.random(0, 255), math.random(0, 255)) --133, 170, 91)
	ChunkWait()
end
local fin = os.clock() - st
print(fin)
m.Parent = workspace
--
