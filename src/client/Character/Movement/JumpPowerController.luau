local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Schedules = require(ReplicatedStorage.Shared.Schedules)

local localPlayer = Players.LocalPlayer

local renderStepped

local function adjustJumpPower(character, dt)
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	if character:GetAttribute("Rolling") then return end

	local minJumpPower = character:GetAttribute("MinJumpPower") or 16
	local maxJumpPower = character:GetAttribute("MaxJumpPower") or 28
	local accelerationRate = character:GetAttribute("AccelerationRate") or 16
	local decelerationRate = character:GetAttribute("DecelerationRate") or 2

	local movementDirection = rootPart.CFrame:VectorToObjectSpace(rootPart.AssemblyLinearVelocity).Z / humanoid.WalkSpeed

	local currentPower = humanoid.JumpPower
	local targetPower = if movementDirection < -0.05 then maxJumpPower else minJumpPower
	local rate = if currentPower < targetPower then accelerationRate else decelerationRate

	if character:GetAttribute("Sliding") == true then return end

	if humanoid.MoveDirection.Magnitude == 0 then
		humanoid.JumpPower = minJumpPower
	else
		humanoid.JumpPower = currentPower + math.clamp(targetPower - currentPower, -rate * dt, rate * dt)
	end
end

local function initCharacter(character)
	if renderStepped then renderStepped:Disconnect() end

	local humanoid = character:WaitForChild("Humanoid")
	humanoid.Died:Connect(function()
		if renderStepped then
			renderStepped:Disconnect()
			renderStepped = nil
		end
	end)

	character:SetAttribute("Momentum", 0)
	character:SetAttribute("Friction", 0)

	renderStepped = RunService.Heartbeat:Connect(function(dt)
		adjustJumpPower(character, dt)
	end)
end

local function handleConnections()
	localPlayer.CharacterAdded:Connect(initCharacter)

	if localPlayer.Character then initCharacter(localPlayer.Character) end
end

return Schedules["Boot"].job(handleConnections)
