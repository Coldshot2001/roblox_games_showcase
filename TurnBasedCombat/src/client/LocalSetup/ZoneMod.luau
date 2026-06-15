local Zone = {}
local areadata = require(game.ReplicatedStorage.SharedModules.ZonesDatabase)
local plrs = game:GetService("Players")
local SoundServ = game:GetService("SoundService")
local Serv = {
	tween = game:GetService("TweenService"),
}

local LastMusic = nil

Zone.Data = {
	["Initialized"] = false,
	["CurrentArea"] = "None",
}

Zone.Functions = {}

Zone.RenderedData = {}

Zone.Originals = {
	["Ambient"] = Color3.fromRGB(0, 0, 0),
	["Brightness"] = 2,
	["ColorShift_Bottom"] = Color3.fromRGB(0, 0, 0),
	["ColorShift_Top"] = Color3.fromRGB(0, 0, 0),
	["EnvironmentDiffuseScale"] = 0,
	["EnvironmentSpecularScale"] = 0,
	["OutdoorAmbient"] = Color3.fromRGB(127, 127, 127),
	["FogColor"] = Color3.fromRGB(180, 255, 253),
	["FogStart"] = 50,
	["FogEnd"] = 2000,
	["ExposureCompensation"] = 0,
}

local function EnteredArea(Area)
	if Zone.Data.CurrentArea ~= Area then
		Zone:ResetLighting()
	end
	Zone.Data.CurrentArea = Area
	game.ReplicatedStorage.SharedRemotes.AreaHandle:FireServer(Area)
	Zone:UpdateLighting(Area)
end

local function CheckHitboxes(CurrentArea)
	do
		local HitboxFolder = game.Workspace:WaitForChild("Zones")
		for _, Area in pairs(HitboxFolder:GetChildren()) do
			if Area.Name ~= CurrentArea then
				if not Zone.Functions[Area.Name] then
					return false
				end
			end
		end
		return true
	end
end

local function SetUpHitboxes(CurrentArea)
	local HitboxFolder = game.Workspace:WaitForChild("Zones")
	for _, Area in pairs(HitboxFolder:GetChildren()) do
		Area.Transparency = 1
		if Area.Name ~= CurrentArea and not Zone.Functions[Area.Name] then
			Zone.Functions[Area.Name] = Area.Touched:Connect(function(prt)
				if prt.Parent == game.Players.LocalPlayer.Character and prt.Name == "HumanoidRootPart" then
					if plrs:GetPlayerFromCharacter(prt.Parent) == game.Players.LocalPlayer then
						Zone.Functions[Area.Name]:Disconnect()
						Zone.Functions[Area.Name] = nil
						EnteredArea(Area.Name)
						SetUpHitboxes(Area.Name)
					end
				end
			end)
		end
	end
	return true
end

function Zone:SetUp()
	repeat
		wait(0.2)
	until game.Workspace:FindFirstChild(game.Players.LocalPlayer.Name)

	local HitboxFolder = game.Workspace:WaitForChild("Zones")
	Zone:ResetLighting()

	for _, Area in pairs(HitboxFolder:GetChildren()) do
		local Start = SetUpHitboxes("None")
		if Start ~= true then
			warn("Zone Hitbox Failure")
			return false
		end
	end

	local check = CheckHitboxes(Zone.Data.CurrentArea)
	if check == true then
		Zone.Data.Initialized = true
		return true
	else
		warn("Zone Hitbox Failure")
		return false
	end
end

function Zone:FadeText(val, Va)
	if val == true then
		local ui = game.Players.LocalPlayer.PlayerGui.DisplaysGui:WaitForChild("Zone")

		if Zone.Data.CurrentArea == Va then
			local tinfo = TweenInfo.new(1)
			local twens = {}
			local goal = {
				["TextTransparency"] = 1,
				["TextStrokeTransparency"] = 1,
			}

			table.insert(twens, Serv.tween:Create(ui.DisplayName, tinfo, goal))
			table.insert(twens, Serv.tween:Create(ui.Desc, tinfo, goal))

			for _, fade in next, twens do
				fade:Play()
			end
		end

		wait(1.25)

		local data = areadata.Areas[Va]
		ui.DisplayName.Text = data.DisplayName
		ui.Desc.Text = data.Desc

		if data.DisplayNameColor then
			ui.DisplayName.TextColor3 = data.DisplayNameColor
		end
		if data.DescNameColor then
			ui.Desc.TextColor3 = data.DescNameColor
		end
		if ui.Desc.Visible == false then
			ui.Desc.TextTransparency = 1
			ui.Desc.TextStrokeTransparency = 1
			ui.Desc.Visible = true
		end
		if ui.DisplayName.Visible == false then
			ui.DisplayName.TextTransparency = 1
			ui.DisplayName.TextStrokeTransparency = 1
			ui.DisplayName.Visible = true
		end

		local tinfo = TweenInfo.new(1)
		local twens = {}
		local goal = {
			["TextTransparency"] = 0,
			["TextStrokeTransparency"] = 1,
		}
		table.insert(twens, Serv.tween:Create(ui.DisplayName, tinfo, goal))
		table.insert(twens, Serv.tween:Create(ui.Desc, tinfo, goal))

		for _, fade in next, twens do
			fade:Play()
		end

		wait(4)

		if Zone.Data.CurrentArea == Va then
			local tinfo = TweenInfo.new(1)
			local twens = {}
			local goal = {
				["TextTransparency"] = 1,
				["TextStrokeTransparency"] = 1,
			}

			table.insert(twens, Serv.tween:Create(ui.DisplayName, tinfo, goal))
			table.insert(twens, Serv.tween:Create(ui.Desc, tinfo, goal))

			for _, fade in next, twens do
				fade:Play()
			end
		end
	end
end

function Zone:PlayMusic(area)
	local ZoneData
	if area then
		ZoneData = areadata.Areas[area]
	else
		ZoneData = areadata.Areas[Zone.Data.CurrentArea]
	end
	local data = game.Players.LocalPlayer.Data:InvokeServer("InBattle")

	if ZoneData then
		local NewMusic
		if data[1][1] == true then
			NewMusic = ZoneData.BattleMusic:Clone()
		else
			NewMusic = ZoneData.Music:Clone()
		end

		if NewMusic then
			NewMusic.Parent = game.SoundService
			NewMusic:Play()

			local twens = {}
			NewMusic.Volume = 0
			local tinfo = TweenInfo.new(2)
			local goal = {
				["Volume"] = 1,
			}
			table.insert(twens, Serv.tween:Create(NewMusic, tinfo, goal))

			for _, fade in next, twens do
				fade:Play()
			end

			local sounds = SoundServ:PlayLocalSound(NewMusic)

			--print(string.format("Playing %q",NewMusic.Name))

			if LastMusic ~= nil then
				local twens = {}
				local goal = {
					["Volume"] = 0,
				}
				table.insert(twens, Serv.tween:Create(LastMusic, tinfo, goal))

				for _, fade in next, twens do
					fade:Play()
				end

				coroutine.wrap(function()
					local msc = LastMusic
					wait(2)
					msc:Stop()
					msc:Destroy()
				end)()
			end
		end

		LastMusic = NewMusic
	end
end

function Zone:UpdateLighting(area)
	repeat
		wait(0.2)
	until game.Workspace:FindFirstChild(game.Players.LocalPlayer.Name)

	if areadata.Areas[area] then
		local data = areadata.Areas[area]
		--local ui = game.Players.LocalPlayer.PlayerGui:WaitForChild("HUD"):WaitForChild("Area_Frame")
		if data.DisplayName and data.Desc then
			coroutine.wrap(function()
				Zone:FadeText(true, area)
			end)()
		end

		local tinfo = TweenInfo.new(3)
		local twens = {}
		for property, value in next, data.Lighting do
			local goal = {
				[property] = data.Lighting[property],
			}
			table.insert(twens, Serv.tween:Create(game.Lighting, tinfo, goal))
		end

		for _, fade in next, twens do
			fade:Play()
		end

		Zone:PlayMusic(Zone.Data.CurrentArea)
	end
end

function Zone:ResetLighting(area)
	local tinfo = TweenInfo.new(3)
	local twens = {}
	for property, value in next, Zone.Originals do
		if game.Lighting[property] ~= Zone.Originals[property] then
			local goal = {
				[property] = Zone.Originals[property],
			}
			table.insert(twens, Serv.tween:Create(game.Lighting, tinfo, goal))
		end
	end
	for _, fade in next, twens do
		fade:Play()
	end
	if areadata.Areas[area] then
		if area.Music then
			area.Music:Stop()
		end
	end
end

return Zone
