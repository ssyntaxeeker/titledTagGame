local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Schedules = require(ReplicatedStorage.Shared.Schedules)

local localPlayer = Players.LocalPlayer

local momentum = 0
local friction = 0

local function moveUpdate(deltaTime)
	local character = localPlayer.Character
	local humanoid = character.Humanoid

	if character:GetAttribute("Crouching") or character:GetAttribute("Rolling") then return end

	local moveStrength = math.min(deltaTime, 1) * 60
	--local isCrouching = character:GetAttribute("Crouching")

	local moveVector = humanoid.MoveDirection
	local floorMaterial = humanoid.FloorMaterial

	local isSprinting = UserInputService:IsKeyDown(Enum.KeyCode.W)

	local walkBase = character:GetAttribute("MinRunSpeed") or 16
	local runBase = character:GetAttribute("MaxRunSpeed") or 32

	local jumpPowerMin = character:GetAttribute("MinJumpPower") or 16
	local jumpPowerMax = character:GetAttribute("MaxJumpPower") or 28

	if moveVector.Magnitude > 0.1 then
		local momentumDecay = 0.0425 * (character:GetAttribute("MomentumDecay") or 1)
		local frictionDecay = 0.06 * (character:GetAttribute("FrictionDecay") or 1)

		if floorMaterial == Enum.Material.Air then
			momentumDecay = 0.0375 * (character:GetAttribute("MomentumMidair") or 1)
			frictionDecay = 0.06 * (character:GetAttribute("FrictionMidair") or 1)
		end

		momentum = math.clamp(momentum - momentumDecay * moveStrength, 0, 32 * (character:GetAttribute("MomentumMultiplier") or 1))
		friction = math.clamp(friction - frictionDecay * moveStrength, 0, 16)

		local momentumSpeed = momentum * (character:GetAttribute("MomentumSpeed") or 1)
		local frictionSpeed = friction * (character:GetAttribute("FrictionSpeed") or 1)

		local accel = moveStrength * 0.2 * (character:GetAttribute("AccelerationRate") / 16)
		local minSpeed = walkBase + momentumSpeed - frictionSpeed
		local maxSpeed = runBase + momentumSpeed - frictionSpeed

		if floorMaterial ~= Enum.Material.Air then
			if isSprinting or minSpeed < humanoid.WalkSpeed then
				if not isSprinting then accel = moveStrength * -0.5 end
				humanoid.WalkSpeed = math.clamp(humanoid.WalkSpeed + accel, minSpeed, math.max(maxSpeed, minSpeed))
			else
				humanoid.WalkSpeed = math.clamp(humanoid.WalkSpeed + accel, minSpeed, maxSpeed)
			end
		else
			if isSprinting then
				humanoid.WalkSpeed = math.clamp(humanoid.WalkSpeed + accel, minSpeed, maxSpeed)
			else
				humanoid.WalkSpeed = minSpeed
			end
		end

		humanoid.JumpPower = math.clamp(humanoid.JumpPower + moveStrength * 0.2, jumpPowerMin, jumpPowerMax)
	else
		humanoid.WalkSpeed = walkBase
		humanoid.JumpPower = jumpPowerMin
		momentum = 0
	end
end

local function init()
	RunService.RenderStepped:Connect(function(deltaTime)
		local character = localPlayer.Character
		if not character then return end

		local humanoid = character:FindFirstChild("Humanoid")
		if not humanoid then return end

		moveUpdate(deltaTime)
	end)
end

return Schedules.Boot.job(init)
