--!strict

local randomSource = Random.new(os.time())

function fractalNoiseGenerator(seed, amplitude, frequency, octaves, lacunarity, persistence)
	--amplitude = how high is the difference between values
	--frequency = how big/small is the difference between values
	--octaves = how many noise iterations are overlapped on one another
	--lacunarity = how frequent the changes in values are
	--persistence = how persistence the values from the last octave are(aka how much they get modified)

	--Generates a noise generator using cohrent noise (math.noise)
	--Uses "sensible" default values.
	--Check out this glossary: http://libnoise.sourceforge.net/glossary/index.html

	local noise = math.noise
	local resolvedSeed = seed or (randomSource:NextInteger(-10e3, 10e3) * math.pi) -- * pi because math.noise is weird at integer coordinates, and pi is irrational
	local resolvedAmplitude = amplitude or 1
	local resolvedFrequency = frequency or 4
	local resolvedOctaves = octaves or 3
	local resolvedLacunarity = lacunarity or 1.75
	local resolvedPersistence = persistence or 0.8

	return function(x, y, z)
		local value = 0
		local currentAmplitude = resolvedAmplitude
		local currentFrequency = resolvedFrequency

		for _ = 1, resolvedOctaves do
			value = value
				+ noise(
					resolvedSeed + x * currentFrequency,
					resolvedSeed + y * currentFrequency,
					resolvedSeed + z * currentFrequency
				)
					* currentAmplitude
			currentAmplitude = currentAmplitude * resolvedPersistence
			currentFrequency = currentFrequency * resolvedLacunarity
		end

		return value
	end
end

return fractalNoiseGenerator
