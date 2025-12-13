local MapUtils = {}

function MapUtils.GetRandomSpawn(mapModel: Model): SpawnLocation?
	local availableSpawns = mapModel:FindFirstChild("Spawns")
	if not availableSpawns then return end

	availableSpawns = availableSpawns:GetChildren()
	local randomSpawn = availableSpawns[math.random(1, #availableSpawns)]

	return randomSpawn
end

return MapUtils
