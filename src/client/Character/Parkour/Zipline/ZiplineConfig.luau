--!strict
--[[
    ZiplineConfig (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/19

    Frozen UTG zipline attachment, acceleration, and release tuning.
]]

return table.freeze({
	attachRadius = 5,
	hangOffset = 2.5,
	attachGraceSeconds = 0.5,
	maximumSeparation = 6,
	endpointInset = 1,
	inputAcceleration = 600,
	maximumSpeed = 180,
	alignResponsiveness = 100,
	alignMaximumForce = 10000,
	cooldown = 0.5,
	releaseBoost = 50,
})
