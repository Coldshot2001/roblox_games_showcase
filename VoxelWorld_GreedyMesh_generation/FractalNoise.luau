local r = Random.new(os.time())
--this returns a new noise function
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
	local seed = seed or (r:NextInteger(-10e3, 10e3) * math.pi) -- * pi because math.noise is weird at integer coordinates, and pi is irrational
	local amplitude = amplitude or 1
	local frequency = frequency or 4
	local period = 1/frequency
	local octaves = octaves or 3
	local lacunarity = lacunarity or 1.75
	local persistence = persistence or 0.8

	return function(x, y, z)
		local v = 0
		local a = amplitude
		local f = frequency

		for o = 1, octaves do
			v = v + noise(seed + x*f, seed + y*f, seed + z*f) * a
			a = a * persistence
			f = f * lacunarity	
		end

		return v
	end
end

return fractalNoiseGenerator