local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")

local Packet = require(ReplicatedStorage.Shared.Packet)
local Pairsys = workspace:WaitForChild("Pair Systems", 30)
local PairEvent: BindableEvent = script:WaitForChild("PairEvent", 10)

PhysicsService:RegisterCollisionGroup("Player")
PhysicsService:CollisionGroupSetCollidable("Player", "Player", false)

local function AssignCollisionGroup(char: Model)
	for _, v in char:GetDescendants() do
		if v:IsA("BasePart") then
			v.CollisionGroup = "Player"
		end
	end
end
Players.PlayerAdded:Connect(function(player)
	player.CharacterAppearanceLoaded:Connect(function(char)
		AssignCollisionGroup(char)
	end)
end)

local CLONE_HEIGHT = 3.5
local BASE_OFFSET = CFrame.new(0, CLONE_HEIGHT, 0)
local LERP_SPEED = 13

local BASE_WALKSPEED = 16
local LV_MAX_FORCE = 7000
local LV_ACCEL_RATE = 2.5

local PlrPairs = {}
local PairData = {}

local function BuildClone(sourceChar: Model, carrierHRP: BasePart): (Model, BasePart)
	sourceChar.Archivable = true
	local clone = sourceChar:Clone()
	sourceChar.Archivable = false
	clone.Name = sourceChar.Name .. "_Clone"
	clone.Parent = workspace

	for _, v in clone:GetDescendants() do
		if
			v:IsA("Script")
			or v:IsA("LocalScript")
			or v:IsA("ModuleScript")
			or v:IsA("Humanoid")
			or v:IsA("Animator")
			or v:IsA("HumanoidDescription")
			or v:IsA("BodyMover")
			or v:IsA("Constraint")
			or v:IsA("Sound")
		then
			v:Destroy()
		end
	end

	for _, v in clone:GetDescendants() do
		if v:IsA("BasePart") then
			v.Massless = true
			v.CanCollide = false
			v.Anchored = false
			v.CastShadow = false
		end
	end

	local cloneHRP = clone:FindFirstChild("HumanoidRootPart") :: BasePart

	for _, v in clone:GetDescendants() do
		if v:IsA("BasePart") and v ~= cloneHRP then
			local wc = Instance.new("WeldConstraint")
			wc.Part0 = cloneHRP
			wc.Part1 = v
			wc.Parent = cloneHRP
		end
	end
	for _, v in clone:GetDescendants() do
		if v:IsA("Motor6D") then
			v:Destroy()
		end
	end

	local ref = Instance.new("ObjectValue")
	ref.Name = "CarrierHRP"
	ref.Value = carrierHRP
	ref.Parent = clone

	return clone, cloneHRP
end

local function HideCharacter(char: Model)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.PlatformStand = true
	end
	for _, v in char:GetDescendants() do
		if v:IsA("BasePart") then
			v.Transparency = 1
			v.CanCollide = false
			v.Massless = true
			v.CastShadow = false
		end
	end
end

local function ShowCharacter(char: Model)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.PlatformStand = false
		hum.WalkSpeed = BASE_WALKSPEED
	end
	for _, v in char:GetDescendants() do
		if v:IsA("BasePart") then
			v.Transparency = 0
			v.CanCollide = true
			v.Massless = false
		end
	end
end

local function CleanupPair(carrierChar: Model)
	local data = PairData[carrierChar]
	if not data then
		return
	end

	if data.heartbeatConn then
		data.heartbeatConn:Disconnect()
	end
	for _, c in data.cleanupConns do
		c:Disconnect()
	end

	if data.clone and data.clone.Parent then
		data.clone:Destroy()
	end

	if data.lv and data.lv.Parent then
		data.lv:Destroy()
	end
	if data.lvAttach and data.lvAttach.Parent then
		data.lvAttach:Destroy()
	end

	local carrierHum = carrierChar:FindFirstChildOfClass("Humanoid")
	if carrierHum then
		carrierHum.WalkSpeed = BASE_WALKSPEED
	end

	if data.balancerChar and data.balancerChar.Parent then
		ShowCharacter(data.balancerChar)
	end

	PairData[carrierChar] = nil
end

PairEvent.Event:Connect(function(pairTable: { Model }, titleLabel: TextLabel)
	if not pairTable[1] or not pairTable[2] then
		return
	end

	local carrierChar = pairTable[1]
	local balancerChar = pairTable[2]
	local carrierHRP = carrierChar:WaitForChild("HumanoidRootPart") :: BasePart
	local carrierHum = carrierChar:WaitForChild("Humanoid") :: Humanoid

	--countdown
	for t = 5, 0, -1 do
		titleLabel.Text = tostring(t)
		task.wait(1)
	end
	titleLabel.Text = ""

	local clone, cloneHRP = BuildClone(balancerChar, carrierHRP)

	local mainWeld = Instance.new("Weld")
	mainWeld.Part0 = carrierHRP
	mainWeld.Part1 = cloneHRP
	mainWeld.C0 = BASE_OFFSET
	mainWeld.Parent = carrierHRP

	local function MakeArmIK(side: string)
		local chainRoot = carrierChar:FindFirstChild(side .. "UpperArm")
		local endEffector = carrierChar:FindFirstChild(side .. "Hand")
		local target = clone:FindFirstChild(side .. "LowerLeg")
		if not (chainRoot and endEffector and target) then
			warn("[Balancing] Missing IK parts for " .. side)
			return
		end
		local ik = Instance.new("IKControl")
		ik.Name = "IK_" .. side
		ik.Type = Enum.IKControlType.Transform
		ik.ChainRoot = chainRoot
		ik.EndEffector = endEffector
		ik.Target = target
		ik.SmoothTime = 0.05
		ik.Parent = carrierHum
	end
	MakeArmIK("Left")
	MakeArmIK("Right")

	local lvAttach = Instance.new("Attachment")
	lvAttach.Parent = carrierHRP

	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = lvAttach
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.MaxForce = 0
	lv.VectorVelocity = Vector3.zero
	lv.Parent = carrierHRP

	PairData[carrierChar] = {
		balancerChar = balancerChar,
		clone = clone,
		mainWeld = mainWeld,
		lv = lv,
		lvAttach = lvAttach,
		appliedVel = Vector3.zero,
		leanNormal = Vector2.zero,
		targetCF = BASE_OFFSET,
		heartbeatConn = nil,
		cleanupConns = {},
	}
	local data = PairData[carrierChar]

	data.heartbeatConn = RunService.Heartbeat:Connect(function(dt)
		local d = PairData[carrierChar]
		if not d then
			return
		end

		if mainWeld and mainWeld.Parent then
			mainWeld.C0 = mainWeld.C0:Lerp(d.targetCF, math.min(LERP_SPEED * dt, 1))
		end

		local nx = d.leanNormal.X
		local ny = d.leanNormal.Y
		local blend = math.min(math.abs(nx) + math.abs(ny), 1)

		--convert lean from carrier-local to world space
		local worldLean = carrierHRP.CFrame.RightVector * nx + carrierHRP.CFrame.LookVector * ny
		local leanMag = worldLean.Magnitude
		local leanDir = leanMag > 1e-4 and worldLean / leanMag or Vector3.zero

		local targetSpeed = BASE_WALKSPEED * blend ^ 0.8
		local targetVel = leanDir * targetSpeed

		d.appliedVel = d.appliedVel:Lerp(targetVel, math.min(LV_ACCEL_RATE * dt, 1))

		carrierHum.WalkSpeed = BASE_WALKSPEED * (1 - blend)

		lv.MaxForce = blend ^ 1.5 * LV_MAX_FORCE
		lv.VectorVelocity = d.appliedVel
	end)

	local cleanupConns = data.cleanupConns

	table.insert(
		cleanupConns,
		carrierHum.Died:Connect(function()
			CleanupPair(carrierChar)
		end)
	)

	local balancerHum = balancerChar:FindFirstChildOfClass("Humanoid")
	if balancerHum then
		table.insert(
			cleanupConns,
			balancerHum.Died:Connect(function()
				CleanupPair(carrierChar)
			end)
		)
	end

	HideCharacter(balancerChar)
	balancerChar.HumanoidRootPart.Anchored = false
	carrierHRP.Anchored = false
	carrierHRP:PivotTo(CFrame.new(0, 10, 0))

	local balancerPlayer = Players:GetPlayerFromCharacter(balancerChar)
	if balancerPlayer then
		Packet.StartBalance.sendTo(clone, balancerPlayer)
	end
end)

Packet.MovementPacket.listen(function(data, player)
	local balancerChar = player.Character
	if not balancerChar then
		return
	end

	local carrierChar = nil
	for carrier, rdata in PairData do
		if rdata.balancerChar == balancerChar then
			carrierChar = carrier
			break
		end
	end
	if not carrierChar then
		return
	end

	local d = PairData[carrierChar]
	if not d then
		return
	end

	d.leanNormal = data.normal
	d.targetCF = BASE_OFFSET * CFrame.fromOrientation(math.rad(data.angle.X), 0, math.rad(data.angle.Y))
end)

Players.PlayerRemoving:Connect(function(player)
	local char = player.Character
	if not char then
		return
	end
	if PairData[char] then
		CleanupPair(char)
		return
	end
	for carrier, rdata in PairData do
		if rdata.balancerChar == char then
			CleanupPair(carrier)
			break
		end
	end
end)

local function HandleTouch(pairTable, slot, sensorPart, touchedPart, titleLabel)
	if pairTable[slot] ~= nil then
		return
	end
	local plr = Players:GetPlayerFromCharacter(touchedPart.Parent)
	if not plr or not plr.Character then
		return
	end
	local char = plr.Character
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if touchedPart ~= hrp then
		return
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return
	end
	pairTable[slot] = char
	hrp.Anchored = true
	hrp.CFrame = sensorPart.CFrame
	PairEvent:Fire(pairTable, titleLabel)
end

for _, pairModel in Pairsys:GetChildren() do
	table.insert(PlrPairs, {})
	local curPair = PlrPairs[#PlrPairs]
	local p1Part = pairModel:WaitForChild("Player1", 30) :: BasePart
	local p2Part = pairModel:WaitForChild("Player2", 30) :: BasePart
	local title =
		pairModel:WaitForChild("Title", 30):WaitForChild("SurfaceGui", 10):WaitForChild("TextLabel", 10) :: TextLabel
	title.Text = ""

	p1Part.Touched:Connect(function(o)
		HandleTouch(curPair, 1, p1Part, o, title)
	end)
	p2Part.Touched:Connect(function(o)
		HandleTouch(curPair, 2, p2Part, o, title)
	end)
end
