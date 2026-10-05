--!strict

return function()
	local NeighbourLogic = require(script.Parent.NeighbourLogic)

	local generatorDefinition = { Type = "Generator", Flux = 10, Mana = 1 }

	local function makeCooler(maxCapacity: number): any
		return {
			ItemID = "2",
			MaxCapacity = maxCapacity,
			CurCapacity = 0,
			CurIntake = 0,
		}
	end

	local function groupsOf(coolers: { any }): any
		return {
			Cooler = { count = #coolers, items = coolers },
		}
	end

	describe("Check", function()
		it("gives all the flux to one cooler", function()
			local cooler = makeCooler(100)
			local _, generateFlux = NeighbourLogic.Check(generatorDefinition, groupsOf({ cooler }))
			expect(cooler.CurIntake).to.equal(10)
			expect(cooler.CurCapacity).to.equal(10)
			expect(generateFlux).to.equal(false)
		end)

		it("splits the flux between two coolers", function()
			local first = makeCooler(100)
			local second = makeCooler(100)
			NeighbourLogic.Check(generatorDefinition, groupsOf({ first, second }))
			expect(first.CurIntake).to.equal(5)
			expect(second.CurIntake).to.equal(5)
		end)

		it("splits the flux between three coolers", function()
			local coolers = { makeCooler(100), makeCooler(100), makeCooler(100) }
			NeighbourLogic.Check(generatorDefinition, groupsOf(coolers))
			expect(coolers[1].CurIntake).to.equal(3.33)
			expect(coolers[2].CurIntake).to.equal(3.33)
			expect(coolers[3].CurIntake).to.equal(3.33)
		end)

		it("stops flux generation while the generator serves a cooler", function()
			local generateMana, generateFlux =
				NeighbourLogic.Check(generatorDefinition, groupsOf({ makeCooler(100) }))
			expect(generateMana).to.equal(true)
			expect(generateFlux).to.equal(false)
		end)

		it("never fills a cooler past its capacity", function()
			local cooler = makeCooler(4)
			cooler.CurCapacity = 3
			NeighbourLogic.Check(generatorDefinition, groupsOf({ cooler }))
			expect(cooler.CurCapacity).to.equal(4)
		end)

		it("keeps the generator running when there are no neighbours", function()
			local generateMana, generateFlux = NeighbourLogic.Check(generatorDefinition, {})
			expect(generateMana).to.equal(true)
			expect(generateFlux).to.equal(true)
		end)
	end)
end
