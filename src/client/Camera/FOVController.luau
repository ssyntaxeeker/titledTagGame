local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Schedules = require(ReplicatedStorage.Shared.Schedules)
local SettingsInterface = require(ReplicatedStorage.Modules.Settings.SettingsInterface)

local currentCamera = workspace.CurrentCamera
local localPlayer = Players.LocalPlayer

local renderStepped

local function calculateFOV(walkSpeed)
	local fov = 50 * SettingsInterface.display.fov + 75

	local m = ((fov + 7) - (fov - 7)) / 16
	local y = m * (walkSpeed - 16) + (fov + 2)
	return y
end

local function Lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function initCharacter(character)
	if renderStepped then renderStepped:Disconnect() end

	local humanoid = character:WaitForChild("Humanoid")

	character.Humanoid.Died:Connect(function()
		if not renderStepped then return end
		renderStepped:Disconnect()
		renderStepped = nil
	end)

	renderStepped = RunService.RenderStepped:Connect(function(dt)
		currentCamera.FieldOfView = Lerp(currentCamera.FieldOfView, calculateFOV(humanoid.WalkSpeed), dt)
	end)
end

local function handleConnections()
	if localPlayer.Character then initCharacter(localPlayer.Character) end

	localPlayer.CharacterAdded:Connect(initCharacter)
end

return Schedules.Boot.job(handleConnections)
