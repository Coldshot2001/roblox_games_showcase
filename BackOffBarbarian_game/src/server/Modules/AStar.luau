--!strict

local AStar = {}

local function keyOf(node: any): string
	return string.format("%d,%d", node.x, node.y)
end

local function nodeDistance(nodeA: any, nodeB: any): number
	return AStar.distance(nodeA.x, nodeA.y, nodeB.x, nodeB.y)
end

local function lowestFScore(set: { any }, fScore: { [string]: number }): any?
	local lowest = math.huge
	local bestNode = nil
	for _, node in ipairs(set) do
		local score = fScore[keyOf(node)] or math.huge
		if score < lowest then
			lowest = score
			bestNode = node
		end
	end
	return bestNode
end

local function neighborNodes(node: any, nodes: any): { any }
	local neighbors = {}
	local x, y = node.x, node.y

	if nodes[x + 1] and nodes[x + 1][y] ~= nil then
		table.insert(neighbors, { x = x + 1, y = y })
	end
	if nodes[x - 1] and nodes[x - 1][y] ~= nil then
		table.insert(neighbors, { x = x - 1, y = y })
	end
	if nodes[x] and nodes[x][y + 1] ~= nil then
		table.insert(neighbors, { x = x, y = y + 1 })
	end
	if nodes[x] and nodes[x][y - 1] ~= nil then
		table.insert(neighbors, { x = x, y = y - 1 })
	end

	return neighbors
end

local function notIn(set: { any }, node: any): boolean
	for _, other in ipairs(set) do
		if other.x == node.x and other.y == node.y then
			return false
		end
	end
	return true
end

local function removeNode(set: { any }, node: any)
	for index, other in ipairs(set) do
		if other.x == node.x and other.y == node.y then
			set[index] = set[#set]
			set[#set] = nil
			return
		end
	end
end

local function unwindPath(flatPath: { any }, cameFrom: any, currentNode: any): { any }
	local parent = cameFrom[keyOf(currentNode)]
	if parent then
		table.insert(flatPath, 1, parent)
		return unwindPath(flatPath, cameFrom, parent)
	end
	return flatPath
end

function AStar.distance(x1: number, y1: number, x2: number, y2: number): number
	return math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
end

function AStar.path(start: any, goal: any, nodes: any): { any }?
	local closedSet = {}
	local openSet = { start }
	local cameFrom = {}
	local gScore: { [string]: number } = {}
	local fScore: { [string]: number } = {}

	gScore[keyOf(start)] = 0
	fScore[keyOf(start)] = nodeDistance(start, goal)

	while #openSet > 0 do
		local current = lowestFScore(openSet, fScore)
		if current == nil then
			break
		end

		if current.x == goal.x and current.y == goal.y then
			local path = unwindPath({}, cameFrom, goal)
			table.insert(path, goal)
			return path
		end

		removeNode(openSet, current)
		table.insert(closedSet, current)

		for _, neighbor in ipairs(neighborNodes(current, nodes)) do
			if notIn(closedSet, neighbor) then
				local tentativeG = (gScore[keyOf(current)] or math.huge) + nodeDistance(current, neighbor)
				local knownG = gScore[keyOf(neighbor)]
				if notIn(openSet, neighbor) or knownG == nil or tentativeG < knownG then
					cameFrom[keyOf(neighbor)] = current
					gScore[keyOf(neighbor)] = tentativeG
					fScore[keyOf(neighbor)] = tentativeG + nodeDistance(neighbor, goal)
					if notIn(openSet, neighbor) then
						table.insert(openSet, neighbor)
					end
				end
			end
		end
	end

	return nil -- no path
end

return AStar
