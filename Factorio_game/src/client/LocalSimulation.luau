local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local AssetsFolder = ReplicatedStorage:WaitForChild("Assets")
local SimulationRem = AssetsFolder.Events.Simulation
local GuiInteractionRem = AssetsFolder.Events.GuiInteraction
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer.PlayerGui
local GridMap2D = require(ReplicatedStorage.GridMap2D)
local GameLogic = require(ReplicatedStorage.GameLogic)
local ItemsDatabase = require(ReplicatedStorage.ItemsDatabase)
local ClientDataDisplay = require(ReplicatedStorage.ClientDataDisplay)
local GameGrid, SimTask, SimData
local CurSelectedMachine = { x = 0, y = 0 }
local GameRunning = false

local function formatNumber(num)
	return string.gsub(string.format("%.3f", num), "%.?0+$", "")
end

local StatsGui = PlayerGui:WaitForChild("Test")

local function LocalGameLoop()
	while true do
		GameLogic:Tick(SimData)

		local SimStats = SimData["Stats"]

		ClientDataDisplay:UpdateStats({
			CurFlux = SimStats["CurFlux"],
			MaxFlux = SimStats["MaxFlux"],
			CurMana = SimStats["CurMana"],
			MaxMana = SimStats["MaxMana"],
			TickPerSec = SimStats["TickPerSec"],
		})
		if CurSelectedMachine["x"] ~= 0 then -- if x is zero the position is wrong to begin with dont bother checking y
			ClientDataDisplay:UpdateMachineStats({
				SimData["GameGrid"]:GetValue(CurSelectedMachine["x"], CurSelectedMachine["y"]),
			})
		end

		task.wait(1 / SimStats["TickPerSec"])
	end
end

local function HandleSimulationEvent(Mode, ...)
	local args = { ... }
	if Mode == "Setup" then
		SimData = args[1]

		local SimStats = SimData["Stats"]
		SimData["GameGrid"] =
			GridMap2D.new(SimStats["LayoutWidth"], SimStats["LayoutHeight"], 4.5, Vector3.new(10, 0.5, 10), false)

		ClientDataDisplay:UpdateStats(SimStats)

		local curWidth = SimStats["LayoutWidth"]

		local CurLayout = SimData["CurrentLayout"]
		for y, Table in CurLayout do
			for x, Table2 in Table do
				if next(Table2) ~= nil then
					GameLogic:AddItem(x, y, Table2[1]["ItemID"], SimData["GameGrid"], Table2[1])
				end
			end
		end

		SimTask = task.spawn(LocalGameLoop)
		GameRunning = true
	elseif Mode == "Correct" then
		if SimTask ~= nil then
			GameRunning = false
			task.cancel(SimTask)
		end

		local CorrectSimData = args[1]
		SimData["BoughtUpgrades"] = CorrectSimData["BoughtUpgrades"]
		SimData["Stats"] = CorrectSimData["Stats"]
		SimData["SavedLayouts"] = CorrectSimData["SavedLayouts"]
		local CorrectLayout = CorrectSimData["CurrentLayout"]
		for y, Table in CorrectLayout do
			for x, Table2 in Table do
				if next(Table2) ~= nil then
					GameLogic:UpdateItem(x, y, SimData["GameGrid"], Table2[1])
				else
					GameLogic:UpdateItem(x, y, SimData["GameGrid"], nil)
				end
			end
		end

		local SimStats = SimData["Stats"]
		ClientDataDisplay:UpdateStats(SimStats)

		if GameRunning == true then
			SimTask = task.spawn(LocalGameLoop)
			GameRunning = true
		end
	end
end

SimulationRem.OnClientEvent:Connect(HandleSimulationEvent)

LocalPlayer.PlayerScripts.SimPause.Event:Connect(function(Running)
	if Running == false then
		if SimTask == nil then
			return
		end
		GameRunning = false
		SimTask = task.cancel(SimTask)
	elseif Running == true then
		SimTask = task.spawn(LocalGameLoop)
		GameRunning = true
	end
end)

LocalPlayer:GetAttributeChangedSignal("CurSelectedX"):Connect(function()
	CurSelectedMachine["x"] = LocalPlayer:GetAttribute("CurSelectedX")
end)

LocalPlayer:GetAttributeChangedSignal("CurSelectedY"):Connect(function()
	CurSelectedMachine["y"] = LocalPlayer:GetAttribute("CurSelectedY")
end)
