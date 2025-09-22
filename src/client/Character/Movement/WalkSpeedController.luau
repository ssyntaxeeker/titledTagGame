local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Schedules = require(ReplicatedStorage.Shared.Schedules)
local Slide = require(ReplicatedStorage.Modules.Character.Parkour.Landing.Slide)

local localPlayer = Players.LocalPlayer
local renderStepped

local function isMoving()
	return UserInputService:IsKeyDown(Enum.KeyCode.W)
end

local function isSprinting(character)
	return not UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
		and not character:GetAttribute("Crouching")
		and not character:GetAttribute("Sliding")
end

local function adjustWalkSpeed(character, dt)
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end

	if character:GetAttribute("Rolling") then return end

	local minRunSpeed = character:GetAttribute("MinRunSpeed") or 16
	local maxRunSpeed = character:GetAttribute("MaxRunSpeed") or 32
	local acceleration = character:GetAttribute("AccelerationRate") or 20
	local deceleration = character:GetAttribute("DecelerationRate") or 14
	local momentumDecay = character:GetAttribute("MomentumDecay") or 0.0425
	local frictionDecay = character:GetAttribute("FrictionDecay") or 0.06

	local currentSpeed = humanoid.WalkSpeed
	local targetSpeed = minRunSpeed
	local floorMaterial = humanoid.FloorMaterial

	if currentSpeed > 37 then
		deceleration *= (5 / 6) * currentSpeed - 28.6667
	end

	if isMoving() then
		if isSprinting(character) then
			targetSpeed = maxRunSpeed
		else
			targetSpeed = minRunSpeed
		end
	else
		if character:GetAttribute("Sliding") then Slide.Stop() end

		targetSpeed = minRunSpeed
		deceleration *= 23
	end

	local momentum = character:GetAttribute("Momentum") or 0
	local friction = character:GetAttribute("Friction") or 0

	local decay = if floorMaterial == Enum.Material.Air then momentumDecay * 0.62 else momentumDecay
	local frictionLoss = if floorMaterial == Enum.Material.Air then frictionDecay * 1 else frictionDecay

	momentum = math.clamp(momentum - decay * dt * 60, 0, 32)
	friction = math.clamp(friction - frictionLoss * dt * 60, 0, 16)

	character:SetAttribute("Momentum", momentum)
	character:SetAttribute("Friction", friction)

	if character:GetAttribute("Sliding") then
		humanoid.WalkSpeed = math.max(minRunSpeed / 2, currentSpeed - deceleration * dt)
		return
	end

	if character:GetAttribute("Crouching") then
		humanoid.WalkSpeed = minRunSpeed / 1.8
		return
	end

	if humanoid.MoveDirection.Magnitude < 0.1 then
		humanoid.WalkSpeed = minRunSpeed
		return
	end

	local rate = if currentSpeed < targetSpeed then acceleration else deceleration
	local momentumBoost = momentum * 0.5
	local frictionPenalty = friction * 0.5

	local finalTarget = math.clamp(targetSpeed + momentumBoost - frictionPenalty, minRunSpeed, maxRunSpeed)
	humanoid.WalkSpeed = math.min(44, currentSpeed + math.clamp(finalTarget - currentSpeed, -rate * dt, rate * dt))
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

	renderStepped = RunService.RenderStepped:Connect(function(dt)
		adjustWalkSpeed(character, dt)
	end)
end

local function handleConnections()
	localPlayer.CharacterAdded:Connect(initCharacter)
	if localPlayer.Character then initCharacter(localPlayer.Character) end
end

return Schedules["Boot"].job(handleConnections)
