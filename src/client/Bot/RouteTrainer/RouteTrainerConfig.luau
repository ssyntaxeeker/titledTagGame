--!strict
--[[
    RouteTrainerConfig (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/20

    Frozen recording, similarity, preview, and publication tuning.
]]

return table.freeze({
	startFinishKey = Enum.KeyCode.P,
	failureKey = Enum.KeyCode.O,
	sampleInterval = 1 / 20,
	maximumAttemptSeconds = 30,
	maximumAttempts = 12,
	requiredBestAttempts = 3,
	minimumAttemptDistance = 8,
	similarEndpointRadius = 14,
	similarMidpointRadius = 12,
	ghostTransparency = 0.55,
	ghostPlaybackSpeed = 1,
	maximumLogs = 60,
})
