--!strict

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local CharactersDatabase = require(game.ServerStorage.CharactersDatabase).Characters
local CharacterClass = require(game.ServerStorage.CharacterClass)

local STORE_NAME = "TurnBasedCombatPlayerData_v1"
local MAX_ATTEMPTS = 3
local RETRY_BASE_SECONDS = 2
local SCHEMA_VERSION = 1

local Storage = {}

Storage.GameData = {} -- [userId] = PlayerData
Storage.Battles = {} -- [userId] = sorted battle table

local store: any = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn(string.format("GameDataStorage: DataStore %q is not available (%s)", STORE_NAME, tostring(result)))
	end
end

local function retry(operation: () -> any): (boolean, any)
	local lastError: any = "DataStore is not available"
	for attempt = 1, MAX_ATTEMPTS do
		if store ~= nil then
			local ok, result = pcall(operation)
			if ok then
				return true, result
			end
			lastError = result
		end
		if attempt < MAX_ATTEMPTS then
			task.wait(RETRY_BASE_SECONDS * attempt)
		end
	end
	return false, lastError
end

local function keyFor(player: Player): string
	return string.format("player_%d", player.UserId)
end

local function buildSavePayload(playerData: any): any
	local units = {}
	for index, unit in ipairs(playerData.Inventory.Units) do
		units[index] = {
			name = unit.Name,
			level = unit.Level,
			currentHealth = unit["Current Health"],
		}
	end

	local team = {}
	for _, unit in ipairs(playerData.Team) do
		local index = table.find(playerData.Inventory.Units, unit)
		if index then
			table.insert(team, index)
		end
	end

	return {
		version = SCHEMA_VERSION,
		currencies = {
			Gold = playerData.Currencies.Gold,
			Crystal = playerData.Currencies.Crystal,
		},
		zones = { playerData.Zones[1], playerData.Zones[2] },
		costume = playerData.Costume,
		units = units,
		team = team,
	}
end

local function rebuildUnit(saved: any): any?
	if typeof(saved) ~= "table" or typeof(saved.name) ~= "string" then
		return nil
	end
	local template = CharactersDatabase[saved.name]
	if not template then
		return nil
	end

	local unit = CharacterClass.clone(template)
	if typeof(saved.level) == "number" then
		unit.Level = saved.level
	end
	if typeof(saved.currentHealth) == "number" then
		unit["Current Health"] = math.clamp(saved.currentHealth, 0, unit.Health)
	end
	return unit
end

local function buildPlayerData(saved: any): any?
	if typeof(saved) ~= "table" then
		return nil
	end

	local units = {}
	for _, savedUnit in ipairs(saved.units or {}) do
		local unit = rebuildUnit(savedUnit)
		if unit then
			table.insert(units, unit)
		end
	end
	if #units == 0 then
		return nil
	end

	local team = {}
	for _, index in ipairs(saved.team or {}) do
		local unit = units[index]
		if unit and not table.find(team, unit) then
			table.insert(team, unit)
		end
	end
	if #team == 0 then
		table.insert(team, units[1])
	end

	local currencies = { Gold = 0, Crystal = 0 }
	if typeof(saved.currencies) == "table" then
		currencies.Gold = math.max(0, tonumber(saved.currencies.Gold) or 0)
		currencies.Crystal = math.max(0, tonumber(saved.currencies.Crystal) or 0)
	end

	local zones = { "None", {} }
	if typeof(saved.zones) == "table" then
		if typeof(saved.zones[1]) == "string" then
			zones[1] = saved.zones[1]
		end
		if typeof(saved.zones[2]) == "table" then
			zones[2] = saved.zones[2]
		end
	end

	return {
		Team = team,
		InBattle = { false, nil },
		Inventory = { Units = units, Equipment = {} },
		Quests = { CurrentQuests = {}, FinishedQuests = {} },
		Currencies = currencies,
		Zones = zones,
		Costume = typeof(saved.costume) == "string" and saved.costume or "None",
	}
end

function Storage.LoadPlayer(player: Player): any?
	local ok, saved = retry(function()
		return store:GetAsync(keyFor(player))
	end)
	if not ok then
		return nil
	end
	return buildPlayerData(saved)
end

function Storage.SavePlayer(player: Player): boolean
	local playerData = Storage.GameData[player.UserId]
	if not playerData then
		return false
	end

	local payload = buildSavePayload(playerData)
	local ok, err = retry(function()
		store:UpdateAsync(keyFor(player), function()
			return payload
		end)
	end)
	if not ok then
		warn(string.format("GameDataStorage: could not save %d (%s)", player.UserId, tostring(err)))
	end
	return ok
end

function Storage.SaveAll()
	for userId in pairs(Storage.GameData) do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			Storage.SavePlayer(player)
		end
	end
end

return Storage
