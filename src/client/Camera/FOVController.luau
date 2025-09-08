local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Schedules = require(ReplicatedStorage.Shared.Schedules)

local currentCamera = workspace.CurrentCamera
local localPlayer = Players.LocalPlayer

local maxRunSpeedFOV = 120
local minRunSpeedFOV = 110
local increment = 117

local renderStepped

local function calculateFOV(walkSpeed)
	local m = (maxRunSpeedFOV - minRunSpeedFOV) / 16
	local y = m * (walkSpeed - 16) + increment
	return y
end

local function Lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function initCharacter(character)
	if renderStepped then renderStepped:Disconnect() end

	character.Humanoid.Died:Connect(function()
		if not renderStepped then return end
		renderStepped:Disconnect()
		renderStepped = nil
	end)

	local humanoid = character.Humanoid

	renderStepped = RunService.RenderStepped:Connect(function(dt)
		currentCamera.FieldOfView = Lerp(currentCamera.FieldOfView, calculateFOV(humanoid.WalkSpeed), dt)
	end)
end

local function handleConnections()
	if localPlayer.Character then initCharacter(localPlayer.Character) end

	localPlayer.CharacterAdded:Connect(initCharacter)
end

return Schedules.Boot.job(handleConnections)
