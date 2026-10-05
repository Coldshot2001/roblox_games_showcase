local LPlr = game.Players.LocalPlayer
local RunService = game:GetService("RunService")

local LocalGui = {}
LocalGui.SetUp = false

function LocalGui:StartUp()
	if LocalGui.SetUp == false then
		do
			local MAX_RETRIES = 8

			local StarterGui = game:GetService("StarterGui")

			local function coreCall(method, ...)
				local result = {}
				for _ = 1, MAX_RETRIES do
					result = { pcall(StarterGui[method], StarterGui, ...) }
					if result[1] then
						break
					end
					RunService.Stepped:Wait()
				end
				return unpack(result)
			end

			coreCall("SetCore", "ResetButtonCallback", false)
			StarterGui = nil
		end
		LocalGui.SetUp = true
	end
end

local CurTime
local TimerEv = nil
function LocalGui:TimerMode(Mode: boolean, Time: number)
	if Mode == false then
		if TimerEv then
			TimerEv:Disconnect()
			TimerEv = nil
		end
		local TimerLabel = LPlr.PlayerGui:WaitForChild("Main").MainFrame.Timer
		TimerLabel.Visible = false
		TimerLabel.Text = "00:00<font size='10'> 000</font>"
		CurTime = 0
	elseif Mode == true then
		CurTime = Time
		local TimerLabel = LPlr.PlayerGui:WaitForChild("Main").MainFrame.Timer
		TimerEv = RunService.Heartbeat:Connect(function()
			local TimePassed = workspace:GetServerTimeNow() - CurTime
			local m = math.floor(TimePassed / 60) -- Minutes
			local s = math.floor(TimePassed % 60) -- Seconds
			local ms = math.floor((TimePassed % 1) * 1000) -- Milliseconds

			TimerLabel.Text = string.format("%02d:%02d<font size='10'> %03d</font>", m, s, ms)
		end)
		TimerLabel.Visible = true
	end
end

return LocalGui
