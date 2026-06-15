local HttpService = game:GetService("HttpService")
local ServerScriptService = game:GetService("ServerScriptService")
local BuddyDB = require(ServerScriptService:WaitForChild("BuddyDB"))
local GearDB = require(ServerScriptService:WaitForChild("GearDB"))
local BattleSystem = require(ServerScriptService:WaitForChild("BattleSystem"))

function CreateBuddy(DataTable)
	local newBuddy = {}
	newBuddy.Stats = DataTable.Stats
	newBuddy.Abilities = DataTable.Abilities or {}
	newBuddy.Gear = nil
	newBuddy.Level = 1
	newBuddy.Experience = 0
	newBuddy.RequiredExperience = 2
	newBuddy.Model = DataTable.Model:Clone()
	newBuddy.UUID = HttpService:GenerateGUID(false)

	return newBuddy
end

local NoobWithSword = CreateBuddy(BuddyDB["2"])
NoobWithSword.Gear = GearDB["1"]

local GuestWithTrowel = CreateBuddy(BuddyDB["1"])
GuestWithTrowel.Gear = GearDB["2"]

local ta = {
	NoobWithSword,
	CreateBuddy(BuddyDB["1"]),
}
local tb = {
	GuestWithTrowel,
	CreateBuddy(BuddyDB["2"]),
	CreateBuddy(BuddyDB["1"]),
}
local test = BattleSystem.new(ta, tb)

local outcome
repeat
	outcome = test:ProcessTurn()
until outcome ~= "Undetermined"
print(outcome)
