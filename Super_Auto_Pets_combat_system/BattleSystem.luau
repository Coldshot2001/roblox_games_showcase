local function ShiftUnits(Table)
	if #Table < 1 then return end
	while Table[1] == nil do
		for i = 1, 5 do
			if Table[i+1] == nil or Table[i] ~= nil then continue end
			Table[i] = Table[i+1]
			Table[i+1] = nil
		end
	end
end

local BattleSystem = {}
BattleSystem.__index = BattleSystem

function BattleSystem.new(PlrTeam, EnemyTeam)
	local newBattle = {}
	newBattle.PlrTeam = PlrTeam
	newBattle.EnemyTeam = EnemyTeam
	newBattle.CurrentTurn = 0
	setmetatable(newBattle, BattleSystem)

	return newBattle
end

function BattleSystem:FireEvent(Event, ...)
	local Data = {...}
	for i = 1, 5 do
		local buddy = self.PlrTeam[i]
		if buddy == nil then continue end
		local EventAbility = buddy.Abilities[Event]
		if EventAbility then
			EventAbility(self, i, Data, true) --true = is part of plrTeam
		end
		if buddy.Gear == nil then continue end
		local GearAbility = buddy.Gear.Abilities[Event]
		if GearAbility then
			GearAbility(self, i, Data, true)
		end
	end
	for i = 1, 5 do
		local buddy = self.EnemyTeam[i]
		if buddy == nil then continue end
		local EventAbility = buddy.Abilities[Event]
		if EventAbility then
			EventAbility(self, i, Data, false) --false = is part of enemyteam
		end
		if buddy.Gear == nil then continue end
		local GearAbility = buddy.Gear.Abilities[Event]
		if GearAbility then
			GearAbility(self, i, Data, false)
		end
	end
end

function BattleSystem:Attack(source, target)
	if target.Stats.Health <= 0 then return end
	
	local OldHealth = target.Stats.Health
	local Damage = {source.Stats.Damage}
	self:FireEvent("BeforeDamage", source.UUID, Damage)
	Damage[1] = Damage[1] < 0 and 0 or Damage[1]
	target.Stats.Health -= Damage[1]
	
	if target.Stats.Health ~= OldHealth then
		self:FireEvent("Hurt", target.UUID)
	end
	self:FireEvent("AfterAttack", source.UUID)
	if target.Stats.Health <= 0 then
		self:FireEvent("Died", target.UUID)
		self:FireEvent("Kill", source.UUID, target.UUID)
	end
end

function BattleSystem:DealDamage(source, target, DMG)
	if target.Stats.Health <= 0 then return end

	local OldHealth = target.Stats.Health
	local Damage = {DMG}
	self:FireEvent("BeforeDamage", source.UUID, Damage)
	Damage[1] = Damage[1] < 0 and 0 or Damage[1]
	target.Stats.Health -= Damage[1]

	if target.Stats.Health ~= OldHealth then
		self:FireEvent("Hurt", target.UUID)
	end
	if target.Stats.Health <= 0 then
		self:FireEvent("Died", target.UUID)
		self:FireEvent("Kill", source.UUID, target.UUID)
	end
end

function BattleSystem:ProcessTurn()
	print("turn start")
	print(self.PlrTeam) --debug
	print(self.EnemyTeam)
	print("---")
	
	if #self.EnemyTeam <= 0 and #self.PlrTeam > 0 then
		return "Win"
	elseif #self.PlrTeam <= 0 and #self.EnemyTeam > 0 then
		return "Loss"
	elseif #self.PlrTeam <= 0 and #self.EnemyTeam <= 0 then
		return "Draw"
	end
	
	self.CurrentTurn += 1
	
	if self.CurrentTurn == 1 then
		self:FireEvent("BattleStart")
	end
	
	ShiftUnits(self.PlrTeam)
	ShiftUnits(self.EnemyTeam)
	
	local Buddy1 = self.PlrTeam[1]
	local Buddy2 = self.EnemyTeam[1]
	
	self:FireEvent("BeforeAttack", Buddy1.UUID)
	self:FireEvent("BeforeAttack", Buddy2.UUID)
	self:Attack(Buddy1, Buddy2)
	self:Attack(Buddy2, Buddy1)
	
	for i = 1, 5 do
		local buddy = self.PlrTeam[i]
		if buddy == nil then continue end
		if buddy.Stats.Health <= 0 then
			self.PlrTeam[i] = nil
		end
	end
	for i = 1, 5 do
		local buddy = self.EnemyTeam[i]
		if buddy == nil then continue end
		if buddy.Stats.Health <= 0 then
			self.EnemyTeam[i] = nil
		end
	end
	
	print("turn end")
	print(self.PlrTeam) --debug
	print(self.EnemyTeam)
	print("---")
	
	if #self.EnemyTeam <= 0 and #self.PlrTeam > 0 then
		return "Win"
	elseif #self.PlrTeam <= 0 and #self.EnemyTeam > 0 then
		return "Loss"
	elseif #self.PlrTeam <= 0 and #self.EnemyTeam <= 0 then
		return "Draw"
	else
		return "Undetermined"
	end
end

return BattleSystem
