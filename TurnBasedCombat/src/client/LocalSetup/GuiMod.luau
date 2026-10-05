local Gui = {}
local player = game.Players.LocalPlayer
local RenderMod = require(script.Parent:WaitForChild("RenderMod"))
local ts = game:GetService("TweenService")
local CurSkill = nil
local CurSelection = nil
local AllyDebounce = true
local EnemyDebounce = true

local RarityColor = {
	Common = Color3.fromRGB(221, 221, 221),
	Uncommon = Color3.fromRGB(0, 216, 0),
	Rare = Color3.fromRGB(0, 170, 255),
	Super = Color3.fromRGB(234, 78, 234),
	Legendary = Color3.fromRGB(255, 215, 0),
}

local function shallowCopy(original)
	return table.clone(original)
end

local function PointInPart(point, part)
	point = part.CFrame:pointToObjectSpace(point)
	return math.abs(point.X) <= part.Size.X / 2
		and math.abs(point.Y) <= part.Size.Y / 2
		and math.abs(point.Z) <= part.Size.Z / 2
end

local function DisplayUnit(model)
	local Frame = player.PlayerGui.DisplaysGui.Inventory.UnitInfo.UnitDisplay.Frame
	local oldmodel = Frame:FindFirstChildOfClass("Model")
	if oldmodel then
		oldmodel.Parent = nil
		Frame:FindFirstChildOfClass("Camera").Parent = nil
	end
	Frame.CurrentCamera = nil
	local Model = model:Clone()
	Model.Parent = Frame
	local viewportCamera = Instance.new("Camera")
	Frame.CurrentCamera = viewportCamera
	viewportCamera.Parent = Frame
	local orientation, size = Model:GetBoundingBox()
	local part = Instance.new("Part")
	part.Transparency = 1
	part.Anchored = true
	part.Size = size
	part.CFrame = orientation
	part.Parent = Frame
	viewportCamera.CFrame = orientation
	repeat
		local cameraInPart = PointInPart(viewportCamera.CFrame.Position, part)
		if cameraInPart == true then
			viewportCamera.CFrame *= CFrame.new(0, 0, 1)
		end
	until cameraInPart == false
	viewportCamera.CFrame *= CFrame.new(0, 0, 2.5)
	part.Parent = nil
	while Model.Parent ~= nil do
		Model:SetPrimaryPartCFrame(Model.PrimaryPart.CFrame * CFrame.fromEulerAnglesXYZ(0, -0.015, 0))
		task.wait()
	end
end

local AllyConnections = {}
local EnemyConnections = {}
local function ButtonsDebounce(Type, Debounce)
	local TargetsUi = player.PlayerGui:WaitForChild("BattleGui").Targets
	if Type == "Ally" then
		AllyDebounce = Debounce
		if Debounce == false then
			for _, v in ipairs(TargetsUi.Allies:GetChildren()) do
				if not v:IsA("UIGridLayout") then
					v.Active = true
					for _, connection in pairs(AllyConnections) do
						connection:Disconnect()
					end
					v.AutoButtonColor = true
					v.TextColor3 = Color3.fromRGB(255, 255, 255)
					v.Darken.Visible = false
				end
			end
		else
			for _, v in ipairs(TargetsUi.Allies:GetChildren()) do
				if not v:IsA("UIGridLayout") then
					v.Active = false
					v.AutoButtonColor = false
					local connection
					connection = v:GetPropertyChangedSignal("AutoButtonColor"):Connect(function()
						v.AutoButtonColor = false
					end)
					table.insert(AllyConnections, connection)
					v.TextColor3 = Color3.fromRGB(255, 255, 255)
					v.Darken.Visible = true
				end
			end
		end
	elseif Type == "Enemy" then
		EnemyDebounce = Debounce
		if Debounce == false then
			for _, v in ipairs(TargetsUi.Enemies:GetChildren()) do
				if not v:IsA("UIGridLayout") then
					v.Active = true
					for _, connection in pairs(EnemyConnections) do
						connection:Disconnect()
					end
					v.AutoButtonColor = true
					v.TextColor3 = Color3.fromRGB(255, 255, 255)
					v.Darken.Visible = false
				end
			end
		else
			for _, v in ipairs(TargetsUi.Enemies:GetChildren()) do
				if not v:IsA("UIGridLayout") then
					v.Active = false
					v.AutoButtonColor = false
					local connection
					connection = v:GetPropertyChangedSignal("AutoButtonColor"):Connect(function()
						v.AutoButtonColor = false
					end)
					table.insert(EnemyConnections, connection)
					v.TextColor3 = Color3.fromRGB(255, 255, 255)
					v.Darken.Visible = true
				end
			end
		end
	end
end

local CharStats = {}
local function buttonlogic(Index, targetButton, buttondebounce)
	local Char = CharStats[Index]
	local TargetsUi = player.PlayerGui:WaitForChild("BattleGui").Targets
	local charinfo = TargetsUi.CharacterInfo
	if CurSelection ~= Char then
		charinfo.CharName.Text = string.format("%s - LVL %i", Char[1].Name, Char[1].Level)
		charinfo.HealthBarBG.HealthAmount.Text = string.format("%i/%i", Char[1]["Current Health"], Char[1].Health)
		charinfo.HealthBarBG.HealthBar.Size = UDim2.fromScale(Char[1]["Current Health"] / Char[1].Health, 1)
		charinfo.HealthBarBG.HealthBar.BackgroundColor3 =
			Color3.fromRGB(214, 0, 0):lerp(Color3.fromRGB(0, 170, 0), Char[1]["Current Health"] / Char[1].Health)
		if charinfo.Position ~= UDim2.fromScale(-0.01, 0.32) then
			local tween = ts:Create(
				charinfo,
				TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Position = UDim2.fromScale(-0.01, 0.32) }
			)
			tween:Play()
		end
	end
	if buttondebounce == false then
		if CurSelection ~= Char then
			CurSelection = Char
			for _, v in ipairs(TargetsUi.Allies:GetChildren()) do
				if not v:IsA("UIGridLayout") and v ~= targetButton then
					v.TextColor3 = Color3.fromRGB(255, 255, 255)
				end
			end
			for _, v in ipairs(TargetsUi.Enemies:GetChildren()) do
				if not v:IsA("UIGridLayout") and v ~= targetButton then
					v.TextColor3 = Color3.fromRGB(255, 255, 255)
				end
			end
			targetButton.TextColor3 = Char[2] == "Ally" and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
		else
			game.ReplicatedStorage.SharedRemotes.CombatHandle:FireServer(CurSkill, Char[1].Name, Index)
			ButtonsDebounce("Ally", true)
			ButtonsDebounce("Enemy", true)
			CurSelection = nil
			CurSkill = nil
			RenderMod:DestroyPointers(player, "All")
			local tween = ts:Create(
				charinfo,
				TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Position = UDim2.fromScale(-0.21, 0.32) }
			)
			tween:Play()
		end
	else
		for _, v in ipairs(TargetsUi.Allies:GetChildren()) do
			if not v:IsA("UIGridLayout") and v ~= targetButton then
				v.TextColor3 = Color3.fromRGB(255, 255, 255)
			end
		end
		for _, v in ipairs(TargetsUi.Enemies:GetChildren()) do
			if not v:IsA("UIGridLayout") and v ~= targetButton then
				v.TextColor3 = Color3.fromRGB(255, 255, 255)
			end
		end
		CurSelection = nil
	end
end

local function HandleSkillType(Type)
	RenderMod:DestroyPointers(player, "All")
	local Chars = player.Data:InvokeServer("InBattle")
	Chars = Chars[1][2]
	local checked = {}
	if Type == "Attack" then
		ButtonsDebounce("Ally", true)
		ButtonsDebounce("Enemy", false)
		for _, charName in pairs(Chars["Enemies"]) do
			local model
			for i = 1, #Chars["Enemies"], 1 do
				if not table.find(checked, i) then
					model = workspace.Battles[player.Name]["Enemy" .. i]:FindFirstChild(charName)
					if model then
						table.insert(checked, i)
						break
					end
				end
			end
			if model then
				RenderMod:CreatePointer(model, "Enemy")
			end
		end
	elseif Type == "Support" then
		ButtonsDebounce("Ally", false)
		ButtonsDebounce("Enemy", true)
		for _, charName in pairs(Chars["Allies"]) do
			local model
			for i = 1, #Chars["Allies"], 1 do
				if not table.find(checked, i) then
					model = workspace.Battles[player.Name]["Ally" .. i]:FindFirstChild(charName)
					if model then
						table.insert(checked, i)
						break
					end
				end
			end
			if model then
				RenderMod:CreatePointer(model, "Ally")
			end
		end
	elseif Type == "Passive" then
		ButtonsDebounce("Ally", true)
		ButtonsDebounce("Enemy", true)
	end
end

function Gui:SetupSkills(SkillTable, Debounce)
	local MovesGui = player.PlayerGui.BattleGui.MovesGui
	if Debounce == true then
		local tween = ts:Create(
			MovesGui.Parent.Forfeit,
			TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
			{ Position = UDim2.fromScale(0.09, 0.22) }
		)
		tween:Play()
		MovesGui.DescriptionBG.Description.SkillName.Text = ""
		MovesGui.DescriptionBG.Description.SkillDescription.Text = ""
		MovesGui.DescriptionBG.Description.SkillCD.Text = ""
		for _, v in ipairs(MovesGui.SkillList:GetChildren()) do
			if not v:IsA("UIGridLayout") then
				v.Parent = nil
			end
		end
		for i, v in pairs(SkillTable) do
			local temp = MovesGui.SkillTemplate:Clone()
			if v["CurCD"] ~= 0 then
				temp.Darken.Visible = true
			end
			temp.SkillImage.MouseButton1Click:Connect(function()
				for _, skillButton in ipairs(MovesGui.SkillList:GetChildren()) do
					if not skillButton:IsA("UIGridLayout") and skillButton ~= temp then
						skillButton.BackgroundColor3 = Color3.fromRGB(132, 108, 0)
					end
				end
				if v["CurCD"] == 0 then
					temp.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
					CurSkill = i
					HandleSkillType(v["Type"])
				else
					HandleSkillType("Passive")
				end
				CurSelection = nil
			end)
			temp.SkillImage.MouseEnter:Connect(function()
				MovesGui.DescriptionBG.Description.SkillName.Text = tostring(v["Name"])
				MovesGui.DescriptionBG.Description.SkillDescription.Text = v["Description"]
				if v["Type"] == "Passive" then
					MovesGui.DescriptionBG.Description.Hourglass.Visible = false
					MovesGui.DescriptionBG.Description.SkillCD.Text = ""
				else
					MovesGui.DescriptionBG.Description.Hourglass.Visible = true
					MovesGui.DescriptionBG.Description.SkillCD.Text = string.format("%i/%i", v["CurCD"], v["BaseCD"])
				end
				local hoverTween = ts:Create(
					MovesGui.DescriptionBG,
					TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
					{ Size = UDim2.fromScale(0.789, 1.232), Position = UDim2.fromScale(0.098, -1.137) }
				)
				hoverTween:Play()
			end)
			temp.SkillImage.MouseLeave:Connect(function()
				MovesGui.DescriptionBG.Description.SkillName.Text = ""
				MovesGui.DescriptionBG.Description.SkillDescription.Text = ""
				MovesGui.DescriptionBG.Description.Hourglass.Visible = false
				MovesGui.DescriptionBG.Description.SkillCD.Text = ""
				local leaveTween = ts:Create(
					MovesGui.DescriptionBG,
					TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
					{ Size = UDim2.fromScale(0.789, 0), Position = UDim2.fromScale(0.098, 0.107) }
				)
				leaveTween:Play()
			end)

			temp.Parent = MovesGui.SkillList
			temp.Visible = true
		end
		if MovesGui.Position ~= UDim2.fromScale(0.696, 0.78) then
			local positionTween = ts:Create(
				MovesGui,
				TweenInfo.new(1, Enum.EasingStyle.Back, Enum.EasingDirection.InOut),
				{ Position = UDim2.fromScale(0.696, 0.78) }
			)
			positionTween:Play()
			positionTween.Completed:Wait()
		end
	else
		MovesGui.DescriptionBG.Description.SkillName.Text = ""
		MovesGui.DescriptionBG.Description.SkillDescription.Text = ""
		MovesGui.DescriptionBG.Description.SkillCD.Text = ""
		local forfeitTween = ts:Create(
			MovesGui.Parent.Forfeit,
			TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
			{ Position = UDim2.fromScale(-0.1, 0.22) }
		)
		forfeitTween:Play()

		local closeTween = ts:Create(
			player.PlayerGui.BattleGui.MovesGui,
			TweenInfo.new(1, Enum.EasingStyle.Back, Enum.EasingDirection.InOut),
			{ Position = UDim2.fromScale(1.1, 0.78) }
		)
		closeTween:Play()
		closeTween.Completed:Wait()
		for _, v in ipairs(MovesGui.SkillList:GetChildren()) do
			if not v:IsA("UIGridLayout") then
				v.Parent = nil
			end
		end
	end
end

function Gui:DisplayCurrentTurn(Char)
	local OrderGui = player.PlayerGui.BattleGui.Order
	for _, v in ipairs(OrderGui:GetChildren()) do
		if not v:IsA("UIGridLayout") then
			v.ImageColor3 = Color3.fromRGB(35, 35, 35)
		end
	end
	local CharUi = OrderGui:FindFirstChild(Char)
	if CharUi then
		CharUi.ImageColor3 = Color3.fromRGB(170, 170, 0)
	end
end

function Gui:CreateCharUi(Chars, Type, _Specific)
	local TargetsUi = player.PlayerGui:WaitForChild("BattleGui").Targets
	if Type == "Create" then
		CharStats = shallowCopy(Chars)
		player.PlayerGui.BattleGui.Order.Visible = true
		for Index, Char in pairs(Chars) do
			local targetButton = TargetsUi.TargetExample:Clone()
			targetButton.Name = string.format("%s%i", Char[1].Name, Index)
			targetButton.Text = Char[1].Name
			targetButton.Parent = Char[2] == "Ally" and TargetsUi.Allies or TargetsUi.Enemies
			targetButton.HealthBarBG.Position = targetButton.Parent == TargetsUi.Allies and UDim2.fromScale(0.5, -0.1)
				or targetButton.HealthBarBG.Position
			targetButton.HealthBarBG.HealthBar.Size = UDim2.fromScale(Char[1]["Current Health"] / Char[1].Health, 1)
			targetButton.HealthBarBG.HealthBar.BackgroundColor3 =
				Color3.fromRGB(214, 0, 0):lerp(Color3.fromRGB(0, 170, 0), Char[1]["Current Health"] / Char[1].Health)
			targetButton.Visible = true
			if Char[2] == "Ally" then
				targetButton.MouseButton1Click:Connect(function()
					buttonlogic(Index, targetButton, AllyDebounce)
				end)
			else
				targetButton.MouseButton1Click:Connect(function()
					buttonlogic(Index, targetButton, EnemyDebounce)
				end)
			end

			local OrderImage = player.PlayerGui.BattleGui.OrderExample:Clone()
			OrderImage.UnitDisplay.Image = Char[1].Portrait
			OrderImage.Name = string.format("%i%s", Index, Char[1].Name)
			OrderImage.Parent = player.PlayerGui.BattleGui.Order
			OrderImage.Visible = true
		end
		ButtonsDebounce("Ally", true)
		ButtonsDebounce("Enemy", true)
	elseif Type == "Update" then
		CharStats[_Specific[2]] = { _Specific[3], _Specific[1] }
		local charButton = TargetsUi.Allies:FindFirstChild(string.format("%s%i", _Specific[3].Name, _Specific[2]))
		if charButton == nil then
			charButton = TargetsUi.Enemies:FindFirstChild(string.format("%s%i", _Specific[3].Name, _Specific[2]))
		end
		if charButton then
			local tween = ts:Create(
				charButton.HealthBarBG.HealthBar,
				TweenInfo.new(1, Enum.EasingStyle.Bounce, Enum.EasingDirection.InOut),
				{
					Size = UDim2.fromScale(_Specific[3]["Current Health"] / _Specific[3].Health, 1),
					BackgroundColor3 = Color3.fromRGB(214, 0, 0):lerp(
						Color3.fromRGB(0, 170, 0),
						_Specific[3]["Current Health"] / _Specific[3].Health
					),
				}
			)
			tween:Play()
			tween.Completed:Wait()
		end
		if _Specific[3]["Current Health"] <= 0 then
			RenderMod:DestroyPointers(player, "Specific", string.format("%s%iPointer", _Specific[1], _Specific[2]))
			player.PlayerGui.BattleGui.Order[string.format("%i%s", _Specific[2], _Specific[3].Name)].Parent = nil

			local deadButton = TargetsUi.Allies:FindFirstChild(string.format("%s%i", _Specific[3].Name, _Specific[2]))
			if deadButton == nil then
				deadButton = TargetsUi.Enemies:FindFirstChild(string.format("%s%i", _Specific[3].Name, _Specific[2]))
			end
			if deadButton then
				deadButton.Parent = nil
			end
			CharStats[_Specific[2]] = nil
		end
	elseif Type == "Remove" then
		CharStats = {}
		player.PlayerGui.BattleGui.Order.Visible = false
		for _, v in ipairs(player.PlayerGui.BattleGui.Order:GetChildren()) do
			if not v:IsA("UIGridLayout") then
				v.Parent = nil
			end
		end
		for _, v in ipairs(TargetsUi.Allies:GetChildren()) do
			if not v:IsA("UIGridLayout") then
				v.Parent = nil
			end
		end
		for _, v in ipairs(TargetsUi.Enemies:GetChildren()) do
			if not v:IsA("UIGridLayout") then
				v.Parent = nil
			end
		end
		local tween = ts:Create(
			TargetsUi.CharacterInfo,
			TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = UDim2.fromScale(-0.21, 0.209) }
		)
		tween:Play()
		tween.Completed:Wait()
		TargetsUi.CharacterInfo.Visible = false
	end
end

function Gui:UpdateCurrency(Type, Amount)
	local Currencies = player.PlayerGui.DisplaysGui.Currencies
	if Amount ~= 0 then
		if Type == "Gold" then
			for i = 0, Amount, math.ceil(Amount / 12) do
				Currencies.Gold.Text = string.format("%i G", i)
				task.wait()
			end
			Currencies.Gold.Text = tostring(Amount .. " G")
		elseif Type == "Crystal" then
			for i = 0, Amount, math.ceil(Amount / 12) do
				Currencies.Crystal.Text = string.format("%i C", i)
				task.wait()
			end
			Currencies.Crystal.Text = tostring(Amount .. " C")
		end
	else
		if Type == "Gold" then
			Currencies.Gold.Text = tostring(Amount .. " G")
		elseif Type == "Crystal" then
			Currencies.Crystal.Text = tostring(Amount .. " C")
		end
	end
end

local EquipConnection
local EquipDebounce = false
function Gui:CreateInventoryUi(Type, Table)
	local InventoryUi = player.PlayerGui.DisplaysGui.Inventory
	if Type == "Unit" then
		for _, v in ipairs(InventoryUi.Units.Frame:GetChildren()) do
			if not v:IsA("UIGridLayout") then
				v.Parent = nil
			end
		end
		for Index, Unit in pairs(Table) do
			local unitUi = InventoryUi.UnitTemplate:Clone()
			unitUi.Image = Unit.Portrait
			unitUi.Outline.ImageColor3 = RarityColor[Unit.Rarity]
			unitUi.Name = string.format("%i%s", Index, Unit.Name)
			unitUi.Parent = InventoryUi.Units.Frame
			unitUi.Visible = true
			unitUi.MouseButton1Click:Connect(function()
				if EquipConnection then
					EquipConnection:Disconnect()
				end
				InventoryUi.UnitInfo.InfoDisplay.Text = Unit.Description
				InventoryUi.UnitInfo.SkillsDisplay.Text = ""
				for i, v in pairs(Unit.Skills) do
					InventoryUi.UnitInfo.SkillsDisplay.Text = InventoryUi.UnitInfo.SkillsDisplay.Text
						.. string.format(
							"\n %i. %s(%s) - %s , %i Turns Cooldown \n",
							i,
							v.Name,
							v.Type,
							v.Description,
							v.BaseCD
						)
				end
				--stats display
				InventoryUi.UnitInfo.StatsDisplay.Text = Unit.Name .. " \n"
				InventoryUi.UnitInfo.StatsDisplay.Text = InventoryUi.UnitInfo.StatsDisplay.Text
					.. "Health - "
					.. Unit.Health
					.. " \n"
				InventoryUi.UnitInfo.StatsDisplay.Text = InventoryUi.UnitInfo.StatsDisplay.Text
					.. "Speed - "
					.. Unit.Speed
					.. " \n"
				InventoryUi.UnitInfo.StatsDisplay.Text = InventoryUi.UnitInfo.StatsDisplay.Text
					.. "Defense - "
					.. Unit.Defense
					.. " \n"
				InventoryUi.UnitInfo.StatsDisplay.Text = InventoryUi.UnitInfo.StatsDisplay.Text
					.. "Attack - "
					.. Unit.Attack
					.. " \n"
				InventoryUi.UnitInfo.StatsDisplay.Text = InventoryUi.UnitInfo.StatsDisplay.Text
					.. "Critical Chance - "
					.. Unit["Critical Chance"]
					.. "% \n"
				InventoryUi.UnitInfo.StatsDisplay.Text = InventoryUi.UnitInfo.StatsDisplay.Text
					.. "Level - "
					.. Unit.Level
					.. " \n"
				InventoryUi.UnitInfo.StatsDisplay.Text = InventoryUi.UnitInfo.StatsDisplay.Text
					.. "EXP - "
					.. Unit["Current EXP"]
					.. "/"
					.. Unit.EXP
					.. " \n"
				InventoryUi.UnitInfo.StatsDisplay.Text = InventoryUi.UnitInfo.StatsDisplay.Text
					.. "Rarity - "
					.. Unit.Rarity
					.. " \n"
				local isLimited = Unit.Limited == true and "Yes" or "No"
				InventoryUi.UnitInfo.StatsDisplay.Text = InventoryUi.UnitInfo.StatsDisplay.Text
					.. "Limited - "
					.. isLimited
					.. " \n"
				--
				InventoryUi.UnitInfo.Equip.Visible = true
				InventoryUi.UnitInfo.Equip.Text = "Equip"
				EquipConnection = InventoryUi.UnitInfo.Equip.MouseButton1Click:Connect(function()
					if EquipDebounce == false then
						EquipDebounce = true
						if InventoryUi.UnitInfo.Equip.Text == "Equip" then
							InventoryUi.UnitInfo.Equip.Text = "Unequip"
							game.ReplicatedStorage.SharedRemotes.UnitHandle:FireServer("UnitEquip", Unit.Name, Index)
						else
							InventoryUi.UnitInfo.Equip.Text = "Equip"
							game.ReplicatedStorage.SharedRemotes.UnitHandle:FireServer("UnitUnequip", Unit.Name, Index)
						end
						task.wait(0.5)
						EquipDebounce = false
					end
				end)
				--display equipment
				DisplayUnit(Unit.Model)
			end)
			local UnitInfo = player.PlayerGui.DisplaysGui.InventoryUnitInfo
			unitUi.MouseEnter:Connect(function()
				UnitInfo.Info.Text = string.format(
					'Lv. %i - <font color="rgb(%i,%i,%i)">%s</font>',
					Unit.Level,
					math.floor(RarityColor[Unit.Rarity].R * 255),
					math.floor(RarityColor[Unit.Rarity].G * 255),
					math.floor(RarityColor[Unit.Rarity].B * 255),
					Unit.Rarity
				)
				UnitInfo.UnitName.Text = Unit.Name
				UnitInfo.Visible = true
			end)
			unitUi.MouseLeave:Connect(function()
				UnitInfo.Visible = false
				UnitInfo.Info.Text = ""
				UnitInfo.UnitName.Text = ""
			end)
		end
	elseif Type == "Equipment" then
		for _, v in ipairs(InventoryUi.Equipment.Frame:GetChildren()) do
			if not v:IsA("UIGridLayout") then
				v.Parent = nil
			end
		end
		--to be made
	end
end

function Gui:UpdateTeamDisplay(Table)
	local TeamUi = player.PlayerGui.DisplaysGui.CurrentTeam.Units
	for Index = 1, 4, 1 do
		local unit = TeamUi:FindFirstChild(string.format("%iUnit", Index))
		if Table[Index] then
			unit.Image = Table[Index].Portrait
		else
			unit.Image = ""
		end
	end
end

function Gui:SetUp()
	local oldspd
	local oldjmp

	do
		local clicked = false
		local debounce = false
		local forfeit = player.PlayerGui.BattleGui.Forfeit
		forfeit.MouseButton1Click:Connect(function()
			if debounce == false then
				if clicked == true then
					debounce = true
					clicked = false
					game.ReplicatedStorage.SharedRemotes.CombatHandle:FireServer("Forefit")
					forfeit.Text = "Forfeit"
					forfeit.AutoButtonColor = false
					task.wait(4)
					debounce = false
					forfeit.AutoButtonColor = true
				else
					clicked = true
					forfeit.Text = "Are you sure you want to forfeit the battle?"
					coroutine.wrap(function()
						task.wait(4)
						clicked = false
						forfeit.Text = "Forfeit"
					end)()
				end
			end
		end)
	end

	do
		local db3 = false
		local Tab = player.PlayerGui.DisplaysGui.Tab.Buttons
		local Inventory = player.PlayerGui.DisplaysGui.Inventory
		Tab.Inventory.MouseButton1Click:Connect(function()
			player.PlayerGui.DisplaysGui.InventoryUnitInfo.LocalScript.Disabled = Inventory.Visible
			Inventory.Visible = not Inventory.Visible
		end)
		Inventory.UnitsB.MouseButton1Click:Connect(function()
			Inventory.UnitsB.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
			Inventory.EquipmentB.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
			Inventory.Equipment.Visible = false
			Inventory.Units.Visible = true
		end)
		Inventory.EquipmentB.MouseButton1Click:Connect(function()
			Inventory.UnitsB.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
			Inventory.EquipmentB.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
			Inventory.Equipment.Visible = true
			Inventory.Units.Visible = false
		end)
		Inventory.UnitInfo.Info.MouseButton1Click:Connect(function()
			Inventory.UnitInfo.Info.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
			Inventory.UnitInfo.Skills.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
			Inventory.UnitInfo.Stats.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
			Inventory.UnitInfo.InfoDisplay.Visible = true
			Inventory.UnitInfo.SkillsDisplay.Visible = false
			Inventory.UnitInfo.StatsDisplay.Visible = false
		end)
		Inventory.UnitInfo.Skills.MouseButton1Click:Connect(function()
			Inventory.UnitInfo.Info.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
			Inventory.UnitInfo.Skills.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
			Inventory.UnitInfo.Stats.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
			Inventory.UnitInfo.InfoDisplay.Visible = false
			Inventory.UnitInfo.SkillsDisplay.Visible = true
			Inventory.UnitInfo.StatsDisplay.Visible = false
		end)
		Inventory.UnitInfo.Stats.MouseButton1Click:Connect(function()
			Inventory.UnitInfo.Info.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
			Inventory.UnitInfo.Skills.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
			Inventory.UnitInfo.Stats.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
			Inventory.UnitInfo.InfoDisplay.Visible = false
			Inventory.UnitInfo.SkillsDisplay.Visible = false
			Inventory.UnitInfo.StatsDisplay.Visible = true
		end)
		Inventory.Search.Box.SearchBox.FocusLost:Connect(function()
			local currentinventory = Inventory.Units.Visible == true and Inventory.Units.Frame
				or Inventory.Equipment.Frame
			if Inventory.Search.Box.SearchBox.Text == "" then
				for _, v in ipairs(currentinventory:GetChildren()) do
					if not v:IsA("UIGridLayout") then
						v.Visible = true
					end
				end
			else
				for _, v in ipairs(currentinventory:GetChildren()) do
					if
						not v:IsA("UIGridLayout")
						and string.match(string.lower(v.Name), string.lower(Inventory.Search.Box.SearchBox.Text))
							~= nil
					then
						v.Visible = true
					elseif
						not v:IsA("UIGridLayout")
						and string.match(string.lower(v.Name), string.lower(Inventory.Search.Box.SearchBox.Text))
							== nil
					then
						v.Visible = false
					end
				end
			end
		end)

		Tab.Summon.MouseButton1Click:Connect(function()
			if db3 == false then
				db3 = true
				Tab.Summon.AutoButtonColor = false

				if player.Character.Humanoid.WalkSpeed ~= 0 and player.Character.Humanoid.JumpPower ~= 0 then
					oldspd = player.Character.Humanoid.WalkSpeed
					oldjmp = player.Character.Humanoid.JumpPower
				end
				player.Character.Humanoid.WalkSpeed = 0
				player.Character.Humanoid.JumpPower = 0

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

				player.PlayerGui.DisplaysGui.Enabled = false

				for _, v in ipairs(player.PlayerGui.SummonGui.DropRates.ActualRates:GetChildren()) do --TODO: Change so it fires once we change the chosen type
					if not v:IsA("UIGridLayout") then
						local new =
							game.ReplicatedStorage.InvokesHandle:InvokeServer("GachaRates", string.sub(v.Name, 2))
						v.Text = new
					end
				end
				local data = player.Data:InvokeServer("Currencies")
				player.PlayerGui.SummonGui.CurrentCrystals.CrystalsBG.Amount.Text =
					string.format("%i Crystals", data[1]["Crystal"])

				player.PlayerGui.SummonGui.Enabled = true
				workspace.Camera.CameraType = Enum.CameraType.Scriptable
				workspace.Camera.CFrame = workspace.SummonMap.CameraPosition.CFrame

				local fadeBackTween = ts:Create(
					fade,
					TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ BackgroundTransparency = 1 }
				)
				fade.Parent = player.PlayerGui.BattleGui
				fadeBackTween:Play()
				fadeBackTween.Completed:Wait()
				fade.Parent = nil

				db3 = false
				Tab.Summon.AutoButtonColor = true
			end
		end)
	end

	do
		local db1 = false
		local SummonGui = player.PlayerGui.SummonGui
		SummonGui.Close.MouseButton1Click:Connect(function()
			if db1 == false then
				db1 = true

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

				player.PlayerGui.DisplaysGui.Enabled = true
				player.PlayerGui.SummonGui.Enabled = false
				workspace.Camera.CameraType = Enum.CameraType.Custom
				workspace.Camera.CameraSubject = player.Character.Humanoid

				local closeFadeTween = ts:Create(
					fade,
					TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ BackgroundTransparency = 1 }
				)
				fade.Parent = player.PlayerGui.BattleGui
				closeFadeTween:Play()
				closeFadeTween.Completed:Wait()
				fade.Parent = nil

				player.Character.Humanoid.WalkSpeed = oldspd
				player.Character.Humanoid.JumpPower = oldjmp

				db1 = false
			end
		end)

		SummonGui.Summon.SummonBG.SummonButton.MouseButton1Click:Connect(function()
			game.ReplicatedStorage.SharedRemotes.GachaHandle:FireServer() --TODO: Add argument based on what type of summon you want to do
			--animation of summoning here
			local data = player.Data:InvokeServer("Currencies")
			player.PlayerGui.SummonGui.CurrentCrystals.CrystalsBG.Amount.Text =
				string.format("%i Crystals", data[1]["Crystal"])
		end)
	end
end

return Gui
