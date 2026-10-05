local InBattle = false
local GuiMod = require(script:WaitForChild("GuiMod"))
local ZoneMod = require(script:WaitForChild("ZoneMod"))
local RenderMod = require(script:WaitForChild("RenderMod"))
local ts = game:GetService("TweenService")
local player = game.Players.LocalPlayer

local function setTransparency(char, value)
	for _, child in pairs(char:GetChildren()) do
		if child:IsA("BasePart") and child.Name ~= "HumanoidRootPart" then
			child.Transparency = value
		end
	end
end

local function forceResetting(mode)
	local success = false
	while success == false do
		success = pcall(function()
			return game.StarterGui:SetCore("ResetButtonCallback", mode)
		end)
		if not success then
			task.wait()
		end
	end
end

function OverworldSetup()
	local data = player.Data:InvokeServer("InBattle", "Zones")
	local curzone
	if data[1][1] == false then
		for _, v in ipairs(game.Workspace.Enemies:GetChildren()) do
			if tostring(v) == data[2][1] then
				curzone = v
				break
			end
		end
		if curzone then
			for _, Mob in ipairs(curzone:GetChildren()) do
				if game.ReplicatedStorage.Assets.Models[Mob.MobData.MobName.Value] then
					local Old = Mob:FindFirstChild(game.ReplicatedStorage.Assets.Models[Mob.MobData.MobName.Value].Name)
					if Old then
						Old.Parent = nil
					end
					RenderMod:CreateCharModel(
						game.ReplicatedStorage.Assets.Models[Mob.MobData.MobName.Value],
						Mob,
						Mob.MobData.Offset.Value
					)
				end
			end
			for _, v in ipairs(game.Workspace.Enemies:GetChildren()) do
				if v ~= curzone then
					for _, Mob in ipairs(v:GetChildren()) do
						local Old =
							Mob:FindFirstChild(game.ReplicatedStorage.Assets.Models[Mob.MobData.MobName.Value].Name)
						if Old then
							Old.Parent = nil
						end
					end
				end
			end
		else
			warn("No zone to load!")
		end
	else
		warn("Cannot setup overworld in battle!")
	end
end

local ModelName
local oldspd
local oldjmp
function BattleState(_mob)
	if InBattle == true then
		player.PlayerGui.DisplaysGui.Enabled = false
		RenderMod:Battles(false)
		local model = _mob:FindFirstChildOfClass("Model")
		if model then
			ModelName = model.Name
			model.Parent = nil
		end
		local root = workspace.Battles:FindFirstChild(player.Name)
		if root then
			root = root:FindFirstChild("CameraRoot")
			if root then
				workspace.Camera.CameraSubject = root
			end
		end
		setTransparency(player.Character, 1)
	else
		player.PlayerGui.DisplaysGui.Enabled = true
		workspace.Camera.CameraSubject = player.Character.Humanoid
		setTransparency(player.Character, 0)
		--
		player.Character.Humanoid.WalkSpeed = oldspd
		player.Character.Humanoid.JumpPower = oldjmp
		--
		RenderMod:Battles(true)
		forceResetting(true)
	end
	ZoneMod:PlayMusic()
end

function Encounter()
	while InBattle == false do
		task.wait(0.2)
		for _, v in next, game.Workspace.Enemies:GetChildren() do
			for _, Mob in next, v:GetChildren() do
				if (player.Character.PrimaryPart.Position - Mob.Position).magnitude <= 5 and InBattle == false then
					forceResetting(false)
					--
					if player.Character.Humanoid.WalkSpeed ~= 0 and player.Character.Humanoid.JumpPower ~= 0 then
						oldspd = player.Character.Humanoid.WalkSpeed
						oldjmp = player.Character.Humanoid.JumpPower
					end
					player.Character.Humanoid.WalkSpeed = 0
					player.Character.Humanoid.JumpPower = 0
					--
					local fade = Instance.new("Frame")
					fade.ZIndex = 99
					fade.Size = UDim2.fromScale(1, 1)
					fade.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
					fade.BackgroundTransparency = 1
					local tween = ts:Create(
						fade,
						TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
						{ BackgroundTransparency = 0 }
					)
					fade.Parent = player.PlayerGui.BattleGui
					tween:Play()
					tween.Completed:Wait()

					local check = Mob.Combat:InvokeServer(Mob)
					InBattle = check
					BattleState(Mob)

					local fadeOutTween = ts:Create(
						fade,
						TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
						{ BackgroundTransparency = 1 }
					)
					fade.Parent = player.PlayerGui.BattleGui
					fadeOutTween:Play()
					fadeOutTween.Completed:Wait()
					fade.Parent = nil

					if InBattle == true then
						game.ReplicatedStorage.SharedRemotes.CombatHandle:FireServer("Start", ModelName)
						ModelName = nil
					end
				end
			end
		end
	end
end

for _, v in ipairs(game.Workspace.Enemies:GetChildren()) do
	for _, Mob in ipairs(v:GetChildren()) do
		Mob.Transparency = 1
	end
end

--starting up everything
ZoneMod:SetUp()
GuiMod:SetUp()

game.ReplicatedStorage.SharedRemotes.AreaHandle.OnClientEvent:Connect(function()
	OverworldSetup()
end)

game.ReplicatedStorage.SharedRemotes.VisualHandle.OnClientEvent:Connect(function(Type, ...)
	if Type == "CharUi" then
		GuiMod:CreateCharUi(...) --takes as argument the character data and his type
	elseif Type == "CharModel" then
		RenderMod:CreateCharModel(...) --takes as argument pointer to the model to create and its parent
	elseif Type == "InventoryUi" then
		GuiMod:CreateInventoryUi(...) --takes as argument the type of ui, and its data
	elseif Type == "CurrencyUi" then
		GuiMod:UpdateCurrency(...) --takes as argument type of currency and the amount
	elseif Type == "TeamUi" then
		GuiMod:UpdateTeamDisplay(...) --takes as argument the currently equipped team
	end
end)

game.ReplicatedStorage.SharedRemotes.CombatHandle.OnClientEvent:Connect(function(Type, ...)
	--There are 2 main types: Visual,Gui and they have other sub-types
	if string.match(Type, "Gui") then
		if Type == "GuiSkills" then
			GuiMod:SetupSkills(...)
		elseif Type == "GuiTurn" then
			GuiMod:DisplayCurrentTurn(...) --takes as argument name of character
		end
	-- Visual effects are not built yet.
	elseif Type == "End" then
		InBattle = false
		--
		player.Character.Humanoid.WalkSpeed = oldspd
		player.Character.Humanoid.JumpPower = oldjmp
		--
		local fade = Instance.new("Frame")
		fade.ZIndex = 99
		fade.Size = UDim2.fromScale(1, 1)
		fade.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		fade.BackgroundTransparency = 1
		local tween = ts:Create(
			fade,
			TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ BackgroundTransparency = 0 }
		)
		fade.Parent = player.PlayerGui.BattleGui
		tween:Play()
		tween.Completed:Wait()

		GuiMod:SetupSkills(nil, false)
		GuiMod:CreateCharUi(nil, "Remove")
		BattleState()
		OverworldSetup()

		local endFadeTween = ts:Create(
			fade,
			TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ BackgroundTransparency = 1 }
		)
		fade.Parent = player.PlayerGui.BattleGui
		endFadeTween:Play()
		endFadeTween.Completed:Wait()
		fade.Parent = nil

		task.wait(5)

		Encounter()
	else
		warn("Invalid type given!")
	end
end)

Encounter()
