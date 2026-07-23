--!strict
--[[
    BotSkillController (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/18

    Non-yielding movement skill state machine. It executes one affordance at a
    time, keeps locomotion active while setting up tech, and revalidates world
    geometry before committing physics or cooldowns.
]]

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AnimationManager = require(ReplicatedStorage.Modules.Animations.AnimationManager)
local Config = require(ReplicatedStorage.Modules.Bot.BotNavigationConfig)
local MovementRules = require(ReplicatedStorage.Modules.Bot.BotMovementRules)
local BotRouteMemory = require(ReplicatedStorage.Modules.Bot.BotRouteMemory)
local BotSkillCalibration = require(ReplicatedStorage.Modules.Bot.BotSkillCalibration)
local Slide = require(ReplicatedStorage.Modules.Character.Parkour.Landing.Slide)
local Types = require(ReplicatedStorage.Modules.Bot.BotNavigationTypes)

type ActionKind = Types.ActionKind
type RAffordanceEdge = Types.RAffordanceEdge
type RLearningMemory = BotRouteMemory.RMemory
type RCalibrationSelection = BotSkillCalibration.RSelection
type RSkillResult = Types.RSkillResult

export type RController = {
	character: Model,
	humanoid: Humanoid,
	rootPart: BasePart,
	memory: RLearningMemory,
	activeEdge: RAffordanceEdge?,
	phase: string,
	phaseStartedAt: number,
	startedAt: number,
	startPosition: Vector3,
	bestTargetDistance: number,
	lastActionTimes: { [string]: number },
	result: RSkillResult,
	calibrationSelections: { RCalibrationSelection },
	approachOffset: number,
	preJumpDelay: number,
	slideHold: number,
	slideJumpDelay: number,
	slideBoostShouldVault: boolean,
	slideCancelHadGroundSupport: boolean,
	rollBoostDelay: number,
	minimumFallVelocity: number,
	rollFallStartY: number,
	rollWasAirborne: boolean,
	opportunisticRollUntil: number,
	swingBodyPosition: BodyPosition?,
	moveDirection: Vector3,
	preventApproachBacktrack: boolean,
	lockApproachDirection: boolean,
}

export type StartParams = {
	preventApproachBacktrack: boolean?,
	lockApproachDirection: boolean?,
}

local BotSkillController = {}

local function horizontalDirection(fromPosition: Vector3, toPosition: Vector3): Vector3
	local delta = toPosition - fromPosition
	local flat = Vector3.new(delta.X, 0, delta.Z)
	return if flat.Magnitude > 0.01 then flat.Unit else Vector3.zero
end

local function playAnimation(character: Model, animationName: string)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = if humanoid then humanoid:FindFirstChildOfClass("Animator") else nil
	local animations = ReplicatedStorage:FindFirstChild("Assets")
	if not animator or not animations then return end
	local candidate = animations:FindFirstChild(animationName, true)
	if not candidate or not candidate:IsA("Animation") then return end
	local track = AnimationManager.GetTrack(animator, candidate)
	track:Play(0.08)
end

local function playSound(rootPart: BasePart, soundName: string)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local sounds = if assets then assets:FindFirstChild("Sounds") else nil
	local source = if sounds then sounds:FindFirstChild(soundName, true) else nil
	if not source or not source:IsA("Sound") then return end
	local sound = source:Clone()
	sound.Parent = rootPart
	sound:Play()
	Debris:AddItem(sound, math.max(2, sound.TimeLength + 0.5))
end

local function turnAndMove(controller: RController, targetPosition: Vector3, dt: number)
	local direction = horizontalDirection(controller.rootPart.Position, targetPosition)
	if direction.Magnitude <= 0.01 then
		controller.humanoid:Move(Vector3.zero, false)
		return
	end

	controller.moveDirection = controller.moveDirection:Lerp(
		direction,
		math.clamp(dt / Config.routeMoveDirectionSmoothing, 0, 1)
	)
	if controller.moveDirection.Magnitude > 0.01 then controller.moveDirection = controller.moveDirection.Unit end
	local desired = CFrame.lookAt(controller.rootPart.Position, controller.rootPart.Position + controller.moveDirection)
	controller.rootPart.CFrame = controller.rootPart.CFrame:Lerp(
		desired,
		math.clamp(Config.routeTurnRate * dt, 0, 1)
	)
	controller.humanoid:Move(controller.moveDirection, false)
end

local function faceDirection(controller: RController, direction: Vector3, dt: number): boolean
	if direction.Magnitude <= 0.01 then return true end
	local flat = Vector3.new(direction.X, 0, direction.Z).Unit
	local desired = CFrame.lookAt(controller.rootPart.Position, controller.rootPart.Position + flat)
	controller.rootPart.CFrame = controller.rootPart.CFrame:Lerp(
		desired,
		math.clamp(Config.routeTurnRate * dt, 0, 1)
	)
	return controller.rootPart.CFrame.LookVector:Dot(flat) >= Config.skillFacingDot
end

local function horizontalDistance(fromPosition: Vector3, toPosition: Vector3): number
	local delta = toPosition - fromPosition
	return Vector3.new(delta.X, 0, delta.Z).Magnitude
end

local function reachedApproach(controller: RController, approach: Vector3, direction: Vector3): boolean
	local delta = controller.rootPart.Position - approach
	local flatDelta = Vector3.new(delta.X, 0, delta.Z)
	if flatDelta.Magnitude <= Config.skillApproachTolerance then return true end
	local flatDirection = Vector3.new(direction.X, 0, direction.Z)
	if flatDirection.Magnitude <= 0.01 then return false end
	flatDirection = flatDirection.Unit
	local along = flatDelta:Dot(flatDirection)
	local lateral = (flatDelta - flatDirection * along).Magnitude
	return along >= -0.75
		and along <= Config.skillApproachPassDistance
		and lateral <= Config.skillApproachTolerance
end

local function approachExpired(controller: RController): boolean
	return os.clock() - controller.startedAt >= Config.skillApproachTimeoutSeconds
end

local function canCommitApproach(controller: RController, approach: Vector3, direction: Vector3): boolean
	return reachedApproach(controller, approach, direction)
		or (approachExpired(controller)
			and horizontalDistance(controller.rootPart.Position, approach) <= Config.skillApproachActivationDistance)
end

local function setPhase(controller: RController, phase: string)
	controller.phase = phase
	controller.phaseStartedAt = os.clock()
	controller.result.reason = phase
end

local function finish(controller: RController, succeeded: boolean, reason: string)
	local edge = controller.activeEdge
	local duration = math.max(0, os.clock() - controller.startedAt)
	if edge then
		local progressQuality = 0
		local contactPosition = edge.setup.contactPosition
		if contactPosition and controller.bestTargetDistance < math.huge then
			local rootTarget = contactPosition + Vector3.yAxis * Config.rootFloorOffset
			local initialDistance = (controller.startPosition - rootTarget).Magnitude
			if initialDistance > 0.1 then
				progressQuality = math.clamp(
					(initialDistance - controller.bestTargetDistance) / initialDistance,
					0,
					1
				)
			end
		end
		for _, selection in controller.calibrationSelections do
			BotSkillCalibration.record(controller.memory, selection, succeeded, duration, progressQuality)
		end
	end
	if controller.swingBodyPosition then
		controller.swingBodyPosition:Destroy()
		controller.swingBodyPosition = nil
	end
	if controller.character:GetAttribute("Sliding") then
		Slide.StopForCharacter(controller.character)
		if edge and edge.action == "SlideBoost" then controller.lastActionTimes.SlideBoost = os.clock() end
	end
	controller.character:SetAttribute("Sliding", nil)
	controller.character:SetAttribute("Vaulting", nil)
	controller.character:SetAttribute("Swinging", nil)
	controller.character:SetAttribute("Rolling", nil)
	controller.humanoid.HipHeight = 0
	controller.humanoid.WalkSpeed = Config.botWalkSpeed
	controller.humanoid.JumpPower = Config.botJumpPower
	controller.result = {
		status = if succeeded then "Succeeded" else "Failed",
		action = if edge then edge.action else nil,
		reason = reason,
		edgeId = if edge then edge.id else nil,
	}
end

local function calibratedApproach(controller: RController, edge: RAffordanceEdge): Vector3
	local direction = Vector3.new(edge.setup.approachDirection.X, 0, edge.setup.approachDirection.Z)
	local approach = edge.setup.approachPosition - edge.setup.approachDirection * controller.approachOffset
	if not controller.preventApproachBacktrack or direction.Magnitude <= 0.01 then return approach end
	direction = direction.Unit
	local behindStart = (approach - controller.startPosition):Dot(direction)
	return if behindStart < 0 then approach - direction * behindStart else approach
end

local function aerialClearanceValid(controller: RController, edge: RAffordanceEdge, ignore: { Instance }): boolean
	if MovementRules.hasOverheadClearance(controller.rootPart.Position, edge.setup.requiredHeight, ignore) then
		return true
	end
	finish(controller, false, "Roof blocks required upward movement")
	return false
end

local function cooldownReady(controller: RController, action: ActionKind): boolean
	local cooldown = if action == "Jump"
		then Config.jumpCooldownSeconds
		elseif action == "Vault" or action == "HighVault"
		then Config.vaultCooldownSeconds
		elseif action == "Swing"
		then Config.swingCooldownSeconds
		elseif action == "Roll" or action == "RollBoost"
		then Config.rollCooldownSeconds
		elseif action == "SlideBoost"
		then Config.slideCooldownSeconds
		else 0
	return os.clock() - (controller.lastActionTimes[action] or 0) >= cooldown
end

local function markAction(controller: RController, action: ActionKind)
	controller.lastActionTimes[action] = os.clock()
end

local function stopOpportunisticRoll(controller: RController)
	controller.opportunisticRollUntil = 0
	controller.character:SetAttribute("Rolling", nil)
	controller.humanoid.WalkSpeed = Config.botWalkSpeed
end

local function reachedTarget(controller: RController, edge: RAffordanceEdge): boolean
	local target = edge.setup.contactPosition
	if not target then return false end
	local rootTarget = Vector3.new(target.X, target.Y + Config.rootFloorOffset, target.Z)
	return (controller.rootPart.Position - rootTarget).Magnitude <= Config.planNodeReachDistance
end

local function updateWalk(controller: RController, edge: RAffordanceEdge, dt: number, ignore: { Instance })
	local target = edge.setup.contactPosition or edge.setup.lookTarget or edge.setup.approachPosition
	if edge.setup.requiresSlide and controller.phase == "Approach" then
		if not MovementRules.isGrounded(controller.humanoid, controller.rootPart, ignore) then return end
		controller.character:SetAttribute("Sliding", true)
		controller.humanoid.HipHeight = Config.escapeSlideHipHeight
		playAnimation(controller.character, "SlideEnter")
		playSound(controller.rootPart, "Slide")
		setPhase(controller, "SlidingThroughPassage")
	end
	turnAndMove(controller, target, dt)
	local reachDistance = if edge.setup.requiresSlide
		then Config.slideTraversalReachDistance
		else Config.planNodeReachDistance
	local reached = (controller.rootPart.Position - target).Magnitude <= reachDistance
		or (not edge.setup.requiresSlide and reachedTarget(controller, edge))
	if reached then
		finish(controller, true, if edge.setup.requiresSlide then "Slid through low passage" else "Reached walk transition")
	elseif os.clock() - controller.startedAt > math.max(1.2, edge.expectedTime * 3) then
		finish(controller, false, if edge.setup.requiresSlide then "Low passage traversal timed out" else "Walk transition timed out")
	end
end

local function updateJump(controller: RController, edge: RAffordanceEdge, dt: number, ignore: { Instance })
	local target = edge.setup.contactPosition or edge.setup.lookTarget or edge.setup.approachPosition
	turnAndMove(controller, target, dt)
	if controller.phase == "Approach" then
		local approach = calibratedApproach(controller, edge)
		if not canCommitApproach(controller, approach, edge.setup.approachDirection) then
			if approachExpired(controller) then finish(controller, false, "Could not reach jump setup") end
			return
		end
		if not MovementRules.isGrounded(controller.humanoid, controller.rootPart, ignore) then return end
		if not cooldownReady(controller, "Jump") then return end
		if not aerialClearanceValid(controller, edge, ignore) then return end
		markAction(controller, "Jump")
		controller.humanoid.Jump = true
		playSound(controller.rootPart, "Jump")
		setPhase(controller, "Airborne")
	elseif reachedTarget(controller, edge) then
		finish(controller, true, "Jump destination reached")
	elseif os.clock() - controller.startedAt > 1.5 then
		finish(controller, false, "Jump missed destination")
	end
end

local function executeVaultImpulse(controller: RController, probe: MovementRules.VaultProbe)
	local studs = math.clamp(probe.vaultStuds, 0, 2.75)
	local velocity = controller.rootPart.AssemblyLinearVelocity
	local hitParent = probe.result.Instance.Parent
	local isTruss = probe.result.Instance:IsA("TrussPart")
		or (hitParent ~= nil and hitParent:FindFirstChildOfClass("TrussPart") ~= nil)
	controller.character:SetAttribute("Vaulting", true)
	controller.rootPart.AssemblyLinearVelocity = Vector3.new(
		velocity.X,
		math.clamp(studs / 1.5 * 30, 30, math.huge),
		velocity.Z
	) - probe.direction * 2
	if not isTruss then controller.humanoid.WalkSpeed += 2 end
	markAction(controller, "Vault")
	playAnimation(controller.character, "Vault")
	playSound(controller.rootPart, "Vault")
end

local function vaultProbeMatchesEdge(probe: MovementRules.VaultProbe?, edge: RAffordanceEdge): boolean
	if not probe then return false end
	if edge.action == "SlideBoost" then return true end
	local lookTarget = edge.setup.lookTarget
	if lookTarget then
		-- Maps commonly build one ledge from separate wall, trim, and floor parts.
		-- The hit position is the stable contract; exact instance identity is not.
		return (probe.result.Position - lookTarget).Magnitude <= Config.vaultTargetTolerance
	end
	local targetPart = edge.setup.targetPart
	return targetPart == nil or probe.result.Instance == targetPart
end

local function updateVault(controller: RController, edge: RAffordanceEdge, dt: number, ignore: { Instance })
	local approach = calibratedApproach(controller, edge)
	local direction = edge.setup.approachDirection
	if controller.phase == "Approach" then
		turnAndMove(controller, approach + direction * 4, dt)
		if not canCommitApproach(controller, approach, direction) then
			if approachExpired(controller) then finish(controller, false, "Could not reach vault setup") end
			return
		end
		if not faceDirection(controller, direction, dt) then return end
		local isGrounded = MovementRules.isGrounded(controller.humanoid, controller.rootPart, ignore)
		if isGrounded and not aerialClearanceValid(controller, edge, ignore) then return end
		if edge.action == "Vault" and isGrounded
			and (edge.setup.requiredHeight < Config.groundVaultMinHeight
				or edge.setup.requiredHeight > Config.groundVaultMaxHeight)
		then
			finish(controller, false, "Grounded vault height is outside the legal band")
			return
		end
		if edge.action == "HighVault" and edge.setup.requiredHeight > Config.maxVaultHeight then
			finish(controller, false, "High-vault ledge exceeds grounded maximum")
			return
		end
		if edge.action == "HighVault" and isGrounded then
			if not cooldownReady(controller, "Jump") then return end
			controller.humanoid.Jump = true
			markAction(controller, "Jump")
			setPhase(controller, "PreJump")
		else
			setPhase(controller, "Probe")
		end
		return
	end
	if controller.phase == "Vaulted" then
		local landing = edge.setup.contactPosition or edge.setup.lookTarget or approach + direction * 4
		turnAndMove(controller, landing, dt)
		if reachedTarget(controller, edge) then
			finish(controller, true, "Vault landing reached")
		elseif os.clock() - controller.startedAt > 1.8 then
			finish(controller, false, "Vault impulse did not reach the validated landing")
		end
		return
	end

	turnAndMove(controller, edge.setup.lookTarget or approach + direction * 4, dt)
	faceDirection(controller, direction, dt)
	if controller.phase == "PreJump" and os.clock() - controller.phaseStartedAt < controller.preJumpDelay then return end
	if not cooldownReady(controller, "Vault") then return end

	local probe = MovementRules.probeVault(controller.rootPart.Position, direction, ignore)
	if not vaultProbeMatchesEdge(probe, edge) then
		if controller.phase == "Probe"
			and edge.action == "HighVault"
			and MovementRules.isGrounded(controller.humanoid, controller.rootPart, ignore)
			and cooldownReady(controller, "Jump")
		then
			if not aerialClearanceValid(controller, edge, ignore) then return end
			controller.humanoid.Jump = true
			markAction(controller, "Jump")
			setPhase(controller, "PreJump")
			return
		end
		if os.clock() - controller.phaseStartedAt > 0.8 then finish(controller, false, "Vault raycast never became valid") end
		return
	end
	executeVaultImpulse(controller, probe :: MovementRules.VaultProbe)
	setPhase(controller, "Vaulted")
end

local function updateTrussClimb(controller: RController, edge: RAffordanceEdge, dt: number, ignore: { Instance })
	local truss = edge.setup.targetPart
	if not truss or not truss:IsA("TrussPart") or not truss.Parent then
		finish(controller, false, "Truss is unavailable")
		return
	end
	local targetFloor = edge.setup.contactPosition
	if not targetFloor then
		finish(controller, false, "Truss transition has no top landing")
		return
	end
	local targetRoot = targetFloor + Vector3.yAxis * Config.rootFloorOffset
	local direction = horizontalDirection(controller.rootPart.Position, truss.Position)
	if direction.Magnitude <= 0.01 then direction = edge.setup.approachDirection end

	if controller.phase == "Approach" then
		turnAndMove(controller, Vector3.new(truss.Position.X, controller.rootPart.Position.Y, truss.Position.Z), dt)
		if horizontalDistance(controller.rootPart.Position, truss.Position) > Config.trussContactDistance then
			if approachExpired(controller) then finish(controller, false, "Could not reach truss") end
			return
		end
		if not faceDirection(controller, direction, dt) then return end
		setPhase(controller, "Climbing")
	end

	if controller.phase == "Climbing" then
		faceDirection(controller, direction, dt)
		controller.humanoid:Move(direction, false)
		if horizontalDistance(controller.rootPart.Position, truss.Position) > Config.trussContactDistance * 2 then
			finish(controller, false, "Lost contact with truss")
			return
		end
		if cooldownReady(controller, "Vault") then
			local probe = MovementRules.probeVault(controller.rootPart.Position, direction, ignore)
			if probe and probe.result.Instance == truss then executeVaultImpulse(controller, probe) end
		end
		if controller.rootPart.Position.Y >= targetRoot.Y - Config.planResyncVerticalTolerance then
			setPhase(controller, "Dismount")
		end
	elseif controller.phase == "Dismount" then
		turnAndMove(controller, targetRoot, dt)
		if reachedTarget(controller, edge) then
			finish(controller, true, "Truss top reached")
			return
		end
	end

	local timeout = math.max(2, edge.expectedTime * Config.trussClimbTimeoutMultiplier)
	if os.clock() - controller.startedAt > timeout then finish(controller, false, "Truss climb timed out") end
end

local function updateSwing(controller: RController, edge: RAffordanceEdge, dt: number, ignore: { Instance })
	local direction = edge.setup.approachDirection
	local approach = calibratedApproach(controller, edge)
	if controller.phase == "Approach" then
		turnAndMove(controller, approach + direction * 4, dt)
		if not canCommitApproach(controller, approach, direction) then
			if approachExpired(controller) then finish(controller, false, "Could not reach swing setup") end
			return
		end
		if not faceDirection(controller, direction, dt) or not cooldownReady(controller, "Swing") then return end
		if not aerialClearanceValid(controller, edge, ignore) then return end
		local probe = MovementRules.probeSwing(controller.rootPart.Position, direction, ignore)
		if probe and edge.setup.targetPart and probe.Instance ~= edge.setup.targetPart then probe = nil end
		if not probe then
			local lookTarget = edge.setup.lookTarget
			local needsHeight = lookTarget ~= nil and lookTarget.Y > controller.rootPart.Position.Y + 1.5
			if needsHeight and MovementRules.isGrounded(controller.humanoid, controller.rootPart, ignore)
				and cooldownReady(controller, "Jump")
			then
				controller.humanoid.Jump = true
				markAction(controller, "Jump")
				setPhase(controller, "SwingPreJump")
				return
			end
			finish(controller, false, "Swing bar raycast invalid after approach")
			return
		end
		setPhase(controller, "SwingProbeValid")
	end

	if controller.phase == "SwingPreJump" or controller.phase == "SwingProbeValid" then
		turnAndMove(controller, edge.setup.lookTarget or approach + direction * 4, dt)
		faceDirection(controller, direction, dt)
		if controller.phase == "SwingPreJump"
			and os.clock() - controller.phaseStartedAt < controller.preJumpDelay
		then
			return
		end
		local probe = MovementRules.probeSwing(controller.rootPart.Position, direction, ignore)
		if probe and edge.setup.targetPart and probe.Instance ~= edge.setup.targetPart then probe = nil end
		if not probe then
			if os.clock() - controller.phaseStartedAt > 0.65 then finish(controller, false, "Swing pre-jump missed bar") end
			return
		end
		controller.character:SetAttribute("Swinging", true)
		markAction(controller, "Swing")
		playAnimation(controller.character, "Swing")
		playSound(controller.rootPart, "Swing")
		local bodyPosition = Instance.new("BodyPosition")
		bodyPosition.MaxForce = Vector3.new(700, 9000, 700)
		bodyPosition.Position = probe.Position + Vector3.new(0, -1.5, 0)
		bodyPosition.Parent = controller.rootPart
		controller.swingBodyPosition = bodyPosition
		setPhase(controller, "Attached")
		return
	end

	if controller.phase == "Attached" and os.clock() - controller.phaseStartedAt >= 0.4 then
		if controller.swingBodyPosition then controller.swingBodyPosition:Destroy() end
		controller.swingBodyPosition = nil
		local velocity = controller.rootPart.AssemblyLinearVelocity
		local swingFactor = (math.clamp(-velocity.Y, 25, 80) / 25) ^ 0.7
		controller.rootPart.AssemblyLinearVelocity += direction * (swingFactor * 50)
		controller.character:SetAttribute("Swinging", nil)
		setPhase(controller, "Released")
	end

	turnAndMove(controller, edge.setup.contactPosition or edge.setup.approachPosition + direction * 6, dt)
	if reachedTarget(controller, edge) then finish(controller, true, "Swing destination reached") end
	if os.clock() - controller.startedAt > 2 then finish(controller, false, "Swing transition timed out") end
end

local function updateSlideBoost(controller: RController, edge: RAffordanceEdge, dt: number, ignore: { Instance })
	local direction = edge.setup.approachDirection
	local approach = calibratedApproach(controller, edge)
	local lookTarget = edge.setup.lookTarget or approach + direction * 8
	if controller.phase == "Approach" then
		if controller.lockApproachDirection then
			turnAndMove(controller, controller.rootPart.Position + direction * 8, dt)
		else
			turnAndMove(controller, approach + direction * 5, dt)
		end
		if not canCommitApproach(controller, approach, direction) then
			if approachExpired(controller) then finish(controller, false, "Could not reach slide-boost setup") end
			return
		end
		if not MovementRules.isGrounded(controller.humanoid, controller.rootPart, ignore) then return end
		if not faceDirection(controller, direction, dt) or not cooldownReady(controller, "SlideBoost") then return end
		local groundedTravelLength = Config.botWalkSpeed * (controller.slideHold + controller.slideJumpDelay)
		local expectedFloorY = approach.Y - Config.rootFloorOffset
		if not MovementRules.hasFlatSlideBoostGround(
			approach,
			direction,
			groundedTravelLength,
			expectedFloorY,
			nil
		) then
			finish(controller, false, "Slide-boost setup is not long and level")
			return
		end
		local started, reason = Slide.StartForCharacter(controller.character)
		if not started then
			if approachExpired(controller) then finish(controller, false, `Slide check failed: {reason or "unknown"}`) end
			return
		end
		setPhase(controller, "Sliding")
		return
	end

	turnAndMove(controller, lookTarget, dt)
	faceDirection(controller, direction, dt)
	-- Run-up calibration owns when the bot reaches the wall. Triggering from
	-- wall distance here bypasses the selected timing and prevents learning.
	if controller.phase == "Sliding" and os.clock() - controller.phaseStartedAt >= controller.slideHold then
		controller.slideCancelHadGroundSupport = MovementRules.hasGroundSupport(
			controller.humanoid,
			controller.rootPart,
			ignore
		)
		Slide.StopForCharacter(controller.character)
		-- As with the player Slide.Stop path, cooldown begins after cancellation;
		-- it never gates or delays the cancellation itself.
		markAction(controller, "SlideBoost")
		setPhase(controller, "Cancelled")
		return
	end
	if controller.phase == "Cancelled" and os.clock() - controller.phaseStartedAt >= controller.slideJumpDelay then
		local hasGroundSupport = controller.slideCancelHadGroundSupport
			or MovementRules.hasGroundSupport(controller.humanoid, controller.rootPart, ignore)
		if not hasGroundSupport then
			finish(controller, false, "Left ground before slide-boost jump")
			return
		end
		if not cooldownReady(controller, "Jump") then return end
		if not aerialClearanceValid(controller, edge, ignore) then return end
		controller.humanoid.Jump = true
		controller.humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		markAction(controller, "Jump")
		playSound(controller.rootPart, "Jump")
		setPhase(controller, "BoostJump")
		return
	end
	if controller.phase == "BoostJump" and controller.slideBoostShouldVault then
		local probe = MovementRules.probeVault(controller.rootPart.Position, direction, ignore)
		if vaultProbeMatchesEdge(probe, edge) and cooldownReady(controller, "Vault") then
			executeVaultImpulse(controller, probe :: MovementRules.VaultProbe)
			setPhase(controller, "Vaulted")
		end
	end

	if reachedTarget(controller, edge) then finish(controller, true, "Slide boost destination reached") end
	if os.clock() - controller.startedAt > 2.2 then finish(controller, false, "Slide boost missed ledge") end
end

local function updateDropOrRoll(controller: RController, edge: RAffordanceEdge, dt: number, ignore: { Instance })
	local target = edge.setup.contactPosition or edge.setup.approachPosition
	if controller.phase == "Approach" then
		local direction = edge.setup.approachDirection
		local approach = calibratedApproach(controller, edge)
		turnAndMove(controller, approach + direction * 4, dt)
		if not canCommitApproach(controller, approach, direction) then
			if approachExpired(controller) then finish(controller, false, "Could not reach drop setup") end
			return
		end
		if MovementRules.isGrounded(controller.humanoid, controller.rootPart, ignore) then
			if not cooldownReady(controller, "Jump") then return end
			controller.rollFallStartY = controller.rootPart.Position.Y
			controller.humanoid.Jump = true
			markAction(controller, "Jump")
			if edge.action == "Roll" then controller.rollWasAirborne = true end
			setPhase(controller, "DropJump")
		else
			controller.rollFallStartY = controller.rootPart.Position.Y
			controller.rollWasAirborne = true
			setPhase(controller, "Falling")
		end
		return
	end
	turnAndMove(controller, target, dt)
	local verticalVelocity = controller.rootPart.AssemblyLinearVelocity.Y
	controller.minimumFallVelocity = math.min(controller.minimumFallVelocity, verticalVelocity)
	local grounded = MovementRules.isGrounded(controller.humanoid, controller.rootPart, ignore)
	if not grounded then controller.rollWasAirborne = true end
	if edge.action == "Roll"
		and controller.phase ~= "Rolled"
		and controller.phase ~= "RollArmed"
		and controller.rollWasAirborne
	then
		local dropDistance = math.max(0, controller.rollFallStartY - controller.rootPart.Position.Y)
		local estimatedFallVelocity = -math.sqrt(2 * Workspace.Gravity * dropDistance)
		local landingVelocity = math.min(controller.minimumFallVelocity, estimatedFallVelocity)
		local requiredFallVelocity = if edge.setup.requiredSpeed < 0
			then edge.setup.requiredSpeed
			else Config.rollRequiredFallSpeed
		if landingVelocity <= requiredFallVelocity then setPhase(controller, "RollArmed") end
	end
	if controller.phase == "RollArmed" and grounded and cooldownReady(controller, "Roll") then
		markAction(controller, "Roll")
		controller.character:SetAttribute("Rolling", true)
		controller.humanoid.WalkSpeed *= 1.3
		playAnimation(controller.character, "Roll")
		playSound(controller.rootPart, "Roll")
		setPhase(controller, "Rolled")
		return
	end
	if controller.phase == "Rolled" then
		if os.clock() - controller.phaseStartedAt >= Config.rollTransitionSeconds and reachedTarget(controller, edge) then
			finish(controller, true, "Roll destination reached")
		elseif os.clock() - controller.startedAt > 2.2 then
			finish(controller, false, "Roll destination missed")
		end
		return
	end
	if reachedTarget(controller, edge) and grounded then
		if edge.action == "Roll" and controller.phase ~= "Rolled" then
			finish(controller, false, "Landed without valid roll velocity")
		else
			finish(controller, true, if edge.action == "Roll" then "Roll destination reached" else "Drop destination reached")
		end
	end
	if os.clock() - controller.startedAt > 2.2 then finish(controller, false, "Drop transition timed out") end
end

local function updateRollBoost(controller: RController, edge: RAffordanceEdge, dt: number, ignore: { Instance })
	local target = edge.setup.contactPosition or edge.setup.approachPosition
	turnAndMove(controller, target, dt)
	if controller.phase == "Boosted" then
		if reachedTarget(controller, edge) then
			finish(controller, true, "Rollboost destination reached")
		elseif os.clock() - controller.startedAt > 1.4 then
			finish(controller, false, "Rollboost missed destination")
		end
		return
	end
	local elapsedSinceRoll = os.clock() - (controller.lastActionTimes.Roll or -math.huge)
	if elapsedSinceRoll > Config.rollBoostDelayMax then
		finish(controller, false, "Rollboost requires a preceding roll")
		return
	end
	if elapsedSinceRoll < controller.rollBoostDelay then return end
	if not MovementRules.isGrounded(controller.humanoid, controller.rootPart, ignore) then return end
	if not aerialClearanceValid(controller, edge, ignore) then return end
	controller.humanoid.JumpPower = Config.botJumpPower * 1.3
	controller.humanoid.Jump = true
	controller.humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	markAction(controller, "RollBoost")
	setPhase(controller, "Boosted")
end

local function updateTrampoline(controller: RController, edge: RAffordanceEdge, dt: number, ignore: { Instance })
	turnAndMove(controller, edge.setup.approachPosition, dt)
	local result = MovementRules.getTrampolineBelow(controller.rootPart.Position, ignore)
	if result then
		local bounce = result.Instance:GetAttribute("BounceAmount")
		local bounceAmount = (if typeof(bounce) == "number" then bounce else 115) / 1.2
		local velocity = controller.rootPart.AssemblyLinearVelocity
		controller.humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		controller.rootPart.AssemblyLinearVelocity = Vector3.new(velocity.X, bounceAmount, velocity.Z)
		playSound(controller.rootPart, "Trampoline")
		setPhase(controller, "Bounced")
	end
	if reachedTarget(controller, edge) then finish(controller, true, "Trampoline destination reached") end
	if os.clock() - controller.startedAt > 2.5 then finish(controller, false, "Trampoline transition timed out") end
end

function BotSkillController.create(
	character: Model,
	humanoid: Humanoid,
	rootPart: BasePart,
	memory: RLearningMemory
): RController
	return {
		character = character,
		humanoid = humanoid,
		rootPart = rootPart,
		memory = memory,
		activeEdge = nil,
		phase = "Idle",
		phaseStartedAt = 0,
		startedAt = 0,
		startPosition = rootPart.Position,
		bestTargetDistance = math.huge,
		lastActionTimes = {},
		result = { status = "Idle", action = nil, reason = "No transition", edgeId = nil },
		calibrationSelections = {},
		approachOffset = 0,
		preJumpDelay = Config.skillPreJumpDelayMin,
		slideHold = Config.slideHoldDefault,
		slideJumpDelay = Config.slideJumpDelayDefault,
		slideBoostShouldVault = true,
		slideCancelHadGroundSupport = false,
		rollBoostDelay = Config.rollBoostDelayDefault,
		minimumFallVelocity = 0,
		rollFallStartY = rootPart.Position.Y,
		rollWasAirborne = false,
		opportunisticRollUntil = 0,
		swingBodyPosition = nil,
		moveDirection = Vector3.zero,
		preventApproachBacktrack = false,
		lockApproachDirection = false,
	}
end

function BotSkillController.start(controller: RController, edge: RAffordanceEdge, params: StartParams?)
	stopOpportunisticRoll(controller)
	if controller.swingBodyPosition then controller.swingBodyPosition:Destroy() end
	controller.activeEdge = edge
	controller.phase = "Approach"
	controller.phaseStartedAt = os.clock()
	controller.startedAt = os.clock()
	controller.startPosition = controller.rootPart.Position
	controller.bestTargetDistance = math.huge
	controller.minimumFallVelocity = math.min(0, controller.rootPart.AssemblyLinearVelocity.Y)
	controller.rollFallStartY = controller.rootPart.Position.Y
	controller.rollWasAirborne = false
	local velocity = controller.rootPart.AssemblyLinearVelocity
	local horizontalVelocity = Vector3.new(velocity.X, 0, velocity.Z)
	if horizontalVelocity.Magnitude >= Config.planInitialMotionSpeed then
		controller.moveDirection = horizontalVelocity.Unit
	elseif controller.moveDirection.Magnitude <= 0.01 then
		local look = controller.rootPart.CFrame.LookVector
		controller.moveDirection = Vector3.new(look.X, 0, look.Z).Unit
	end
	controller.result = { status = "Running", action = edge.action, reason = "Approaching setup", edgeId = edge.id }
	table.clear(controller.calibrationSelections)
	controller.approachOffset = 0
	controller.preJumpDelay = Config.skillPreJumpDelayMin
	controller.slideHold = Config.slideHoldDefault
	controller.slideJumpDelay = Config.slideJumpDelayDefault
	controller.slideBoostShouldVault = true
	controller.slideCancelHadGroundSupport = false
	controller.rollBoostDelay = Config.rollBoostDelayDefault
	controller.preventApproachBacktrack = params ~= nil and params.preventApproachBacktrack == true
	controller.lockApproachDirection = params ~= nil and params.lockApproachDirection == true

	if edge.action == "Jump" or edge.action == "Vault" or edge.action == "HighVault"
		or edge.action == "Swing" or edge.action == "SlideBoost"
	then
		local runupMinimum = if edge.action == "SlideBoost"
			then Config.slideBoostRunupOffsetMin
			else Config.skillRunupOffsetMin
		local runupMaximum = if edge.action == "SlideBoost"
			then Config.slideBoostRunupOffsetMax
			else Config.skillRunupOffsetMax
		local selection = BotSkillCalibration.choose(
			controller.memory,
			edge,
			"RunupOffset",
			runupMinimum,
			runupMaximum,
			0
		)
		controller.approachOffset = selection.value
		controller.calibrationSelections[#controller.calibrationSelections + 1] = selection
	end
	if edge.action == "HighVault" or edge.action == "Swing" then
		local selection = BotSkillCalibration.choose(
			controller.memory,
			edge,
			"PreJumpDelay",
			Config.skillPreJumpDelayMin,
			Config.skillPreJumpDelayMax,
			0.08
		)
		controller.preJumpDelay = selection.value
		controller.calibrationSelections[#controller.calibrationSelections + 1] = selection
	end
	if edge.action == "SlideBoost" then
		local holdSelection = BotSkillCalibration.choose(
			controller.memory,
			edge,
			"SlideHold",
			Config.slideHoldMin,
			Config.slideHoldMax,
			Config.slideHoldDefault
		)
		local jumpSelection = BotSkillCalibration.choose(
			controller.memory,
			edge,
			"SlideJumpDelay",
			Config.slideJumpDelayMin,
			Config.slideJumpDelayMax,
			Config.slideJumpDelayDefault
		)
		controller.slideHold = holdSelection.value
		controller.slideJumpDelay = jumpSelection.value
		local vaultSelection = BotSkillCalibration.chooseBoolean(
			controller.memory,
			edge,
			"VaultFollowup",
			true
		)
		controller.slideBoostShouldVault = vaultSelection.value >= 0.5
		controller.calibrationSelections[#controller.calibrationSelections + 1] = holdSelection
		controller.calibrationSelections[#controller.calibrationSelections + 1] = jumpSelection
		controller.calibrationSelections[#controller.calibrationSelections + 1] = vaultSelection
	elseif edge.action == "RollBoost" then
		local selection = BotSkillCalibration.choose(
			controller.memory,
			edge,
			"RollBoostDelay",
			Config.rollBoostDelayMin,
			Config.rollBoostDelayMax,
			Config.rollBoostDelayDefault
		)
		controller.rollBoostDelay = selection.value
		controller.calibrationSelections[#controller.calibrationSelections + 1] = selection
	end
end

function BotSkillController.cancel(controller: RController, reason: string)
	if not controller.activeEdge then return end
	-- Tactical replans are not evidence that the selected physical setup failed.
	table.clear(controller.calibrationSelections)
	finish(controller, false, reason)
end

function BotSkillController.complete(controller: RController, reason: string)
	if not controller.activeEdge then return end
	finish(controller, true, reason)
end

function BotSkillController.clear(controller: RController)
	controller.activeEdge = nil
	controller.phase = "Idle"
	controller.result = { status = "Idle", action = nil, reason = "No transition", edgeId = nil }
end

function BotSkillController.stopOpportunisticRoll(controller: RController)
	stopOpportunisticRoll(controller)
end

--[=[
	@client

	updateOpportunisticRoll
	=======================

	Observes actual airborne velocity and rolls on landing when the agent says
	the momentum helps its current route. This keeps rolling independent from
	graph destinations while preserving the real fall-speed and cooldown rules.
]=]
function BotSkillController.updateOpportunisticRoll(
	controller: RController,
	targetPosition: Vector3,
	dt: number,
	ignore: { Instance },
	allowed: boolean
): boolean
	local now = os.clock()
	if controller.opportunisticRollUntil > 0 then
		if now < controller.opportunisticRollUntil then
			turnAndMove(controller, targetPosition, dt)
			return true
		end
		stopOpportunisticRoll(controller)
	end

	if controller.activeEdge then return false end

	local verticalVelocity = controller.rootPart.AssemblyLinearVelocity.Y
	local grounded = MovementRules.isGrounded(controller.humanoid, controller.rootPart, ignore)
	if not grounded then
		controller.minimumFallVelocity = math.min(controller.minimumFallVelocity, verticalVelocity)
		if verticalVelocity <= Config.rollRequiredFallSpeed then controller.rollWasAirborne = true end
		return false
	end

	local shouldRoll = allowed
		and controller.rollWasAirborne
		and controller.minimumFallVelocity <= Config.rollRequiredFallSpeed
		and cooldownReady(controller, "Roll")
	controller.rollWasAirborne = false
	controller.minimumFallVelocity = 0
	if not shouldRoll then return false end

	markAction(controller, "Roll")
	controller.opportunisticRollUntil = now + Config.opportunisticRollDurationSeconds
	controller.character:SetAttribute("Rolling", true)
	controller.humanoid.WalkSpeed = Config.botWalkSpeed * 1.3
	playAnimation(controller.character, "Roll")
	playSound(controller.rootPart, "Roll")
	turnAndMove(controller, targetPosition, dt)
	return true
end

function BotSkillController.update(controller: RController, dt: number, ignore: { Instance }): RSkillResult
	local edge = controller.activeEdge
	if not edge or controller.result.status ~= "Running" then return controller.result end
	if not controller.character.Parent or controller.humanoid.Health <= 0 then
		finish(controller, false, "Bot character unavailable")
		return controller.result
	end
	local contactPosition = edge.setup.contactPosition
	if contactPosition then
		local rootTarget = contactPosition + Vector3.yAxis * Config.rootFloorOffset
		controller.bestTargetDistance = math.min(
			controller.bestTargetDistance,
			(controller.rootPart.Position - rootTarget).Magnitude
		)
	end

	if edge.action == "Walk" then
		updateWalk(controller, edge, dt, ignore)
	elseif edge.action == "Jump" then
		updateJump(controller, edge, dt, ignore)
	elseif edge.action == "Vault" or edge.action == "HighVault" then
		updateVault(controller, edge, dt, ignore)
	elseif edge.action == "TrussClimb" then
		updateTrussClimb(controller, edge, dt, ignore)
	elseif edge.action == "Swing" then
		updateSwing(controller, edge, dt, ignore)
	elseif edge.action == "SlideBoost" then
		updateSlideBoost(controller, edge, dt, ignore)
	elseif edge.action == "Drop" or edge.action == "Roll" then
		updateDropOrRoll(controller, edge, dt, ignore)
	elseif edge.action == "RollBoost" then
		updateRollBoost(controller, edge, dt, ignore)
	elseif edge.action == "Trampoline" then
		updateTrampoline(controller, edge, dt, ignore)
	end
	return controller.result
end

return table.freeze(BotSkillController)
