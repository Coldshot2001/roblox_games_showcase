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

local GearDB = {
	["1"] = {
		["Name"] = "Linked Sword",
		["Abilities"] = {
			["BeforeDamage"] = function(Battle, SelfIndex, Data, team)
				--Data[1] = UUID of the unit that triggered this
				--Data[2] = reference to current Damage (which is in index 1)
				local CurTeam
				if team == true then
					CurTeam = Battle.PlrTeam
				elseif team == false then
					CurTeam = Battle.EnemyTeam
				end
				local SelfUnit = CurTeam[SelfIndex]
				if not SelfUnit or SelfUnit.UUID ~= Data[1] then
					return
				end
				Data[2][1] += 3
			end,
		},
		["Description"] = "Attacks deal +3 extra damage.",
		["Model"] = Models["Linked Sword"]
	},
	["2"] = {
		["Name"] = "Trowel",
		["Abilities"] = {
			["BeforeDamage"] = function(Battle, SelfIndex, Data, team)
				--Data[1] = UUID of the unit that triggered this
				--Data[2] = reference to current Damage (which is in index 1)
				--This effect triggers when the enemy is about to deal damage and if we are about to be hit
				local PlayerTeam
				if team == true then
					PlayerTeam = Battle.PlrTeam
				elseif team == false then
					PlayerTeam = Battle.EnemyTeam
				end
				team = not team
				local EnmyTeam
				if team == true then
					EnmyTeam = Battle.PlrTeam
				elseif team == false then
					EnmyTeam = Battle.EnemyTeam
				end
				local FirstEnemy = EnmyTeam[1]
				if not FirstEnemy or FirstEnemy.UUID ~= Data[1] then
					return
				end
				if SelfIndex ~= 1 then return end
				Data[2][1] -= 20
				local SelfUnit = PlayerTeam[SelfIndex]
				if SelfUnit then
					SelfUnit.Gear = nil
				end
			end
		},
		["Description"] = "Take 20 less damage, once.",
		["Model"] = Models.Trowel
	},
}

local ProxyGearDB = {}
setmetatable(ProxyGearDB, {
	__index = function(_, key)
		local originalValue = GearDB[key]
		if originalValue ~= nil then
			return deepcopy(originalValue)
		end
		return nil
	end,

	__newindex = function(_, _, _)
		error("Cannot modify gear database!")
	end
})

return ProxyGearDB
