--!strict
--[[
    RankedMatchConfig (Server)
    ==========================
    Author: Sol (3693744006)
    Updated: 26/07/19

    Defines the initial competitive 1v1 format independently from its runtime
    orchestration so maps and round tuning remain easy to expand.
]]

local stages = {
	table.freeze({
		kind = "Classic",
		mapName = "Crossroads",
	}),
	table.freeze({
		kind = "FFA",
		mapName = "Baseplate",
		killsToWin = 2,
	}),
	table.freeze({
		kind = "Classic",
		mapName = "Glasshouses",
	}),
}

return table.freeze({
	pointsToWin = 5,
	classicDurationSeconds = 125,
	countdownSeconds = 4.5,
	interStageSeconds = 2,
	stages = table.freeze(stages),
})
