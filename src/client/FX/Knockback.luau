local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local KnockbackVelocity = require(ReplicatedStorage.Modules.FX.KnockbackVelocity)
local Net = require(ReplicatedStorage.Packages.Net)

local localPlayer = Players.LocalPlayer

local ApplyKnockbackRE = Net:RemoteEvent("ApplyKnockback")

ApplyKnockbackRE.OnClientEvent:Connect(function(source, knockbackType)
	local targetCharacter = localPlayer.Character
	if not targetCharacter then return end

	local targetRootPart = targetCharacter:FindFirstChild("HumanoidRootPart")
	if not targetRootPart or not targetRootPart:IsA("BasePart") then return end

	if typeof(source) == "Vector3" then
		KnockbackVelocity.apply({
			targetRootPart = targetRootPart,
			originPosition = source,
			knockbackType = knockbackType,
		})
		return
	end

	if typeof(source) ~= "Instance" then return end

	local rootPart = source:FindFirstChild("HumanoidRootPart")
	if not rootPart or not rootPart:IsA("BasePart") then return end

	KnockbackVelocity.apply({
		targetRootPart = targetRootPart,
		originPosition = rootPart.Position,
		sourceVelocity = rootPart.AssemblyLinearVelocity,
		sourceRightVector = rootPart.CFrame.RightVector,
		knockbackType = knockbackType,
		multiplier = source:GetAttribute("KnockbackMultiplier"),
	})
end)

return 0
