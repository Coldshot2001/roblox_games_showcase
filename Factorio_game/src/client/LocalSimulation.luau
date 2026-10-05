--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

local AssetsFolder = ReplicatedStorage:WaitForChild("Assets")
local SimulationRem = AssetsFolder.Events.Simulation

local GridMap2D = require(ReplicatedStorage:WaitForChild("GridMap2D"))
local GameLogic = require(ReplicatedStorage:WaitForChild("GameLogic"))
local ClientDataDisplay = require(ReplicatedStorage:WaitForChild("ClientDataDisplay"))

local CELL_SIZE = 4.5
local GRID_ORIGIN = Vector3.new(10, 0.5, 10)

local SimData: any = nil
local SimTask: thread? = nil
local GameRunning = false
local CurSelectedMachine = { x = 0, y = 0 }

local function stopSimulation()
	if SimTask then
		task.cancel(SimTask)
		SimTask = nil
	end
	GameRunning = false
end

local function startSimulation()
	if SimTask then
		return
	end
	GameRunning = true
	SimTask = task.spawn(function()
		while GameRunning and SimData do
			local stats = SimData.Stats
			GameLogic:Tick(SimData)

			ClientDataDisplay:UpdateStats({
				CurFlux = stats.CurFlux,
				MaxFlux = stats.MaxFlux,
				CurMana = stats.CurMana,
				MaxMana = stats.MaxMana,
				TickPerSec = stats.TickPerSec,
			})

			if CurSelectedMachine.x ~= 0 then
				local cell = SimData.GameGrid:GetValue(CurSelectedMachine.x, CurSelectedMachine.y)
				ClientDataDisplay:UpdateMachineStats(cell and cell[1] or nil)
			end

			task.wait(1 / stats.TickPerSec)
		end
	end)
end

local function loadLayout(snapshot: any)
	GameLogic:ClearAllItems(SimData.GameGrid)
	for _, entry in ipairs(snapshot.CurrentLayout) do
		if
			typeof(entry) == "table"
			and typeof(entry.x) == "number"
			and typeof(entry.y) == "number"
			and typeof(entry.itemID) == "string"
		then
			GameLogic:AddItem(entry.x, entry.y, entry.itemID, SimData.GameGrid, entry.item)
		end
	end
end

local function handleSimulationEvent(mode: string, ...)
	local args = { ... }

	if mode == "Setup" then
		SimData = args[1]
		local stats = SimData.Stats
		SimData.GameGrid = GridMap2D.new(stats.LayoutWidth, stats.LayoutHeight, CELL_SIZE, GRID_ORIGIN)

		ClientDataDisplay:UpdateStats(stats)
		loadLayout(SimData)
		startSimulation()
	elseif mode == "Correct" then
		local wasRunning = GameRunning
		stopSimulation()

		local snapshot = args[1]
		SimData.BoughtUpgrades = snapshot.BoughtUpgrades
		SimData.Stats = snapshot.Stats
		SimData.SavedLayouts = snapshot.SavedLayouts
		loadLayout(snapshot)

		ClientDataDisplay:UpdateStats(SimData.Stats)
		if wasRunning then
			startSimulation()
		end
	end
end

SimulationRem.OnClientEvent:Connect(handleSimulationEvent)

local simPause = LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("SimPause")
simPause.Event:Connect(function(running: boolean)
	if running == false then
		stopSimulation()
	elseif running == true then
		startSimulation()
	end
end)

LocalPlayer:GetAttributeChangedSignal("CurSelectedX"):Connect(function()
	CurSelectedMachine.x = LocalPlayer:GetAttribute("CurSelectedX") or 0
end)

LocalPlayer:GetAttributeChangedSignal("CurSelectedY"):Connect(function()
	CurSelectedMachine.y = LocalPlayer:GetAttribute("CurSelectedY") or 0
end)
