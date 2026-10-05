--!strict

return function()
	local TurnLogic = require(script.Parent.TurnLogic)

	local function makeCharacter()
		return {
			Name = "Claw Dude",
			Health = 9,
			["Current Health"] = 9,
			Skills = {
				[1] = {
					Name = "Attack",
					Type = "Attack",
					CurCD = 0,
					BaseCD = 0,
				},
				[2] = {
					Name = "Heal",
					Type = "Support",
					CurCD = 2,
					BaseCD = 2,
				},
				[3] = {
					Name = "Passive",
					Type = "Passive",
					CurCD = -1,
					BaseCD = -1,
				},
			},
		}
	end

	local function makeEntries()
		local ally = makeCharacter()
		local enemy = makeCharacter()
		enemy.Name = "Cyber Dawg"
		return {
			[1] = { ally, "Ally" },
			[2] = { enemy, "Enemy" },
		}
	end

	describe("getUsableSkill", function()
		it("returns an off cooldown skill", function()
			local skill = TurnLogic.getUsableSkill(makeCharacter(), 1)
			expect(skill).never.to.equal(nil)
			expect(skill.Type).to.equal("Attack")
		end)

		it("rejects a skill that is on cooldown", function()
			expect(TurnLogic.getUsableSkill(makeCharacter(), 2)).to.equal(nil)
		end)

		it("rejects a passive", function()
			expect(TurnLogic.getUsableSkill(makeCharacter(), 3)).to.equal(nil)
		end)

		it("rejects an index that is not a number", function()
			expect(TurnLogic.getUsableSkill(makeCharacter(), "1")).to.equal(nil)
		end)

		it("rejects a fractional index", function()
			expect(TurnLogic.getUsableSkill(makeCharacter(), 1.5)).to.equal(nil)
		end)

		it("rejects an index that does not exist", function()
			expect(TurnLogic.getUsableSkill(makeCharacter(), 99)).to.equal(nil)
		end)
	end)

	describe("getTarget", function()
		it("returns the entry when the name and index match", function()
			local entry = TurnLogic.getTarget(makeEntries(), "Cyber Dawg", 2)
			expect(entry).never.to.equal(nil)
			expect(entry[2]).to.equal("Enemy")
		end)

		it("rejects a name that does not match the index", function()
			expect(TurnLogic.getTarget(makeEntries(), "Claw Dude", 2)).to.equal(nil)
		end)

		it("rejects an index that does not exist", function()
			expect(TurnLogic.getTarget(makeEntries(), "Claw Dude", 50)).to.equal(nil)
		end)

		it("rejects a target name that is not a string", function()
			expect(TurnLogic.getTarget(makeEntries(), 2, 2)).to.equal(nil)
		end)
	end)

	describe("sideMatchesType", function()
		it("lets an attack hit the other side", function()
			expect(TurnLogic.sideMatchesType("Attack", "Enemy")).to.equal(true)
		end)

		it("keeps an attack off the own side", function()
			expect(TurnLogic.sideMatchesType("Attack", "Ally")).to.equal(false)
		end)

		it("lets support help the own side", function()
			expect(TurnLogic.sideMatchesType("Support", "Ally")).to.equal(true)
		end)

		it("keeps support off the other side", function()
			expect(TurnLogic.sideMatchesType("Support", "Enemy")).to.equal(false)
		end)
	end)

	describe("getUsableSkills", function()
		it("returns only skills that are off cooldown", function()
			local usable = TurnLogic.getUsableSkills(makeCharacter())
			expect(#usable).to.equal(1)
		end)

		it("returns an empty list when everything is on cooldown", function()
			local character = makeCharacter()
			character.Skills = {
				[1] = { Type = "Attack", CurCD = 1 },
				[2] = { Type = "Passive", CurCD = -1 },
			}
			expect(#TurnLogic.getUsableSkills(character)).to.equal(0)
		end)
	end)

	describe("teamHealth", function()
		it("adds the health of one side", function()
			local entries = makeEntries()
			expect(TurnLogic.teamHealth(entries, "Ally")).to.equal(9)
			expect(TurnLogic.teamHealth(entries, "Enemy")).to.equal(9)
		end)

		it("returns zero for an empty side", function()
			expect(TurnLogic.teamHealth({}, "Ally")).to.equal(0)
		end)
	end)
end
