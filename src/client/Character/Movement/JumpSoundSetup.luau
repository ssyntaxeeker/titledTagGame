local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Schedules = require(ReplicatedStorage.Shared.Schedules)

local localPlayer = Players.LocalPlayer

local function setupSound(character)
	local rootPart = character:WaitForChild("HumanoidRootPart")

	rootPart:WaitForChild("Jumping").SoundId = "rbxassetid://121152687916961"
end

local function init()
	local character = localPlayer.Character
	if character then setupSound(character) end

	localPlayer.CharacterAdded:Connect(setupSound)
end

return Schedules.Boot.job(init)
