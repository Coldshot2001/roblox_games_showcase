local ServerRemotes = game.ServerScriptService.ServerRemotes
local SharedRemotes = game.ReplicatedStorage.SharedRemotes
local DataStorage = require(script.Parent.ServerCore.GameDataStorage)

local function BattleLoop(player, Chars, Randomness)
	if not DataStorage.Battles[player.Name] then
		return
	end
	for Index, Character in pairs(Chars) do
		game.ReplicatedStorage.SharedRemotes.CombatHandle:FireClient(
			player,
			"GuiTurn",
			string.format("%i%s", Index, Character[1].Name)
		)
		if Character[2] == "Ally" then
			SharedRemotes.CombatHandle:FireClient(player, "GuiSkills", Character[1].Skills, true)
			local player, skill, targetName, Index = SharedRemotes.CombatHandle.OnServerEvent:Wait()
			if skill == "Forefit" then
				ServerRemotes.BattlesEvent:Fire(player, "BattleLost")
				SharedRemotes.CombatHandle:FireClient(player, "End")
				return
			end
			local target
			local skill = Character[1].Skills[skill]
			for i, b in pairs(Chars) do
				if b[1]["Name"] == targetName and i == Index then
					target = b[1]
					break
				end
			end
			--TODO: (Somehow) check for the target's passives and act according to them
			if target then
				skill["Function"](Character[1], target, Chars)
				skill["CurCD"] = skill["BaseCD"] + 1
			end
		else
			SharedRemotes.CombatHandle:FireClient(player, "GuiSkills", nil, false)
			wait(1.1)
			--choosing moves and targets will be done more strategically in the future but for now its just random
			local skill
			repeat
				skill = Character[1].Skills[Randomness:NextInteger(1, #Character[1].Skills)]
			until skill.Type ~= "Passive" and skill["CurCD"] == 0

			local target
			if skill.Type == "Attack" then
				for _, Char in pairs(Chars) do
					if Char[2] == "Ally" then
						target = Char[1]
						break
					end
				end
			elseif skill.Type == "Support" then
				for _, Char in pairs(Chars) do
					if Char[2] == "Enemy" then
						target = Char[1]
						break
					end
				end
			end

			skill["Function"](Character[1], target, Chars)
			skill["CurCD"] = skill["BaseCD"] + 1
		end

		for _, Skill in pairs(Character[1].Skills) do
			if Skill["CurCD"] > 0 and Skill["Type"] ~= "Passive" then
				Skill["CurCD"] -= 1
			end
		end

		local AllyTeamHP, EnemyTeamHP = 0, 0
		for Index, Character in pairs(Chars) do
			game.ReplicatedStorage.SharedRemotes.VisualHandle:FireClient(
				player,
				"CharUi",
				nil,
				"Update",
				{ Character[2], Index, Character[1] }
			)
			if Character[1]["Current Health"] <= 0 then
				local checked = {}
				local model
				if Character[2] == "Enemy" then
					for i = 1, #DataStorage.GameData[player.Name]["InBattle"][2]["Enemies"], 1 do
						if not table.find(checked, i) then
							model = workspace.Battles[player.Name]["Enemy" .. i]:FindFirstChild(Character[1].Name)
							table.insert(checked, i)
							if model then
								DataStorage.GameData[player.Name]["InBattle"][2]["Enemies"][i] = nil
								break
							end
						end
					end
				else
					for i = 1, #DataStorage.GameData[player.Name]["InBattle"][2]["Allies"], 1 do
						if not table.find(checked, i) then
							model = workspace.Battles[player.Name]["Ally" .. i]:FindFirstChild(Character[1].Name)
							table.insert(checked, i)
							if model then
								DataStorage.GameData[player.Name]["InBattle"][2]["Allies"][i] = nil
								break
							end
						end
					end
				end
				if model then
					model.Parent = nil --TODO: change to death animation
				end
				Chars[Index] = nil
			end

			if Character[2] == "Ally" then
				AllyTeamHP += Character[1]["Current Health"]
			else
				EnemyTeamHP += Character[1]["Current Health"]
			end
		end
		if AllyTeamHP <= 0 then
			wait(1)
			ServerRemotes.BattlesEvent:Fire(player, "BattleLost")
			SharedRemotes.CombatHandle:FireClient(player, "End")
			return
		elseif EnemyTeamHP <= 0 then
			wait(1)
			ServerRemotes.BattlesEvent:Fire(player, "BattleWon")
			SharedRemotes.CombatHandle:FireClient(player, "End")
			return
		end
	end
	BattleLoop(player, Chars, Randomness)
end

ServerRemotes.BattlesEvent.Event:Connect(function(player, Type, EnemyName)
	if Type == "BattleStarted" then
		local RandomSeed = Random.new(math.random(0, #EnemyName))
		BattleLoop(player, DataStorage.Battles[player.Name], RandomSeed)
	end
end)
