local ClientData = {}
ClientData["Stats"] = {
	["MaxFlux"] = 1e3,
	["MaxMana"] = 1e2,
	["CurFlux"] = 0,
	["CurMana"] = 10,
	["LayoutWidth"] = 3,
	["LayoutHeight"] = 3,
	["TickPerSec"] = 2,
}
ClientData.Updated = Instance.new("BindableEvent")

function ClientData:UpdateStats(newStats)
	for key, value in pairs(newStats) do
		if self.Stats[key] ~= nil then
			self.Stats[key] = value
		end
	end
	self.Updated:Fire("Stats", self.Stats)
end

function ClientData:UpdateMachineStats(newMachine)
	self.Updated:Fire("CurSelectedMachine", newMachine)
end

return ClientData
