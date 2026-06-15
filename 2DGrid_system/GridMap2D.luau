local Grid = {}
Grid.__index = Grid

function Grid.new(width, height, cellSize, originPosition)
	local GridMap = setmetatable({}, Grid)
	GridMap.originPosition = originPosition
	GridMap.GridArray = {}
	GridMap.width = width
	GridMap.height = height
	GridMap.cellSize = cellSize
	local G = GridMap.GridArray
	--DEBUG local model = Instance.new("Model")
	for x = 1, width do
		G[x] = {}
		for y = 1, height do
			--[[\\DEBUG
			local DEBUGVALUE = game.ServerStorage.Debug:Clone()
			local clone = game.ServerStorage.Tile:Clone()
			local part = Instance.new("Part")
			clone.Parent = part
			DEBUGVALUE.Parent = part
			DEBUGVALUE.TextLabel.Text = math.random(-1,1)*cellSize
			part.Name = string.format("X:%i Y:%i",x,y)
			part.Transparency = 0
			part.CanCollide = true
			part.Anchored = true
			part.CanTouch = false
			part.Size = Vector3.new(cellSize,1,cellSize)
			part.Color = Color3.fromRGB(math.random(0,255),math.random(0,255),math.random(0,255))
			local X = x*cellSize
			local Z = y*cellSize
			part.Position = Vector3.new(X,tonumber(DEBUGVALUE.TextLabel.Text),Z) + originPosition
			part.Parent = model
			--//DEBUG]]
			G[x][y] = {} --{DEBUGVALUE.TextLabel} the contents of the tile
		end
	end
	--DEBUG model.Parent = workspace
	return GridMap
end

function Grid.FromTable(Table, cellSize, originPosition)
	--unfinished
	for y, tb in pairs(Table) do
		for x, v in pairs(tb) do
			if v ~= 0 then
				local part = Instance.new("Part")
				part.Name = string.format("X:%i Y:%i", x, y)
				part.Transparency = 0
				part.CanCollide = true
				part.Anchored = true
				part.CanTouch = false
				part.Size = Vector3.new(cellSize, 1, cellSize)
				part.Color = Color3.fromRGB(math.random(0, 255), math.random(0, 255), math.random(0, 255))
				local X = x * cellSize
				local Z = y * cellSize
				part.Position = Vector3.new(X, v, Z) + originPosition
				part.Parent = workspace
			end
		end
	end
end

function Grid.FromParts(PartsTbl, cellSize, originPosition)
	local GridMap = setmetatable({}, Grid)
	GridMap.originPosition = originPosition
	GridMap.GridArray = {}
	GridMap.cellSize = cellSize
	local G = GridMap.GridArray
	local model = Instance.new("Model")
	local oldprnts = {}
	for _, v in ipairs(PartsTbl) do
		table.insert(oldprnts, v.Parent)
		v.Parent = model
	end
	local _, MDLSize = model:GetBoundingBox()
	GridMap.width = math.floor(MDLSize.X / cellSize)
	GridMap.height = math.floor(MDLSize.Z / cellSize)
	for i, v in ipairs(PartsTbl) do
		v.Parent = oldprnts[i]
	end
	oldprnts = nil
	model:Destroy()
	model = nil
	local ov = OverlapParams.new()
	ov.FilterDescendantsInstances = PartsTbl
	ov.FilterType = Enum.RaycastFilterType.Include
	ov.MaxParts = 1
	for x = 1, GridMap.width do
		G[x] = {}
		for y = 1, GridMap.height do
			local q = workspace:GetPartBoundsInBox(
				CFrame.new((x - 1) * cellSize, 0, (y - 1) * cellSize) + originPosition,
				Vector3.new(cellSize - 1, 100, cellSize - 1),
				ov
			)
			if next(q) ~= nil then
				--local ui = game.ReplicatedStorage.TileTexture:Clone()
				G[x][y] = { ["Position"] = ((q[1].Position.Y + q[1].Size.Y / 2) - 0.5) } --{ui,((q[1].Position.Y+q[1].Size.Y/2)-.5)}
			else
				G[x][y] = -math.huge
			end
		end
	end
	--[[//
	for x,tb in pairs(G) do
		for y,v in pairs(tb) do
			if v ~= -math.huge then
				local part = Instance.new("Part")
				v[1].Parent = part
				part.Name = string.format("X:%i Y:%i",x,y)
				part.Transparency = 1
				part.CanCollide = false
				part.Anchored = true
				part.CanTouch = false
				part.CanQuery = false
				part.Massless = true
				part.CastShadow = false
				part.Size = Vector3.new(cellSize,1,cellSize)
				part.Color = Color3.fromRGB(math.random(0,255),math.random(0,255),math.random(0,255))
				local X = x*cellSize
				local Z = y*cellSize
				part.Position = Vector3.new(X,v[2],Z) + Vector3.new(originPosition.X,0,originPosition.Z)
				part.Parent = workspace
			end
		end
	end
	--\\DISPLAY]]
	return GridMap
end

function Grid:GetWorldPosition(x, y)
	return Vector3.new(x - 1, 0, y - 1) * self.cellSize + self.originPosition
end

function Grid:SetValue(x, y, name, value)
	if x > 0 and y > 0 and x < self.width and y < self.height then
		if self.GridArray[x][y] ~= -math.huge then
			self.GridArray[x][y][name] = value
		else
			warn(string.format("Position %i %i is out of bounds!", x, y))
		end
		--print(x,y,value)
		--[[if self.GridArray[x][y] ~= -math.huge then
			self.GridArray[x][y][1].Color3 = Color3.fromRGB(0, 255, 0) --DEBUG
		end]]
	else
		warn(string.format("Position %i %i is out of bounds!", x, y))
	end
end

function Grid:GetXY(WorldPosition)
	local x = math.round((WorldPosition - self.originPosition).X / self.cellSize)
	local y = math.round((WorldPosition - self.originPosition).Z / self.cellSize)
	return x + 1, y + 1
end

function Grid:PosSetValue(WorldPosition, name, value)
	local x, y = self:GetXY(WorldPosition)
	self:SetValue(x, y, name, value)
end

function Grid:GetValue(x, y)
	if x > 0 and y > 0 and x < self.width and y < self.height then
		return self.GridArray[x][y]
	end
	return -math.huge
end

function Grid:PosGetValue(WorldPosition)
	local x, y = self:GetXY(WorldPosition)
	return self:GetValue(x, y)
end

function Grid:GetNeighbours(x, y)
	--x up+ down-
	--y left- right+
	local ret_tbl = {}
	if self.GridArray[x + 1] and self.GridArray[x + 1][y] ~= -math.huge and self.GridArray[x + 1][y] ~= nil then
		table.insert(ret_tbl, { x + 1, y })
	end
	if self.GridArray[x - 1] and self.GridArray[x - 1][y] ~= -math.huge and self.GridArray[x - 1][y] ~= nil then
		table.insert(ret_tbl, { x - 1, y })
	end
	if self.GridArray[x] and self.GridArray[x][y + 1] ~= -math.huge and self.GridArray[x][y + 1] ~= nil then
		table.insert(ret_tbl, { x, y + 1 })
	end
	if self.GridArray[x] and self.GridArray[x][y - 1] ~= -math.huge and self.GridArray[x][y - 1] ~= nil then
		table.insert(ret_tbl, { x, y - 1 })
	end
	return ret_tbl
end

return Grid
