--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetsFolder = ReplicatedStorage:WaitForChild("Assets")
local SimulationRem = AssetsFolder.Events.Simulation
local GuiInteractionRem = AssetsFolder.Events.GuiInteraction
local LoadingScreen = AssetsFolder.Events.LoadingScreen
local ActionRem = AssetsFolder.Events.Action
local ActionRemFun = AssetsFolder.Events.ActionFunc

local GridMap2D = require(ReplicatedStorage:WaitForChild("GridMap2D"))
local ItemsDatabase = require(ReplicatedStorage:WaitForChild("ItemsDatabase"))
local GameLogic = require(ReplicatedStorage:WaitForChild("GameLogic"))
local Economy = require(ReplicatedStorage:WaitForChild("Economy"))
local DataService = require(script.Parent:WaitForChild("DataService"))

local CELL_SIZE = 4.5
local GRID_ORIGIN = Vector3.new(10, 0.5, 10)
local MAX_TICKS_BETWEEN_CORRECTIONS = 3
local SELL_COOLDOWN_SECONDS = 0.2
local MIN_LAYOUT_SIZE = 1
local MAX_LAYOUT_SIZE = 32
local MIN_TICK_RATE = 1
local MAX_TICK_RATE = 20
local SCHEMA_VERSION = 1

type Stats = { [string]: number }

type Session = {
	Stats: Stats,
	GameGrid: any,
	BoughtUpgrades: any,
	SavedLayouts: any,
	CurrentLayout: any,
	GameTicking: boolean,
	TaskLoop: thread?,
	ElapsedTicks: number,
}

local DEFAULT_DATA = {
	BoughtUpgrades = {},
	Stats = {
		MaxFlux = 1e3,
		MaxMana = 1e2,
		CurFlux = 0,
		CurMana = 10,
		LayoutWidth = 3,
		LayoutHeight = 3,
		TickPerSec = 2,
	},
	SavedLayouts = { {}, {}, {} },
	CurrentLayout = {},
}

local GameSessionData: { [number]: Session } = {}
local lastSellAt: { [number]: number } = {}

local function deepCopy(original: any): any
	if typeof(original) ~= "table" then
		return original
	end
	local copy = {}
	for key, value in pairs(original) do
		copy[deepCopy(key)] = deepCopy(value)
	end
	return copy
end

local function buildLayoutList(session: Session): { any }
	local layout = {}
	for y = 1, session.Stats.LayoutHeight do
		for x = 1, session.Stats.LayoutWidth do
			local cell = session.GameGrid:GetValue(x, y)
			local item = cell and cell[1]
			if item then
				local savedItem = {}
				for key, value in pairs(item) do
					if typeof(value) ~= "Instance" then
						savedItem[key] = value
					end
				end
				table.insert(layout, { x = x, y = y, itemID = item.ItemID, item = savedItem })
			end
		end
	end
	return layout
end

local function buildClientSnapshot(session: Session)
	return {
		Stats = session.Stats,
		BoughtUpgrades = session.BoughtUpgrades,
		SavedLayouts = session.SavedLayouts,
		CurrentLayout = buildLayoutList(session),
	}
end

local function buildSavePayload(session: Session)
	local stats = {}
	for key, value in pairs(session.Stats) do
		if typeof(value) == "number" then
			stats[key] = value
		end
	end

	return {
		version = SCHEMA_VERSION,
		stats = stats,
		boughtUpgrades = session.BoughtUpgrades,
		savedLayouts = session.SavedLayouts,
		layout = buildLayoutList(session),
	}
end

local function applySavedData(session: Session, saved: any)
	if typeof(saved) ~= "table" then
		return
	end

	local savedStats = saved.stats
	if typeof(savedStats) == "table" then
		for key, defaultValue in pairs(session.Stats) do
			local value = savedStats[key]
			if typeof(value) == typeof(defaultValue) and value == value then
				session.Stats[key] = value
			end
		end
	end

	if typeof(saved.boughtUpgrades) == "table" then
		session.BoughtUpgrades = saved.boughtUpgrades
	end
	if typeof(saved.savedLayouts) == "table" then
		session.SavedLayouts = saved.savedLayouts
	end
	if typeof(saved.layout) == "table" then
		session.CurrentLayout = saved.layout
	end

	session.Stats.LayoutWidth =
		math.clamp(math.floor(session.Stats.LayoutWidth), MIN_LAYOUT_SIZE, MAX_LAYOUT_SIZE)
	session.Stats.LayoutHeight =
		math.clamp(math.floor(session.Stats.LayoutHeight), MIN_LAYOUT_SIZE, MAX_LAYOUT_SIZE)
	session.Stats.TickPerSec = math.clamp(session.Stats.TickPerSec, MIN_TICK_RATE, MAX_TICK_RATE)
	session.Stats.CurMana = math.max(0, session.Stats.CurMana)
	session.Stats.CurFlux = math.max(0, session.Stats.CurFlux)
	session.Stats.MaxMana = math.max(session.Stats.CurMana, session.Stats.MaxMana)
	session.Stats.MaxFlux = math.max(session.Stats.CurFlux, session.Stats.MaxFlux)
end

local function restoreLayout(session: Session)
	for _, entry in ipairs(session.CurrentLayout) do
		if
			typeof(entry) == "table"
			and typeof(entry.x) == "number"
			and typeof(entry.y) == "number"
			and typeof(entry.itemID) == "string"
		then
			GameLogic:AddItem(entry.x, entry.y, entry.itemID, session.GameGrid, entry.item)
		end
	end
end

local function buildPublicItem(item: any): { [string]: any }
	local public = {}
	for key, value in pairs(item) do
		if key ~= "Model" then
			public[key] = value
		end
	end
	return public
end

local function stopLoop(userId: number)
	local session = GameSessionData[userId]
	if session and session.TaskLoop then
		task.cancel(session.TaskLoop)
		session.TaskLoop = nil
	end
end

local function serverGameLoop(userId: number)
	while true do
		local session = GameSessionData[userId]
		if not session or not session.GameTicking then
			return
		end

		GameLogic:Tick(session)

		session.ElapsedTicks += 1
		if session.ElapsedTicks >= MAX_TICKS_BETWEEN_CORRECTIONS then
			session.ElapsedTicks = 0
			local player = Players:GetPlayerByUserId(userId)
			if player then
				SimulationRem:FireClient(player, "Correct", buildClientSnapshot(session))
			end
		end

		task.wait(1 / session.Stats.TickPerSec)
	end
end

local function startLoop(userId: number)
	local session = GameSessionData[userId]
	if not session or session.TaskLoop then
		return
	end
	session.TaskLoop = task.spawn(serverGameLoop, userId)
end

local function handleSell(player: Player, session: Session, x: any, y: any)
	if typeof(x) ~= "number" or typeof(y) ~= "number" then
		return
	end
	if x ~= math.floor(x) or y ~= math.floor(y) then
		return
	end

	local now = os.clock()
	if (lastSellAt[player.UserId] or 0) + SELL_COOLDOWN_SECONDS > now then
		return
	end
	lastSellAt[player.UserId] = now

	local cell = session.GameGrid:GetValue(x, y)
	local item = cell and cell[1]
	if not item then
		return
	end

	local definition = ItemsDatabase[item.ItemID]
	if typeof(definition) ~= "table" then
		return
	end

	local refund = Economy.getSellRefund(item, definition)
	session.Stats.CurMana = math.min(session.Stats.CurMana + refund, session.Stats.MaxMana)

	GameLogic:DestroyItem(x, y, session.GameGrid)
	SimulationRem:FireClient(player, "Correct", buildClientSnapshot(session))
end

local function handleGuiEvent(player: Player, mode: string, ...)
	local session = GameSessionData[player.UserId]
	if not session then
		return
	end
	local args = { ... }

	if mode == "Pause" then
		local running = args[1]
		if typeof(running) ~= "boolean" then
			return
		end
		if running then
			if session.GameTicking then
				return
			end
			session.GameTicking = true
			startLoop(player.UserId)
		else
			if not session.GameTicking then
				return
			end
			session.GameTicking = false
			stopLoop(player.UserId)
		end
	elseif mode == "Sell" then
		handleSell(player, session, args[1], args[2])
	end
end

local function handleActionEvent(player: Player, actionName: string, ...)
	local session = GameSessionData[player.UserId]
	if not session or actionName ~= "mouseAction" then
		return false
	end

	local args = { ... }
	local state = args[1]
	if typeof(state) ~= "string" then
		return false
	end

	if state == "Placing" then
		local position = args[2]
		local itemID = args[3]
		if typeof(position) ~= "table" or typeof(itemID) ~= "string" then
			return false
		end

		local x, y = position.x, position.y
		if typeof(x) ~= "number" or typeof(y) ~= "number" then
			return false
		end

		local definition = ItemsDatabase[itemID]
		if typeof(definition) ~= "table" then
			return false
		end
		if not session.GameGrid:IsInBounds(x, y) or not session.GameGrid:IsEmpty(x, y) then
			return false
		end

		local cost = definition.Cost
		if typeof(cost) ~= "number" or cost <= 0 or session.Stats.CurMana < cost then
			return false
		end

		if not GameLogic:AddItem(x, y, itemID, session.GameGrid) then
			return false
		end

		session.Stats.CurMana -= cost
		SimulationRem:FireClient(player, "Correct", buildClientSnapshot(session))
		return true
	elseif state == "Idle" or state == "Selecting" or state == "Selling" then
		local position = args[2]
		if typeof(position) ~= "table" then
			return false
		end

		local x, y = position.x, position.y
		if typeof(x) ~= "number" or typeof(y) ~= "number" then
			return false
		end

		local cell = session.GameGrid:GetValue(x, y)
		local item = cell and cell[1]
		if not item then
			return false
		end

		return buildPublicItem(item)
	end

	return false
end

local function onPlayerAdded(player: Player)
	local ok, finishedLoading = pcall(function()
		return LoadingScreen:InvokeClient(player)
	end)
	if not ok or not finishedLoading or not player.Parent then
		return
	end

	local oldSession = GameSessionData[player.UserId]
	if oldSession then
		stopLoop(player.UserId)
		DataService.Save(player, buildSavePayload(oldSession))
		GameSessionData[player.UserId] = nil
	end

	local session = deepCopy(DEFAULT_DATA) :: Session
	local loaded, saved = DataService.Load(player)
	if loaded then
		applySavedData(session, saved)
	end

	session.GameGrid = GridMap2D.new(
		session.Stats.LayoutWidth,
		session.Stats.LayoutHeight,
		CELL_SIZE,
		GRID_ORIGIN
	)
	restoreLayout(session)

	session.GameTicking = true
	session.ElapsedTicks = 0
	session.TaskLoop = nil
	GameSessionData[player.UserId] = session

	SimulationRem:FireClient(player, "Setup", buildClientSnapshot(session))
	startLoop(player.UserId)

	player:SetAttribute("CurSelectedX", 0)
	player:SetAttribute("CurSelectedY", 0)
end

local function onPlayerRemoving(player: Player)
	local session = GameSessionData[player.UserId]
	if not session then
		return
	end
	stopLoop(player.UserId)
	DataService.Save(player, buildSavePayload(session))
	GameSessionData[player.UserId] = nil
end

GuiInteractionRem.OnServerEvent:Connect(handleGuiEvent)
ActionRem.OnServerEvent:Connect(handleActionEvent)
ActionRemFun.OnServerInvoke = handleActionEvent

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

game:BindToClose(function()
	for userId, session in pairs(GameSessionData) do
		local player = Players:GetPlayerByUserId(userId)
		if player and session then
			stopLoop(userId)
			DataService.Save(player, buildSavePayload(session))
		end
	end
end)
