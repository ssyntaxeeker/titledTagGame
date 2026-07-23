--!strict
--[[
    WalljumpModel (Client)
    ======================
    Author: Sol (3693744006)
    Updated: 26/07/19

    Owns the reusable rear-wall probe and deterministic Walljump velocity
    calculation without reading local-player state.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ParkourAssetScope = require(ReplicatedStorage.Shared.Utils.ParkourAssetScope)
local WalljumpConfig = require(script.Parent.WalljumpConfig)

export type RWalljumpProbe = {
	result: RaycastResult,
	origin: Vector3,
	direction: Vector3,
	distance: number,
	facingDot: number,
}

local WalljumpModel = {}

local function hasNoWalljump(instance: Instance): boolean
	local current: Instance? = instance
	while current and ParkourAssetScope.contains(current) do
		if current:GetAttribute("NoWalljump") == true then return true end
		current = current.Parent
	end
	return false
end

function WalljumpModel.probe(rootCFrame: CFrame, ignore: { Instance }, raycastParams: RaycastParams?): RWalljumpProbe?
	local params = raycastParams or RaycastParams.new()
	if not raycastParams then
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = ignore
		params.IgnoreWater = true
		params.RespectCanCollide = true
	end

	local origin = rootCFrame.Position + Vector3.yAxis * WalljumpConfig.probeOriginHeight
	local direction = -rootCFrame.LookVector * WalljumpConfig.probeDistance
	local result = Workspace:Raycast(origin, direction, params)
	if not result or not result.Instance:IsA("BasePart") then return nil end
	if not ParkourAssetScope.contains(result.Instance) or hasNoWalljump(result.Instance) then return nil end
	local distance = (result.Position - origin).Magnitude
	if distance < WalljumpConfig.minimumContactDistance then return nil end
	if math.abs(result.Normal.Y) > WalljumpConfig.maximumNormalY then return nil end
	local facingDot = result.Normal:Dot(rootCFrame.LookVector)
	if facingDot < WalljumpConfig.minimumFacingDot then return nil end

	local clearanceOrigin = result.Position + result.Normal * 0.1
	local clearance = Workspace:Raycast(
		clearanceOrigin,
		result.Normal * WalljumpConfig.clearanceDistance,
		params
	)
	if clearance then return nil end
	return {
		result = result,
		origin = origin,
		direction = direction,
		distance = distance,
		facingDot = facingDot,
	}
end

function WalljumpModel.isGroundEligible(velocity: Vector3): boolean
	return (velocity * Vector3.new(1, 0, 1)).Magnitude >= WalljumpConfig.groundMinimumHorizontalSpeed
end

function WalljumpModel.velocity(
	velocity: Vector3,
	wallNormal: Vector3,
	wallVelocity: Vector3
): (Vector3, number, number, number)
	local incomingVerticalSpeed = math.min(
		math.abs(velocity.Y),
		WalljumpConfig.maximumUsefulIncomingVerticalSpeed
	)
	local verticalSpeed = math.clamp(
		WalljumpConfig.verticalBaseSpeed + incomingVerticalSpeed * WalljumpConfig.verticalSpeedScale,
		WalljumpConfig.minimumVerticalSpeed,
		WalljumpConfig.maximumVerticalSpeed
	) * WalljumpConfig.verticalLaunchSpeedMultiplier
	local outwardSpeed = math.clamp(
		WalljumpConfig.outwardBaseSpeed + incomingVerticalSpeed * WalljumpConfig.outwardSpeedScale,
		WalljumpConfig.minimumOutwardSpeed,
		WalljumpConfig.maximumOutwardSpeed
	) * WalljumpConfig.outwardLaunchSpeedMultiplier
	local horizontalNormal = wallNormal * Vector3.new(1, 0, 1)
	if horizontalNormal.Magnitude > 0.001 then horizontalNormal = horizontalNormal.Unit end
	local tangentVelocity = velocity - horizontalNormal * velocity:Dot(horizontalNormal)
	local horizontalTangent = tangentVelocity * Vector3.new(1, 0, 1) * WalljumpConfig.tangentRetention
	local inheritedWallVelocity = wallVelocity * Vector3.new(1, 0, 1)
	if inheritedWallVelocity.Magnitude > WalljumpConfig.maximumInheritedWallSpeed then
		inheritedWallVelocity = inheritedWallVelocity.Unit * WalljumpConfig.maximumInheritedWallSpeed
	end
	return horizontalTangent
		+ horizontalNormal * outwardSpeed
		+ Vector3.yAxis * verticalSpeed
		+ inheritedWallVelocity,
		incomingVerticalSpeed,
		verticalSpeed,
		outwardSpeed
end

return table.freeze(WalljumpModel)
