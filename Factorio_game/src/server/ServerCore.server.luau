local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local GridMap2D = require(ReplicatedStorage.GridMap2D)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AssetsFolder = ReplicatedStorage:WaitForChild("Assets")
local SimulationRem = AssetsFolder.Events.Simulation
local GuiInteractionRem = AssetsFolder.Events.GuiInteraction
local LoadingScreen = AssetsFolder.Events.LoadingScreen
local ActionRem = AssetsFolder.Events.Action
local ActionRemFun = AssetsFolder.Events.ActionFunc

function deepCopy(orig)
	local orig_type = type(orig)
	local copy
	if orig_type == "table" then
		copy = {}
		for orig_key, orig_value in next, orig, nil do
			copy[deepCopy(orig_key)] = deepCopy(orig_value)
		end
		setmetatable(copy, deepCopy(getmetatable(orig)))
	else -- number, string, boolean, etc
		copy = orig
	end
	return copy
end

local GameSessionData = {}

local ItemsDatabase = require(ReplicatedStorage.ItemsDatabase)

local GameLogic = require(ReplicatedStorage.GameLogic)

local DefaultData = {
	["BoughtUpgrades"] = {},
	["Stats"] = {
		["MaxFlux"] = 1e3, --1k
		["MaxMana"] = 1e2, --100
		["CurFlux"] = 0,
		["CurMana"] = 10,
		["LayoutWidth"] = 3,
		["LayoutHeight"] = 3,
		["TickPerSec"] = 2, --ticks per second (example 1/5 = 5 ticks for 1 second)
	},
	["SavedLayouts"] = {
		[1] = {},
		[2] = {},
		[3] = {},
	},
	["CurrentLayout"] = {}, --current player setup
}

local ElapsedTicks = 0
local MaxTicks = 3 --100 --IDK maybe we'll make it dynamic at one point

local function ServerGameLoop(UserID)
	while true do
		ElapsedTicks += 1
		GameLogic:Tick(GameSessionData[UserID])

		--Correct the player's simulation!
		if ElapsedTicks == MaxTicks then
			ElapsedTicks = 0
			local Plr = Players:GetPlayerByUserId(UserID)
			--SimulationRem:FireClient(Plr, "Correct", GameSessionData[UserID])
		end

		task.wait(1 / GameSessionData[UserID]["Stats"]["TickPerSec"])
	end
end

local function HandleGuiEvent(plrObj, Mode, ...)
	local args = { ... }
	local UserID = plrObj.UserId
	if Mode == "Pause" then
		local Running = args[1]
		if Running == true then
			if GameSessionData[UserID]["GameTicking"] == true then
				return
			end
			GameSessionData[UserID]["GameTicking"] = true
			GameSessionData[plrObj.UserId]["TaskLoop"] = task.spawn(ServerGameLoop, plrObj.UserId)
		else
			if GameSessionData[UserID]["GameTicking"] == false then
				return
			end
			GameSessionData[UserID]["GameTicking"] = false
			if GameSessionData[plrObj.UserId]["TaskLoop"] ~= nil then
				task.cancel(GameSessionData[plrObj.UserId]["TaskLoop"])
			end
		end
	elseif Mode == "Sell" then
		local SoldItem, x, y = args[1], args[2], args[3]
		--print(SoldItem,x,y)
		local ItemType = ItemsDatabase[SoldItem["ItemID"]]["Type"]

		if ItemType == "Generator" then
			GameSessionData[UserID]["Stats"]["CurMana"] += (ItemsDatabase[SoldItem["ItemID"]]["Cost"] * (SoldItem["CurDurability"] * 100 / SoldItem["MaxDurability"]) / 100)
		else
			GameSessionData[UserID]["Stats"]["CurMana"] += ItemsDatabase[SoldItem["ItemID"]]["Cost"]
		end
		GameSessionData[UserID]["Stats"]["CurMana"] = GameSessionData[UserID]["Stats"]["CurMana"]
					> GameSessionData[UserID]["Stats"]["MaxMana"]
				and GameSessionData[UserID]["Stats"]["MaxMana"]
			or GameSessionData[UserID]["Stats"]["CurMana"]

		GameLogic:DestroyItem(x, y, GameSessionData[UserID]["GameGrid"])
		SimulationRem:FireClient(plrObj, "Correct", GameSessionData[UserID])
	end
end

local function HandleActionEvent(plrObj, ActionName, ...)
	local args = { ... }

	if ActionName == "mouseAction" then
		local CurrentState = args[1]

		if CurrentState == "Placing" then
			local Position, ID = args[2], args[3]
			local CurMachine = ItemsDatabase[ID]
			local X, Y = Position["x"], Position["y"] -- Obtain the x and y from the attribute of the tile

			if not CurMachine then
				return
			end
			if GameSessionData[plrObj.UserId]["GameGrid"]:GetValue(X, Y)[1] ~= nil then
				return
			end

			if
				GameSessionData[plrObj.UserId]
				and GameSessionData[plrObj.UserId]["Stats"]["CurMana"] - ItemsDatabase[ID]["Cost"] >= 0
			then
				GameSessionData[plrObj.UserId]["Stats"]["CurMana"] -= ItemsDatabase[ID]["Cost"]
				GameLogic:AddItem(X, Y, ID, GameSessionData[plrObj.UserId]["GameGrid"]) -- Place item on the server
				SimulationRem:FireClient(plrObj, "Correct", GameSessionData[plrObj.UserId])
			end
		elseif CurrentState == "Idle" or CurrentState == "Selecting" or CurrentState == "Selling" then
			local Position = args[2]
			local X, Y = Position["x"], Position["y"]

			if GameSessionData[plrObj.UserId]["GameGrid"]:GetValue(X, Y)[1] ~= nil then
				return GameSessionData[plrObj.UserId]["GameGrid"]:GetValue(X, Y)[1]
			end

			return false
		end
	end
end

GuiInteractionRem.OnServerEvent:Connect(HandleGuiEvent)
ActionRem.OnServerEvent:Connect(HandleActionEvent)
ActionRemFun.OnServerInvoke = HandleActionEvent

--TODO: check if players can somehow join before Players.PlayerAdded triggers?

Players.PlayerAdded:Connect(function(plrObj)
	local FinishedLoading = LoadingScreen:InvokeClient(plrObj)

	repeat
		task.wait()
	until FinishedLoading

	if GameSessionData[plrObj.UserId] == nil then
		--check for already saved data, if not, load default data
		GameSessionData[plrObj.UserId] = deepCopy(DefaultData)

		GameSessionData[plrObj.UserId]["GameGrid"] = GridMap2D.new(
			GameSessionData[plrObj.UserId]["Stats"]["LayoutWidth"],
			GameSessionData[plrObj.UserId]["Stats"]["LayoutHeight"],
			4.5,
			Vector3.new(10, 0.5, 10)
		)

		local curGrid = GameSessionData[plrObj.UserId]["GameGrid"]
		local curWidth = GameSessionData[plrObj.UserId]["Stats"]["LayoutWidth"]

		--currently we expect the layout to be correctly stored
		--TODO: ADD CHECKS FOR THE LAYOUT
		if next(GameSessionData[plrObj.UserId]["CurrentLayout"]) == nil then
			--DEBUG
			GameLogic:AddItem(2, 1, "1", curGrid)
			GameLogic:AddItem(2, 3, "1", curGrid)
			GameLogic:AddItem(1, 2, "1", curGrid)
			GameLogic:AddItem(3, 2, "1", curGrid)
			GameLogic:AddItem(2, 2, "2", curGrid)
			--
			GameSessionData[plrObj.UserId]["CurrentLayout"] = GameSessionData[plrObj.UserId]["GameGrid"].GridArray
		else
			local success, response =
				pcall(HttpService.JSONDecode, HttpService, GameSessionData[plrObj.UserId]["CurrentLayout"])

			if success then
				GameSessionData[plrObj.UserId]["GameGrid"].GridArray = response
			else
				warn("Error:", response)
			end
		end

		GameSessionData[plrObj.UserId]["GameTicking"] = true
		GameSessionData[plrObj.UserId]["TaskLoop"] = task.spawn(ServerGameLoop, plrObj.UserId)

		SimulationRem:FireClient(plrObj, "Setup", GameSessionData[plrObj.UserId])
	else --prevent player whose data wasnt unloaded to rejoin
		--do some saving stuff here
		GameSessionData[plrObj.UserId]["GameTicking"] = false
		if GameSessionData[plrObj.UserId]["TaskLoop"] ~= nil then
			task.cancel(GameSessionData[plrObj.UserId]["TaskLoop"])
		end
		GameSessionData[plrObj.UserId] = nil
		plrObj:Kick("Data error, please rejoin!")
	end

	plrObj:SetAttribute("CurSelectedX", 0) -- For detecting changes without having to use remotes
	plrObj:SetAttribute("CurSelectedY", 0) -- For detecting changes without having to use remotes
end)

Players.PlayerRemoving:Connect(function(plrObj)
	if GameSessionData[plrObj.UserId] ~= nil then
		--do some saving stuff here
		GameSessionData[plrObj.UserId]["GameTicking"] = false
		if GameSessionData[plrObj.UserId]["TaskLoop"] ~= nil then
			task.cancel(GameSessionData[plrObj.UserId]["TaskLoop"])
		end
		GameSessionData[plrObj.UserId]["TaskLoop"] = nil
		--
		local success, response =
			pcall(HttpService.JSONEncode, HttpService, GameSessionData[plrObj.UserId]["CurrentLayout"])

		if success then
			--TODO: response will be a string we'll have to save
			print(response)
		else
			warn("Error:", response)
		end
		--
		GameSessionData[plrObj.UserId] = nil
	end
end)
