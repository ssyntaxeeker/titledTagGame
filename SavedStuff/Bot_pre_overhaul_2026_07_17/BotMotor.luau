--!strict
--[[
    BotMotor (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/17

    Low-level movement execution with cheap probes and real cooldown pacing.
]]

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Modules.Bot.BotConfig)

local BotMotor = {}

export type RMotorState = {
	lastJumpTime: number,
	lastVaultTime: number,
	lastSwingTime: number,
	lastSlideTime: number,
	lastProgressPosition: Vector3?,
	lastProgressTime: number,
	lastDistance: number?,
	stuckSeconds: number,
	lastTechName: string,
	lastTechResult: string,
	lastRollBoostTime: number,
	lastRollTime: number,
	lastTrampolineTime: number,
	slideBoostActiveUntil: number,
}

function BotMotor.createState(): RMotorState
	return {
		lastJumpTime = 0,
		lastVaultTime = 0,
		lastSwingTime = 0,
		lastSlideTime = 0,
		lastProgressPosition = nil,
		lastProgressTime = os.clock(),
		lastDistance = nil,
		stuckSeconds = 0,
		lastTechName = "None",
		lastTechResult = "Idle",
		lastRollBoostTime = 0,
		lastRollTime = 0,
		lastTrampolineTime = 0,
		slideBoostActiveUntil = 0,
	}
end

function BotMotor.isGrounded(humanoid: Humanoid): boolean
	local humanoidState = humanoid:GetState()
	if humanoidState == Enum.HumanoidStateType.Jumping then return false end
	if humanoidState == Enum.HumanoidStateType.FallingDown then return false end
	if humanoidState == Enum.HumanoidStateType.Flying then return false end
	if humanoidState == Enum.HumanoidStateType.Swimming then return false end
	if humanoid.FloorMaterial ~= Enum.Material.Air then return true end

	local rootPart = humanoid.RootPart
	local velocityY = if rootPart then rootPart.AssemblyLinearVelocity.Y else 0
	if math.abs(velocityY) <= Config.groundedVelocityYThreshold then return true end
	if humanoidState == Enum.HumanoidStateType.Freefall then return false end

	return false
end

local function makeRaycastParams(ignore: { Instance }): RaycastParams
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = ignore
	raycastParams.IgnoreWater = true
	return raycastParams
end

function BotMotor.getForwardClearance(rootPart: BasePart, direction: Vector3, ignore: { Instance }?): number
	local raycastParams = makeRaycastParams(ignore or {})
	local origin = rootPart.Position + Vector3.yAxis * 2.2
	local result = Workspace:Raycast(origin, direction * Config.slideBoostMaxWallClearance, raycastParams)
	if not result then return math.huge end

	return (result.Position - origin).Magnitude
end

function BotMotor.hasDirectLine(rootPart: BasePart, targetPosition: Vector3, ignore: { Instance }): boolean
	local raycastParams = makeRaycastParams(ignore)

	local origin = rootPart.Position + Vector3.yAxis * Config.directRayHeight
	local target = targetPosition + Vector3.yAxis * Config.directRayHeight
	local result = Workspace:Raycast(origin, target - origin, raycastParams)
	return result == nil
end

function BotMotor.updateProgress(state: RMotorState, rootPart: BasePart, targetPosition: Vector3, dt: number)
	local distance = (rootPart.Position - targetPosition).Magnitude
	if not state.lastDistance or distance + 1.5 < state.lastDistance then
		state.lastDistance = distance
		state.lastProgressPosition = rootPart.Position
		state.lastProgressTime = os.clock()
		state.stuckSeconds = 0
		return
	end

	if rootPart.AssemblyLinearVelocity.Magnitude < 3 then
		state.stuckSeconds += dt
	else
		state.stuckSeconds = math.max(0, state.stuckSeconds - dt * 0.5)
	end
end

function BotMotor.moveToward(rootPart: BasePart, humanoid: Humanoid, targetPosition: Vector3)
	local activeUntil = rootPart:GetAttribute("BotSlideBoostActiveUntil")
	if typeof(activeUntil) == "number" and os.clock() < activeUntil then return end

	local delta = targetPosition - rootPart.Position
	local flatDelta = Vector3.new(delta.X, 0, delta.Z)
	if flatDelta.Magnitude <= 0.05 then
		humanoid:Move(Vector3.zero, false)
		rootPart:SetAttribute("BotMoveDirectionX", 0)
		rootPart:SetAttribute("BotMoveDirectionZ", 0)
		return
	end

	local desiredDirection = flatDelta.Unit
	local oldX = rootPart:GetAttribute("BotMoveDirectionX")
	local oldZ = rootPart:GetAttribute("BotMoveDirectionZ")
	local oldDirection = if typeof(oldX) == "number" and typeof(oldZ) == "number"
		then Vector3.new(oldX, 0, oldZ)
		else desiredDirection
	if oldDirection.Magnitude <= 0.05 or oldDirection.Unit:Dot(desiredDirection) < Config.pathLookaheadMinDot then
		oldDirection = desiredDirection
	end
	local blendedDirection = oldDirection.Unit:Lerp(desiredDirection, Config.moveDirectionAlpha)
	if blendedDirection.Magnitude <= 0.05 then blendedDirection = desiredDirection end
	blendedDirection = blendedDirection.Unit
	rootPart:SetAttribute("BotMoveDirectionX", blendedDirection.X)
	rootPart:SetAttribute("BotMoveDirectionZ", blendedDirection.Z)

	humanoid.WalkSpeed = Config.botWalkSpeed
	humanoid.UseJumpPower = true
	humanoid.JumpPower = Config.botJumpPower
	humanoid:Move(blendedDirection, false)
end

function BotMotor.faceMoveDirection(rootPart: BasePart, targetPosition: Vector3, dt: number)
	local delta = targetPosition - rootPart.Position
	local flatDelta = Vector3.new(delta.X, 0, delta.Z)
	if flatDelta.Magnitude <= 0.1 then return end

	local moveX = rootPart:GetAttribute("BotMoveDirectionX")
	local moveZ = rootPart:GetAttribute("BotMoveDirectionZ")
	local direction = if typeof(moveX) == "number" and typeof(moveZ) == "number" and Vector3.new(moveX, 0, moveZ).Magnitude > 0.1
		then Vector3.new(moveX, 0, moveZ).Unit
		else flatDelta.Unit
	local desired = CFrame.lookAt(rootPart.Position, rootPart.Position + direction)
	rootPart.CFrame = rootPart.CFrame:Lerp(desired, math.clamp(dt * Config.turnRate, 0, 1))
end

local function faceFlatTarget(rootPart: BasePart, targetPosition: Vector3)
	local delta = targetPosition - rootPart.Position
	local flatDelta = Vector3.new(delta.X, 0, delta.Z)
	if flatDelta.Magnitude <= 0.1 then return end

	rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + flatDelta.Unit)
end

local function rotateFlatDirection(direction: Vector3, degrees: number): Vector3
	local radians = math.rad(degrees)
	local cos = math.cos(radians)
	local sin = math.sin(radians)
	return Vector3.new(direction.X * cos - direction.Z * sin, 0, direction.X * sin + direction.Z * cos)
end

local function parseSlideBoostAction(actionName: string): { holdSeconds: number, jumpDelaySeconds: number, jumpWallClearance: number?, backoffDistance: number? }?
	local holdMsText, jumpMsText, clearanceText, backoffText = string.match(actionName, "^SlideBoost@(%d+):(%d+):(%d+):(%d+)$")
	if not holdMsText then
		holdMsText, jumpMsText = string.match(actionName, "^SlideBoost@(%d+):(%d+)$")
	end
	if not holdMsText or not jumpMsText then return nil end
	local holdMs = tonumber(holdMsText)
	local jumpMs = tonumber(jumpMsText)
	if not holdMs or not jumpMs then return nil end
	local clearanceStuds = if clearanceText then tonumber(clearanceText) else nil
	local backoffStuds = if backoffText then tonumber(backoffText) else nil

	return {
		holdSeconds = holdMs / 1000,
		jumpDelaySeconds = jumpMs / 1000,
		jumpWallClearance = clearanceStuds,
		backoffDistance = backoffStuds,
	}
end

function BotMotor.tryJump(state: RMotorState, humanoid: Humanoid)
	local now = os.clock()
	if now - state.lastJumpTime < Config.jumpCooldownSeconds then
		state.lastTechName = "Jump"
		state.lastTechResult = "Cooldown"
		return false
	end
	if not BotMotor.isGrounded(humanoid) then
		state.lastTechName = "Jump"
		local rootPart = humanoid.RootPart
		local velocityY = if rootPart then rootPart.AssemblyLinearVelocity.Y else 0
		state.lastTechResult = `Blocked: {humanoid:GetState().Name} yVel {math.floor(velocityY * 10) / 10}`
		return false
	end

	state.lastJumpTime = now
	humanoid.Jump = true
	state.lastTechName = "Jump"
	state.lastTechResult = "Success"
	return true
end

function BotMotor.getVaultProbe(rootPart: BasePart, ignore: { Instance }): RaycastResult?
	local raycastParams = makeRaycastParams(ignore)
	local lookVector = rootPart.CFrame.LookVector

	local distance = Config.vaultProbeForwardMax
	while distance >= Config.vaultProbeForwardMin do
		local origin = rootPart.Position + lookVector * distance + Vector3.yAxis * Config.vaultProbeHeight
		local result = Workspace:Raycast(origin, -Vector3.yAxis * Config.vaultProbeDepth, raycastParams)
		if result and result.Instance:IsA("BasePart") then
			local forwardOrigin = rootPart.Position
				+ Vector3.yAxis * Config.vaultBlockedProbeHeight
				- lookVector * Config.vaultBlockedProbeBack
			local forwardCheck = Workspace:Raycast(forwardOrigin, lookVector * Config.vaultBlockedProbeDistance, raycastParams)
			if not forwardCheck and not result.Instance:GetAttribute("NoClimb") then return result end
		end

		distance -= Config.vaultProbeForwardStep
	end

	return nil
end

function BotMotor.findVaultableTarget(rootPart: BasePart, goalPosition: Vector3, ignore: { Instance }): Vector3?
	local raycastParams = makeRaycastParams(ignore)
	local goalDelta = goalPosition - rootPart.Position
	local flatGoalDelta = Vector3.new(goalDelta.X, 0, goalDelta.Z)
	local baseDirection = if flatGoalDelta.Magnitude > 0.1 then flatGoalDelta.Unit else rootPart.CFrame.LookVector
	local bestTarget: Vector3? = nil
	local bestScore = -math.huge
	local currentGoalDistance = (rootPart.Position - goalPosition).Magnitude

	for _, angle in Config.vaultSearchAngles do
		local direction = rotateFlatDirection(baseDirection, angle)
		local distance = Config.vaultSearchForwardMin
		while distance <= Config.vaultSearchForwardMax do
			local origin = rootPart.Position + direction * distance + Vector3.yAxis * Config.vaultProbeHeight
			local result = Workspace:Raycast(origin, -Vector3.yAxis * Config.vaultProbeDepth, raycastParams)
			if result and result.Instance:IsA("BasePart") and not result.Instance:GetAttribute("NoClimb") then
				local heightDelta = result.Position.Y - rootPart.Position.Y
				if heightDelta >= Config.vaultSearchMinHeight and heightDelta <= Config.vaultSearchMaxHeight then
					local forwardOrigin = rootPart.Position
						+ Vector3.yAxis * Config.vaultBlockedProbeHeight
						- direction * Config.vaultBlockedProbeBack
					local forwardCheck = Workspace:Raycast(forwardOrigin, direction * math.min(distance + 1, Config.vaultBlockedProbeDistance + distance), raycastParams)
					if not forwardCheck or forwardCheck.Instance == result.Instance then
						local target = result.Position + direction * 1.5 + Vector3.yAxis * math.max(1.5, heightDelta)
						local progress = currentGoalDistance - (target - goalPosition).Magnitude
						local anglePenalty = math.abs(angle) * 0.025
						local score = progress + math.max(0, heightDelta) * 1.2 - distance * 0.08 - anglePenalty
						if score > bestScore then
							bestScore = score
							bestTarget = target
						end
					end
				end
			end

			distance += Config.vaultSearchForwardStep
		end
	end

	return bestTarget
end

function BotMotor.tryVault(state: RMotorState, rootPart: BasePart, humanoid: Humanoid, targetPosition: Vector3, ignore: { Instance }): boolean
	local now = os.clock()
	if now - state.lastVaultTime < Config.vaultCooldownSeconds then
		state.lastTechName = "Vault"
		state.lastTechResult = "Cooldown"
		return false
	end

	local delta = targetPosition - rootPart.Position
	local flatDelta = Vector3.new(delta.X, 0, delta.Z)
	if flatDelta.Magnitude <= 0.1 then return false end
	faceFlatTarget(rootPart, targetPosition)

	local probe = BotMotor.getVaultProbe(rootPart, ignore)
	if not probe then
		state.lastTechName = "Vault"
		state.lastTechResult = "Blocked: no valid vault ray"
		return false
	end

	local heightDelta = math.clamp(math.abs(probe.Position.Y - rootPart.Position.Y), 0, Config.maxVaultHeight)
	state.lastVaultTime = now
	local desiredHorizontalVelocity = flatDelta.Unit * math.max(
		Config.vaultForwardBoost,
		Vector3.new(rootPart.AssemblyLinearVelocity.X, 0, rootPart.AssemblyLinearVelocity.Z).Magnitude
	)
	rootPart.AssemblyLinearVelocity = Vector3.new(
		desiredHorizontalVelocity.X,
		math.max(rootPart.AssemblyLinearVelocity.Y, 30 + heightDelta * 2.8),
		desiredHorizontalVelocity.Z
	)
	humanoid.Jump = true
	state.lastTechName = "Vault"
	state.lastTechResult = `Success: {math.floor(heightDelta * 10) / 10} studs`
	return true
end

function BotMotor.tryNearbyVault(state: RMotorState, rootPart: BasePart, humanoid: Humanoid, goalPosition: Vector3, ignore: { Instance }): boolean
	local target = BotMotor.findVaultableTarget(rootPart, goalPosition, ignore)
	if not target then
		state.lastTechName = "VaultSearch"
		state.lastTechResult = "No vaultable part nearby"
		return false
	end

	return BotMotor.tryVault(state, rootPart, humanoid, target, ignore)
end

function BotMotor.getSwingProbe(rootPart: BasePart, ignore: { Instance }): RaycastResult?
	local raycastParams = makeRaycastParams(ignore)
	local lookVector = rootPart.CFrame.LookVector

	local distance = Config.vaultProbeForwardMax
	while distance >= Config.vaultProbeForwardMin do
		local origin = rootPart.Position + lookVector * distance + Vector3.yAxis * Config.vaultProbeHeight
		local result = Workspace:Raycast(origin, -Vector3.yAxis * Config.vaultProbeDepth, raycastParams)
		if result and result.Instance:IsA("BasePart") then
			local instance = result.Instance
			if instance:GetAttribute("SwingBar") or (instance.Parent and instance.Parent:GetAttribute("SwingBar")) then return result end
		end

		distance -= Config.vaultProbeForwardStep
	end

	return nil
end

function BotMotor.trySwing(state: RMotorState, rootPart: BasePart, humanoid: Humanoid, targetPosition: Vector3, ignore: { Instance }): boolean
	local now = os.clock()
	if now - state.lastSwingTime < Config.swingCooldownSeconds then
		state.lastTechName = "Swing"
		state.lastTechResult = "Cooldown"
		return false
	end

	local delta = targetPosition - rootPart.Position
	local flatDelta = Vector3.new(delta.X, 0, delta.Z)
	if flatDelta.Magnitude <= 0.1 then return false end
	faceFlatTarget(rootPart, targetPosition)

	local probe = BotMotor.getSwingProbe(rootPart, ignore)
	if not probe then
		state.lastTechName = "Swing"
		state.lastTechResult = "Blocked: no swing bar ray"
		return false
	end

	state.lastSwingTime = now
	local fallFactor = (math.clamp(-rootPart.AssemblyLinearVelocity.Y, 25, 80) / 25) ^ 0.7
	rootPart.AssemblyLinearVelocity += flatDelta.Unit * (fallFactor * 50)
	humanoid.Jump = true
	state.lastTechName = "Swing"
	state.lastTechResult = `Success: {math.floor(fallFactor * 100)}%`
	return true
end

function BotMotor.trySlideBoost(
	state: RMotorState,
	rootPart: BasePart,
	humanoid: Humanoid,
	targetPosition: Vector3,
	ignore: { Instance }?,
	forceExperiment: boolean?,
	timingInfo: { holdSeconds: number?, jumpDelaySeconds: number?, jumpWallClearance: number?, backoffDistance: number? }?
): boolean
	local now = os.clock()
	if now - state.lastSlideTime < Config.slideCooldownSeconds then
		state.lastTechName = "SlideBoost"
		state.lastTechResult = "Cooldown"
		return false
	end
	if not BotMotor.isGrounded(humanoid) then return false end

	local heightDelta = targetPosition.Y - rootPart.Position.Y
	if not forceExperiment and (heightDelta < Config.maxVaultHeight or heightDelta > Config.maxSlideBoostHeight + 1) then
		state.lastTechName = "SlideBoost"
		state.lastTechResult = `Blocked: height {math.floor(heightDelta * 10) / 10}`
		return false
	end

	local delta = targetPosition - rootPart.Position
	local flatDelta = Vector3.new(delta.X, 0, delta.Z)
	if flatDelta.Magnitude <= 0.1 then
		state.lastTechName = "SlideBoost"
		state.lastTechResult = "Blocked: no direction"
		return false
	end

	local direction = flatDelta.Unit
	local clearance = BotMotor.getForwardClearance(rootPart, direction, ignore)
	local backoffDistance = (timingInfo and timingInfo.backoffDistance) or Config.slideBoostBackoffDistance
	if clearance < Config.slideBoostMinWallClearance and backoffDistance <= 0 then
		state.lastTechName = "SlideBoost"
		state.lastTechResult = `Blocked: too close {math.floor(clearance * 10) / 10}`
		return false
	end
	if clearance > Config.slideBoostMaxWallClearance then
		state.lastTechName = "SlideBoost"
		state.lastTechResult = "Blocked: no obstacle ahead"
		return false
	end

	local holdSeconds = (timingInfo and timingInfo.holdSeconds) or Config.slideBoostHoldSeconds
	local jumpDelaySeconds = (timingInfo and timingInfo.jumpDelaySeconds) or Config.slideBoostJumpDelaySeconds
	local jumpWallClearance = (timingInfo and timingInfo.jumpWallClearance) or Config.slideBoostJumpWallClearance
	local activeUntil = now
		+ (if clearance < Config.slideBoostMinWallClearance then 0.35 else 0)
		+ holdSeconds
		+ jumpDelaySeconds
		+ Config.slideBoostPostJumpVaultDelaySeconds
		+ 0.25

	state.lastSlideTime = now
	state.slideBoostActiveUntil = activeUntil
	rootPart:SetAttribute("BotSlideBoostActiveUntil", activeUntil)
	state.lastTechName = "SlideBoost"
	state.lastTechResult = `Slide setup from {math.floor(clearance * 10) / 10}; jump at {math.floor(jumpWallClearance * 10) / 10}`

	task.spawn(function()
		local character = rootPart.Parent
		local oldHipHeight = humanoid.HipHeight

		if not rootPart.Parent or not humanoid.Parent then return end
		if not BotMotor.isGrounded(humanoid) then
			state.lastTechName = "SlideBoost"
			state.lastTechResult = `Blocked: {humanoid:GetState().Name} before slide`
			return
		end

		if clearance < Config.slideBoostMinWallClearance and backoffDistance > 0 then
			local backoffEnd = os.clock() + math.min(0.45, backoffDistance / Config.botWalkSpeed)
			state.lastTechResult = `Backing up {math.floor(backoffDistance * 10) / 10} studs`
			while os.clock() < backoffEnd and BotMotor.getForwardClearance(rootPart, direction, ignore) < Config.slideBoostMinWallClearance do
				if not rootPart.Parent or not humanoid.Parent then return end
				rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + direction)
				humanoid:Move(-direction, false)
				task.wait(0.03)
			end
		end

		if character then character:SetAttribute("Sliding", true) end
		humanoid.HipHeight = 0.2
		state.lastTechName = "SlideBoost"
		state.lastTechResult = `Sliding {math.floor(holdSeconds * 1000)}ms; cancel before wall`

		local slideEnd = os.clock() + holdSeconds
		while os.clock() < slideEnd and BotMotor.getForwardClearance(rootPart, direction, ignore) > jumpWallClearance do
			if not rootPart.Parent or not humanoid.Parent then return end
			rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + direction)
			humanoid:Move(direction, false)
			rootPart.AssemblyLinearVelocity = direction * math.max(34, Vector3.new(
				rootPart.AssemblyLinearVelocity.X,
				0,
				rootPart.AssemblyLinearVelocity.Z
			).Magnitude) + Vector3.yAxis * rootPart.AssemblyLinearVelocity.Y
			task.wait(0.03)
		end

		if not rootPart.Parent or not humanoid.Parent then return end
		if not BotMotor.isGrounded(humanoid) then
			state.lastTechName = "SlideBoost"
			state.lastTechResult = `Blocked: {humanoid:GetState().Name} at cancel`
			if character then character:SetAttribute("Sliding", nil) end
			humanoid.HipHeight = oldHipHeight
			return
		end

		if character then character:SetAttribute("Sliding", nil) end
		humanoid.HipHeight = oldHipHeight
		state.lastTechName = "SlideBoost"
		state.lastTechResult = `Cancel; jump in {math.floor(jumpDelaySeconds * 1000)}ms`

		task.wait(jumpDelaySeconds)
		if not rootPart.Parent or not humanoid.Parent then return end
		rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + direction)
		humanoid.Jump = true
		rootPart.AssemblyLinearVelocity = direction * math.max(40, Vector3.new(
			rootPart.AssemblyLinearVelocity.X,
			0,
			rootPart.AssemblyLinearVelocity.Z
		).Magnitude)
			+ Vector3.yAxis * 48
		state.lastTechName = "SlideBoost"
		state.lastTechResult = "Jumped; probing vault"

		task.wait(Config.slideBoostPostJumpVaultDelaySeconds)
		if not rootPart.Parent or not humanoid.Parent then return end
		BotMotor.tryVault(state, rootPart, humanoid, targetPosition, ignore or {})
	end)

	return true
end

function BotMotor.tryRollBoost(state: RMotorState, rootPart: BasePart, humanoid: Humanoid, targetPosition: Vector3): boolean
	local now = os.clock()
	if now - state.lastRollBoostTime < 0.8 then
		state.lastTechName = "RollBoost"
		state.lastTechResult = "Cooldown"
		return false
	end
	local rollDelay = now - state.lastRollTime
	if rollDelay < Config.rollBoostMinDelaySeconds or rollDelay > Config.rollBoostMaxDelaySeconds then
		state.lastTechName = "RollBoost"
		state.lastTechResult = `Blocked: needs post-roll jump ({math.floor(rollDelay * 1000)}ms)`
		return false
	end
	if not BotMotor.isGrounded(humanoid) then
		state.lastTechName = "RollBoost"
		state.lastTechResult = `Blocked: {humanoid:GetState().Name}`
		return false
	end

	local delta = targetPosition - rootPart.Position
	local flatDelta = Vector3.new(delta.X, 0, delta.Z)
	if flatDelta.Magnitude <= 0.1 then return false end

	state.lastRollBoostTime = now
	humanoid.Jump = true
	rootPart.AssemblyLinearVelocity = flatDelta.Unit * math.max(36, rootPart.AssemblyLinearVelocity.Magnitude)
		+ Vector3.yAxis * 38
	state.lastTechName = "RollBoost"
	state.lastTechResult = "Success"
	return true
end

function BotMotor.tryRoll(state: RMotorState, rootPart: BasePart, humanoid: Humanoid, targetPosition: Vector3): boolean
	local now = os.clock()
	if now - state.lastRollTime < Config.rollCooldownSeconds then return false end
	if not BotMotor.isGrounded(humanoid) then return false end

	local delta = targetPosition - rootPart.Position
	local flatDelta = Vector3.new(delta.X, 0, delta.Z)
	if flatDelta.Magnitude <= 0.1 then return false end

	state.lastRollTime = now
	rootPart.AssemblyLinearVelocity = flatDelta.Unit * math.max(42, rootPart.AssemblyLinearVelocity.Magnitude)
		+ Vector3.new(0, rootPart.AssemblyLinearVelocity.Y, 0)
	state.lastTechName = "Roll"
	state.lastTechResult = "Speed preserved"
	return true
end

function BotMotor.tryTrampoline(state: RMotorState, rootPart: BasePart, humanoid: Humanoid, ignore: { Instance }): boolean
	local now = os.clock()
	if now - state.lastTrampolineTime < Config.trampolineCooldownSeconds then return false end

	local raycastParams = makeRaycastParams(ignore)
	local result = Workspace:Raycast(rootPart.Position + Vector3.yAxis * 0.2, -Vector3.yAxis * Config.trampolineProbeDistance, raycastParams)
	if not result or not CollectionService:HasTag(result.Instance, "Trampoline") then return false end

	local bounceAmount = result.Instance:GetAttribute("BounceAmount")
	local finalBounce = (if typeof(bounceAmount) == "number" then bounceAmount else Config.trampolineDefaultBounceAmount) / 1.2
	local velocity = rootPart.AssemblyLinearVelocity
	state.lastTrampolineTime = now
	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	rootPart.AssemblyLinearVelocity = Vector3.new(velocity.X, finalBounce, velocity.Z)
	state.lastTechName = "Trampoline"
	state.lastTechResult = `Bounce {math.floor(finalBounce * 10) / 10}`
	return true
end

function BotMotor.executePlannedAction(
	state: RMotorState,
	rootPart: BasePart,
	humanoid: Humanoid,
	targetPosition: Vector3,
	actionName: string,
	ignore: { Instance }
): boolean
	if actionName == "Walk" then return false end
	if actionName == "Jump" then return BotMotor.tryJump(state, humanoid) end
	if actionName == "Vault" or actionName == "HighVault" then return BotMotor.tryVault(state, rootPart, humanoid, targetPosition, ignore) end
	if actionName == "Swing" then return BotMotor.trySwing(state, rootPart, humanoid, targetPosition, ignore) end
	if actionName == "SlideBoost" then return BotMotor.trySlideBoost(state, rootPart, humanoid, targetPosition, ignore) end
	if actionName == "RollBoost" then return BotMotor.tryRollBoost(state, rootPart, humanoid, targetPosition) end
	if actionName == "Roll" or actionName == "Drop" then return BotMotor.tryRoll(state, rootPart, humanoid, targetPosition) end
	if actionName == "Trampoline" then return BotMotor.tryTrampoline(state, rootPart, humanoid, ignore) end

	return false
end

function BotMotor.executeExperimentalAction(
	state: RMotorState,
	rootPart: BasePart,
	humanoid: Humanoid,
	targetPosition: Vector3,
	actionName: string,
	ignore: { Instance }
): boolean
	if actionName == "Jump" then return BotMotor.tryJump(state, humanoid) end
	if actionName == "Vault" then return BotMotor.tryVault(state, rootPart, humanoid, targetPosition, ignore) end
	if actionName == "Swing" then return BotMotor.trySwing(state, rootPart, humanoid, targetPosition, ignore) end
	if actionName == "SlideBoost" then return BotMotor.trySlideBoost(state, rootPart, humanoid, targetPosition, ignore, true) end
	local slideBoostTiming = parseSlideBoostAction(actionName)
	if slideBoostTiming then
		return BotMotor.trySlideBoost(state, rootPart, humanoid, targetPosition, ignore, true, slideBoostTiming)
	end
	if actionName == "RollBoost" then return BotMotor.tryRollBoost(state, rootPart, humanoid, targetPosition) end
	if actionName == "Roll" then return BotMotor.tryRoll(state, rootPart, humanoid, targetPosition) end
	if actionName == "Trampoline" then return BotMotor.tryTrampoline(state, rootPart, humanoid, ignore) end

	return false
end

return BotMotor
