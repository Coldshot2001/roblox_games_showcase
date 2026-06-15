local ByteNet = require(game:GetService("ReplicatedStorage").Shared.ByteNet)

return ByteNet.defineNamespace("Movement", function()
	return {
		MovementPacket = ByteNet.definePacket({
			reliabilityType = "unreliable",
			value = ByteNet.struct({
				angle = ByteNet.vec2,
				normal = ByteNet.vec2,
			}),
		}),
		StartBalance = ByteNet.definePacket({
			reliabilityType = "reliable",
			value = ByteNet.inst,
		}),
	}
end)
