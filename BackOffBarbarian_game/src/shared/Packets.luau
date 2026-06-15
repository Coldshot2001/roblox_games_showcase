local Packet = require(script.Parent.Parent:WaitForChild("Packages"):WaitForChild("Packet"))

return {
	-- player requests to move in a direction (1–4)
	MovePacket = Packet("MovePacket", Packet.NumberU8),

	-- sends a map's grid data
	SendMapPacket = Packet(
		"SendMapPacket",
		Packet.Any, -- GridArray
		Packet.NumberU8, -- cellSize
		Packet.Vector3F32, -- originPosition
		Packet.String -- map Name
	),

	-- sends "RoundOver", "TimerStart", "TimerEnd"
	SendGameDataPacket = Packet(
		"SendGameDataPacket",
		Packet.String, -- Event name
		Packet.Any
	),

	-- confirms a move and gives new position
	MoveAckPacket = Packet(
		"MoveAckPacket",
		Packet.Boolean8, -- accepted
		Packet.NumberU8, -- new gridX
		Packet.NumberU8, -- new gridY
		Packet.String -- mapName
	),

	-- another entity moved (other players, enemies)
	EntityMovePacket = Packet(
		"EntityMovePacket",
		Packet.String, -- entityId
		Packet.String, -- entityType: "player" or "enemy"
		Packet.NumberU8, -- gridX
		Packet.NumberU8, -- gridY
		Packet.String, -- mapName
		Packet.NumberU8 -- dir (1-4, or 0 if unknown e.g. enemy)
	),

	-- tells a client which animation pack another player is using
	AnimationPackPacket = Packet(
		"AnimationPackPacket",
		Packet.NumberU64, -- userId of the player
		Packet.String -- animation pack name
	),
}
