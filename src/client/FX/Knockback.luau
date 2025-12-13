local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Packages.Net)

local localPlayer = Players.LocalPlayer

local ApplyKnockbackRE = Net:RemoteEvent("ApplyKnockback")

ApplyKnockbackRE.OnClientEvent:Connect(function(character, knockbackType)
	local targetCharacter = localPlayer.Character
	local targetRootPart = targetCharacter.HumanoidRootPart
	local rootPart = character.HumanoidRootPart

	local direction = (targetRootPart.Position - rootPart.Position).Unit
	local attackerVelocity = rootPart.AssemblyLinearVelocity.Magnitude
	local speedFactor = math.clamp(attackerVelocity / 32, 0, 3)

	local baseForward = 48
	local knockbackMultiplier = character:GetAttribute("KnockbackMultiplier")
	local forwardImpulse = direction * (baseForward + speedFactor * 20) * (knockbackMultiplier or 1)
	local upImpulse = Vector3.new(0, 11 + speedFactor * 5, 0) * ((knockbackMultiplier and knockbackMultiplier / 2) or 0.5)

	forwardImpulse *= Vector3.new(1.1, 0.7, 1.1)

	local randomSide = rootPart.CFrame.RightVector * (math.random() - 0.5) * 15
	local finalVelocity = forwardImpulse + upImpulse + randomSide

	if knockbackType == "NTB" then
		finalVelocity *= 0.6
	end

	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.Velocity = finalVelocity
	bodyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
	bodyVelocity.P = 1e4
	bodyVelocity.Parent = targetRootPart
	Debris:AddItem(bodyVelocity, 0.07)
end)

return 0
