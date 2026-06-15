local pattern = {1,2,3,4}

local function rotate90(tbl)
	local M,N = #tbl,#tbl[1]
	local new_tbl = {}

	for x=1,N do
		new_tbl[x] = {}
		for y=1,M do
			new_tbl[x][y] = tbl[(M+1)-y][x]
		end
	end

	return new_tbl 
end

local SolutionGen = {}

function SolutionGen.Generate(sizeX,sizeY)
	math.randomseed(os.clock())
	local counter1 = math.random(1,5) -- change pattern counter
	local grid = {}
	for i = 1, sizeX do
		grid[i] = {}
		counter1 = counter1 + 1
		counter1 = counter1 >= 5 and 1 or counter1
		local counter2 -- index counter
		if counter1 < 3 then
			counter2 = 1
		elseif counter1 > 2 then
			counter2 = 3
		end
		for j = 1, sizeY do
			grid[i][j] = pattern[(counter2%4)+1] --[(counter2%4)+1]
			counter2 = counter2 + 1
			--counter2 = (((counter2 - 1) % (5 - 1)) + (5 - 1)) % (5 - 1) + 1
		end
	end
	local rotation = math.random(0,3)
	if rotation > 0 then
		for _=1,rotation do
			grid = rotate90(grid)
		end
	end
	return grid
end

return SolutionGen
