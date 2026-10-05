--!strict

local Characters = require(game.ServerStorage.CharactersDatabase).Characters
local CharacterClass = require(game.ServerStorage.CharacterClass)
local DataStorage = require(script.Parent.GameDataStorage)

local Data = {}
Data.__index = Data

function Data:Create(_player: Player): any
	return {
		Team = {},
		InBattle = { false, nil },
		Inventory = {
			Units = {
				CharacterClass.clone(Characters["Claw Dude"]),
				CharacterClass.clone(Characters["Blue Gun Dude"]),
			},
			Equipment = {},
		},
		Quests = { CurrentQuests = {}, FinishedQuests = {} },
		Currencies = {
			Gold = 0,
			Crystal = 50,
		},
		Zones = { "None", {} },
		Costume = "None",
	}
end

function Data:BattleCreate(player: Player, enemyTeam: any): any?
	local playerData = DataStorage.GameData[player.UserId]
	if not playerData then
		warn(string.format("GameDataMod: no data for player %d", player.UserId))
		return nil
	end

	local allies = {}
	for _, character in ipairs(playerData.Team) do
		table.insert(allies, character.Name)
	end

	local enemies = {}
	for _, character in ipairs(enemyTeam) do
		table.insert(enemies, character.Name)
	end

	return { Allies = allies, Enemies = enemies }
end

return Data
