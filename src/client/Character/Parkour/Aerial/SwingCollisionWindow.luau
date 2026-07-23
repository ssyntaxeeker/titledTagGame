--!strict
--[[
    SwingCollisionWindow (Client)
    =====================
    Author: Sol (3693744006)
    Updated: 26/07/21

    Temporarily disables collision between the swinging character and nearby
    swing-bar geometry throughout the swing and briefly after release. Pairwise
    constraints keep the window reliable when map collision properties replicate.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ParkourMovementModel = require(ReplicatedStorage.Modules.Character.Parkour.ParkourMovementModel)

type RCollisionClaim = {
	originalCanCollide: boolean,
	claimCount: number,
}

local SEARCH_RADIUS = 8
local MAX_NEARBY_PARTS = 128
local claimsByPart: { [BasePart]: RCollisionClaim } = {}

local SwingCollisionWindow = {}

--[=[
    @client
    @tag Cleanup

    acquire
    =======

    Disables collision on the contacted swing part and every swing-bar part
    whose bounds are near the contact point. Call this when the swing starts
    and release it after the post-launch collision window. The caller owns and
    must invoke the returned cleanup function. Cleanup is idempotent.

    @return () -> () -- Releases this window's claims and restores each part
        after its final active claim ends.
]=]
function SwingCollisionWindow.acquire(character: Model, contactPosition: Vector3, contactedPart: BasePart): () -> ()
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = { character }
	overlapParams.RespectCanCollide = false
	overlapParams.MaxParts = MAX_NEARBY_PARTS

	local acquiredParts: { BasePart } = {}
	local collisionConstraints: { NoCollisionConstraint } = {}
	local characterParts: { BasePart } = {}
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then characterParts[#characterParts + 1] = descendant end
	end
	local seen: { [BasePart]: boolean } = {}
	local nearbyParts = Workspace:GetPartBoundsInRadius(contactPosition, SEARCH_RADIUS, overlapParams)
	nearbyParts[#nearbyParts + 1] = contactedPart

	for _, part in nearbyParts do
		if seen[part] or (part ~= contactedPart and not ParkourMovementModel.isSwingBar(part)) then continue end
		seen[part] = true
		acquiredParts[#acquiredParts + 1] = part

		local existingClaim = claimsByPart[part]
		if existingClaim then
			existingClaim.claimCount += 1
		else
			claimsByPart[part] = {
				originalCanCollide = part.CanCollide,
				claimCount = 1,
			}
		end
		part.CanCollide = false

		for _, characterPart in characterParts do
			local constraint = Instance.new("NoCollisionConstraint")
			constraint.Name = "SwingCollisionWindow"
			constraint.Part0 = characterPart
			constraint.Part1 = part
			constraint.Parent = character
			collisionConstraints[#collisionConstraints + 1] = constraint
		end
	end

	local released = false
	local destroyingConnection: RBXScriptConnection? = nil
	local function release()
		if released then return end
		released = true
		if destroyingConnection then
			destroyingConnection:Disconnect()
			destroyingConnection = nil
		end
		for _, constraint in collisionConstraints do
			constraint:Destroy()
		end
		table.clear(collisionConstraints)

		for _, part in acquiredParts do
			local claim = claimsByPart[part]
			if not claim then continue end
			claim.claimCount -= 1
			if claim.claimCount > 0 then continue end

			claimsByPart[part] = nil
			if part.Parent then part.CanCollide = claim.originalCanCollide end
		end
	end
	destroyingConnection = character.Destroying:Connect(release)
	return release
end

return table.freeze(SwingCollisionWindow)
