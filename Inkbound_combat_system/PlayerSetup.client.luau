--Services
local RunService = game:GetService("RunService")
local plr = game:GetService("Players").LocalPlayer

--Constants
local CF_REALLY_FAR_AWAY = CFrame.new(0, 10e8, 0)
local VISUAL_OFFSET = 1

--References
local CombatRemote = game:GetService("ReplicatedStorage"):WaitForChild("StartCombat")
local DataRemote = game:GetService("ReplicatedStorage"):WaitForChild("SendData")

--Private Functions
local function distance(x1, y1, x2, y2)
	return math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
end

local visualBorders = {}
local nextVisualId = 0
local CombatBorder = game:GetService("ReplicatedStorage"):WaitForChild("Border")
local function CreateVisualBorder(radius, pos, color)
	local NewBorder = CombatBorder:Clone()
	NewBorder.Decal.Color3 = color
	NewBorder.Decal.Transparency = 0.3
	NewBorder.Size = Vector3.new(radius * 2 + VISUAL_OFFSET, 1, radius * 2 + VISUAL_OFFSET)
	NewBorder.Position = Vector3.new(pos.X, -0.5, pos.Z)
	nextVisualId += 1
	visualBorders[nextVisualId] = NewBorder
	NewBorder.Parent = workspace
	return nextVisualId
end

local function UpdateVisualBorder(ID, radius, pos, color)
	local CurBorder = visualBorders[ID]
	if not CurBorder then
		return
	end
	CurBorder.Size = Vector3.new(radius * 2 + VISUAL_OFFSET, 1, radius * 2 + VISUAL_OFFSET)
	CurBorder.Position = Vector3.new(pos.X, -0.5, pos.Z)
	CurBorder.Decal.Color3 = color
end

local function DestroyVisualBorder(ID)
	local CurBorder = visualBorders[ID]
	if CurBorder then
		CurBorder:Destroy()
		visualBorders[ID] = nil
	end
end

local collisionBorders = {}
local nextCollisionId = 0
local function CollisionCheck()
	local char = plr.Character or plr.CharacterAdded:Wait()
	local HRP = char:WaitForChild("HumanoidRootPart")
	local point = { x = HRP.Position.X, y = HRP.Position.Z }
	RunService:BindToRenderStep("CircleCollision", Enum.RenderPriority.Camera.Value - 1, function()
		for _, circle in pairs(collisionBorders) do
			local new_x = HRP.Position.X
			local new_y = HRP.Position.Z

			local dist = distance(new_x, new_y, circle.center.x, circle.center.y)

			if dist > circle.radius then
				local angle = math.atan2(new_y - circle.center.y, new_x - circle.center.x)
				new_x = circle.center.x + circle.radius * math.cos(angle)
				new_y = circle.center.y + circle.radius * math.sin(angle)
			end

			point.x = new_x
			point.y = new_y
			HRP.CFrame = CFrame.new(point.x, HRP.Position.Y, point.y) * HRP.CFrame.Rotation
		end
	end)
end

local function AddCollisionBorder(radius, pos)
	nextCollisionId += 1
	collisionBorders[nextCollisionId] = { center = { x = pos.X, y = pos.Z }, radius = radius }
	return nextCollisionId
end

local function RemoveCollisionBorder(ID)
	collisionBorders[ID] = nil
end

local combatPoints = {}
local CombatPart = game:GetService("ReplicatedStorage"):WaitForChild("CombatPos")
local Prompt = game:GetService("ReplicatedStorage"):WaitForChild("CombatPrompt")
local function AddCombatPoint(PointTable)
	local NewPoint = CombatPart:Clone()
	NewPoint.Position = PointTable["Position"]
	CreateVisualBorder(PointTable["Radius"], PointTable["Position"], Color3.fromRGB(170, 0, 255))
	local CombatId = #combatPoints + 1
	local NewPrompt = Prompt:Clone()
	NewPrompt.MaxActivationDistance = PointTable["Radius"] / 1.5
	NewPrompt.Triggered:Connect(function(triggeringPlayer)
		local char = triggeringPlayer.Character or triggeringPlayer.CharacterAdded:Wait()
		local HRP = char:WaitForChild("HumanoidRootPart")
		if (HRP.Position - NewPoint.Position).Magnitude <= PointTable["Radius"] / 1.5 then
			CombatRemote:FireServer(CombatId)
		end
	end)
	NewPrompt.Parent = NewPoint
	combatPoints[CombatId] =
		{ ["Part"] = NewPoint, ["Radius"] = PointTable["Radius"], ["Position"] = PointTable["Position"] }
	NewPoint.Parent = workspace
	return CombatId
end

local function CombatPointLogic()
	RunService:BindToRenderStep("CombatPointsVisual", Enum.RenderPriority.Last.Value + 2, function(deltaTime)
		for _, combatPoint in pairs(combatPoints) do
			combatPoint["Part"].CFrame = combatPoint["Part"].CFrame
				* CFrame.fromOrientation(0, math.rad(15) * deltaTime, 0)
		end
	end)
end

local PLR_DATA = nil
local PlayerGui = plr.PlayerGui
local function SetupPlayerInterfaceWithData(NEW_DATA)
	PLR_DATA = NEW_DATA
	PLR_DATA["Color"] = Color3.fromRGB(0, 170, 255)
	for Stat, Val in pairs(PLR_DATA) do
		local Stat_GUI = PlayerGui.Stats:FindFirstChild(Stat)
		if Stat_GUI then
			Stat_GUI.Text = Val
		end
	end
end

local movingBorders = {}
local nextMovingId = 0
local function CreateMovingBorder(target, color)
	local HRP = target:WaitForChild("HumanoidRootPart")

	local VisualBorderID = CreateVisualBorder(PLR_DATA["Movement"] * 3, HRP.Position, Color3.fromRGB(255, 0, 0))
	nextMovingId += 1
	local MovingBorderID = nextMovingId
	movingBorders[MovingBorderID] = {
		["VisualBorderID"] = VisualBorderID,
		["Position"] = HRP.Position,
		["Target"] = HRP,
		["Center"] = HRP.Position,
		["OriginalRadius"] = PLR_DATA["Movement"] * PLR_DATA["AP"],
		["Color"] = color,
	}
	return MovingBorderID
end

local function MovingBorderLogic()
	RunService:BindToRenderStep("MovingBorderVisual", Enum.RenderPriority.Last.Value + 3, function(_deltaTime)
		for _, circle in pairs(movingBorders) do
			circle["Position"] = circle["Target"].Position
			local distance_to_center = math.clamp(
				distance(circle["Center"].X, circle["Center"].Z, circle["Position"].X, circle["Position"].Z),
				0,
				circle["OriginalRadius"]
			)
			local new_circle_radius = math.sqrt(circle["OriginalRadius"] ^ 2 - distance_to_center ^ 2)

			UpdateVisualBorder(circle["VisualBorderID"], new_circle_radius, circle["Target"].Position, circle["Color"])
		end
	end)
end

CollisionCheck()
CombatPointLogic()
MovingBorderLogic()

local fightVisualIds = {}
local fightCollisionIds = {}
local fightMovingIds = {}

local function EndFightVisuals()
	for _, id in ipairs(fightVisualIds) do
		DestroyVisualBorder(id)
	end
	for _, id in ipairs(fightCollisionIds) do
		RemoveCollisionBorder(id)
	end
	for _, id in ipairs(fightMovingIds) do
		local moving = movingBorders[id]
		if moving then
			DestroyVisualBorder(moving["VisualBorderID"])
			movingBorders[id] = nil
		end
	end
	fightVisualIds = {}
	fightCollisionIds = {}
	fightMovingIds = {}
	if PLR_DATA then
		PlayerGui.Stats.AP.Text = tostring(PLR_DATA["AP"])
	end
end

plr.CharacterRemoving:Connect(EndFightVisuals)

CombatRemote.OnClientEvent:Connect(function(ID)
	local char = plr.Character or plr.CharacterAdded:Wait()
	local HRP = char:WaitForChild("HumanoidRootPart")

	for i = 1, PLR_DATA["AP"] do
		table.insert(
			fightVisualIds,
			CreateVisualBorder(PLR_DATA["Movement"] * i, HRP.Position, PLR_DATA["Color"])
		)
	end
	table.insert(fightCollisionIds, AddCollisionBorder(PLR_DATA["Movement"] * PLR_DATA["AP"], HRP.Position))
	table.insert(fightCollisionIds, AddCollisionBorder(combatPoints[ID]["Radius"], combatPoints[ID]["Position"]))
	table.insert(fightMovingIds, CreateMovingBorder(char, Color3.fromRGB(255, 0, 0)))

	combatPoints[ID]["Part"].CFrame = CF_REALLY_FAR_AWAY

	local circleX, circleY = HRP.Position.X, HRP.Position.Z
	while plr.Character and plr.Character.Parent do
		task.wait()
		local dist = distance(HRP.Position.X, HRP.Position.Z, circleX, circleY)
		local timesOutside = math.ceil(math.max(0, (dist - PLR_DATA["Movement"]) / PLR_DATA["Movement"]))

		if timesOutside > 0 then
			PlayerGui.Stats.AP.Text = string.format("%i - %i", PLR_DATA["AP"], timesOutside)
		else
			PlayerGui.Stats.AP.Text = string.format("%i", PLR_DATA["AP"])
		end
	end

	EndFightVisuals()
end)

DataRemote.OnClientEvent:Connect(function(mode, ...)
	local vars = { ... }
	if mode == "Data" then
		SetupPlayerInterfaceWithData(vars[1])
	elseif mode == "CombatPoints" then
		for _, point in pairs(vars[1]) do
			AddCombatPoint(point)
		end
	end
end)
