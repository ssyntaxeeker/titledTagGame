--!strict
--[[
    KnockbackVelocity (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/16

    Applies short velocity pushes for tag knockback on locally simulated
    characters and training bots.
]]

local Debris = game:GetService("Debris")

local KnockbackVelocity = {}

export type Params = {
	targetRootPart: BasePart,
	originPosition: Vector3,
	sourceVelocity: Vector3?,
	knockbackType: string?,
	multiplier: number?,
	sourceRightVector: Vector3?,
}

function KnockbackVelocity.apply(params: Params)
	local targetRootPart = params.targetRootPart
	local away = targetRootPart.Position - params.originPosition
	local direction = if away.Magnitude > 0.1 then away.Unit else -targetRootPart.CFrame.LookVector
	local sourceVelocity = params.sourceVelocity or Vector3.zero
	local speedFactor = math.clamp(sourceVelocity.Magnitude / 32, 0, 3)
	local multiplier = if typeof(params.multiplier) == "number" then params.multiplier else 1

	local forwardImpulse = direction * (48 + speedFactor * 20) * multiplier
	local upImpulse = Vector3.new(0, 11 + speedFactor * 5, 0) * math.clamp(multiplier * 0.5, 0.35, 1.4)
	forwardImpulse *= Vector3.new(1.1, 0.7, 1.1)

	local sourceRightVector = params.sourceRightVector or targetRootPart.CFrame.RightVector
	local randomSide = sourceRightVector * (math.random() - 0.5) * 15
	local finalVelocity = forwardImpulse + upImpulse + randomSide
	if params.knockbackType == "NTB" then finalVelocity *= 0.6 end
	if params.knockbackType == "BotTag" then finalVelocity = forwardImpulse * 0.34 + Vector3.new(0, 7, 0) end
	if params.knockbackType == "LocalBotTag" then finalVelocity = forwardImpulse * 0.18 + Vector3.new(0, 3, 0) end

	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.Velocity = finalVelocity
	bodyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
	bodyVelocity.P = 1e4
	bodyVelocity.Parent = targetRootPart
	Debris:AddItem(bodyVelocity, 0.07)
end

return table.freeze(KnockbackVelocity)
