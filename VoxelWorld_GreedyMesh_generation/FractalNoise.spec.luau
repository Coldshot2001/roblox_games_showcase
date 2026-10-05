--!strict

return function()
	local fractalNoiseGenerator = require(script.Parent.FractalNoise)

	describe("fractalNoiseGenerator", function()
		it("returns a function", function()
			expect(typeof(fractalNoiseGenerator(1, 1, 4, 3, 1.75, 0.8))).to.equal("function")
		end)

		it("returns the same value for the same seed and position", function()
			local noiseA = fractalNoiseGenerator(123, 1, 4, 3, 1.75, 0.8)
			local noiseB = fractalNoiseGenerator(123, 1, 4, 3, 1.75, 0.8)
			expect(noiseA(0.5, 0.25, 0.75)).to.equal(noiseB(0.5, 0.25, 0.75))
		end)

		it("keeps the output inside the amplitude range", function()
			local noise = fractalNoiseGenerator(5, 1, 4, 4, 1.75, 0.8)
			for _ = 1, 100 do
				local value = noise(math.random(), math.random(), math.random())
				expect(math.abs(value) <= 5).to.equal(true)
			end
		end)

		it("uses the default values when none are given", function()
			local noise = fractalNoiseGenerator(nil, nil, nil, nil, nil, nil)
			expect(typeof(noise(1, 2, 3))).to.equal("number")
		end)
	end)
end
