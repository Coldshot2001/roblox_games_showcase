local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer.PlayerGui
local PauseGUI = PlayerGui.Test3
local StatsGui = PlayerGui.Test
local StateText = PauseGUI.StateText
local ItemInfo = PlayerGui.ItemInfo
local ItemInfoText = PlayerGui.ItemInfoText
local Container = ItemInfo.Container
local AssetsFolder = ReplicatedStorage:WaitForChild("Assets")
local GuiInteractionRem = AssetsFolder.Events.GuiInteraction
local ActonRem = AssetsFolder.Events.Action
local ActionRemFun = AssetsFolder.Events.ActionFunc
local SimPauseEvent = LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("SimPause")
local ItemsDatabase = require(ReplicatedStorage.ItemsDatabase)
local ClientDataDisplay = require(ReplicatedStorage.ClientDataDisplay)
local Running = true
-- I added for action handling
local PlacementDebounce = time()
local CurrentState = "Idle"
local CurrentlySelected = nil
local SelectionDestroyedHandler = nil
-- I added for adding delay to the runservice
local Elapsed = 0
local Rate = 0.25
local Mouse = LocalPlayer:GetMouse()
--

local function formatNumber(num)
	return string.gsub(string.format("%.3f", num), "%.?0+$", "")
end

local function changeState(State)
	if typeof(State) ~= "string" then
		warn("Can't change to empty state")
		return
	end
	CurrentState = State
	StateText.Text = "Current State :" .. State
end

local function changeSellButtonColor(Color)
	PauseGUI.SellToggle.BackgroundColor3 = Color
end

local function resetItemButtonColor()
	for _, Button in PlayerGui.Test2.Shop.Useable:GetChildren() do
		if Button:IsA("TextButton") then
			Button.BackgroundColor3 = Color3.new(1, 1, 1)
		end
	end
end

local function clearContainer()
	for _, text in Container:GetChildren() do
		if text:IsA("TextLabel") then
			text:Destroy()
		end
	end
end

local function toggleSell()
	if CurrentState ~= "Selling" then
		changeState("Selling")
		CurrentlySelected = nil
		Container.Visible = false
		clearContainer()
		changeSellButtonColor(Color3.fromRGB(177, 1, 7))
		resetItemButtonColor()
	else
		changeState("Idle")
		changeSellButtonColor(Color3.fromRGB(212, 1, 8))
		resetItemButtonColor()
	end
end

local function updateStatsDisplay(SimStats)
	StatsGui.Stats.Flux.Text = formatNumber(SimStats.CurFlux) .. "/" .. formatNumber(SimStats.MaxFlux)
	StatsGui.Stats.Mana.Text = formatNumber(SimStats.CurMana) .. "/" .. formatNumber(SimStats.MaxMana)
end

local function updateMachineStatsDisplay(SimStats)
	if #SimStats[1] == 0 then
		return
	end
	for k, v in SimStats[1][1] do
		if type(v) == "userdata" then
			continue
		end
		local ItemInfoTextClone = Container:FindFirstChild(k)
		ItemInfoTextClone.Text = k .. ":" .. v
		ItemInfoTextClone.Parent = Container
	end
end

local function selectShopItem(name, chosenItem)
	resetItemButtonColor()
	if chosenItem == "Self" then
		return
	end
	local ItemButton = PlayerGui.Test2.Shop.Useable:FindFirstChild(name)
	ItemButton.BackgroundColor3 = Color3.new(0.52549, 0.52549, 0.52549)
end

local function setSelectedPositionAtt(x, y)
	LocalPlayer:SetAttribute("CurSelectedX", x)
	LocalPlayer:SetAttribute("CurSelectedY", y)
end

local ChosenMachine: string = "0"

local function itemButtonOnPress(ID, Name)
	if ChosenMachine == ID then
		ChosenMachine = "0"
		changeState("Idle")
		changeSellButtonColor(Color3.fromRGB(212, 1, 8))
		selectShopItem(Name, "Self")
	else
		ChosenMachine = ID
		clearContainer()
		setSelectedPositionAtt(0, 0)
		changeState("Placing")
		changeSellButtonColor(Color3.fromRGB(212, 1, 8))
		selectShopItem(Name, "Other")
		CurrentlySelected = nil
		Container.Visible = false
	end
end

ClientDataDisplay.Updated.Event:Connect(function(dataType, data)
	if dataType == "Stats" then
		updateStatsDisplay(data)
	elseif dataType == "CurSelectedMachine" then
		updateMachineStatsDisplay(data)
	end
end)

updateStatsDisplay(ClientDataDisplay.Stats)

PauseGUI.PauseGame.MouseButton1Click:Connect(function()
	Running = not Running
	if Running == true then
		PauseGUI.PauseGame.Text = "Pause"
	else
		PauseGUI.PauseGame.Text = "Unpause"
	end
	GuiInteractionRem:FireServer("Pause", Running)
	SimPauseEvent:Fire(Running)
end)
PauseGUI.SellToggle.MouseButton1Click:Connect(toggleSell)

local ItemBtn = PlayerGui:WaitForChild("Test2").Shop.ItemTemplate
for ID, ItemData in pairs(ItemsDatabase) do
	local ItemBtnClone = ItemBtn:Clone()
	ItemBtnClone.Name = ItemData["Name"]
	ItemBtnClone.Text = ItemData["Name"]
	ItemBtnClone.LayoutOrder = tonumber(ID)
	ItemBtnClone.Parent = PlayerGui.Test2.Shop.Useable
	ItemBtnClone.Visible = true
	ItemBtnClone.MouseButton1Click:Connect(function()
		itemButtonOnPress(ID, ItemData["Name"])
	end)
end

local camera = workspace.CurrentCamera
local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local params = RaycastParams.new()
params.FilterDescendantsInstances = { char }
params.FilterType = Enum.RaycastFilterType.Exclude

local function rayResult(x, y)
	local unitRay = camera:ScreenPointToRay(x, y)
	return workspace:Raycast(unitRay.Origin, unitRay.Direction * 500, params)
end

local function handleMouseAction(inputObject)
	local result = rayResult(inputObject.Position.X, inputObject.Position.Y)
	if not result then
		return Enum.ContextActionResult.Pass
	end

	if CurrentState == "Placing" and PlacementDebounce <= time() then
		PlacementDebounce = time() + 0.5
		CurrentlySelected = nil
		if ChosenMachine ~= 0 and result.Instance:HasTag("Tile") then
			ActonRem:FireServer(
				"mouseAction",
				CurrentState,
				{ x = result.Instance:GetAttribute("x"), y = result.Instance:GetAttribute("y") },
				ChosenMachine
			)
		end
	elseif CurrentState == "Idle" or CurrentState == "Hovering" then
		if result.Instance:HasTag("MachineModel") then
			local x = result.Instance.Parent:GetAttribute("x")
			local y = result.Instance.Parent:GetAttribute("y")
			local PositionInfo = ActionRemFun:InvokeServer("mouseAction", CurrentState, { x = x, y = y })
			--print(PositionInfo)
			if PositionInfo then
				clearContainer()
				changeState("Selecting")
				setSelectedPositionAtt(x, y)
				changeSellButtonColor(Color3.fromRGB(212, 1, 8))
				CurrentlySelected = { x = x, y = y }
				Container.Visible = true

				for k, v in PositionInfo do
					local ItemInfoTextClone = ItemInfoText:Clone()
					ItemInfoTextClone.Name = k
					ItemInfoTextClone.Text = k .. ":" .. v
					ItemInfoTextClone.Parent = Container
				end

				result.Instance.Parent.Destroying:Connect(function()
					if
						(CurrentState == "Selecting" or CurrentState == "Hovering")
						and (CurrentlySelected["x"] == x and CurrentlySelected["y"] == y)
					then
						clearContainer()
						changeState("Idle")
						setSelectedPositionAtt(0, 0)
						changeSellButtonColor(Color3.fromRGB(212, 1, 8))
						CurrentlySelected = nil
						Container.Visible = false
					end
				end)
			end
		end
	elseif CurrentState == "Selecting" then
		if result.Instance:HasTag("MachineModel") then
			local x = result.Instance.Parent:GetAttribute("x")
			local y = result.Instance.Parent:GetAttribute("y")

			if CurrentlySelected and (CurrentlySelected["x"] == x and CurrentlySelected["y"] == y) then
				clearContainer()
				changeState("Idle")
				setSelectedPositionAtt(0, 0)
				changeSellButtonColor(Color3.fromRGB(212, 1, 8))
				CurrentlySelected = nil
				Container.Visible = false

				return
			end

			local PositionInfo = ActionRemFun:InvokeServer("mouseAction", CurrentState, { x = x, y = y })
			if PositionInfo then
				clearContainer()
				setSelectedPositionAtt(x, y)
				CurrentlySelected = { x = x, y = y }
				Container.Visible = true

				for k, v in PositionInfo do
					local ItemInfoTextClone = ItemInfoText:Clone()
					ItemInfoTextClone.Name = k
					ItemInfoTextClone.Text = k .. ":" .. v
					ItemInfoTextClone.Parent = Container
				end

				result.Instance.Parent.Destroying:Connect(function()
					if
						(CurrentState == "Selecting" or CurrentState == "Hovering")
						and (CurrentlySelected["x"] == x and CurrentlySelected["y"] == y)
					then
						clearContainer()
						changeState("Idle")
						setSelectedPositionAtt(0, 0)
						changeSellButtonColor(Color3.fromRGB(212, 1, 8))
						CurrentlySelected = nil
						Container.Visible = false
					end
				end)
			else
				clearContainer()
				changeState("Idle")
				setSelectedPositionAtt(0, 0)
				changeSellButtonColor(Color3.fromRGB(212, 1, 8))
				CurrentlySelected = nil
				Container.Visible = false
			end
		else
			clearContainer()
			changeState("Idle")
			setSelectedPositionAtt(0, 0)
			changeSellButtonColor(Color3.fromRGB(212, 1, 8))
			CurrentlySelected = nil
			Container.Visible = false
		end
	elseif CurrentState == "Selling" then
		if result.Instance:HasTag("MachineModel") then
			local x = result.Instance.Parent:GetAttribute("x")
			local y = result.Instance.Parent:GetAttribute("y")

			local PositionInfo = ActionRemFun:InvokeServer("mouseAction", CurrentState, { x = x, y = y })
			if PositionInfo then
				GuiInteractionRem:FireServer("Sell", PositionInfo, x, y)
			end
		end
	end
end

local function handleAction(actionName, inputState, inputObject)
	if actionName == "mouseAction" and inputState == Enum.UserInputState.Begin then
		handleMouseAction(inputObject)
	end
end

ContextActionService:BindAction("mouseAction", handleAction, false, Enum.UserInputType.MouseButton1)

local function HandleGuiEvent(Mode, ...) end

GuiInteractionRem.OnClientEvent:Connect(HandleGuiEvent)
