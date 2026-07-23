--!strict
--[[
    WallrunModel (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/18

    Pure wallrun probes and velocity equations shared by runtime controllers.
]]

local Workspace = game:GetService("Workspace")

local WallrunConfig = require(script.Parent.WallrunConfig)
local ParkourAssetScope = require(game:GetService("ReplicatedStorage").Shared.Utils.ParkourAssetScope)

export type RWallrunProbe = {
	result: RaycastResult,
	direction: Vector3,
	side: number,
}

local WallrunModel = {}

-- Resolves the legacy surface property for the exact face represented by a
-- world-space raycast normal. Wallrun geometry must opt in with that face set
-- to Weld; a welded face elsewhere on the same part does not qualify.
function WallrunModel.isWeldSurface(part: BasePart, worldNormal: Vector3): boolean
	local normal = part.CFrame:VectorToObjectSpace(worldNormal)
	local absoluteX = math.abs(normal.X)
	local absoluteY = math.abs(normal.Y)
	local absoluteZ = math.abs(normal.Z)
	if absoluteX >= absoluteY and absoluteX >= absoluteZ then
		return (if normal.X >= 0 then part.RightSurface else part.LeftSurface) == Enum.SurfaceType.Weld
	elseif absoluteY >= absoluteZ then
		return (if normal.Y >= 0 then part.TopSurface else part.BottomSurface) == Enum.SurfaceType.Weld
	else
		return (if normal.Z >= 0 then part.BackSurface else part.FrontSurface) == Enum.SurfaceType.Weld
	end
end

function WallrunModel.probe(character: Model, rootPart: BasePart): RWallrunProbe?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.IgnoreWater = true
	params.RespectCanCollide = true

	for _, side in { 1, -1 } do
		local direction = rootPart.CFrame.RightVector * side * WallrunConfig.probeDistance
		local result = Workspace:Raycast(rootPart.Position, direction, params)
		if not result then continue end
		if not ParkourAssetScope.contains(result.Instance) then continue end
		if math.abs(result.Normal.Y) >= WallrunConfig.maximumNormalY then continue end
		if result.Instance:GetAttribute("Wallrun") ~= true then continue end
		if not result.Instance:IsA("BasePart") or not WallrunModel.isWeldSurface(result.Instance, result.Normal) then
			continue
		end
		return {
			result = result,
			direction = direction,
			side = side,
		}
	end
	return nil
end

function WallrunModel.travelDirection(rootPart: BasePart, result: RaycastResult): (Vector3, number)
	local localPosition = rootPart.CFrame:PointToObjectSpace(result.Position)
	local side = math.sign(localPosition.X)
	if side == 0 then side = 1 end
	return CFrame.lookAt(Vector3.zero, result.Normal).RightVector * side, side
end

function WallrunModel.releaseVelocity(velocity: Vector3, lookDirection: Vector3, cameraPitch: number): Vector3
	local verticalVelocity = if cameraPitch > -37.5
		then math.max(cameraPitch * 0.5, 45)
		else math.min(cameraPitch * 0.5, -45)
	local horizontalVelocity = Vector3.new(velocity.X, verticalVelocity, velocity.Z)
	return (horizontalVelocity + lookDirection * ((90 - math.abs(cameraPitch)) * 0.5))
		* WallrunConfig.releaseVelocityMultiplier
end

function WallrunModel.momentumReward(velocity: Vector3): number
	return math.clamp(velocity.Magnitude / 65, 1, 5) * WallrunConfig.releaseMomentumScale
end

return table.freeze(WallrunModel)
