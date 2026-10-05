--!strict

local DataStoreService = game:GetService("DataStoreService")

local STORE_NAME = "FactorioPlayerData_v1"
local MAX_ATTEMPTS = 3
local RETRY_BASE_SECONDS = 2

local DataService = {}

local store: any = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn(string.format("DataService: DataStore %q is not available (%s)", STORE_NAME, tostring(result)))
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

function DataService.Load(player: Player): (boolean, any)
	return retry(function()
		return store:GetAsync(keyFor(player))
	end)
end

function DataService.Save(player: Player, payload: any): boolean
	local ok, err = retry(function()
		store:UpdateAsync(keyFor(player), function()
			return payload
		end)
	end)
	if not ok then
		warn(string.format("DataService: could not save %d (%s)", player.UserId, tostring(err)))
	end
	return ok
end

return DataService
