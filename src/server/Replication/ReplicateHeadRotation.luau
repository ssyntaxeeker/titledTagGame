local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Packages.Net)

local UpdateCameraRotationRE = Net:RemoteEvent("UpdateCameraRotation")

UpdateCameraRotationRE.OnServerEvent:Connect(function(player, NeckC0)
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end

	local torso = character:FindFirstChild("Torso")
	if not torso then return end

	local neck = torso:FindFirstChild("Neck")
	if not neck then return end

	neck.C0 = NeckC0
end)

return 0
