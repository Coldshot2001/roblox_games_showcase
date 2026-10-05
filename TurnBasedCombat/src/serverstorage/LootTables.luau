--!strict

local Characters = require(game.ServerStorage.CharactersDatabase).Characters

local Tables = {
	["Rarities"] = {
		{ "Common", 80 },
		{ "Uncommon", 75 },
		{ "Rare", 66 },
		{ "Super", 46 },
		{ "Legendary", 32 },
	},
	["Common"] = {
		{ Characters["Punching Dummy"], 100 },
	},
	["Uncommon"] = {
		{ Characters["Cyber Dawg"], 100 },
	},
	["Rare"] = {
		{ Characters["Palace Sentry"], 100 },
	},
	["Super"] = {
		{ Characters["Blue Gun Dude"], 100 },
	},
	["Legendary"] = {
		{ Characters["Claw Dude"], 100 },
	},
}

return Tables
