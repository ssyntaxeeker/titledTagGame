--!strict
--[[
    BotMovementRules (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/18

    Pure eligibility probes mirroring the player vault, swing, grounded, roll,
    trampoline, and barrier rules. Planning and execution share these probes.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Modules.Bot.BotNavigationConfig)

local BotMovementRules = {}

export type VaultProbe = {
	result: RaycastResult,
	vaultStuds: number,
	direction: Vector3,
}

local function makeParams(ignore: { Instance }?, include: { Instance }?): RaycastParams
	local params = RaycastParams.new()
	params.IgnoreWater = true
	if include then
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = include
	else
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = ignore or {}
	end
	return params
end

function BotMovementRules.isBarrier(instance: Instance): boolean
	local current: Instance? = instance
	while current do
		if current.Name == "Barriers" then return true end
		current = current.Parent
	end
	return false
end

function BotMovementRules.isSwingBar(instance: Instance): boolean
	return instance:GetAttribute("SwingBar") == true
		or (instance.Parent ~= nil and instance.Parent:GetAttribute("SwingBar") == true)
end

function BotMovementRules.isTrampoline(instance: Instance): boolean
	return CollectionService:HasTag(instance, "Trampoline")
end

--[=[
	@client

	hasGroundSupport
	================

	Checks physical floor support without rejecting transient vertical velocity.
	Slide cancellation changes HipHeight and can move the root vertically even
	though the character remains eligible to perform the player's follow-up jump.
]=]
function BotMovementRules.hasGroundSupport(humanoid: Humanoid, rootPart: BasePart, ignore: { Instance }): boolean
	if humanoid.FloorMaterial ~= Enum.Material.Air then return true end

	local result = Workspace:Raycast(rootPart.Position, -Vector3.yAxis * 3.2, makeParams(ignore, nil))
	return result ~= nil and result.Normal.Y >= 0.55
end

function BotMovementRules.isGrounded(humanoid: Humanoid, rootPart: BasePart, ignore: { Instance }): boolean
	if math.abs(rootPart.AssemblyLinearVelocity.Y) > 0.5 then return false end
	return BotMovementRules.hasGroundSupport(humanoid, rootPart, ignore)
end

function BotMovementRules.hasBodyClearance(fromPosition: Vector3, toPosition: Vector3, ignore: { Instance }): boolean
	local delta = toPosition - fromPosition
	if delta.Magnitude <= 0.1 then return true end
	local params = makeParams(ignore, nil)
	local lowerHit = Workspace:Raycast(fromPosition + Vector3.yAxis * 0.5, delta, params)
	local upperHit = Workspace:Raycast(fromPosition + Vector3.yAxis * 2.5, delta, params)
	return lowerHit == nil and upperHit == nil
end

--[=[
	@client

	hasGroundedRunCorridor
	======================

	Validates a walk-plan shortcut against both body obstruction and continuous
	floor support. This allows long straight graph segments without cutting over
	voids or unsupported corners.
]=]
function BotMovementRules.hasGroundedRunCorridor(
	fromPosition: Vector3,
	toPosition: Vector3,
	ignore: { Instance }
): boolean
	if not BotMovementRules.hasBodyClearance(fromPosition, toPosition, ignore) then return false end
	local map = Workspace:FindFirstChild("Map")
	if not map then return false end
	local params = makeParams(ignore, { map })
	params.RespectCanCollide = true
	for sampleIndex = 1, Config.routeShortcutSupportSamples do
		local alpha = sampleIndex / (Config.routeShortcutSupportSamples + 1)
		local rootPosition = fromPosition:Lerp(toPosition, alpha)
		local floorHit = Workspace:Raycast(
			rootPosition + Vector3.yAxis * 0.25,
			-Vector3.yAxis * (Config.rootFloorOffset + Config.routeShortcutFloorTolerance + 0.25),
			params
		)
		if not floorHit or floorHit.Normal.Y < Config.walkableNormalY then return false end
		local expectedFloorY = rootPosition.Y - Config.rootFloorOffset
		if math.abs(floorHit.Position.Y - expectedFloorY) > Config.routeShortcutFloorTolerance then return false end
	end
	return true
end

--[=[
	@client

	hasDirectRunCorridor
	====================

	Uses a torso-width sweep rather than line of sight. A thin ray can pass over
	short walls or beside corners that still stop the bot's collidable body.
]=]
function BotMovementRules.hasDirectRunCorridor(
	fromPosition: Vector3,
	toPosition: Vector3,
	ignore: { Instance }
): boolean
	local delta = toPosition - fromPosition
	local flatDelta = Vector3.new(delta.X, 0, delta.Z)
	if flatDelta.Magnitude <= 0.1 then return true end
	local map = Workspace:FindFirstChild("Map")
	local params = makeParams(ignore, if map then { map } else nil)
	params.RespectCanCollide = true
	local center = fromPosition + Vector3.yAxis * Config.directRunCorridorCenterOffset
	local hit = Workspace:Blockcast(
		CFrame.new(center),
		Vector3.new(
			Config.directRunCorridorWidth,
			Config.directRunCorridorHeight,
			Config.directRunCorridorWidth
		),
		flatDelta,
		params
	)
	return hit == nil
end

function BotMovementRules.hasOverheadClearance(
	rootPosition: Vector3,
	requiredRise: number,
	ignore: { Instance },
	include: { Instance }?
): boolean
	local rise = math.max(Config.minimumAerialRise, requiredRise) + Config.aerialClearancePadding
	local origin = rootPosition + Vector3.yAxis * Config.aerialBodyTopOffset
	return Workspace:Raycast(origin, Vector3.yAxis * rise, makeParams(ignore, include)) == nil
end

--[=[
	@client

	hasFlatSlideBoostGround
	=======================

	Validates continuous, collidable support for the complete grounded portion
	of a slide boost. Different coplanar parts are allowed, but any gap, slope,
	or floor-height change invalidates the setup.
]=]
function BotMovementRules.hasFlatSlideBoostGround(
	startPosition: Vector3,
	direction: Vector3,
	length: number,
	expectedFloorY: number,
	params: RaycastParams?
): boolean
	local raycastParams = params
	if not raycastParams then
		local map = Workspace:FindFirstChild("Map")
		if not map then return false end
		raycastParams = makeParams(nil, { map })
	end
	raycastParams.RespectCanCollide = true

	local sampleCount = math.max(1, math.ceil(length / Config.slideBoostGroundProbeStep))
	for index = 0, sampleCount do
		local distance = length * index / sampleCount
		local samplePosition = startPosition + direction * distance
		local origin = Vector3.new(
			samplePosition.X,
			expectedFloorY + Config.slideBoostGroundProbeHeight,
			samplePosition.Z
		)
		local floorHit = Workspace:Raycast(
			origin,
			-Vector3.yAxis * (Config.slideBoostGroundProbeHeight + Config.slideBoostGroundHeightTolerance + 0.5),
			raycastParams
		)
		if not floorHit or not floorHit.Instance:IsA("BasePart") then return false end
		if not floorHit.Instance.CanCollide or floorHit.Normal.Y < Config.walkableNormalY then return false end
		if math.abs(floorHit.Position.Y - expectedFloorY) > Config.slideBoostGroundHeightTolerance then return false end
	end
	return true
end

function BotMovementRules.probeVault(
	rootPosition: Vector3,
	lookDirection: Vector3,
	ignore: { Instance }
): VaultProbe?
	local flatDirection = Vector3.new(lookDirection.X, 0, lookDirection.Z)
	if flatDirection.Magnitude <= 0.01 then return nil end
	flatDirection = flatDirection.Unit

	local params = makeParams(ignore, nil)
	local obstacleHit: RaycastResult? = nil
	for distance = 2.5, 0.5, -0.25 do
		local origin = rootPosition + flatDirection * distance + Vector3.yAxis * 2.75
		obstacleHit = Workspace:Raycast(origin, -Vector3.yAxis * 3.25, params)
		if obstacleHit then break end
	end

	if not obstacleHit then return nil end
	if BotMovementRules.isBarrier(obstacleHit.Instance) or obstacleHit.Instance:GetAttribute("NoClimb") then return nil end
	if BotMovementRules.isSwingBar(obstacleHit.Instance) then return nil end

	local forwardOrigin = rootPosition + Vector3.yAxis * 1.25 - flatDirection * 2.5
	if Workspace:Raycast(forwardOrigin, flatDirection * 3, params) then return nil end

	return {
		result = obstacleHit,
		vaultStuds = math.abs(obstacleHit.Position.Y - rootPosition.Y),
		direction = flatDirection,
	}
end

function BotMovementRules.probeSwing(
	rootPosition: Vector3,
	lookDirection: Vector3,
	ignore: { Instance }
): RaycastResult?
	local flatDirection = Vector3.new(lookDirection.X, 0, lookDirection.Z)
	if flatDirection.Magnitude <= 0.01 then return nil end
	flatDirection = flatDirection.Unit

	local params = makeParams(ignore, nil)
	for height = 2, 6, 1 do
		local hit = Workspace:Raycast(rootPosition + Vector3.yAxis * height, flatDirection * 5, params)
		if hit and BotMovementRules.isSwingBar(hit.Instance) then return hit end
	end
	return nil
end

function BotMovementRules.getTrampolineBelow(rootPosition: Vector3, ignore: { Instance }): RaycastResult?
	local result = Workspace:Raycast(rootPosition + Vector3.yAxis * 0.2, -Vector3.yAxis * 3.8, makeParams(ignore, nil))
	if result and BotMovementRules.isTrampoline(result.Instance) then return result end
	return nil
end

return table.freeze(BotMovementRules)
