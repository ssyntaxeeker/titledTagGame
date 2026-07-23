--!strict
--[[
    Leaderboards (Shared)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/19

    Stable ordered-leaderboard categories. New crew or seasonal categories can
    be registered without changing the leaderboard storage service.
]]

return table.freeze({
	cacheSeconds = 30,
	maximumEntries = 100,
	categories = table.freeze({
		IndividualELO = table.freeze({
			dataStoreName = "Leaderboard_IndividualELO_AllTime_V1",
			playerAttribute = "ELO",
		}),
	}),
})
