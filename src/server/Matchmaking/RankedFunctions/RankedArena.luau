--!strict
--[[
    RankedArena (Server)
    ====================
    Author: Sol (3693744006)
    Updated: 26/07/19

    Validates the mandatory per-map ranked spawn contract. Ranked matches do
    not synthesize or fall back to positions when an arena is malformed.
]]

export type RRankedSpawns = {
	runner: BasePart,
	tagger: BasePart,
}

local RankedArena = {}

function RankedArena.requireSpawns(mapModel: Instance?): RRankedSpawns
	local map = mapModel or workspace:FindFirstChild("Map")
	assert(
		map and (map:IsA("Folder") or map:IsA("Model")),
		"[RankedArena.requireSpawns] ranked map Folder or Model is missing"
	)
	local ranked = map:FindFirstChild("Ranked")
	assert(ranked and ranked:IsA("Folder"), "[RankedArena.requireSpawns] Map.Ranked must be a Folder")
	local runnerSpawn = ranked:FindFirstChild("RunnerSpawn")
	local taggerSpawn = ranked:FindFirstChild("TaggerSpawn")
	assert(
		runnerSpawn and runnerSpawn:IsA("BasePart"),
		"[RankedArena.requireSpawns] Map.Ranked.RunnerSpawn must be a BasePart"
	)
	assert(
		taggerSpawn and taggerSpawn:IsA("BasePart"),
		"[RankedArena.requireSpawns] Map.Ranked.TaggerSpawn must be a BasePart"
	)
	return {
		runner = runnerSpawn,
		tagger = taggerSpawn,
	}
end

return table.freeze(RankedArena)
