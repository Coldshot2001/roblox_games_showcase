--!strict

local Battle = {}

local MAX_MODEL_RAISE_STEPS = 50

local function charSort(entry1: any, entry2: any): boolean
	local speed1 = entry1[1].Speed or 0
	local speed2 = entry2[1].Speed or 0
	if speed1 == speed2 then
		return entry1[1].Name < entry2[1].Name
	end
	return speed1 > speed2
end

local function GetTouchingParts(part: BasePart): { BasePart }
	local connection = part.Touched:Connect(function() end)
	local results = part:GetTouchingParts()
	connection:Disconnect()
	return results
end

function Battle:SortTeams(playerTeam: any, enemyTeam: any): { any }?
	if not playerTeam and not enemyTeam then
		warn("BattleMod: no teams to sort")
		return nil
	end

	local finalOrder = {}
	if playerTeam then
		for _, character in pairs(playerTeam) do
			table.insert(finalOrder, { character, "Ally" })
		end
	end
	if enemyTeam then
		for _, character in pairs(enemyTeam) do
			table.insert(finalOrder, { character, "Enemy" })
		end
	end
	table.sort(finalOrder, charSort)
	return finalOrder
end

function Battle:GenerateBattleModels(player: Player, sortedTable: any)
	local battleFolder = Instance.new("Folder")
	battleFolder.Name = player.Name
	battleFolder.Parent = workspace.Battles

	local anchor = player.Character.PrimaryPart.CFrame

	local camRoot = Instance.new("Part")
	camRoot.Name = "CameraRoot"
	camRoot.Transparency = 1
	camRoot.Size = Vector3.new(1, 1, 1)
	camRoot.Anchored = true
	camRoot.CanCollide = false
	camRoot.CFrame = anchor * CFrame.new(0, 0, -4)
	camRoot.Parent = battleFolder

	for position = 1, 4 do
		local allySpot = Instance.new("Part")
		allySpot.Name = "Ally" .. position
		allySpot.Transparency = 1
		allySpot.Size = Vector3.new(1, 1, 1)
		allySpot.Anchored = true
		allySpot.CanCollide = false
		allySpot.CFrame = anchor * CFrame.new(-10 + position * 4, 0, 4)
		allySpot.Parent = battleFolder

		local enemySpot = Instance.new("Part")
		enemySpot.Name = "Enemy" .. position
		enemySpot.Transparency = 1
		enemySpot.Size = Vector3.new(1, 1, 1)
		enemySpot.Anchored = true
		enemySpot.CanCollide = false
		enemySpot.CFrame = anchor * CFrame.new(-10 + position * 4, 0, -12) * CFrame.Angles(0, math.rad(180), 0)
		enemySpot.Parent = battleFolder
	end

	local allyIndex = 0
	local enemyIndex = 0
	for _, entry in pairs(sortedTable) do
		local anchorName
		if entry[2] == "Ally" then
			allyIndex += 1
			anchorName = "Ally" .. allyIndex
		else
			enemyIndex += 1
			anchorName = "Enemy" .. enemyIndex
		end

		local modelAnchor = battleFolder:FindFirstChild(anchorName)
		local orientation, size = entry[1].Model:GetBoundingBox()

		local model = Instance.new("Part")
		model.Name = entry[1].Name
		model.Transparency = 1
		model.CanCollide = false
		model.Anchored = true
		model.Size = size
		model.CFrame = orientation
		model.Parent = modelAnchor
		model.CFrame = modelAnchor.CFrame

		local steps = 0
		repeat
			local stuck = false
			for _, part in pairs(GetTouchingParts(model)) do
				if part:FindFirstAncestor("Map") and part.CanCollide then
					stuck = true
					break
				end
			end
			if stuck then
				model.CFrame *= CFrame.new(0, 0.1, 0)
				steps += 1
			end
		until stuck == false or steps >= MAX_MODEL_RAISE_STEPS

		local offset = entry[1].Model:FindFirstChild("Offset")
		if offset then
			model.CFrame *= CFrame.new(offset.Value)
		end
		game.ReplicatedStorage.SharedRemotes.VisualHandle:FireAllClients("CharModel", entry[1].Model, model)
	end

	game.ReplicatedStorage.SharedRemotes.VisualHandle:FireClient(player, "CharUi", sortedTable, "Create")
end

function Battle:DestroyBattleModels(playerName: string)
	local folder = workspace.Battles:FindFirstChild(playerName)
	if folder then
		folder:Destroy()
	end
end

return Battle
