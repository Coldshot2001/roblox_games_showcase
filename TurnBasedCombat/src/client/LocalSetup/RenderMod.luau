local Render = {}

local Connection1
local Connection2

local function setTransparency(char, value)
	for _, child in pairs(char:GetChildren()) do
		if child:IsA("BasePart") and child.Name ~= "HumanoidRootPart" then
			child.Transparency = value
		elseif child:IsA("Beam") then --will add more checks as we get more models
			child.Enabled = false
		end
	end
end

local function BattleRender(child)
	if child.Name ~= game.Players.LocalPlayer.Name then
		child.ChildAdded:Connect(function()
			for _, b in ipairs(child:GetChildren()) do
				if b:IsA("Model") then
					setTransparency(b, 1)
				end
			end
		end)
	end
end

function Render:CreatePointer(Object, Type)
	local Pointer = game.ReplicatedStorage.Assets.Models.Arrow:Clone()
	if Type == "Ally" then
		Pointer.Color = Color3.fromRGB(0, 255, 0)
		Pointer.Name = string.format("Ally%iPointer", tonumber(string.match(Object.Parent.Name, "%d$")))
	elseif Type == "Enemy" then
		Pointer.Color = Color3.fromRGB(255, 0, 0)
		Pointer.Name = string.format("Enemy%iPointer", tonumber(string.match(Object.Parent.Name, "%d$")))
	end
	if Object:IsA("Model") then
		Pointer.CFrame = Object.PrimaryPart.CFrame
	else
		Pointer.CFrame = Object.CFrame
	end
	Pointer.Orientation = Vector3.new(Pointer.Orientation.X, Pointer.Orientation.Y, -90)
	Pointer.CFrame = Pointer.CFrame * CFrame.new(-7, 0, 0)
	local tween = game:GetService("TweenService"):Create(
		Pointer,
		TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In, -1, true),
		{ CFrame = Pointer.CFrame * CFrame.new(1, 0, 0) }
	)
	Pointer.Parent = Object.Parent.Parent
	tween:Play()
end

function Render:DestroyPointers(...)
	--first argument always has to be the player and second always has to be the type
	--current types: All-destroys all pointers; Others-destroys all pointers but one; Specific-destroys a specific pointer; Ally-destroys all pointers of allies(but not enemies) ; Enemy-destroys all pointers of enemies(but not allies)
	local args = { ... }
	if typeof(args[2]) == "string" and args[1] == game.Players.LocalPlayer then
		local folder = workspace.Battles:FindFirstChild(args[1].Name)
		if args[2] == "All" then
			for _, v in ipairs(folder:GetChildren()) do
				if string.match(v.Name, "Pointer") == "Pointer" then
					v.Parent = nil
				end
			end
		elseif args[2] == "Others" then
			for _, v in ipairs(folder:GetChildren()) do
				if string.match(v.Name, "Pointer") == "Pointer" and v.Name ~= args[3] then
					v.Parent = nil
				end
			end
		elseif args[2] == "Specific" then
			for _, v in ipairs(folder:GetChildren()) do
				if string.match(v.Name, "Pointer") == "Pointer" and v.Name == args[3] then
					v.Parent = nil
				end
			end
		elseif args[2] == "Ally" then
			for _, v in ipairs(folder:GetChildren()) do
				if string.match(v.Name, "Ally") == "Ally" then
					v.Parent = nil
				end
			end
		elseif args[2] == "Enemy" then
			for _, v in ipairs(folder:GetChildren()) do
				if string.match(v.Name, "Enemy") == "Enemy" then
					v.Parent = nil
				end
			end
		else
			warn("Unhandled type given!")
		end
	else
		warn("Wrong arguments given!")
	end
end

function Render:Battles(Type)
	if Type == false then
		Connection1 = workspace.Battles.ChildAdded:Connect(BattleRender)
		Connection2 = game.Players.PlayerAdded:Connect(function(player)
			setTransparency(player.Character, 1)
		end)
		for _, a in ipairs(workspace.Battles:GetChildren()) do
			if a.Name ~= game.Players.LocalPlayer.Name then
				for _, b in ipairs(a:GetChildren()) do
					if b:IsA("Model") then
						setTransparency(b, 1)
					end
				end
			end
		end
		for _, c in ipairs(game.Players:GetPlayers()) do
			setTransparency(c.Character, 1)
		end
	elseif Type == true then
		Connection1:Disconnect()
		Connection2:Disconnect()
		for _, a in ipairs(workspace.Battles:GetChildren()) do
			if a.Name ~= game.Players.LocalPlayer.Name then
				for _, b in ipairs(a:GetChildren()) do
					if b:IsA("Model") then
						setTransparency(b, 0)
					end
				end
			end
		end
		for _, c in ipairs(game.Players:GetPlayers()) do
			setTransparency(c.Character, 0)
		end
	end
end

function Render:CreateCharModel(Model, Parent, _Offset)
	local ModelClone = Model:Clone()
	local oldppart = ModelClone.PrimaryPart
	local orientation, size = ModelClone:GetBoundingBox()
	local h = Instance.new("Part")
	h.CFrame = orientation
	h.Size = size
	h.Parent = ModelClone
	ModelClone.PrimaryPart = h
	if _Offset then
		ModelClone:SetPrimaryPartCFrame(Parent.CFrame * CFrame.new(_Offset))
	else
		ModelClone:SetPrimaryPartCFrame(Parent.CFrame)
	end
	wait()
	ModelClone.PrimaryPart = oldppart
	h.Parent = nil
	ModelClone.Parent = Parent
end

return Render
