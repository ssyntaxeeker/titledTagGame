local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CameraModule = require(ReplicatedStorage.Modules.Camera.CameraModule)

local localPlayer = Players.LocalPlayer

local function setupCharacter(char)
	CameraModule.SetCharacter(char)
end

localPlayer.CharacterAdded:Connect(setupCharacter)

if localPlayer.Character then setupCharacter(localPlayer.Character) end

return 0
