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

--Class
local visualBorders = {}
local CombatBorder = game:GetService("ReplicatedStorage"):WaitForChild("Border")
local function CreateVisualBorder(radius, pos, color)
	local NewBorder = CombatBorder:Clone()
	NewBorder.Decal.Color3 = color
	NewBorder.Decal.Transparency = 0.3
	NewBorder.Size = Vector3.new(radius * 2 + VISUAL_OFFSET, 1, radius * 2 + VISUAL_OFFSET)
	NewBorder.Position = Vector3.new(pos.X, -0.5, pos.Z)
	visualBorders[#visualBorders + 1] = NewBorder
	NewBorder.Parent = workspace
	return #visualBorders
end

local function UpdateVisualBorder(ID, radius, pos, color)
	local CurBorder = visualBorders[ID]
	CurBorder.Size = Vector3.new(radius * 2 + VISUAL_OFFSET, 1, radius * 2 + VISUAL_OFFSET)
	CurBorder.Position = Vector3.new(pos.X, -0.5, pos.Z)
	CurBorder.Decal.Color3 = color
end

local collisionBorders = {}
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
	collisionBorders[#collisionBorders + 1] = { center = { x = pos.X, y = pos.Z }, radius = radius }
	return #collisionBorders
end

local function RemoveCollisionBorder(ID)
	table.remove(collisionBorders, ID)
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
	NewPrompt.Triggered:Connect(function(plr)
		local char = plr.Character or plr.CharacterAdded:Wait()
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
local function CreateMovingBorder(target, color)
	local HRP = target:WaitForChild("HumanoidRootPart")

	local VisualBorderID = CreateVisualBorder(PLR_DATA["Movement"] * 3, HRP.Position, Color3.fromRGB(255, 0, 0))
	local MovingBorderID = #movingBorders + 1
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
	RunService:BindToRenderStep("CombatPointsVisual", Enum.RenderPriority.Last.Value + 3, function(deltaTime)
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

function generateRandomPoint(largerOriginX, largerOriginY, largerRadius, smallerOriginX, smallerOriginY, smallerRadius)
	local x, y
	repeat
		-- Generate random angle and radius
		local angle = math.random() * 2 * math.pi
		local radius = math.sqrt(math.random() * largerRadius ^ 2)

		-- Convert polar coordinates to Cartesian coordinates
		x = largerOriginX + radius * math.cos(angle)
		y = largerOriginY + radius * math.sin(angle)
	until (x - smallerOriginX) ^ 2 + (y - smallerOriginY) ^ 2 > smallerRadius ^ 2

	return x, y
end

CollisionCheck()
CombatPointLogic()
MovingBorderLogic()
CombatRemote.OnClientEvent:Connect(function(ID)
	local char = plr.Character or plr.CharacterAdded:Wait()
	local HRP = char:WaitForChild("HumanoidRootPart")
	for i = 1, PLR_DATA["AP"] do
		CreateVisualBorder(PLR_DATA["Movement"] * i, HRP.Position, PLR_DATA["Color"])
	end
	local circleID1 = AddCollisionBorder(PLR_DATA["Movement"] * PLR_DATA["AP"], HRP.Position)
	local circleID2 = AddCollisionBorder(combatPoints[ID]["Radius"], combatPoints[ID]["Position"])
	CreateMovingBorder(char, Color3.fromRGB(255, 0, 0))

	--test
	local a = Instance.new("Folder")
	for i = 1, 105 do
		local b = Instance.new("Part")
		b.Parent = a
		b.Size = Vector3.new(2, 2, 2)
		b.Anchored = true
		b.Color = Color3.fromRGB(170, 0, 255)
		b.CanCollide = false
		local x, z = generateRandomPoint(
			combatPoints[ID]["Part"].Position.X,
			combatPoints[ID]["Part"].Position.Z,
			combatPoints[ID]["Radius"],
			HRP.Position.X,
			HRP.Position.Z,
			PLR_DATA["Movement"] * 1.3
		)
		b.Position = Vector3.new(x, 4, z)
	end
	a.Parent = workspace
	--
	combatPoints[ID]["Part"].CFrame = CF_REALLY_FAR_AWAY

	local circleX, circleY = HRP.Position.X, HRP.Position.Z
	while true do
		task.wait()
		local dist = distance(HRP.Position.X, HRP.Position.Z, circleX, circleY)
		local timesOutside = math.ceil(math.max(0, (dist - PLR_DATA["Movement"]) / PLR_DATA["Movement"]))

		if timesOutside > 0 then
			PlayerGui.Stats.AP.Text = string.format("%i - %i", PLR_DATA["AP"], timesOutside)
		else
			PlayerGui.Stats.AP.Text = string.format("%i", PLR_DATA["AP"])
		end
	end
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
