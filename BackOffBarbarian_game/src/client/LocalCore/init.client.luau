local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Packets = require(ReplicatedStorage.SharedModules.Packets)
local GuiHandler = require(script.LocalGuiHandler)
local Controls = require(script.ControlsHandler)
local Visuals = require(script.VisualHandler)
local AnimationHandler = require(script.AnimationHandler)

local function registerCharacter(player, character, packName)
	local entityId = player == Players.LocalPlayer and "local" or tostring(player.UserId)
	local humanoid = character:WaitForChild("Humanoid")
	local animator = humanoid:WaitForChild("Animator")
	AnimationHandler:Register(entityId, animator, packName)
	if player ~= Players.LocalPlayer then
		Visuals:RegisterEntityModel(tostring(player.UserId), character)
	end
end

Packets.AnimationPackPacket.OnClientEvent:Connect(function(userId, packName)
	AnimationHandler:SetPack(tostring(userId), packName)
end)

Packets.SendMapPacket.OnClientEvent:Connect(function(GridArray, cellSize, originPosition, Name)
	Visuals:CacheMap(GridArray, cellSize, originPosition, Name)
end)

Packets.MoveAckPacket.OnClientEvent:Connect(function(_accepted, gridX, gridY, mapName)
	Visuals:OnSpawnAck(gridX, gridY, mapName)
end)

Packets.EntityMovePacket.OnClientEvent:Connect(function(entityId, entityType, gridX, gridY, mapName, dir)
	Visuals:OnEntityMoved(entityId, entityType, gridX, gridY, mapName, dir)
end)

Packets.SendGameDataPacket.OnClientEvent:Connect(function(Event, arg)
	if Event == "RoundOver" then
		Visuals:ReleaseMap(arg)
		GuiHandler:TimerMode(false)
	elseif Event == "TimerStart" then
		GuiHandler:TimerMode(true, arg)
	elseif Event == "TimerEnd" then
		GuiHandler:TimerMode(false)
	end
end)

Players.LocalPlayer.CharacterAdded:Connect(function(character)
	task.wait()
	Controls:Reset()
	local myPack = "Default"
	registerCharacter(Players.LocalPlayer, character, myPack)
end)

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		registerCharacter(player, character, "Default")
	end)
end)

for _, player in ipairs(Players:GetPlayers()) do
	if player ~= Players.LocalPlayer and player.Character then
		registerCharacter(player, player.Character, "Default")
	end
end

Players.PlayerRemoving:Connect(function(player)
	local entityId = tostring(player.UserId)
	AnimationHandler:Unregister(entityId)
	Visuals:UnregisterEntity(entityId)
end)

Controls:StartUp(Players.LocalPlayer)
repeat
	task.wait()
until Controls.SetUp
task.spawn(function()
	Controls:CooldownStartUp()
end)

local function BindingFunction(actionName, inputState, inputObject)
	Controls:Move(actionName, inputState, inputObject)
end
ContextActionService:BindAction("1", BindingFunction, false, unpack(Controls.INPUTS.DOWN))
ContextActionService:BindAction("2", BindingFunction, false, unpack(Controls.INPUTS.RIGHT))
ContextActionService:BindAction("3", BindingFunction, false, unpack(Controls.INPUTS.UP))
ContextActionService:BindAction("4", BindingFunction, false, unpack(Controls.INPUTS.LEFT))

GuiHandler:StartUp()
repeat
	task.wait()
until GuiHandler.SetUp

Visuals:StartUp()
repeat
	task.wait()
until Visuals.SetUp
