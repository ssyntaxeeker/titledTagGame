--!strict
--[[
    WalljumpConfig (Client)
    =======================
    Author: Sol (3693744006)
    Updated: 26/07/19

    Frozen rear-wall eligibility, launch, feedback, and anti-repeat tuning.
]]

return table.freeze({
	probeOriginHeight = 0.3,
	probeDistance = 3.5,
	minimumContactDistance = 0.6,
	minimumFacingDot = 0.7,
	maximumNormalY = 0.15,
	clearanceDistance = 2.5,
	groundMinimumHorizontalSpeed = 4,
	maximumUsefulIncomingVerticalSpeed = 65,
	verticalBaseSpeed = 18,
	verticalSpeedScale = 0.2,
	minimumVerticalSpeed = 18,
	maximumVerticalSpeed = 26,
	outwardBaseSpeed = 20,
	outwardSpeedScale = 0.4,
	minimumOutwardSpeed = 24,
	maximumOutwardSpeed = 46,
	verticalLaunchSpeedMultiplier = 1.4,
	outwardLaunchSpeedMultiplier = 1.82,
	tangentRetention = 0.85,
	maximumInheritedWallSpeed = 24,
	cooldown = 0.25,
	stateSeconds = 0.15,
	cameraShakeDuration = 0.12,
	cameraShakeIntensity = 0.18,
	fastDebugVerticalSpeed = 45,
})
