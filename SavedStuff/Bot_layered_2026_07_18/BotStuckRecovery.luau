--!strict
--[[
    BotStuckRecovery (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/17

    Detects actual wall penetration and performs a short, learned slide
    fallback without competing with normal graph backtracking.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Modules.Bot.BotNavigationConfig)
local MovementRules = require(ReplicatedStorage.Modules.Bot.BotMovementRules)
local BotRouteMemory = require(ReplicatedStorage.Modules.Bot.BotRouteMemory)

type RMemory = BotRouteMemory.RMemory

export type RState = {
	active: boolean,
	direction: Vector3,
	startedAt: number,
	startPosition: Vector3,
	lastAttemptAt: number,
	memoryKey: string?,
	originalHipHeight: number,
	originalJumpPower: number,
	reason: string,
}

local BotStuckRecovery = {}

local function horizontalUnit(direction: Vector3): Vector3
	local flat = Vector3.new(direction.X, 0, direction.Z)
	return if flat.Magnitude > 0.01 then flat.Unit else Vector3.zAxis
end

local function getExitDirection(part: BasePart, worldPoint: Vector3): Vector3?
	local point = part.CFrame:PointToObjectSpace(worldPoint)
	local half = part.Size * 0.5
	if math.abs(point.X) >= half.X - Config.escapeSlidePenetrationInset
		or math.abs(point.Y) >= half.Y - Config.escapeSlidePenetrationInset
		or math.abs(point.Z) >= half.Z - Config.escapeSlidePenetrationInset
	then
		return nil
	end

	local xDepth = half.X - math.abs(point.X)
	local zDepth = half.Z - math.abs(point.Z)
	local localDirection = if xDepth <= zDepth
		then Vector3.new(if point.X >= 0 then 1 else -1, 0, 0)
		else Vector3.new(0, 0, if point.Z >= 0 then 1 else -1)
	return horizontalUnit(part.CFrame:VectorToWorldSpace(localDirection))
end

local function findPenetrationDirection(rootPart: BasePart): (Vector3?, string)
	local map = Workspace:FindFirstChild("Map")
	if not map then return nil, "Map unavailable" end

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Include
	overlapParams.FilterDescendantsInstances = { map }
	overlapParams.MaxParts = Config.escapeSlideOverlapPartLimit
	local nearby = Workspace:GetPartBoundsInBox(
		rootPart.CFrame,
		Vector3.new(Config.escapeSlideBodyWidth, Config.escapeSlideBodyHeight, Config.escapeSlideBodyWidth),
		overlapParams
	)
	for _, part in nearby do
		if not part:IsA("BasePart") or not part.CanCollide then continue end
		local rootExit = getExitDirection(part, rootPart.Position)
		if rootExit then return rootExit, `overlapping {part.Name}` end
	end
	return nil, "Root is not penetrating map geometry"
end

local function chooseDirection(memory: RMemory, rootPart: BasePart, baseDirection: Vector3): (Vector3?, string?)
	local map = Workspace:FindFirstChild("Map")
	if not map then return nil, nil end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { map }
	params.IgnoreWater = true
	local tangent = Vector3.yAxis:Cross(baseDirection)
	local candidates = { baseDirection, tangent, -tangent, -baseDirection }
	local bestDirection: Vector3? = nil
	local bestKey: string? = nil
	local bestScore = -math.huge
	for _, rawDirection in candidates do
		local direction = horizontalUnit(rawDirection)
		local key = BotRouteMemory.recoverySlideKey(rootPart.Position, direction)
		if not BotRouteMemory.shouldTryRecoverySlide(memory, key) then continue end
		local hit = Workspace:Raycast(
			rootPart.Position + Vector3.yAxis * Config.escapeSlideWallProbeHeight,
			direction * Config.escapeSlideClearanceProbeDistance,
			params
		)
		local clearance = if hit
			then (hit.Position - rootPart.Position).Magnitude
			else Config.escapeSlideClearanceProbeDistance
		local score = clearance + BotRouteMemory.getRecoverySlideScore(memory, key)
		if score > bestScore then
			bestScore = score
			bestDirection = direction
			bestKey = key
		end
	end
	return bestDirection, bestKey
end

function BotStuckRecovery.create(): RState
	return {
		active = false,
		direction = Vector3.zero,
		startedAt = 0,
		startPosition = Vector3.zero,
		lastAttemptAt = 0,
		memoryKey = nil,
		originalHipHeight = 0,
		originalJumpPower = Config.botJumpPower,
		reason = "Idle",
	}
end

function BotStuckRecovery.tryStart(
	state: RState,
	memory: RMemory,
	character: Model,
	humanoid: Humanoid,
	rootPart: BasePart,
	preferredDirection: Vector3
): boolean
	local now = os.clock()
	if state.active or now - state.lastAttemptAt < Config.escapeSlideRetryCooldownSeconds then return false end
	local ignore = { character }
	local debugFolder = Workspace:FindFirstChild("BotDebug")
	if debugFolder then ignore[#ignore + 1] = debugFolder end
	if not MovementRules.isGrounded(humanoid, rootPart, ignore) then return false end

	local wallDirection, reason = findPenetrationDirection(rootPart)
	if not wallDirection then return false end
	local direction, memoryKey = chooseDirection(memory, rootPart, wallDirection)
	if not direction or not memoryKey then return false end

	state.active = true
	state.direction = direction
	state.startedAt = now
	state.startPosition = rootPart.Position
	state.lastAttemptAt = now
	state.memoryKey = memoryKey
	state.originalHipHeight = humanoid.HipHeight
	state.originalJumpPower = humanoid.JumpPower
	state.reason = reason
	character:SetAttribute("Sliding", true)
	humanoid.HipHeight = Config.escapeSlideHipHeight
	humanoid.JumpPower = 25
	return true
end

function BotStuckRecovery.update(
	state: RState,
	memory: RMemory,
	character: Model,
	humanoid: Humanoid,
	rootPart: BasePart,
	dt: number
): "Idle" | "Running" | "Succeeded" | "Failed"
	if not state.active then return "Idle" end
	local desired = CFrame.lookAt(rootPart.Position, rootPart.Position + state.direction)
	rootPart.CFrame = rootPart.CFrame:Lerp(desired, math.clamp(Config.turnRate * dt, 0, 1))
	humanoid:Move(state.direction, false)
	if os.clock() - state.startedAt < Config.escapeSlideDurationSeconds then return "Running" end

	local displacement = Vector3.new(
		rootPart.Position.X - state.startPosition.X,
		0,
		rootPart.Position.Z - state.startPosition.Z
	).Magnitude
	local succeeded = displacement >= Config.escapeSlideSuccessDistance
	character:SetAttribute("Sliding", nil)
	humanoid.HipHeight = state.originalHipHeight
	humanoid.JumpPower = state.originalJumpPower
	humanoid:Move(Vector3.zero, false)
	if state.memoryKey then BotRouteMemory.recordRecoverySlide(memory, state.memoryKey, succeeded, displacement) end
	state.active = false
	state.reason = if succeeded then `escaped {math.floor(displacement * 10) / 10} studs` else "slide made no escape progress"
	return if succeeded then "Succeeded" else "Failed"
end

function BotStuckRecovery.cancel(state: RState, character: Model, humanoid: Humanoid)
	if not state.active then return end
	character:SetAttribute("Sliding", nil)
	humanoid.HipHeight = state.originalHipHeight
	humanoid.JumpPower = state.originalJumpPower
	humanoid:Move(Vector3.zero, false)
	state.active = false
	state.reason = "Cancelled"
end

return table.freeze(BotStuckRecovery)
