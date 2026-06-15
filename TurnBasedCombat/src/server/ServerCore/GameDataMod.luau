local Characters = require(game.ServerStorage.CharactersDatabase).Characters --TODO: Remove this once we add the ability to get characters
local DataStorage = require(script.Parent.GameDataStorage)
local Data = {}
Data.__index = Data

local function shallowCopy(original)
	local copy = {}
	for key, value in pairs(original) do
		copy[key] = value
	end
	return copy
end --TODO: Remove this once we add the ability to get characters

function Data:Create(Player)
	local PlayerData = {
		Team = {}, -- the units in the player's team
		InBattle = { false, nil }, --in battle?, pointer to the battle in GameDataStorage
		Inventory = {
			Units = { shallowCopy(Characters["Claw Dude"]), shallowCopy(Characters["Blue Gun Dude"]) },
			Equipment = {},
		},
		Quests = { CurrentQuests = {}, FinishedQuests = {} },
		Currencies = {
			Gold = 0,
			Crystal = 50,
		},
		Zones = { "None", {} }, --Current zone you're in, zones you've visited before(will probably be used for fast travel or smtn)
		Costume = "None", --The current unit you look like (you can only costume as certain units, there is a default unit if you have none equipped)
	}

	return PlayerData
end

function Data:BattleCreate(Player, enemyTeam)
	if enemyTeam then
		local allyteam, enemyteam = {}, {}
		for _, char in pairs(DataStorage.GameData[Player.Name]["Team"]) do
			table.insert(allyteam, char.Name)
		end
		for _, char in pairs(enemyTeam) do
			table.insert(enemyteam, char.Name)
		end
		local battletable = {
			["Allies"] = allyteam,
			["Enemies"] = enemyteam,
		}
		return battletable
	else
		warn(string.format("No enemies provided to create battle for player %q", Player.Name))
	end
end

return Data
