--!strict

local ServerRemotes = game.ServerScriptService.ServerRemotes
local SharedRemotes = game.ReplicatedStorage.SharedRemotes

local DataStorage = require(script.Parent.ServerCore.GameDataStorage)
local TurnLogic = require(script.Parent.ServerCore.TurnLogic)

local TURN_TIMEOUT_SECONDS = 30
local ENEMY_PAUSE_SECONDS = 1.1
local RESULT_PAUSE_SECONDS = 1

local turnSignals: { [number]: BindableEvent } = {}

SharedRemotes.CombatHandle.OnServerEvent:Connect(function(player, ...)
	local signal = turnSignals[player.UserId]
	if signal then
		signal:Fire({ ... })
	end
end)

local function requestTurn(player: Player): { any }?
	local signal = Instance.new("BindableEvent")
	turnSignals[player.UserId] = signal

	local timeoutThread = task.delay(TURN_TIMEOUT_SECONDS, function()
		if turnSignals[player.UserId] == signal then
			signal:Fire(nil)
		end
	end)

	local answer = signal.Event:Wait()
	task.cancel(timeoutThread)

	if turnSignals[player.UserId] == signal then
		turnSignals[player.UserId] = nil
	end
	signal:Destroy()

	if typeof(answer) ~= "table" then
		return nil
	end
	return answer
end

local function takePlayerTurn(player: Player, entries: any, character: any): boolean
	SharedRemotes.CombatHandle:FireClient(player, "GuiSkills", character.Skills, true)

	local answer = requestTurn(player)
	if answer == nil then
		return false
	end
	if answer[1] == "Forefit" then
		return false
	end

	local skill = TurnLogic.getUsableSkill(character, answer[1])
	local targetEntry = TurnLogic.getTarget(entries, answer[2], answer[3])
	if not skill or not targetEntry then
		return true
	end
	if not TurnLogic.sideMatchesType(skill.Type, targetEntry[2]) then
		return true
	end

	skill.Function(character, targetEntry[1], entries)
	skill.CurCD = (skill.BaseCD or 0) + 1
	return true
end

local function takeEnemyTurn(player: Player, entries: any, character: any, random: Random)
	SharedRemotes.CombatHandle:FireClient(player, "GuiSkills", nil, false)
	task.wait(ENEMY_PAUSE_SECONDS)

	local skills = TurnLogic.getUsableSkills(character)
	if #skills == 0 then
		return
	end

	local skill = skills[random:NextInteger(1, #skills)]
	local targetSide = skill.Type == "Attack" and "Ally" or "Enemy"
	local targetEntry = TurnLogic.getFirstEntry(entries, targetSide)
	if not targetEntry then
		return
	end

	skill.Function(character, targetEntry[1], entries)
	skill.CurCD = (skill.BaseCD or 0) + 1
end

local function tickCooldowns(character: any)
	for _, skill in pairs(character.Skills or {}) do
		if (skill.CurCD or 0) > 0 and skill.Type ~= "Passive" then
			skill.CurCD -= 1
		end
	end
end

local function broadcastHealth(player: Player, entries: any)
	for index, entry in pairs(entries) do
		SharedRemotes.VisualHandle:FireClient(player, "CharUi", nil, "Update", {
			entry[2],
			index,
			entry[1],
		})
	end
end

local function removeDead(player: Player, entries: any)
	local folder = workspace.Battles:FindFirstChild(player.Name)
	for index, entry in pairs(entries) do
		local character = entry[1]
		if (character["Current Health"] or 0) <= 0 then
			if folder then
				local model = folder:FindFirstChild(character.Name, true)
				if model then
					model:Destroy()
				end
			end
			entries[index] = nil
		end
	end
end

local function battleLoop(player: Player, entries: any)
	local random = Random.new()

	while DataStorage.Battles[player.UserId] ~= nil do
		for index, entry in pairs(entries) do
			if DataStorage.Battles[player.UserId] == nil then
				return
			end

			local character = entry[1]
			SharedRemotes.CombatHandle:FireClient(player, "GuiTurn", string.format("%d%s", index, character.Name))

			if entry[2] == "Ally" then
				if not takePlayerTurn(player, entries, character) then
					ServerRemotes.BattlesEvent:Fire(player, "BattleLost")
					return
				end
			else
				takeEnemyTurn(player, entries, character, random)
			end

			broadcastHealth(player, entries)
			removeDead(player, entries)

			if TurnLogic.teamHealth(entries, "Ally") <= 0 then
				task.wait(RESULT_PAUSE_SECONDS)
				ServerRemotes.BattlesEvent:Fire(player, "BattleLost")
				return
			elseif TurnLogic.teamHealth(entries, "Enemy") <= 0 then
				task.wait(RESULT_PAUSE_SECONDS)
				ServerRemotes.BattlesEvent:Fire(player, "BattleWon")
				return
			end
		end

		for _, entry in pairs(entries) do
			tickCooldowns(entry[1])
		end
	end
end

ServerRemotes.BattlesEvent.Event:Connect(function(player: Player, eventType: string)
	if eventType ~= "BattleStarted" then
		return
	end
	local entries = DataStorage.Battles[player.UserId]
	if not entries then
		return
	end
	task.spawn(function()
		battleLoop(player, entries)
	end)
end)
