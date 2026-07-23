--!strict
--[[
    BotMotion (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/18

    Deterministic locomotion and parkour executor. It revalidates real vault,
    swing, grounded, slide, roll, and cooldown constraints at execution time.
]]

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AnimationManager = require(ReplicatedStorage.Modules.Animations.AnimationManager)
local CharacterMovementModel = require(ReplicatedStorage.Modules.Character.Movement.CharacterMovementModel)
local ParkourMovementModel = require(ReplicatedStorage.Modules.Character.Parkour.ParkourMovementModel)
local Slide = require(ReplicatedStorage.Modules.Character.Parkour.Landing.Slide)
local Config = require(ReplicatedStorage.Modules.Bot.BotConfig)
local Types = require(ReplicatedStorage.Modules.Bot.BotTypes)

type Action = Types.Action
type REdge = Types.REdge

export type RState = {
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
	edge: REdge?,
	phase: string,
	startedAt: number,
	phaseAt: number,
	lastAction: { [string]: number },
	result: "Idle" | "Running" | "Succeeded" | "Failed",
	reason: string,
	moveDirection: Vector3,
	minimumFallVelocity: number,
	rollArmed: boolean,
	rollUntil: number,
	rollPressedAt: number?,
	rollStartedAt: number,
	rollJumpBoostAt: number,
	rollBoostUsed: boolean,
	rollPreviousWalkSpeed: number,
	rollDirection: Vector3,
	swingPosition: BodyPosition?,
	swingPart: BasePart?,
	swingPartCanCollide: boolean,
	swingParentPart: BasePart?,
	swingParentCanCollide: boolean,
	swingEntryVelocityY: number,
	lastTrampoline: { [BasePart]: number },
	slideHold: number,
	slideJumpDelay: number,
}

local BotMotion = {}

local function ignoreList(character: Model): { Instance }
	local ignore: { Instance } = { character }
	local bots = Workspace:FindFirstChild("Bots")
	if bots then ignore[#ignore + 1] = bots end
	return ignore
end

local function params(character: Model): RaycastParams
	local value = RaycastParams.new()
	value.FilterType = Enum.RaycastFilterType.Exclude
	value.FilterDescendantsInstances = ignoreList(character)
	value.IgnoreWater = true
	return value
end

local function flatDirection(fromPosition: Vector3, toPosition: Vector3): Vector3
	local delta = toPosition - fromPosition
	local flat = Vector3.new(delta.X, 0, delta.Z)
	return if flat.Magnitude > 0.01 then flat.Unit else Vector3.zero
end

local function grounded(state: RState): boolean
	if math.abs(state.root.AssemblyLinearVelocity.Y) > 0.5 then return false end
	if state.humanoid.FloorMaterial ~= Enum.Material.Air then return true end
	local hit = Workspace:Raycast(state.root.Position, -Vector3.yAxis * 3.2, params(state.character))
	return hit ~= nil and hit.Normal.Y >= 0.55
end

local function hasGroundSupport(state: RState): boolean
	if state.humanoid.FloorMaterial ~= Enum.Material.Air then return true end
	local hit = Workspace:Raycast(state.root.Position, -Vector3.yAxis * 3.2, params(state.character))
	return hit ~= nil and hit.Normal.Y >= 0.55
end

local function cooldown(state: RState, action: string, duration: number): boolean
	return os.clock() - (state.lastAction[action] or 0) >= duration
end

local function mark(state: RState, action: string)
	state.lastAction[action] = os.clock()
end

local function animation(state: RState, name: string): AnimationTrack?
	local animator = state.humanoid:FindFirstChildOfClass("Animator")
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local candidate = if assets then assets:FindFirstChild(name, true) else nil
	if not animator or not candidate or not candidate:IsA("Animation") then return nil end
	local track = AnimationManager.GetTrack(animator, candidate)
	track:Play(0.08)
	return track
end

local function sound(state: RState, name: string)
	local source = ReplicatedStorage.Assets:FindFirstChild(name, true)
	if not source or not source:IsA("Sound") then return end
	local clone = source:Clone()
	clone.Parent = state.root
	clone:Play()
	Debris:AddItem(clone, 3)
end

local function move(state: RState, target: Vector3, dt: number)
	local direction = flatDirection(state.root.Position, target)
	if direction.Magnitude == 0 then
		state.character:SetAttribute("ForwardHeld", false)
		state.humanoid:Move(Vector3.zero, false)
		return
	end
	state.moveDirection = state.moveDirection:Lerp(direction, math.clamp(dt / 0.05, 0, 1))
	if state.moveDirection.Magnitude > 0.01 then state.moveDirection = state.moveDirection.Unit end
	local desired = CFrame.lookAt(state.root.Position, state.root.Position + state.moveDirection)
	state.root.CFrame = state.root.CFrame:Lerp(desired, math.clamp(dt * 24, 0, 1))
	state.character:SetAttribute("ForwardHeld", true)
	state.humanoid:Move(state.moveDirection, false)
end

local function phase(state: RState, name: string)
	state.phase = name
	state.phaseAt = os.clock()
end

local function finish(state: RState, succeeded: boolean, reason: string)
	if state.swingPosition then
		state.swingPosition:Destroy()
		state.swingPosition = nil
	end
	if state.swingPart and state.swingPart.Parent then state.swingPart.CanCollide = state.swingPartCanCollide end
	if state.swingParentPart and state.swingParentPart.Parent then
		state.swingParentPart.CanCollide = state.swingParentCanCollide
	end
	state.swingPart = nil
	state.swingParentPart = nil
	if state.character:GetAttribute("Sliding") then Slide.StopForCharacter(state.character) end
	state.character:SetAttribute("Vaulting", nil)
	state.character:SetAttribute("Swinging", nil)
	state.result = if succeeded then "Succeeded" else "Failed"
	state.reason = reason
end

local function reached(state: RState, target: Vector3): boolean
	if (state.root.Position - target).Magnitude <= Config.plannerReachDistance then return true end
	local edge = state.edge
	if not edge or edge.direction.Magnitude < 0.1 then return false end
	local remaining = Vector3.new(target.X - state.root.Position.X, 0, target.Z - state.root.Position.Z)
	local forwardRemaining = remaining:Dot(edge.direction)
	local lateral = (remaining - edge.direction * forwardRemaining).Magnitude
	return forwardRemaining <= 0
		and lateral <= Config.plannerReachDistance * 1.25
		and math.abs(target.Y - state.root.Position.Y) <= Config.plannerGoalLayerTolerance + 2
end

local function probeVault(state: RState): ParkourMovementModel.RAerialProbe?
	return ParkourMovementModel.probeVault(
		state.root.Position,
		state.root.CFrame.LookVector,
		ignoreList(state.character)
	)
end

local function executeVault(state: RState, probe: ParkourMovementModel.RAerialProbe)
	local studs = ParkourMovementModel.vaultStuds(probe.studs)
	state.character:SetAttribute("Vaulting", true)
	state.root.AssemblyLinearVelocity = ParkourMovementModel.vaultVelocity(
		state.root.AssemblyLinearVelocity,
		probe.direction,
		studs
	)
	if not ParkourMovementModel.isTruss(probe.result.Instance) then
		state.humanoid.WalkSpeed += 2
		state.character:SetAttribute("Momentum", (state.character:GetAttribute("Momentum") or 0) + 2)
	end
	mark(state, "Vault")
	animation(state, "Vault")
	sound(state, "Vault")
	phase(state, "Vaulted")
	task.delay(0.11, function()
		if state.character.Parent then state.character:SetAttribute("Vaulting", nil) end
	end)
end

local function updateTrampoline(state: RState)
	local trampolineHit = Workspace:Raycast(
		state.root.Position + Vector3.yAxis * 0.2,
		-Vector3.yAxis * 3.8,
		params(state.character)
	)
	if not trampolineHit or not trampolineHit.Instance:IsA("BasePart") then return end
	local trampoline = trampolineHit.Instance
	if not CollectionService:HasTag(trampoline, "Trampoline") then return end
	if os.clock() - (state.lastTrampoline[trampoline] or 0) <= ParkourMovementModel.cooldowns.trampoline then return end
	local bounceAmount = trampoline:GetAttribute("BounceAmount")
	assert(typeof(bounceAmount) == "number", "[BotMotion.updateTrampoline] trampoline has no numeric BounceAmount")
	state.lastTrampoline[trampoline] = os.clock()
	if state.character:GetAttribute("Sliding") then Slide.StopForCharacter(state.character) end
	state.humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	state.root.AssemblyLinearVelocity = ParkourMovementModel.trampolineVelocity(
		state.root.AssemblyLinearVelocity,
		bounceAmount
	)
	mark(state, "Trampoline")
	sound(state, "Trampoline")
end

function BotMotion.create(character: Model, humanoid: Humanoid, root: BasePart): RState
	return {
		character = character,
		humanoid = humanoid,
		root = root,
		edge = nil,
		phase = "Idle",
		startedAt = 0,
		phaseAt = 0,
		lastAction = {},
		result = "Idle",
		reason = "No transition",
		moveDirection = Vector3.zero,
		minimumFallVelocity = 0,
		rollArmed = false,
		rollUntil = 0,
		rollPressedAt = nil,
		rollStartedAt = 0,
		rollJumpBoostAt = 0,
		rollBoostUsed = false,
		rollPreviousWalkSpeed = humanoid.WalkSpeed,
		rollDirection = Vector3.zero,
		swingPosition = nil,
		swingPart = nil,
		swingPartCanCollide = false,
		swingParentPart = nil,
		swingParentCanCollide = false,
		swingEntryVelocityY = 0,
		lastTrampoline = {},
		slideHold = 0.275,
		slideJumpDelay = 0.1,
	}
end

function BotMotion.start(state: RState, edge: REdge, learnedSlideHold: number?)
	state.edge = edge
	state.startedAt = os.clock()
	state.result = "Running"
	state.reason = "Approaching setup"
	state.slideHold = math.clamp(learnedSlideHold or math.random(200, 350) / 1000, Config.slideHoldMinimum, Config.slideHoldMaximum)
	state.slideJumpDelay = math.random(60, 150) / 1000
	phase(state, "Approach")
end

function BotMotion.clear(state: RState)
	state.edge = nil
	state.phase = "Idle"
	state.result = "Idle"
	state.reason = "No transition"
end

function BotMotion.cancel(state: RState, reason: string)
	if state.result == "Running" then finish(state, false, reason) end
	BotMotion.clear(state)
end

function BotMotion.direct(state: RState, target: Vector3, dt: number)
	move(state, target, dt)
end

function BotMotion.directCorridor(state: RState, target: Vector3): boolean
	local delta = target - state.root.Position
	if math.abs(delta.Y) > Config.plannerGoalLayerTolerance then return false end
	local hit = Workspace:Blockcast(
		CFrame.new(state.root.Position - Vector3.yAxis * 0.3),
		Vector3.new(2.2, 4.4, 2.2),
		Vector3.new(delta.X, 0, delta.Z),
		params(state.character)
	)
	if hit then return false end
	for index = 1, 3 do
		local point = state.root.Position:Lerp(target, index / 4)
		local floorHit = Workspace:Raycast(point + Vector3.yAxis, -Vector3.yAxis * 5, params(state.character))
		if not floorHit or floorHit.Normal.Y < Config.walkableNormalY then return false end
	end
	return true
end

function BotMotion.updateLocomotion(state: RState, dt: number)
	updateTrampoline(state)
	local floorHit = Workspace:Raycast(state.root.Position, -Vector3.yAxis * 4, params(state.character))
	local shouldStopSlide = CharacterMovementModel.updateWalkSpeed(
		state.character,
		dt,
		true,
		if floorHit then floorHit.Normal else nil
	)
	if shouldStopSlide and state.character:GetAttribute("Sliding") then
		Slide.StopForCharacter(state.character)
		state.humanoid.WalkSpeed = state.character:GetAttribute("MinRunSpeed") or 16
	end
	CharacterMovementModel.updateJumpPower(state.character, dt)
end

function BotMotion.updateRoll(state: RState, goal: Vector3, dt: number, boostRequested: boolean): boolean
	if state.rollUntil > 0 then
		local now = os.clock()
		local rollElapsed = now - state.rollStartedAt
		if state.rollJumpBoostAt > 0 and now >= state.rollJumpBoostAt then
			state.rollJumpBoostAt = 0
			state.humanoid.JumpPower *= 1.3
		end
		if boostRequested
			and not state.rollBoostUsed
			and rollElapsed >= Config.rollBoostDelay
			and hasGroundSupport(state)
		then
			state.rollBoostUsed = true
			state.humanoid.Jump = true
			state.humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			mark(state, "RollBoost")
			return true
		end
		if now < state.rollUntil then
			if rollElapsed < Config.rollBoostDelay and state.rollDirection.Magnitude > 0.1 then
				state.humanoid:Move(state.rollDirection, false)
			else
				move(state, goal, dt)
			end
			return true
		end
		state.rollUntil = 0
		state.character:SetAttribute("Rolling", nil)
		state.humanoid.WalkSpeed = state.rollPreviousWalkSpeed
		state.humanoid.JumpPower = state.character:GetAttribute("MaxJumpPower") or 28
	end
	local velocityY = state.root.AssemblyLinearVelocity.Y
	if not hasGroundSupport(state) then
		state.minimumFallVelocity = math.min(state.minimumFallVelocity, velocityY)
		state.rollArmed = state.rollArmed or velocityY <= Config.rollRequiredVelocity
		if state.rollArmed and not state.rollPressedAt then
			local floorHit = Workspace:Raycast(state.root.Position, -Vector3.yAxis * 60, params(state.character))
			local timeToFloor = if floorHit then floorHit.Distance / math.max(-velocityY, 1) else math.huge
			if timeToFloor <= 0.09 then state.rollPressedAt = os.clock() end
		end
		return false
	end
	if state.edge then return false end
	local usefulDirection = flatDirection(state.root.Position, goal)
	local useful = boostRequested
		or ((goal - state.root.Position).Magnitude > 10
			and usefulDirection.Magnitude > 0
			and goal.Y <= state.root.Position.Y + 4)
	local pressedAt = state.rollPressedAt
	local pressSeconds = if pressedAt then os.clock() - pressedAt else math.huge
	if not useful
		or not state.rollArmed
		or pressSeconds >= ParkourMovementModel.rollInputWindow
		or not cooldown(state, "Roll", Config.rollCooldown)
	then
		state.rollArmed = false
		state.minimumFallVelocity = 0
		state.rollPressedAt = nil
		return false
	end
	local profile = ParkourMovementModel.rollProfile(pressSeconds * 1000)
	state.rollArmed = false
	state.minimumFallVelocity = 0
	state.rollPressedAt = nil
	state.rollStartedAt = os.clock()
	state.rollBoostUsed = false
	state.rollPreviousWalkSpeed = state.humanoid.WalkSpeed
	state.rollJumpBoostAt = state.rollStartedAt + profile.jumpBoostDelay
	state.rollUntil = state.rollJumpBoostAt + profile.boostWindow
	state.character:SetAttribute("Rolling", true)
	state.humanoid.WalkSpeed *= profile.speedMultiplier
	state.rollDirection = if state.humanoid.MoveDirection.Magnitude > 0.1
		then state.humanoid.MoveDirection
		else state.root.CFrame.LookVector
	mark(state, "Roll")
	local rollTrack = animation(state, "Roll")
	if rollTrack then rollTrack:AdjustSpeed(if profile.perfect then profile.speedMultiplier else 1) end
	sound(state, "Roll")
	move(state, goal, dt)
	return true
end

function BotMotion.update(state: RState, dt: number): ("Idle" | "Running" | "Succeeded" | "Failed", string)
	local edge = state.edge
	if not edge or state.result ~= "Running" then return state.result, state.reason end
	if os.clock() - state.startedAt > Config.skillTimeout then
		finish(state, false, "Transition timed out")
		return state.result, state.reason
	end
	local velocityY = state.root.AssemblyLinearVelocity.Y
	if not grounded(state) then
		state.minimumFallVelocity = math.min(state.minimumFallVelocity, velocityY)
		state.rollArmed = state.rollArmed or velocityY <= Config.rollRequiredVelocity
	end

	if edge.action == "Walk" then
		move(state, edge.target, dt)
		if reached(state, edge.target) then finish(state, true, "Walk reached") end
	elseif edge.action == "Jump" then
		move(state, edge.target, dt)
		if state.phase == "Approach" and grounded(state) and cooldown(state, "Jump", Config.jumpCooldown) then
			state.humanoid.Jump = true
			state.humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			mark(state, "Jump")
			phase(state, "Jumped")
		end
		if state.phase == "Jumped" and grounded(state) and reached(state, edge.target) then finish(state, true, "Jump landed") end
	elseif edge.action == "Drop" then
		move(state, edge.target, dt)
		if state.phase == "Approach" and grounded(state) and cooldown(state, "Jump", Config.jumpCooldown) then
			state.humanoid.Jump = true
			mark(state, "Jump")
			phase(state, "Dropping")
		end
		if state.phase == "Dropping" and grounded(state) and reached(state, edge.target) then finish(state, true, "Drop landed") end
	elseif edge.action == "Vault" or edge.action == "HighVault" then
		move(state, edge.approach + edge.direction * 4, dt)
		if state.phase == "Approach" and (state.root.Position - edge.approach).Magnitude <= Config.skillApproachTolerance then
			if edge.action == "HighVault" and grounded(state) and cooldown(state, "Jump", Config.jumpCooldown) then
				state.humanoid.Jump = true
				mark(state, "Jump")
				phase(state, "PreJump")
			else
				phase(state, "Probe")
			end
		end
		if state.phase == "Probe" or state.phase == "PreJump" then
			local probe = probeVault(state)
			if probe and cooldown(state, "Vault", Config.vaultCooldown) then executeVault(state, probe) end
		end
		if state.phase == "Vaulted" then
			move(state, edge.target, dt)
			if reached(state, edge.target) then finish(state, true, "Vault landed") end
		end
	elseif edge.action == "TrussClimb" then
		local truss = edge.targetPart
		if not truss or not truss:IsA("TrussPart") then
			finish(state, false, "Truss unavailable")
			return state.result, state.reason
		end
		move(state, Vector3.new(truss.Position.X, state.root.Position.Y, truss.Position.Z), dt)
		if (flatDirection(state.root.Position, truss.Position)).Magnitude > 0 then
			state.humanoid:Move(edge.direction, false)
		end
		if cooldown(state, "Vault", Config.vaultCooldown) then
			local probe = probeVault(state)
			if probe and probe.result.Instance == truss then executeVault(state, probe) end
		end
		if state.root.Position.Y >= edge.target.Y - Config.plannerGoalLayerTolerance then
			move(state, edge.target, dt)
			if reached(state, edge.target) then finish(state, true, "Truss climbed") end
		end
	elseif edge.action == "SlideBoost" then
		move(state, edge.approach + edge.direction * 5, dt)
		if state.phase == "Approach"
			and (state.root.Position - edge.approach).Magnitude <= Config.skillApproachTolerance
			and grounded(state)
			and cooldown(state, "Slide", Config.slideCooldown)
		then
			local started = Slide.StartForCharacter(state.character)
			if started then phase(state, "Sliding") end
		end
		if state.phase == "Sliding" and os.clock() - state.phaseAt >= state.slideHold then
			Slide.StopForCharacter(state.character)
			mark(state, "Slide")
			phase(state, "Cancelled")
		elseif state.phase == "Cancelled" and os.clock() - state.phaseAt >= state.slideJumpDelay then
			state.humanoid.Jump = true
			state.humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			mark(state, "Jump")
			phase(state, "BoostJump")
		elseif state.phase == "BoostJump" then
			local probe = probeVault(state)
			if probe and cooldown(state, "Vault", Config.vaultCooldown) then executeVault(state, probe) end
		end
		if (state.phase == "BoostJump" or state.phase == "Vaulted") and reached(state, edge.target) then finish(state, true, "Slide boost landed") end
	elseif edge.action == "RollBoost" then
		move(state, edge.target, dt)
		if os.clock() - (state.lastAction.RollBoost or 0) > Config.rollDuration then
			finish(state, false, "Rollboost was not chained from a landing roll")
		elseif reached(state, edge.target) then
			finish(state, true, "Rollboost landed")
		end
	elseif edge.action == "Swing" then
		move(state, edge.approach + edge.direction * 4, dt)
		if state.phase == "Approach" and (state.root.Position - edge.approach).Magnitude <= Config.skillApproachTolerance then
			local probe = ParkourMovementModel.probeSwing(
				state.root.Position,
				state.root.CFrame.LookVector,
				ignoreList(state.character)
			)
			if probe and cooldown(state, "Swing", Config.swingCooldown) then
				local swingPart = probe.result.Instance
				assert(swingPart:IsA("BasePart"), "[BotMotion.update] swing probe did not hit a BasePart")
				state.swingPart = swingPart
				state.swingPartCanCollide = swingPart.CanCollide
				swingPart.CanCollide = false
				local swingParent = swingPart.Parent
				if swingParent and swingParent:IsA("BasePart") and swingParent:GetAttribute("SwingBar") then
					state.swingParentPart = swingParent
					state.swingParentCanCollide = swingParent.CanCollide
					swingParent.CanCollide = false
				end
				state.character:SetAttribute("Swinging", true)
				local targetPosition = probe.result.Position - Vector3.yAxis * 1.5
				local backOffset = state.root.CFrame.LookVector * -1
				local desiredPosition = Vector3.new(state.root.Position.X, targetPosition.Y, state.root.Position.Z)
				state.root.CFrame = state.root.CFrame:Lerp(CFrame.new(targetPosition + backOffset), 0.5)
				state.root.CFrame = state.root.CFrame:Lerp(CFrame.new(desiredPosition), 0.5)
				local body = Instance.new("BodyPosition")
				body.MaxForce = Vector3.new(700, 9000, 700)
				body.Position = targetPosition
				body.Parent = state.root
				state.swingPosition = body
				state.swingEntryVelocityY = state.root.AssemblyLinearVelocity.Y
				mark(state, "Swing")
				local swingTrack = animation(state, "Swing")
				if swingTrack then swingTrack:AdjustSpeed(1.5) end
				sound(state, "Swing")
				phase(state, "Attached")
			end
		elseif state.phase == "Attached" and os.clock() - state.phaseAt >= ParkourMovementModel.swingHoldSeconds then
			if state.swingPosition then state.swingPosition:Destroy() end
			state.swingPosition = nil
			state.character:SetAttribute("Swinging", nil)
			if state.swingPart and state.swingPart.Parent then state.swingPart.CanCollide = state.swingPartCanCollide end
			if state.swingParentPart and state.swingParentPart.Parent then
				state.swingParentPart.CanCollide = state.swingParentCanCollide
			end
			state.swingPart = nil
			state.swingParentPart = nil
			local moveDirection = if state.humanoid.MoveDirection.Magnitude > 0.1
				then state.humanoid.MoveDirection
				else state.root.CFrame.LookVector
			state.root.AssemblyLinearVelocity += moveDirection
				* ParkourMovementModel.swingFactor(state.swingEntryVelocityY)
				* 50
			phase(state, "Released")
		elseif state.phase == "Released" then
			move(state, edge.target, dt)
			if reached(state, edge.target) then finish(state, true, "Swing landed") end
		end
	elseif edge.action == "Trampoline" then
		move(state, edge.target, dt)
		if state.phase == "Approach" and os.clock() - (state.lastAction.Trampoline or 0) <= 0.2 then
			phase(state, "Bounced")
		end
		if state.phase == "Bounced" and reached(state, edge.target) then finish(state, true, "Trampoline reached") end
	end
	return state.result, state.reason
end

return table.freeze(BotMotion)
