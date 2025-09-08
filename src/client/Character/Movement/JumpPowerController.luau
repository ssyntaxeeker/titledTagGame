local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Schedules = require(ReplicatedStorage.Shared.Schedules)

local localPlayer = Players.LocalPlayer

local renderStepped

local function isRunning()
	return UserInputService:IsKeyDown(Enum.KeyCode.W)
end

local function adjustJumpPower(character, dt)
	local humanoid = character.Humanoid

	local currentPower = humanoid.JumpPower

	local minJumpPower = character:GetAttribute("MinJumpPower") or 16
	local maxJumpPower = character:GetAttribute("MaxJumpPower") or 28
	local accelerationRate = character:GetAttribute("AccelerationRate") or 16
	local decelerationRate = character:GetAttribute("DecelerationRate") or 2

	local jumpPowerBoost = math.max(currentPower / maxJumpPower, 1)
	local targetPower = if isRunning() then maxJumpPower else minJumpPower
	targetPower *= jumpPowerBoost
	local rate = if currentPower < targetPower then accelerationRate else decelerationRate

	if humanoid.MoveDirection.Magnitude == 0 then
		humanoid.JumpPower = minJumpPower
	else
		humanoid.JumpPower = currentPower + math.clamp(targetPower - currentPower, -rate * dt, rate * dt)
	end
end

local function initCharacter(character)
	if renderStepped then renderStepped:Disconnect() end

	character.Humanoid.Died:Connect(function()
		if not renderStepped then return end

		renderStepped:Disconnect()
		renderStepped = nil
	end)

	renderStepped = RunService.RenderStepped:Connect(function(dt)
		adjustJumpPower(character, dt)
	end)
end

local function handleConnections()
	if localPlayer.Character then initCharacter(localPlayer.Character) end

	localPlayer.CharacterAdded:Connect(initCharacter)
end

return Schedules["Boot"].job(handleConnections)
