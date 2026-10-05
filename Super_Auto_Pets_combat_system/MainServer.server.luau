--!strict

local HttpService = game:GetService("HttpService")
local ServerScriptService = game:GetService("ServerScriptService")

local BuddyDB = require(ServerScriptService:WaitForChild("BuddyDB"))
local GearDB = require(ServerScriptService:WaitForChild("GearDB"))
local BattleSystem = require(ServerScriptService:WaitForChild("BattleSystem"))

local function copyStats(stats: any): any
	return table.clone(stats)
end

local function CreateBuddy(dataTable: any): any
	local newBuddy = {}
	newBuddy.Stats = copyStats(dataTable.Stats)
	newBuddy.Abilities = dataTable.Abilities or {}
	newBuddy.Gear = nil
	newBuddy.Level = 1
	newBuddy.Experience = 0
	newBuddy.RequiredExperience = 2
	newBuddy.Model = dataTable.Model:Clone()
	newBuddy.UUID = HttpService:GenerateGUID(false)

	return newBuddy
end

local NoobWithSword = CreateBuddy(BuddyDB["2"])
NoobWithSword.Gear = GearDB["1"]

local GuestWithTrowel = CreateBuddy(BuddyDB["1"])
GuestWithTrowel.Gear = GearDB["2"]

local playerTeam = {
	NoobWithSword,
	CreateBuddy(BuddyDB["1"]),
}
local enemyTeam = {
	GuestWithTrowel,
	CreateBuddy(BuddyDB["2"]),
	CreateBuddy(BuddyDB["1"]),
}

local demoBattle = BattleSystem.new(playerTeam, enemyTeam)

local outcome
repeat
	outcome = demoBattle:ProcessTurn()
until outcome ~= "Undetermined"

print(string.format("Demo battle outcome: %s", outcome))
