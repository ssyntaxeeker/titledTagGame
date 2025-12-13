local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Schedules = require(ReplicatedStorage.Shared.Schedules)
local Slide = require(ReplicatedStorage.Modules.Character.Parkour.Landing.Slide)

local localPlayer = Players.LocalPlayer

local renderStepped

local function isRunning()
	return UserInputService:IsKeyDown(Enum.KeyCode.W)
end

local function adjustWalkSpeed(character, dt)
	local humanoid = character.Humanoid

	local minRunSpeed = character:GetAttribute("MinRunSpeed") or 16
	local maxRunSpeed = character:GetAttribute("MaxRunSpeed") or 32
	local accelerationRate = character:GetAttribute("AccelerationRate") or 16
	local decelerationRate = character:GetAttribute("DecelerationRate") or 1.4

	local currentSpeed = humanoid.WalkSpeed
	local targetSpeed = if isRunning() then maxRunSpeed else minRunSpeed
	local rate = if currentSpeed < targetSpeed then accelerationRate else decelerationRate

	if not character:GetAttribute("Rolling") then
		if currentSpeed > 37.5 then rate = rate * 4 end
	end

	local isSliding = character:GetAttribute("Sliding")

	if character:GetAttribute("Crouching") == true then
		humanoid.WalkSpeed = minRunSpeed / 1.8
	elseif not isRunning() then
		humanoid.WalkSpeed = minRunSpeed

		if isSliding then Slide.Stop() end
	elseif not isSliding then
		humanoid.WalkSpeed = currentSpeed + math.clamp(targetSpeed - currentSpeed, -rate * dt, rate * dt)
	end
end

local function initCharacter(character)
	if renderStepped then renderStepped:Disconnect() end

	character:WaitForChild("Humanoid").Died:Connect(function()
		if not renderStepped then return end

		renderStepped:Disconnect()
		renderStepped = nil
	end)

	renderStepped = RunService.RenderStepped:Connect(function(dt)
		adjustWalkSpeed(character, dt)
	end)
end

local function handleConnections()
	localPlayer.CharacterAdded:Connect(initCharacter)

	if localPlayer.Character then initCharacter(localPlayer.Character) end
end

return Schedules["Boot"].job(handleConnections)
