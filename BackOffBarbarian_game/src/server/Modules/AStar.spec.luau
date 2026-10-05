--!strict

return function()
	local AStar = require(script.Parent.AStar)

	local function makeOpenGrid(width: number, height: number): any
		local grid = {}
		for x = 1, width do
			grid[x] = {}
			for y = 1, height do
				grid[x][y] = { Position = 0 }
			end
		end
		return grid
	end

	describe("distance", function()
		it("measures a straight line", function()
			expect(AStar.distance(0, 0, 3, 4)).to.equal(5)
		end)
	end)

	describe("path", function()
		it("finds the goal on an open grid", function()
			local grid = makeOpenGrid(5, 5)
			local path = AStar.path({ x = 1, y = 1 }, { x = 5, y = 5 }, grid)
			expect(path).never.to.equal(nil)
			expect(path[1].x).to.equal(1)
			expect(path[1].y).to.equal(1)
			expect(path[#path].x).to.equal(5)
			expect(path[#path].y).to.equal(5)
		end)

		it("takes the short way around a wall", function()
			local grid = makeOpenGrid(5, 5)
			grid[2][1] = nil
			grid[2][2] = nil
			grid[2][3] = nil
			local path = AStar.path({ x = 1, y = 2 }, { x = 3, y = 2 }, grid)
			expect(path).never.to.equal(nil)
			expect(#path).to.equal(7)
		end)

		it("returns nil when the goal is walled off", function()
			local grid = makeOpenGrid(5, 5)
			grid[2][1] = nil
			grid[2][2] = nil
			grid[2][3] = nil
			grid[2][4] = nil
			grid[2][5] = nil
			local path = AStar.path({ x = 1, y = 2 }, { x = 5, y = 2 }, grid)
			expect(path).to.equal(nil)
		end)

		it("returns a one node path when the start is the goal", function()
			local grid = makeOpenGrid(3, 3)
			local path = AStar.path({ x = 2, y = 2 }, { x = 2, y = 2 }, grid)
			expect(path).never.to.equal(nil)
			expect(#path).to.equal(1)
		end)
	end)
end
