--item with ID 0 is NIL, empty space

local module = {
	["1"] = {
		["Name"] = "Magic Spark",
		["Type"] = "Generator",
		["Cost"] = 10, --Currency Cost
		["Durability"] = 15, --Default settings, items lose 1 durability per tick
		["Mana"] = 1, --Gained Mana Per Tick
		["Flux"] = 1, --Gained Flux Per Tick
		["Model"] = "Magic Spark" --The model will always be found in RepStorage.Models 
	},
	["2"] = {
		["Name"] = "Flux Well",
		["Type"] = "Cooler",
		["Cost"] = 50,
		["Capacity"] = 80, --How much flux it can store
		["Transfer"] = 4, --How much flux it deletes from itself
		["Model"] = "Flux Well"
	},
	["3"] = {
		["Name"] = "Mana Concentrator",
		["Type"] = "Amplifier",
		["Cost"] = 500,
		["Durability"] = 100,
		["Bonus"] = 1.05, --Increases output of mana from a generator by its bonus for as long as its still alive, in this case, 5% (number *= Item["Bonus"])
	},
	["4"] = {
		["Name"] = "Cauldron Enlargening Talisman",
		["Type"] = "ManaUpgrade",
		["Cost"] = 1e3,
		["Bonus"] = 100, --adds 100 more mana space to cauldron
		["Capacity"] = 10,
	},
	["5"] = {
		["Name"] = "Flux Vial",
		["Type"] = "FluxStorage",
		["Cost"] = 500,
		["Capacity"] = 2e3,
		--Just holds Flux, can be taken out of
	},
	["6"] = {
		["Name"] = "Flux Dimensional Pocket",
		["Type"] = "FluxUpgrade",
		["Cost"] = 1e3,
		["Bonus"] = 100, --adds 100 more flux space to flux storage
	},
	["7"] = {
		["Name"] = "Flux Vacuum",
		["Type"] = "FluxInlet",
		["Cost"] = 160,
		["Transfer"] = 16 --takes 16 flux out of adjacent stuff and puts it in the flux storage
 	},
	["8"] = {
		["Name"] = "Flux Dispenser", --should look like an air humidifer
		["Type"] = "FluxOutlet",
		["Cost"] = 160,
		["Transfer"] = 16 --opposite of inlet
	},
	["9"] = {
		["Name"] = "Flux Balancer",
		["Type"] = "Exchanger",
		["Cost"] = 160,
		["Durability"] = 320,
	},
}

for key, item in pairs(module) do
	item["ItemID"] = key
end

table.freeze(module)
return module
