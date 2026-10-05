--!strict

return function()
	local BattleSystem = require(script.Parent.BattleSystem)

	local function makeBuddy(uuid: string, health: number, damage: number): any
		return {
			UUID = uuid,
			Stats = { Health = health, Damage = damage },
			Abilities = {},
			Gear = nil,
		}
	end

	describe("ProcessTurn", function()
		it("returns Win when the enemy team falls", function()
			local player = makeBuddy("player", 10, 10)
			local enemy = makeBuddy("enemy", 2, 1)
			local battle = BattleSystem.new({ player }, { enemy })
			expect(battle:ProcessTurn()).to.equal("Win")
		end)

		it("returns Loss when the player team falls", function()
			local player = makeBuddy("player", 2, 1)
			local enemy = makeBuddy("enemy", 10, 10)
			local battle = BattleSystem.new({ player }, { enemy })
			expect(battle:ProcessTurn()).to.equal("Loss")
		end)

		it("returns Draw when both last units fall in one turn", function()
			local player = makeBuddy("player", 1, 1)
			local enemy = makeBuddy("enemy", 1, 1)
			local battle = BattleSystem.new({ player }, { enemy })
			expect(battle:ProcessTurn()).to.equal("Draw")
		end)

		it("returns Undetermined while both sides still have units", function()
			local player = makeBuddy("player", 10, 1)
			local enemy = makeBuddy("enemy", 10, 1)
			local battle = BattleSystem.new({ player }, { enemy })
			expect(battle:ProcessTurn()).to.equal("Undetermined")
		end)

		it("removes a dead unit from its slot", function()
			local player = makeBuddy("player", 10, 10)
			local enemy = makeBuddy("enemy", 1, 1)
			local battle = BattleSystem.new({ player }, { enemy })
			battle:ProcessTurn()
			expect(battle.EnemyTeam[1]).to.equal(nil)
		end)
	end)
end
