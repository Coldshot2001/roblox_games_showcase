--!strict

local AStar = require(game.ServerScriptService.Modules.AStar)

local EnemyLogic = {}
EnemyLogic.__index = EnemyLogic
EnemyLogic.TAG_NAME = "Enemy"

function EnemyLogic.new(enemy: Model, enemyId: string)
	local self = {}
	self.map = nil
	self.pos = nil
	self.model = enemy
	self.enemyId = enemyId
	self.possibleTargets = nil
	self.getPlayerPos = nil
	self.onMoved = nil
	self.MOVEMENT_DELAY = 2.5
	self.running = false
	self.attacking = false
	return setmetatable(self, EnemyLogic)
end

local function GetTarget(startPos, targets, getPlayerPos)
	local closestDist = math.huge
	local closestPos = nil
	for _, player in pairs(targets) do
		local pos = getPlayerPos(player)
		if pos ~= nil then
			local posVec = Vector3.new(pos[1], pos[2], 0)
			local dist = (startPos - posVec).Magnitude
			if dist < closestDist then
				closestDist = dist
				closestPos = posVec
			end
		end
	end
	return closestPos
end

local function PositionModel(x, y, model, gridHeight, originPosition)
	model:PivotTo(
		CFrame.new((x - 1) * 7, gridHeight, (y - 1) * 7)
			* CFrame.new(originPosition.X, 4.5, originPosition.Z)
			* CFrame.fromOrientation(0, math.rad(180), 0)
	)
end

local function Move(startPos, endPos, grid, model, originPosition)
	local path = AStar.path({ x = startPos.X, y = startPos.Y }, { x = endPos.X, y = endPos.Y }, grid)
	if not path or #path < 2 then
		return startPos
	end

	local nextStep = path[2]
	local cell = grid[nextStep.x] and grid[nextStep.x][nextStep.y]
	if not cell then
		return startPos
	end

	PositionModel(nextStep.x, nextStep.y, model, cell["Position"], originPosition)
	return Vector3.new(nextStep.x, nextStep.y, 0)
end

local function ChooseAction(self, startPos, endPos, grid, model, originPosition)
	local dist = (startPos - endPos).Magnitude
	if dist == 1 then
		self.attacking = true
		return startPos
	elseif dist > 1 then
		self.attacking = false
		return Move(startPos, endPos, grid, model, originPosition)
	end
	self.attacking = false
	return startPos
end

function EnemyLogic:Cleanup()
	self.running = false
	if self.model then
		self.model:Destroy()
	end
end

function EnemyLogic:UpdateTargets(players)
	self.possibleTargets = players
end

function EnemyLogic:Spawn(Location, MapName, MapData, getPlayerPos, onMoved)
	self.pos = Vector3.new(Location[1], Location[2], 0)
	self.map = MapName
	self.getPlayerPos = getPlayerPos
	self.onMoved = onMoved

	local curMap = MapData
	PositionModel(
		self.pos.X,
		self.pos.Y,
		self.model,
		curMap.GridArray[self.pos.X][self.pos.Y]["Position"],
		curMap.originPosition
	)

	if self.onMoved then
		self.onMoved(self.enemyId, self.pos.X, self.pos.Y, self.map)
	end

	self.running = true
	while self.running do
		self.target = GetTarget(self.pos, self.possibleTargets, self.getPlayerPos)
		if self.target then
			local newPos = ChooseAction(self, self.pos, self.target, curMap.GridArray, self.model, curMap.originPosition)
			if newPos ~= self.pos then
				self.pos = newPos
				if self.onMoved then
					self.onMoved(self.enemyId, self.pos.X, self.pos.Y, self.map)
				end
			end
		end
		task.wait(self.MOVEMENT_DELAY)
	end
end

return EnemyLogic
