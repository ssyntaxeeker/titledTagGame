local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CameraModule = require(ReplicatedStorage.Modules.Camera.CameraModule)

local localPlayer = Players.LocalPlayer

local CameraInputs = {}

CameraInputs.ChangeCameraPerspective = {}
CameraInputs.UnlockCamera = {}

CameraInputs.ChangeCameraPerspective.OnBegan = function()
	CameraModule.FirstPerson = not CameraModule.FirstPerson

	local character = localPlayer.Character
	if not character then return end

	local overheadUI = character:WaitForChild("Head"):FindFirstChild("PlayerName")
	if not overheadUI then return end

	overheadUI.Enabled = not CameraModule.FirstPerson
end

CameraInputs.UnlockCamera.OnBegan = function()
	CameraModule.RMB = true
	CameraModule.StartRMB = true
end

CameraInputs.UnlockCamera.OnEnded = function()
	CameraModule.ResetCamera = true
	CameraModule.RMB = false
end

return CameraInputs
