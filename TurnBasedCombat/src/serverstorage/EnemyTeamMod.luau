--!strict

local Characters = require(game.ServerStorage.CharactersDatabase).Characters
local CharacterClass = require(game.ServerStorage.CharacterClass)

local Enemy = {}

Enemy.Teams = {
	["Cyber Dawg"] = {
		["Max Enemies"] = 2,
		["Cyber Dawg"] = { 60, 1 },
	},
	["Punching Dummy"] = {
		["Max Enemies"] = 1,
		["Punching Dummy"] = { 100, 1 },
	},
	["Palace Sentry"] = {
		["Max Enemies"] = 1,
		["Palace Sentry"] = { 100, 3 },
	},
}

local function chooseRandom(table_: any): string?
	local total = 0
	local roll = math.random(100)
	for name, entry in pairs(table_) do
		total += entry[1]
		if total >= roll then
			return name
		end
	end
	return nil
end

function Enemy:GenerateTeam(teamDefinition: any): { any }
	local team = table.clone(teamDefinition)
	local maxEnemies = team["Max Enemies"] or 1
	team["Max Enemies"] = nil

	local finalTeam = {}
	for _ = 1, maxEnemies do
		local chosenName = chooseRandom(team)
		if chosenName then
			local template = Characters[chosenName]
			if template then
				table.insert(finalTeam, CharacterClass.clone(template))
			end
		end
	end

	return finalTeam
end

return Enemy
