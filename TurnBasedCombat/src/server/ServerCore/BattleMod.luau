local Battle = {}

local function CharSort(char1,char2)
	if char1[1].Speed > char2[1].Speed then
		return true
	end
end

local function isEmpty(tabl)
	return next(tabl) == nil
end

local function GetTouchingParts(part)
	local connection = part.Touched:Connect(function() end)
	local results = part:GetTouchingParts()
	connection:Disconnect()
	return results
end

function Battle:SortTeams(_playerTeam,_enemyTeam)
	local FinalOrder = {}
	if _playerTeam or _enemyTeam then
		if _playerTeam then
			for _,v in pairs(_playerTeam) do
				table.insert(FinalOrder,{v,"Ally"})
			end	
		end
		if _enemyTeam then
			for _,v in pairs(_enemyTeam) do
				table.insert(FinalOrder,{v,"Enemy"})
			end
		end
		table.sort(FinalOrder,CharSort)
		return FinalOrder
	else
		warn("No teams to sort!")
		return nil
	end
end

function Battle:GenerateBattleModels(player,SortedTabl)
	local BattleFolder = Instance.new("Folder")
	BattleFolder.Name = player.Name
	BattleFolder.Parent = workspace.Battles
	local Anchor = player.Character.PrimaryPart.CFrame
	local CamRoot = Instance.new("Part")
	CamRoot.Name = tostring("CameraRoot")
	CamRoot.Transparency = 1
	CamRoot.Size = Vector3.new(1,1,1)
	CamRoot.Anchored = true
	CamRoot.CanCollide = false
	CamRoot.CFrame = Anchor * CFrame.new(0,0,-4)
	CamRoot.Parent = BattleFolder
	for team = 1,2 do
		if team == 1 then
			for pos = 1,4 do
				local test = Instance.new("Part")
				test.Name = tostring("Ally"..pos)
				test.Transparency = 1
				test.Size = Vector3.new(1,1,1)
				test.Anchored = true
				test.CanCollide = false
				test.CFrame = Anchor * CFrame.new(-10+(pos*4),0,4)
				test.Parent = BattleFolder
			end
		else
			for pos = 1,4 do
				local test = Instance.new("Part")
				test.Name = tostring("Enemy"..pos)
				test.Transparency = 1
				test.Size = Vector3.new(1,1,1)
				test.Anchored = true
				test.CanCollide = false
				test.CFrame = Anchor * CFrame.new(-10+(pos*4),0,-12) * CFrame.Angles(0,math.rad(180),0)
				test.Parent = BattleFolder
			end
		end
	end
	local AIndex = 0
	local EIndex = 0
	for _,v in pairs(SortedTabl) do	
		local AnchorName 
		if v[2] == "Ally" then
			AIndex += 1
			AnchorName = tostring(v[2]..AIndex)
		else
			EIndex += 1
			AnchorName = tostring(v[2]..EIndex)
		end
		local ModelAnchor = BattleFolder:FindFirstChild(AnchorName)
		local orientation,size = v[1].Model:GetBoundingBox()
		local Model = Instance.new("Part")
		Model.Name = v[1].Name
		Model.Transparency = 1
		Model.CanCollide = false
		Model.Anchored = true
		Model.Size = size
		Model.CFrame = orientation
		Model.Parent = ModelAnchor
		Model.CFrame = ModelAnchor.CFrame
		repeat
			local check = false
			for _,v in pairs(GetTouchingParts(Model)) do
				if v:FindFirstAncestor("Map") and v.CanCollide == true then
					check = true
					break
				end
			end
			if check == true then
				Model.CFrame *= CFrame.new(0,.1,0)
			end
		until check == false
		local offset = v[1].Model:FindFirstChild("Offset")
		if offset then
			Model.CFrame *= CFrame.new(offset.Value)
		end
		game.ReplicatedStorage.SharedRemotes.VisualHandle:FireAllClients("CharModel",v[1].Model,Model)	
	end
	game.ReplicatedStorage.SharedRemotes.VisualHandle:FireClient(player,"CharUi",SortedTabl,"Create")
end

return Battle
