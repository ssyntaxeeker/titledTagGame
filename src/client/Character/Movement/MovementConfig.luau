--!strict
--[[
    MovementConfig (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/18

    Frozen tuning values reconstructed from UTG's movement and parkour loops.
]]

return table.freeze({
	walkSpeed = 8,
	runSpeed = 16,
	sprintSpeed = 32,
	jumpPower = 16,
	sprintJumpPower = 28,
	gravity = 75,
	accelerationPerFrame = 0.2,
	walkDecayPerFrame = 0.5,
	momentumDecayPerFrame = 0.0425,
	midairMomentumDecayPerFrame = 0.0375,
	frictionDecayPerFrame = 0.06,
	maximumMomentum = 32,
	maximumFriction = 16,
	momentumResetSpeed = 6.8,
	slideJumpMultiplier = 0.925,
	slideMaximumSeconds = 3,
	slideAirborneGraceSeconds = 0.1,
	slideStopSpeed = 2,
	slideSteerMultiplier = 1,
	slideSteerResponse = 4,
	slideVelocityTurnResponse = 5,
	slideSlopeMaximumMultiplier = 2.125,
	slideSlopeMomentumThreshold = 1.2,
	slideSlopeMomentumReward = 5,
})
