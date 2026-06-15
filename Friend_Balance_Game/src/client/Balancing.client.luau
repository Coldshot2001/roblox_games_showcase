--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Packet = require(ReplicatedStorage.Shared.Packet)
local Player = Players.LocalPlayer
local ControlModule = require(Player:WaitForChild("PlayerScripts").PlayerModule:WaitForChild("ControlModule"))

local function WorldMoveVec(camRel: Vector3): Vector3
	local _, yaw = workspace.CurrentCamera.CFrame:ToEulerAnglesYXZ()
	return CFrame.fromEulerAnglesYXZ(0, yaw, 0) * Vector3.new(camRel.X, 0, camRel.Z)
end

local heartbeatConn: RBXScriptConnection? = nil
local sessionId = 0

local DIAMOND_SIZE = 1.0
local GRAVITY_BASE = 4
local GRAVITY_POWER = 1.7
local INPUT_FORCE = 12
local DAMPING = 1.2
local MAX_TILT_DEG = 25
local SEND_HZ = 0.1
local CAM_DIST = 8
local CAM_HEIGHT = 11

Packet.StartBalance.listen(function(replica: Model)
	if heartbeatConn then
		heartbeatConn:Disconnect()
		heartbeatConn = nil
	end
	sessionId += 1
	local mySession = sessionId

	local replicaHRP = replica:WaitForChild("HumanoidRootPart") :: BasePart
	local carrierHRP = (replica:WaitForChild("CarrierHRP") :: ObjectValue).Value :: BasePart

	local Camera = workspace.CurrentCamera
	Camera.CameraType = Enum.CameraType.Scriptable

	local ancestryConn: RBXScriptConnection
	ancestryConn = replica.AncestryChanged:Connect(function()
		if replica.Parent ~= nil then
			return
		end
		ancestryConn:Disconnect()
		Camera.CameraType = Enum.CameraType.Custom
		Camera.CameraSubject = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
		if heartbeatConn then
			heartbeatConn:Disconnect()
			heartbeatConn = nil
		end
	end)

	local pos = Vector2.zero
	local initAng = math.random() * 2 * math.pi
	local vel = Vector2.new(math.cos(initAng), math.sin(initAng)) * 1.5

	local lastSend = -math.huge
	local pendingSend = false

	local function DoSend()
		lastSend = time()
		local nx = pos.X / DIAMOND_SIZE
		local ny = pos.Y / DIAMOND_SIZE
		Packet.MovementPacket.send({
			angle = Vector2.new(MAX_TILT_DEG * ny, -MAX_TILT_DEG * nx),
			normal = Vector2.new(nx, ny),
		})
	end

	heartbeatConn = RunService.Heartbeat:Connect(function(dt)
		local cLook
		do
			local lv = carrierHRP.CFrame.LookVector
			local flat = Vector3.new(lv.X, 0, lv.Z)
			cLook = flat.Magnitude > 0.05 and flat.Unit or Vector3.new(0, 0, -1)
		end
		local rPos = replicaHRP.Position
		Camera.CFrame = CFrame.new(rPos - cLook * CAM_DIST + Vector3.new(0, CAM_HEIGHT, 0), rPos)

		--project world WASD onto carrier's local right/forward.
		local wmv = WorldMoveVec(ControlModule:GetMoveVector())
		local wFlat = Vector3.new(wmv.X, 0, wmv.Z)
		local cRight = -carrierHRP.CFrame.RightVector
		local cFwd = carrierHRP.CFrame.LookVector
		local inpX = wFlat:Dot(Vector3.new(cRight.X, 0, cRight.Z)) * INPUT_FORCE
		local inpY = wFlat:Dot(Vector3.new(cFwd.X, 0, cFwd.Z)) * INPUT_FORCE

		local dist = math.sqrt(pos.X * pos.X + pos.Y * pos.Y)
		local gx, gy = 0, 0
		if dist > 1e-4 then
			local gMag = GRAVITY_BASE * dist ^ GRAVITY_POWER
			gx = pos.X / dist * gMag
			gy = pos.Y / dist * gMag
		end

		vel = vel + Vector2.new(gx + inpX, gy + inpY) * dt
		vel = vel * math.max(1 - DAMPING * dt, 0)
		local nx = pos.X + vel.X * dt
		local ny = pos.Y + vel.Y * dt

		local l1 = math.abs(nx) + math.abs(ny)
		if l1 > DIAMOND_SIZE then
			local over = l1 - DIAMOND_SIZE
			local sx = nx > 0 and 1 or (nx < 0 and -1 or 0)
			local sy = ny > 0 and 1 or (ny < 0 and -1 or 0)
			local s2 = sx * sx + sy * sy

			if s2 > 0 then
				nx = nx - over * sx / s2
				ny = ny - over * sy / s2
				local invM = 1 / math.sqrt(s2)
				local unx = sx * invM
				local uny = sy * invM
				local vn = vel.X * unx + vel.Y * uny
				if vn > 0 then
					vel = Vector2.new(vel.X - vn * unx, vel.Y - vn * uny)
				end
			end
			-- TODO: fire fell off event
		end

		pos = Vector2.new(nx, ny)

		if pendingSend then
			return
		end
		local elapsed = time() - lastSend
		if elapsed >= SEND_HZ then
			DoSend()
		else
			pendingSend = true
			task.delay(SEND_HZ - elapsed, function()
				if sessionId ~= mySession or not heartbeatConn then
					pendingSend = false
					return
				end
				pendingSend = false
				DoSend()
			end)
		end
	end)
end)
