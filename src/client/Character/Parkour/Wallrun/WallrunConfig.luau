--!strict
--[[
    WallrunConfig (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/18

    Frozen wallrun eligibility and physics tuning reconstructed from UTG.
]]

return table.freeze({
	probeDistance = 5,
	maximumNormalY = 0.15,
	entryVerticalVelocity = 10,
	minimumFallVelocity = -10,
	verticalAccelerationPerFrame = 1,
	baseWalkSpeed = 32,
	cooldown = 0.66,
	releaseVelocityMultiplier = 0.7,
	releaseMomentumScale = 5,
})
