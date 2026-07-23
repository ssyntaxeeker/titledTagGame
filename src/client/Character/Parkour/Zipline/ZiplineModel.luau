--!strict
--[[
    ZiplineModel (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/19

    Discovers valid UTG zipline models and resolves their movement axis.
]]

local Workspace = game:GetService("Workspace")

local ZiplineConfig = require(script.Parent.ZiplineConfig)
local ParkourAssetScope = require(game:GetService("ReplicatedStorage").Shared.Utils.ParkourAssetScope)

export type RZiplineTarget = {
	container: Instance,
	zipPart: BasePart,
	topAttachment: Attachment,
	origin: Vector3,
	axis: Vector3,
	upperLimit: number,
}

local ZiplineModel = {}

local function targetFromPart(part: BasePart): RZiplineTarget?
	if not ParkourAssetScope.contains(part) then return nil end
	local model = part.Parent
	if not model or model:GetAttribute("Zipline") ~= true then return nil end
	local zipPart = model:FindFirstChild("ZipPart")
	if not zipPart or not zipPart:IsA("BasePart") then return nil end
	local topAttachment = zipPart:FindFirstChild("TopAttachment")
	if not topAttachment or not topAttachment:IsA("Attachment") then return nil end
	local localAxis = topAttachment.Axis.Unit
	local upperLimit = math.abs(localAxis.X) * zipPart.Size.X
		+ math.abs(localAxis.Y) * zipPart.Size.Y
		+ math.abs(localAxis.Z) * zipPart.Size.Z
	return {
		container = model,
		zipPart = zipPart,
		topAttachment = topAttachment,
		origin = topAttachment.WorldPosition,
		axis = topAttachment.WorldAxis.Unit,
		upperLimit = upperLimit,
	}
end

function ZiplineModel.find(character: Model, position: Vector3, nearbyParts: { BasePart }?): RZiplineTarget?
	local candidates: { BasePart }
	if nearbyParts then
		candidates = nearbyParts
	else
		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character }
		params.RespectCanCollide = false
		candidates = Workspace:GetPartBoundsInRadius(position, ZiplineConfig.attachRadius, params)
	end
	local closestTarget: RZiplineTarget? = nil
	local closestDistance = math.huge
	for _, part in candidates do
		local target = targetFromPart(part)
		if not target then continue end
		local along = math.clamp((position - target.origin):Dot(target.axis), 0, target.upperLimit)
		local distance = (target.origin + target.axis * along - position).Magnitude
		if distance >= closestDistance then continue end
		closestTarget = target
		closestDistance = distance
	end
	return closestTarget
end

return table.freeze(ZiplineModel)
