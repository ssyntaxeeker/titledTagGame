--!strict
--[[
    VaultClearanceModel (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/20

    Detects shallow overhangs along the opening portion of a vault and adjusts
    horizontal velocity just enough to clear them without disabling collision.
]]

local Workspace = game:GetService("Workspace")

local SWEEP_SECONDS = 0.1
local CLEARANCE_STEP = 0.2
local MAX_CLEARANCE = 1
local HEAD_SWEEP_SCALE = Vector3.new(0.92, 0.92, 0.92)
local MIN_CLEARANCE_SPEED = 8

local VaultClearanceModel = {}

local function castIsClear(origin: CFrame, size: Vector3, direction: Vector3, params: RaycastParams): boolean
	return Workspace:Blockcast(origin, size, direction, params) == nil
end

--[=[
	@client

	adjustVelocity
	==============

	Preserves the normal vault velocity unless the character's head is about to
	hit a shallow lip that has a clear trajectory within one stud. Deep ceilings
	and enclosed geometry intentionally receive no correction.
]=]
function VaultClearanceModel.adjustVelocity(
	character: Model,
	vaultTarget: Instance?,
	intendedVelocity: Vector3,
	lookDirection: Vector3
): Vector3
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then return intendedVelocity end

	local ignore: { Instance } = { character }
	if vaultTarget then table.insert(ignore, vaultTarget) end
	local debugFolder = Workspace:FindFirstChild("Debug")
	if debugFolder then table.insert(ignore, debugFolder) end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = ignore
	raycastParams.IgnoreWater = true
	raycastParams.RespectCanCollide = true

	local flatLook = Vector3.new(lookDirection.X, 0, lookDirection.Z)
	if flatLook.Magnitude < 0.001 then return intendedVelocity end
	flatLook = flatLook.Unit
	local horizontalVelocity = Vector3.new(intendedVelocity.X, 0, intendedVelocity.Z)
	local verticalDisplacement = intendedVelocity.Y * SWEEP_SECONDS
		- 0.5 * Workspace.Gravity * SWEEP_SECONDS ^ 2
	local sweepDirection = flatLook * 0.35 + Vector3.yAxis * verticalDisplacement
	local sweepSize = head.Size * HEAD_SWEEP_SCALE
	if castIsClear(head.CFrame, sweepSize, sweepDirection, raycastParams) then return intendedVelocity end

	local outward = -flatLook
	local right = Vector3.yAxis:Cross(flatLook).Unit
	local directions = {
		outward,
		(outward + right * 0.5).Unit,
		(outward - right * 0.5).Unit,
		right,
		-right,
	}

	local correction: Vector3? = nil
	for distance = CLEARANCE_STEP, MAX_CLEARANCE, CLEARANCE_STEP do
		for _, direction in directions do
			local offset = direction * distance
			if castIsClear(head.CFrame + offset, sweepSize, sweepDirection, raycastParams) then
				correction = offset
				break
			end
		end
		if correction then break end
	end
	if not correction then return intendedVelocity end

	local correctionDirection = correction.Unit
	local correctedHorizontal = horizontalVelocity
	local velocityTowardObstruction = correctedHorizontal:Dot(correctionDirection)
	if velocityTowardObstruction < 0 then
		correctedHorizontal -= correctionDirection * velocityTowardObstruction
	end
	correctedHorizontal += correctionDirection * math.max(MIN_CLEARANCE_SPEED, correction.Magnitude / SWEEP_SECONDS)

	return Vector3.new(correctedHorizontal.X, intendedVelocity.Y, correctedHorizontal.Z)
end

return table.freeze(VaultClearanceModel)
