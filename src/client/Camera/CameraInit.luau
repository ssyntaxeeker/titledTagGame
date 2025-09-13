local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CameraModule = require(ReplicatedStorage.Modules.Camera.CameraModule)
local InputsManager = require(ReplicatedStorage.Modules.Inputs.InputsManager)

local localPlayer = Players.LocalPlayer

local function setupCharacter(char)
	CameraModule.SetCharacter(char)
end

localPlayer.CharacterAdded:Connect(setupCharacter)

if localPlayer.Character then setupCharacter(localPlayer.Character) end

InputsManager.AddInput("ChangeCameraPerspective", {
	Keys = { Enum.KeyCode.Z, Enum.KeyCode.V },
	OnBegan = function()
		CameraModule.FirstPerson = not CameraModule.FirstPerson

		local character = localPlayer.Character
		if not character then return end

		local overheadUI = character:WaitForChild("Head"):FindFirstChild("PlayerName")
		if not overheadUI then return end
		overheadUI.Enabled = not CameraModule.FirstPerson
	end,
})

InputsManager.AddInput("UnlockCamera", {
	Keys = { Enum.UserInputType.MouseButton2 },
	OnBegan = function()
		CameraModule.RMB = true
		CameraModule.SaveCameraDirection = true
	end,
	OnEnded = function()
		CameraModule.ResetCamera = true
		CameraModule.RMB = false
	end,
})

return 0
