local NeighbourLogic = {
	["Generator"] = {
		["Cooler"] = function(ItemData,NeighbourData,GenerateMana,GenerateFlux)
			local NewFluxAmount = math.floor(ItemData["Flux"] / NeighbourData["Count"] * 100) / 100

			for i,NeighbourData in ipairs(NeighbourData["Data"]) do
				NeighbourData[i]["CurIntake"] += NewFluxAmount
				NeighbourData[i]["CurCapacity"] += NewFluxAmount
			end
			
			GenerateFlux = false
			
			return GenerateMana,GenerateFlux
		end,
	}
}

function NeighbourLogic.Check(ItemData,PlayerStats,NeighbourTypeCount)
	local GenerateMana,GenerateFlux = true,true
	
	for Type,Table in NeighbourTypeCount do
		if not NeighbourLogic[ ItemData["Type"] ] or not NeighbourLogic[ ItemData["Type"] ][Type] then continue end 
		GenerateMana,GenerateFlux = NeighbourLogic[ ItemData["Type"] ][Type](ItemData,Table,GenerateMana,GenerateFlux)
	end
	
	return GenerateMana,GenerateFlux
end

return NeighbourLogic
