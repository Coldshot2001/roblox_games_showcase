--!strict

local TEAM_SIZE = 5

local BattleSystem = {}
BattleSystem.__index = BattleSystem

local function teamCount(team: any): number
	local count = 0
	for index = 1, TEAM_SIZE do
		if team[index] ~= nil then
			count += 1
		end
	end
	return count
end

local function compactTeam(team: any)
	local alive = {}
	for index = 1, TEAM_SIZE do
		local unit = team[index]
		if unit ~= nil then
			table.insert(alive, unit)
		end
	end
	for index = 1, TEAM_SIZE do
		team[index] = alive[index]
	end
end

function BattleSystem.new(plrTeam: any, enemyTeam: any): any
	local newBattle = {}
	newBattle.PlrTeam = plrTeam
	newBattle.EnemyTeam = enemyTeam
	newBattle.CurrentTurn = 0
	return setmetatable(newBattle, BattleSystem)
end

function BattleSystem:FireEvent(eventName: string, ...)
	local data = { ... }

	for index = 1, TEAM_SIZE do
		local buddy = self.PlrTeam[index]
		if buddy == nil then
			continue
		end
		local eventAbility = buddy.Abilities[eventName]
		if eventAbility then
			eventAbility(self, index, data, true) --true = is part of plrTeam
		end
		if buddy.Gear == nil then
			continue
		end
		local gearAbility = buddy.Gear.Abilities[eventName]
		if gearAbility then
			gearAbility(self, index, data, true)
		end
	end

	for index = 1, TEAM_SIZE do
		local buddy = self.EnemyTeam[index]
		if buddy == nil then
			continue
		end
		local eventAbility = buddy.Abilities[eventName]
		if eventAbility then
			eventAbility(self, index, data, false) --false = is part of enemyteam
		end
		if buddy.Gear == nil then
			continue
		end
		local gearAbility = buddy.Gear.Abilities[eventName]
		if gearAbility then
			gearAbility(self, index, data, false)
		end
	end
end

function BattleSystem:Attack(source: any, target: any)
	if target.Stats.Health <= 0 then
		return
	end

	local oldHealth = target.Stats.Health
	local damage = { source.Stats.Damage }
	self:FireEvent("BeforeDamage", source.UUID, damage)
	damage[1] = damage[1] < 0 and 0 or damage[1]
	target.Stats.Health -= damage[1]

	if target.Stats.Health ~= oldHealth then
		self:FireEvent("Hurt", target.UUID)
	end
	self:FireEvent("AfterAttack", source.UUID)
	if target.Stats.Health <= 0 then
		self:FireEvent("Died", target.UUID)
		self:FireEvent("Kill", source.UUID, target.UUID)
	end
end

function BattleSystem:DealDamage(source: any, target: any, damageAmount: number)
	if target.Stats.Health <= 0 then
		return
	end

	local oldHealth = target.Stats.Health
	local damage = { damageAmount }
	self:FireEvent("BeforeDamage", source.UUID, damage)
	damage[1] = damage[1] < 0 and 0 or damage[1]
	target.Stats.Health -= damage[1]

	if target.Stats.Health ~= oldHealth then
		self:FireEvent("Hurt", target.UUID)
	end
	if target.Stats.Health <= 0 then
		self:FireEvent("Died", target.UUID)
		self:FireEvent("Kill", source.UUID, target.UUID)
	end
end

function BattleSystem:ProcessTurn(): string
	if teamCount(self.EnemyTeam) <= 0 and teamCount(self.PlrTeam) > 0 then
		return "Win"
	elseif teamCount(self.PlrTeam) <= 0 and teamCount(self.EnemyTeam) > 0 then
		return "Loss"
	elseif teamCount(self.PlrTeam) <= 0 and teamCount(self.EnemyTeam) <= 0 then
		return "Draw"
	end

	self.CurrentTurn += 1

	if self.CurrentTurn == 1 then
		self:FireEvent("BattleStart")
	end

	compactTeam(self.PlrTeam)
	compactTeam(self.EnemyTeam)

	local buddy1 = self.PlrTeam[1]
	local buddy2 = self.EnemyTeam[1]

	self:FireEvent("BeforeAttack", buddy1.UUID)
	self:FireEvent("BeforeAttack", buddy2.UUID)
	self:Attack(buddy1, buddy2)
	self:Attack(buddy2, buddy1)

	for index = 1, TEAM_SIZE do
		local buddy = self.PlrTeam[index]
		if buddy ~= nil and buddy.Stats.Health <= 0 then
			self.PlrTeam[index] = nil
		end
		local enemy = self.EnemyTeam[index]
		if enemy ~= nil and enemy.Stats.Health <= 0 then
			self.EnemyTeam[index] = nil
		end
	end

	local playerAlive = teamCount(self.PlrTeam)
	local enemyAlive = teamCount(self.EnemyTeam)
	if enemyAlive <= 0 and playerAlive > 0 then
		return "Win"
	elseif playerAlive <= 0 and enemyAlive > 0 then
		return "Loss"
	elseif playerAlive <= 0 and enemyAlive <= 0 then
		return "Draw"
	end

	return "Undetermined"
end

return BattleSystem
