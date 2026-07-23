--!strict
--[[
    ParkourMovementModel (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/18

    Shared, character-agnostic UTG parkour probes and physics equations. Player
    inputs and training bots consume this module so their legal moves match.
]]

local Workspace = game:GetService("Workspace")

local ParkourAssetScope = require(game:GetService("ReplicatedStorage").Shared.Utils.ParkourAssetScope)

export type RAerialProbe = {
	result: RaycastResult,
	studs: number,
	direction: Vector3,
	rayOrigin: Vector3,
	rayDirection: Vector3,
	forwardOrigin: Vector3,
	forwardDirection: Vector3,
}

export type RRollProfile = {
	perfect: boolean,
	speedMultiplier: number,
	jumpBoostDelay: number,
	boostWindow: number,
}

local ParkourMovementModel = {}

ParkourMovementModel.cooldowns = table.freeze({
	vault = 0.1,
	swing = 0.45,
	roll = 0.05,
	trampoline = 0.5,
	rope = 0.2,
	rail = 0.2,
	window = 0.15,
})
ParkourMovementModel.rollRequiredVelocity = -40
ParkourMovementModel.rollInputWindow = 0.7
ParkourMovementModel.swingHoldSeconds = 0.4
ParkourMovementModel.vaultMomentum = 3
ParkourMovementModel.vaultStackingWindow = 0.5
ParkourMovementModel.vaultStackingMultiplier = 0.45
ParkourMovementModel.vaultStateSeconds = 0.11
ParkourMovementModel.swingMomentum = 3

local function params(ignore: { Instance }): RaycastParams
	local value = RaycastParams.new()
	value.FilterType = Enum.RaycastFilterType.Exclude
	value.FilterDescendantsInstances = ignore
	value.IgnoreWater = true
	return value
end

function ParkourMovementModel.isSwingBar(instance: Instance): boolean
	if not ParkourAssetScope.contains(instance) then return false end
	return ParkourMovementModel.affordanceValue(instance, "SwingBar") == true
		or ParkourMovementModel.isExperimentalSwingBar(instance)
end

function ParkourMovementModel.isExperimentalSwingBar(instance: Instance): boolean
	if not ParkourAssetScope.contains(instance) then return false end
	local current: Instance? = instance
	while current and ParkourAssetScope.contains(current) do
		if current.Name == "ExperimentalSwingbar"
			or current.Name == "ExperimentalSwingBar"
			or current:GetAttribute("ExperimentalSwingbar") == true
			or current:GetAttribute("ExperimentalSwingBar") == true
		then
			return true
		end
		current = current.Parent
	end
	return false
end

function ParkourMovementModel.hasAffordance(instance: Instance, attributeName: string): boolean
	return ParkourMovementModel.affordanceValue(instance, attributeName) ~= nil
end

function ParkourMovementModel.affordanceValue(instance: Instance, attributeName: string): any
	if not ParkourAssetScope.contains(instance) then return nil end
	local current: Instance? = instance
	while current and ParkourAssetScope.contains(current) do
		local value = current:GetAttribute(attributeName)
		if value ~= nil then return value end
		current = current.Parent
	end
	return nil
end

function ParkourMovementModel.isTruss(instance: Instance): boolean
	local parent = instance.Parent
	return instance:IsA("TrussPart") or (parent ~= nil and parent:FindFirstChildOfClass("TrussPart") ~= nil)
end

function ParkourMovementModel.probeAerial(
	rootPosition: Vector3,
	lookDirection: Vector3,
	ignore: { Instance },
	raycastParams: RaycastParams?
): RAerialProbe?
	local activeParams = raycastParams or params(ignore)
	local hit: RaycastResult? = nil
	local rayOrigin = rootPosition + lookDirection * 0.5 + Vector3.yAxis * 2.75
	local rayDirection = -Vector3.yAxis * 3.25
	for distance = 2.5, 0.5, -0.25 do
		rayOrigin = rootPosition + lookDirection * distance + Vector3.yAxis * 2.75
		hit = Workspace:Raycast(rayOrigin, rayDirection, activeParams)
		if hit then break end
	end
	if not hit then return nil end
	local forwardOrigin = rootPosition + Vector3.yAxis * 1.25 - lookDirection * 2.5
	local forwardDirection = lookDirection * 3
	if Workspace:Raycast(forwardOrigin, forwardDirection, activeParams) then return nil end
	return {
		result = hit,
		studs = math.abs(hit.Position.Y - rootPosition.Y),
		direction = lookDirection,
		rayOrigin = rayOrigin,
		rayDirection = rayDirection,
		forwardOrigin = forwardOrigin,
		forwardDirection = forwardDirection,
	}
end

function ParkourMovementModel.probeVault(
	rootPosition: Vector3,
	lookDirection: Vector3,
	ignore: { Instance },
	raycastParams: RaycastParams?
): RAerialProbe?
	local probe = ParkourMovementModel.probeAerial(rootPosition, lookDirection, ignore, raycastParams)
	if not probe or ParkourMovementModel.isSwingBar(probe.result.Instance) then return nil end
	if probe.result.Instance:GetAttribute("NoClimb") then return nil end
	return probe
end

function ParkourMovementModel.probeSwing(
	rootPosition: Vector3,
	lookDirection: Vector3,
	ignore: { Instance },
	raycastParams: RaycastParams?
): RAerialProbe?
	local probe = ParkourMovementModel.probeAerial(rootPosition, lookDirection, ignore, raycastParams)
	return if probe and ParkourMovementModel.isSwingBar(probe.result.Instance) then probe else nil
end

function ParkourMovementModel.vaultStuds(studs: number): number
	return math.clamp(studs, 0, 2.75)
end

function ParkourMovementModel.vaultVelocity(velocity: Vector3, lookDirection: Vector3, studs: number): Vector3
	local clampedStuds = ParkourMovementModel.vaultStuds(studs)
	return Vector3.new(velocity.X, math.clamp(clampedStuds / 1.5 * 30, 30, math.huge), velocity.Z)
		- lookDirection * 2
end

function ParkourMovementModel.swingFactor(verticalVelocity: number): number
	return (math.clamp(-verticalVelocity, 25, 80) / 25) ^ 0.7
end

function ParkourMovementModel.vaultMomentumReward(lastVaultAt: number?, now: number, multiplier: number): number
	local freshVault = lastVaultAt == nil or now - lastVaultAt >= ParkourMovementModel.vaultStackingWindow
	return ParkourMovementModel.vaultMomentum
		* multiplier
		* (if freshVault then 1 else ParkourMovementModel.vaultStackingMultiplier)
end

function ParkourMovementModel.swingMomentumReward(swingFactor: number): number
	return swingFactor * ParkourMovementModel.swingMomentum
end

function ParkourMovementModel.rollProfile(milliseconds: number): RRollProfile
	local seconds = milliseconds / 1000
	local perfect = seconds < 0.1
	return {
		perfect = perfect,
		speedMultiplier = if perfect then 1.3 + ((0.1 - seconds) * 3.5) ^ 0.85 else 1.3,
		jumpBoostDelay = 0.15,
		boostWindow = if perfect then 0.2 else 0.35,
	}
end

function ParkourMovementModel.trampolineVelocity(velocity: Vector3, bounceAmount: number): Vector3
	return Vector3.new(velocity.X, bounceAmount / 1.2, velocity.Z)
end

return table.freeze(ParkourMovementModel)
