local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Promise = require(ReplicatedStorage.Packages.Promise)
local Packets = require(ReplicatedStorage.SharedModules.Packets)
local MovePacket = Packets.MovePacket
local Visuals = require(script.Parent.VisualHandler)

local Controls = {}

Controls.INPUTS = {
	["UP"] = { Enum.KeyCode.W, Enum.KeyCode.Up },
	["DOWN"] = { Enum.KeyCode.S, Enum.KeyCode.Down },
	["LEFT"] = { Enum.KeyCode.A, Enum.KeyCode.Left },
	["RIGHT"] = { Enum.KeyCode.D, Enum.KeyCode.Right },
}
Controls.SetUp = false

local LocalPlayer = nil
local MOVEMENT_ATTEMPTS = 0
local MOVEMENT_COOLDOWN = 0
local MOVEMENT_DEBOUNCE = false
local BASE_COOLDOWN = 0
local MAX_COOLDOWN = 1
local COOLDOWN_STEP = 0.1
local ATTEMPT_THRESHOLD = 3

function Controls:StartUp(Player: Player)
	if Controls.SetUp == false then
		LocalPlayer = Player
		local plrcontrols =
			require(LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")):GetControls()
		plrcontrols:Disable()
		Controls.SetUp = true
	end
end

function Controls:Move(actionName, inputState, _inputObject)
	if inputState ~= Enum.UserInputState.Begin then
		return
	end
	MOVEMENT_ATTEMPTS += 1
	if MOVEMENT_DEBOUNCE then
		return
	end
	MOVEMENT_DEBOUNCE = true

	local dir = tonumber(actionName)

	local curX, curY = Visuals:GetLocalPosition()
	local mapName = Visuals.CURRENT_MAP
	if curX ~= 0 then
		local predX, predY = Visuals:PredictMove(mapName, curX, curY, dir)
		if predX and not Visuals:IsOccupied(mapName, predX, predY) then
			Visuals:OnLocalPlayerMoved(true, predX, predY, mapName, dir)
		end
	end

	MovePacket:Fire(dir)

	Promise.fromEvent(Packets.MoveAckPacket.OnClientEvent, function()
		return MOVEMENT_DEBOUNCE == true
	end)
		:timeout(5)
		:andThen(function(_accepted, gridX, gridY, ackMapName)
			local px, py = Visuals:GetLocalPosition()
			if gridX ~= px or gridY ~= py then
				Visuals:OnLocalPlayerMoved(false, gridX, gridY, ackMapName, nil)
			end
		end)
		:catch(function()
			warn("MoveAckPacket timed out")
		end)
		:finally(function()
			if MOVEMENT_COOLDOWN > 0 then
				Promise.delay(MOVEMENT_COOLDOWN):andThen(function()
					MOVEMENT_DEBOUNCE = false
				end)
			else
				MOVEMENT_DEBOUNCE = false
			end
		end)
end

function Controls:CooldownStartUp()
	while true do
		if MOVEMENT_ATTEMPTS > ATTEMPT_THRESHOLD then
			MOVEMENT_COOLDOWN = math.min(MOVEMENT_COOLDOWN + COOLDOWN_STEP, MAX_COOLDOWN)
		elseif MOVEMENT_COOLDOWN > BASE_COOLDOWN then
			MOVEMENT_COOLDOWN = math.max(MOVEMENT_COOLDOWN - COOLDOWN_STEP, BASE_COOLDOWN)
		end
		MOVEMENT_ATTEMPTS = 0
		task.wait(0.5)
	end
end

function Controls:Reset()
	MOVEMENT_ATTEMPTS = 0
	MOVEMENT_COOLDOWN = BASE_COOLDOWN
	MOVEMENT_DEBOUNCE = false
end

return Controls
