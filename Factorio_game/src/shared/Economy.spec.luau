--!strict

return function()
	local Economy = require(script.Parent.Economy)

	local generator = { Type = "Generator", Cost = 100 }
	local cooler = { Type = "Cooler", Cost = 50 }

	describe("getSellRefund", function()
		it("pays the full cost for a non generator", function()
			local refund = Economy.getSellRefund({ ItemID = "2" }, cooler)
			expect(refund).to.equal(50)
		end)

		it("scales the generator refund with its durability", function()
			local item = { ItemID = "1", MaxDurability = 10, CurDurability = 5 }
			expect(Economy.getSellRefund(item, generator)).to.equal(50)
		end)

		it("never pays more than the full cost", function()
			local item = { ItemID = "1", MaxDurability = 10, CurDurability = 9999 }
			expect(Economy.getSellRefund(item, generator)).to.equal(100)
		end)

		it("pays nothing for a broken generator", function()
			local item = { ItemID = "1", MaxDurability = 10, CurDurability = 0 }
			expect(Economy.getSellRefund(item, generator)).to.equal(0)
		end)

		it("pays nothing when the durability data is missing", function()
			local item = { ItemID = "1" }
			expect(Economy.getSellRefund(item, generator)).to.equal(0)
		end)

		it("pays nothing when the cost is not a number", function()
			local brokenDefinition = { Type = "Cooler", Cost = "lots" }
			expect(Economy.getSellRefund({ ItemID = "2" }, brokenDefinition)).to.equal(0)
		end)
	end)
end
