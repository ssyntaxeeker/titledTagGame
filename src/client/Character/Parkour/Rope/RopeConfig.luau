--!strict
--[[
    RopeConfig (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/19

    Frozen tuning for UTG-style rope attachment and release.
]]

return table.freeze({
	probeDistance = 10,
	grabDistance = 2.25,
	maximumSeparation = 18,
	alignResponsiveness = 120,
	alignMaximumForce = 10000,
	movementImpulse = 6.75,
	releaseCooldown = 0.2,
	releaseVerticalVelocity = 45,
	releaseForwardVelocity = 28,
})
