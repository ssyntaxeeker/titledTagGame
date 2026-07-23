--!strict
--[[
    CharacterMovementModel (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/20

    Deterministic UTG speed, jump, momentum, friction, slope, and slide
    lifecycle equations, including per-mode momentum ceilings.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MovementConfig = require(ReplicatedStorage.Modules.Character.Movement.MovementConfig)

export type UpdateParams = {
	dt: number,
	moveMagnitude: number,
	sprinting: boolean,
	slopeTilt: number?,
}

local CharacterMovementModel = {}

local function deltaLerp(response: number, dt: number): number
	return math.min(1 - math.exp(-response * dt), 1)
end

local function updateSlide(character: Model, humanoid: Humanoid, dt: number, slopeTilt: number?): (number, number, boolean)
	if not character:GetAttribute("Sliding") then
		local previousMultiplier = character:GetAttribute("SlideSlopeSpeed")
		if typeof(previousMultiplier) == "number" and previousMultiplier > MovementConfig.slideSlopeMomentumThreshold then
			local momentum = character:GetAttribute("Momentum") or 0
			local rewardMultiplier = character:GetAttribute("MomentumMultiplier") or 1
			character:SetAttribute("Momentum", momentum + MovementConfig.slideSlopeMomentumReward * rewardMultiplier)
		end
		character:SetAttribute("SlideSlopeSpeed", nil)
		character:SetAttribute("SlideSlopeAcceleration", nil)
		return 1, 1, false
	end

	local speedMultiplier = character:GetAttribute("SlideSlopeSpeed") or 1
	local accelerationMultiplier = character:GetAttribute("SlideSlopeAcceleration") or 1.5
	if slopeTilt then
		humanoid.HipHeight = if slopeTilt > 0 then slopeTilt else slopeTilt * 0.666
		local response = if math.abs(slopeTilt) < 0.1 then 2 else 7.5
		if slopeTilt < -0.1 then
			speedMultiplier = math.clamp(
				speedMultiplier + slopeTilt * -0.025 * math.min(dt, 1) * 60,
				0.1,
				MovementConfig.slideSlopeMaximumMultiplier
			)
		else
			speedMultiplier += ((slopeTilt * -1.75 + 1) - speedMultiplier) * deltaLerp(response, dt)
		end
		accelerationMultiplier = speedMultiplier
			+ ((slopeTilt * -1.25 + 1.5) - speedMultiplier) * deltaLerp(response, dt)
	else
		humanoid.HipHeight = 0.2
		speedMultiplier += (1 - speedMultiplier) * deltaLerp(2, dt)
	end
	character:SetAttribute("SlideSlopeSpeed", speedMultiplier)
	character:SetAttribute("SlideSlopeAcceleration", accelerationMultiplier)

	local now = os.clock()
	local airborneAt = character:GetAttribute("SlideAirborneAt")
	if humanoid.FloorMaterial == Enum.Material.Air then
		if typeof(airborneAt) ~= "number" then
			airborneAt = now
			character:SetAttribute("SlideAirborneAt", airborneAt)
		end
	else
		character:SetAttribute("SlideAirborneAt", nil)
	end
	local horizontalVelocity = humanoid.RootPart and humanoid.RootPart.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
	local startedAt = character:GetAttribute("SlideStartedAt")
	local expired = typeof(startedAt) == "number" and now - startedAt >= MovementConfig.slideMaximumSeconds
	local airborneTooLong = typeof(airborneAt) == "number" and now - airborneAt >= MovementConfig.slideAirborneGraceSeconds
	local tooSlow = horizontalVelocity ~= nil and horizontalVelocity.Magnitude < MovementConfig.slideStopSpeed
	return speedMultiplier, accelerationMultiplier, expired or airborneTooLong or tooSlow
end

-- Updates all movement-derived humanoid properties once per heartbeat.
function CharacterMovementModel.update(character: Model, params: UpdateParams): boolean
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	assert(humanoid, "[CharacterMovementModel.update] character has no Humanoid")
	assert(rootPart and rootPart:IsA("BasePart"), "[CharacterMovementModel.update] character has no HumanoidRootPart")
	if character:GetAttribute("Rolling") then return false end

	local dt60 = math.min(params.dt, 1) * 60
	local slopeSpeed, slopeAcceleration, shouldStopSlide = updateSlide(character, humanoid, params.dt, params.slopeTilt)
	local walkSpeed = MovementConfig.walkSpeed * slopeSpeed
	local runSpeed = (character:GetAttribute("MinRunSpeed") or MovementConfig.runSpeed) * slopeSpeed
	local sprintSpeed = (character:GetAttribute("MaxRunSpeed") or MovementConfig.sprintSpeed) * slopeSpeed
	local minimumJump = character:GetAttribute("MinJumpPower") or MovementConfig.jumpPower
	local maximumJump = character:GetAttribute("MaxJumpPower") or MovementConfig.sprintJumpPower
	if character:GetAttribute("Sliding") then
		minimumJump *= MovementConfig.slideJumpMultiplier
		maximumJump *= MovementConfig.slideJumpMultiplier
	end
	if character:GetAttribute("Crouching") then runSpeed = walkSpeed end

	if params.moveMagnitude > 0.1 then
		local airborne = humanoid.FloorMaterial == Enum.Material.Air
		local configuredMaximumMomentum = character:GetAttribute("MaximumMomentum")
		local maximumMomentum = if typeof(configuredMaximumMomentum) == "number"
			then configuredMaximumMomentum
			else MovementConfig.maximumMomentum
		local momentumDecay = if airborne
			then MovementConfig.midairMomentumDecayPerFrame
			else MovementConfig.momentumDecayPerFrame
		local momentum = math.clamp(
			(character:GetAttribute("Momentum") or 0) - momentumDecay * dt60,
			0,
			maximumMomentum
		)
		local friction = math.clamp(
			(character:GetAttribute("Friction") or 0) - MovementConfig.frictionDecayPerFrame * dt60,
			0,
			MovementConfig.maximumFriction
		)
		character:SetAttribute("Momentum", momentum)
		character:SetAttribute("Friction", friction)
		walkSpeed += momentum - friction
		runSpeed += momentum - friction
		sprintSpeed += momentum - friction

		local speedDelta = dt60 * MovementConfig.accelerationPerFrame * slopeAcceleration
		if airborne then
			if params.sprinting then
				walkSpeed = runSpeed
				runSpeed = sprintSpeed
			end
		elseif params.sprinting or runSpeed < humanoid.WalkSpeed then
			if not params.sprinting then speedDelta = -dt60 * MovementConfig.walkDecayPerFrame end
			walkSpeed = runSpeed
			runSpeed = sprintSpeed
		end
		humanoid.WalkSpeed = math.clamp(humanoid.WalkSpeed + speedDelta, walkSpeed, math.max(runSpeed, walkSpeed))
		humanoid.JumpPower = math.clamp(
			humanoid.JumpPower + dt60 * MovementConfig.accelerationPerFrame,
			minimumJump,
			maximumJump
		)
	else
		humanoid.JumpPower = minimumJump
		if humanoid.FloorMaterial ~= Enum.Material.Air then humanoid.WalkSpeed = runSpeed end
		character:SetAttribute("Momentum", 0)
	end

	local velocity = rootPart.AssemblyLinearVelocity
	if Vector2.new(velocity.X, velocity.Z).Magnitude < MovementConfig.momentumResetSpeed then
		character:SetAttribute("Momentum", 0)
	end
	return shouldStopSlide
end

return table.freeze(CharacterMovementModel)
