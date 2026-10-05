local Models = game:GetService("ReplicatedStorage"):WaitForChild("Models")

local function deepcopy(orig)
	local orig_type = type(orig)
	local copy
	if orig_type == 'table' then
		copy = {}
		for orig_key, orig_value in next, orig, nil do
			copy[deepcopy(orig_key)] = deepcopy(orig_value)
		end
		setmetatable(copy, deepcopy(getmetatable(orig)))
	else -- number, string, boolean, etc
		copy = orig
	end
	return copy
end

local BuddyDB = {
	["1"] = {
		["Name"] = "Guest 101",
		["Stats"] = {
			["Health"] = 2,
			["Damage"] = 2
		},
		["Abilities"] = {},
		["Description"] = "Not too strong, not too weak...",
		["Model"] = Models.Guest
	},
	["2"] = {
		["Name"] = "Noob",
		["Stats"] = {
			["Health"] = 1,
			["Damage"] = 1
		},
		["Abilities"] = {
			["Died"] = function(Battle, SelfIndex, Data, team)
				local CurTeam
				if team == true then
					CurTeam = Battle.PlrTeam
				elseif team == false then
					CurTeam = Battle.EnemyTeam
				end

				local SelfUnit = CurTeam and CurTeam[SelfIndex]
				if not SelfUnit or SelfUnit.UUID ~= Data[1] then
					return
				end

				-- Count the living units by hand, the team array has holes.
				local living = {}
				for index = 1, 5 do
					if CurTeam[index] ~= nil then
						table.insert(living, index)
					end
				end
				if #living <= 1 then
					return
				end

				local RandomBuddy = SelfIndex
				while RandomBuddy == SelfIndex do
					RandomBuddy = living[math.random(1, #living)]
				end
				CurTeam[RandomBuddy].Stats.Health += 1
				CurTeam[RandomBuddy].Stats.Damage += 1
			end,
		},
		["Description"] = "On Wipeout -> Give 1 random buddy +1 HP/+1 ATK",
		["Model"] = Models.Noob
	}
}

local ProxyBuddyDB = {}
setmetatable(ProxyBuddyDB, {
	__index = function(_, key)
		local originalValue = BuddyDB[key]
		if originalValue ~= nil then
			return deepcopy(originalValue)
		end
		return nil
	end,

	__newindex = function(_, _, _)
		error("Cannot modify unit database!")
	end
})

return ProxyBuddyDB
