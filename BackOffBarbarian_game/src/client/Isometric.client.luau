local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

local FOV = 15
local OFFSET_X = 30
local OFFSET_Y = 110
local OFFSET_Z = 160
local LERP_SPEED = 0.15

local function bindCamera()
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = FOV

	RunService:BindToRenderStep("Isometric", Enum.RenderPriority.Camera.Value + 1, function()
		local chr = LocalPlayer.Character
		if chr == nil then return end

		local hrp = chr:FindFirstChild("HumanoidRootPart")
		local head = chr:FindFirstChild("Head")
		local torso = chr:FindFirstChild("Torso") or chr:FindFirstChild("UpperTorso")
		if hrp == nil or head == nil then return end

		if torso then
			SoundService:SetListener(Enum.ListenerType.ObjectPosition, torso)
		end

		local targetPos = Vector3.new(hrp.Position.X + OFFSET_X, hrp.Position.Y + OFFSET_Y, hrp.Position.Z + OFFSET_Z)
		camera.CFrame = camera.CFrame:Lerp(CFrame.new(targetPos, head.Position), LERP_SPEED)
	end)
end

camera:GetPropertyChangedSignal("CameraType"):Connect(function()
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end
end)

bindCamera()