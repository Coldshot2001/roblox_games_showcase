--!strict

export type Cell = { [any]: any }

local Grid = {}
Grid.__index = Grid

export type GridMap = typeof(setmetatable(
	{} :: {
		width: number,
		height: number,
		cellSize: number,
		originPosition: Vector3,
		GridArray: { [number]: { [number]: Cell? } },
	},
	Grid
))

local function inBounds(self: GridMap, x: number, y: number): boolean
	if typeof(x) ~= "number" or typeof(y) ~= "number" then
		return false
	end
	if x ~= math.floor(x) or y ~= math.floor(y) then
		return false
	end
	return x >= 1 and x <= self.width and y >= 1 and y <= self.height
end

function Grid.new(width: number, height: number, cellSize: number, originPosition: Vector3): GridMap
	assert(typeof(width) == "number" and width > 0, "width must be a positive number")
	assert(typeof(height) == "number" and height > 0, "height must be a positive number")
	assert(typeof(cellSize) == "number" and cellSize > 0, "cellSize must be a positive number")
	assert(typeof(originPosition) == "Vector3", "originPosition must be a Vector3")

	local grid = setmetatable({
		width = width,
		height = height,
		cellSize = cellSize,
		originPosition = originPosition,
		GridArray = {},
	}, Grid)

	for x = 1, width do
		local column: { [number]: Cell? } = {}
		for y = 1, height do
			column[y] = nil
		end
		grid.GridArray[x] = column
	end

	return grid
end

function Grid.FromParts(PartsTbl: { BasePart }, cellSize: number, originPosition: Vector3): GridMap
	assert(#PartsTbl > 0, "PartsTbl must contain at least one part")

	local model = Instance.new("Model")
	local oldParents: { Instance? } = {}

	for i, part in ipairs(PartsTbl) do
		oldParents[i] = part.Parent
		part.Parent = model
	end

	local _, modelSize = model:GetBoundingBox()
	local width = math.max(1, math.floor(modelSize.X / cellSize))
	local height = math.max(1, math.floor(modelSize.Z / cellSize))

	for i, part in ipairs(PartsTbl) do
		part.Parent = oldParents[i]
	end

	model:Destroy()

	local grid = Grid.new(width, height, cellSize, originPosition)

	local overlap = OverlapParams.new()
	overlap.FilterDescendantsInstances = PartsTbl
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.MaxParts = 1

	for x = 1, width do
		for y = 1, height do
			local parts = workspace:GetPartBoundsInBox(
				CFrame.new((x - 1) * cellSize, 0, (y - 1) * cellSize) + originPosition,
				Vector3.new(cellSize - 1, 100, cellSize - 1),
				overlap
			)
			local floor = parts[1]
			if floor then
				grid.GridArray[x][y] = {
					Position = (floor.Position.Y + floor.Size.Y / 2) - 0.5,
				}
			end
		end
	end

	return grid
end

function Grid:GetWorldPosition(x: number, y: number): Vector3
	return Vector3.new(x - 1, 0, y - 1) * self.cellSize + self.originPosition
end

function Grid:GetXY(worldPosition: Vector3): (number, number)
	local x = math.round((worldPosition - self.originPosition).X / self.cellSize)
	local y = math.round((worldPosition - self.originPosition).Z / self.cellSize)
	return x + 1, y + 1
end

function Grid:IsInBounds(x: number, y: number): boolean
	return inBounds(self, x, y)
end

function Grid:IsEmpty(x: number, y: number): boolean
	local cell = self:GetValue(x, y)
	return cell == nil or next(cell) == nil
end

function Grid:SetValue(x: number, y: number, cell: Cell?): boolean
	if not inBounds(self, x, y) then
		warn(string.format("GridMap2D: (%s, %s) is out of bounds", tostring(x), tostring(y)))
		return false
	end
	self.GridArray[x][y] = cell
	return true
end

function Grid:GetValue(x: number, y: number): Cell?
	if not inBounds(self, x, y) then
		return nil
	end
	return self.GridArray[x][y]
end

function Grid:PosSetValue(worldPosition: Vector3, cell: Cell?): boolean
	local x, y = self:GetXY(worldPosition)
	return self:SetValue(x, y, cell)
end

function Grid:PosGetValue(worldPosition: Vector3): Cell?
	local x, y = self:GetXY(worldPosition)
	return self:GetValue(x, y)
end

-- Diagonal cells are not counted
function Grid:GetNeighbours(x: number, y: number): { { number } }
	local neighbours: { { number } } = {}

	if self:GetValue(x + 1, y) ~= nil then
		table.insert(neighbours, { x + 1, y })
	end
	if self:GetValue(x - 1, y) ~= nil then
		table.insert(neighbours, { x - 1, y })
	end
	if self:GetValue(x, y + 1) ~= nil then
		table.insert(neighbours, { x, y + 1 })
	end
	if self:GetValue(x, y - 1) ~= nil then
		table.insert(neighbours, { x, y - 1 })
	end

	return neighbours
end

return Grid
