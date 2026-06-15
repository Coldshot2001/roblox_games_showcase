local AnimationPacks = require(game:GetService("ReplicatedStorage").SharedModules.AnimationPacks)

local AnimationHandler = {}

local registry = {}

local function getPackData(packName)
	return AnimationPacks[packName] or AnimationPacks.Default
end

local function loadTrack(animator, animId)
	if animId == nil or animId == "rbxassetid://0" or animId == "" then
		return nil
	end
	local anim = Instance.new("Animation")
	anim.AnimationId = animId
	local track = animator:LoadAnimation(anim)
	anim:Destroy()
	return track
end

local function getOrLoadTrack(record, animId)
	if record.tracks[animId] then
		return record.tracks[animId]
	end
	local track = loadTrack(record.animator, animId)
	if track then
		record.tracks[animId] = track
	end
	return track
end

local function stopCurrent(record)
	if record.currentAnim and record.currentAnim.IsPlaying then
		record.currentAnim:Stop(0.1)
	end
	record.currentAnim = nil
end

function AnimationHandler:Register(entityId, animator, packName)
	registry[entityId] = {
		animator = animator,
		packName = packName or "Default",
		currentAnim = nil,
		tracks = {},
	}
	local pack = getPackData(packName)
	local idle = getOrLoadTrack(registry[entityId], pack.Idle)
	if idle then
		idle.Looped = true
		idle:Play()
		registry[entityId].currentAnim = idle
	end
end

function AnimationHandler:SetPack(entityId, packName)
	local record = registry[entityId]
	if record == nil then
		return
	end
	stopCurrent(record)

	for _, track in pairs(record.tracks) do
		track:Destroy()
	end
	record.tracks = {}
	record.packName = packName or "Default"

	local pack = getPackData(record.packName)
	local idle = getOrLoadTrack(record, pack.Idle)
	if idle then
		idle.Looped = true
		idle:Play()
		record.currentAnim = idle
	end
end

function AnimationHandler:PlayMove(entityId, dir)
	local record = registry[entityId]
	if record == nil then
		return
	end
	local pack = getPackData(record.packName)
	local animId = pack.Move[dir]
	if animId == nil or animId == "rbxassetid://0" then
		return
	end

	stopCurrent(record)

	local track = getOrLoadTrack(record, animId)
	if track == nil then
		return
	end

	track.Looped = false
	track:Play(0.05)
	record.currentAnim = track

	track.Stopped:Once(function()
		if record.currentAnim == track then
			record.currentAnim = nil
			local idle = getOrLoadTrack(record, pack.Idle)
			if idle then
				idle.Looped = true
				idle:Play(0.1)
				record.currentAnim = idle
			end
		end
	end)
end

function AnimationHandler:PlayCorrection(entityId)
	local record = registry[entityId]
	if record == nil then
		return
	end
	local pack = getPackData(record.packName)
	local animId = pack.Correction
	if animId == nil or animId == "rbxassetid://0" or animId == "" then
		return
	end

	stopCurrent(record)

	local track = getOrLoadTrack(record, animId)
	if track == nil then
		return
	end

	track.Looped = false
	track.Priority = Enum.AnimationPriority.Action
	track:Play(0.05)
	record.currentAnim = track

	track.Stopped:Once(function()
		if record.currentAnim == track then
			record.currentAnim = nil
			local idle = getOrLoadTrack(record, pack.Idle)
			if idle then
				idle.Looped = true
				idle:Play(0.1)
				record.currentAnim = idle
			end
		end
	end)
end

function AnimationHandler:Unregister(entityId)
	local record = registry[entityId]
	if record == nil then
		return
	end
	stopCurrent(record)
	for _, track in pairs(record.tracks) do
		track:Destroy()
	end
	registry[entityId] = nil
end

return AnimationHandler
