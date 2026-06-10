local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LeaningInterface = require(game.ReplicatedStorage.Modules.Character.Movement.Leaning.LeaningInterface)
local Schedules = require(game.ReplicatedStorage.Shared.Schedules)
local Slide = require(game.ReplicatedStorage.Modules.Character.Parkour.Landing.Slide)

local localPlayer = Players.LocalPlayer
local connection

local function wantsSprint(character)
	return not UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
		and not character:GetAttribute("Sliding")
		and not character:GetAttribute("Crouching")
end

local function adjustWalkSpeed(character, dt)
	local humanoid = character:FindFirstChild("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")

	if not humanoid or not rootPart then return end

	if character:GetAttribute("Rolling") then return end

	local dt60 = math.min(dt, 1) * 60

	--------------------------------------------------
	-- BASE SPEEDS (matches utg)
	--------------------------------------------------

	local crouchSpeed = 8
	local runSpeed = character:GetAttribute("MinRunSpeed") or 16
	local sprintSpeed = character:GetAttribute("MaxRunSpeed") or 32

	--------------------------------------------------
	-- SLIDE
	--------------------------------------------------

	if character:GetAttribute("Sliding") then
		local slopeCF = LeaningInterface.slopeTiltCFrame

		if slopeCF then
			local forward = rootPart.CFrame.LookVector
			local normal = slopeCF.UpVector

			local slopeTilt = -forward:Dot(normal)

			humanoid.WalkSpeed += slopeTilt * dt60 * 0.35
		end

		humanoid.WalkSpeed = math.clamp(humanoid.WalkSpeed, runSpeed, sprintSpeed * 2)

		if humanoid.WalkSpeed < 17 then
			Slide.Stop()
			humanoid.WalkSpeed = runSpeed
		end

		return
	end

	local crouching = character:GetAttribute("Crouching")
	local sprintHeld = wantsSprint(character)
	local forwardHeld = character:GetAttribute("ForwardHeld")

	if crouching then
		humanoid.WalkSpeed = crouchSpeed
		return
	end

	if not sprintHeld or not forwardHeld then
		humanoid.WalkSpeed = math.max(runSpeed, humanoid.WalkSpeed - dt60 * 0.5)
		return
	end

	--------------------------------------------------
	-- MOMENTUM / FRICTION
	--------------------------------------------------

	local momentum = character:GetAttribute("Momentum") or 0
	local friction = character:GetAttribute("Friction") or 0

	local floorMaterial = humanoid.FloorMaterial
	local airborne = floorMaterial == Enum.Material.Air

	local momentumDecay = airborne and 0.0375 or 0.0425
	local frictionDecay = airborne and 0.06 or 0.06

	momentum = math.clamp(momentum - momentumDecay * dt60, 0, 32)

	friction = math.clamp(friction - frictionDecay * dt60, 0, 16)

	character:SetAttribute("Momentum", momentum)
	character:SetAttribute("Friction", friction)

	--------------------------------------------------
	-- APPLY MOMENTUM TO SPEED TIERS
	--------------------------------------------------

	local momentumBonus = momentum
	local frictionPenalty = friction

	crouchSpeed += momentumBonus
	runSpeed += momentumBonus
	sprintSpeed += momentumBonus

	crouchSpeed -= frictionPenalty
	runSpeed -= frictionPenalty
	sprintSpeed -= frictionPenalty

	--------------------------------------------------
	-- MOVEMENT INPUT
	--------------------------------------------------

	local moveDirection = humanoid.MoveDirection
	local moving = moveDirection.Magnitude > 0.1

	local sprinting = character:GetAttribute("ForwardHeld") and moving and wantsSprint(character) and not crouching

	--------------------------------------------------
	-- CROUCH
	--------------------------------------------------

	if crouching then
		runSpeed = crouchSpeed
		sprintSpeed = crouchSpeed
	end

	--------------------------------------------------
	-- ACCELERATION MODEL
	--------------------------------------------------

	local minSpeed = runSpeed
	local maxSpeed = runSpeed

	if sprinting then maxSpeed = sprintSpeed end

	local accel = dt60 * 0.2

	if airborne then
		if sprinting then
			minSpeed = runSpeed
			maxSpeed = sprintSpeed
		end
	else
		if sprinting or humanoid.WalkSpeed > runSpeed then
			minSpeed = runSpeed
			maxSpeed = sprintSpeed
		end
	end

	humanoid.WalkSpeed = math.clamp(humanoid.WalkSpeed + accel, minSpeed, maxSpeed)

	--------------------------------------------------
	-- NO INPUT
	--------------------------------------------------

	if not moving then
		if not airborne then humanoid.WalkSpeed = runSpeed end
	end

	--------------------------------------------------
	-- MOMENTUM RESET
	--------------------------------------------------

	local horizontalVelocity = Vector2.new(rootPart.AssemblyLinearVelocity.X, rootPart.AssemblyLinearVelocity.Z).Magnitude

	if horizontalVelocity < 6.8 then character:SetAttribute("Momentum", 0) end
	if horizontalVelocity < runSpeed and character:GetAttribute("Sliding") then Slide.Stop() end
end

local function initCharacter(character)
	if connection then connection:Disconnect() end

	character:SetAttribute("Momentum", 0)
	character:SetAttribute("Friction", 0)

	local humanoid = character:WaitForChild("Humanoid")

	humanoid.Died:Connect(function()
		if connection then
			connection:Disconnect()
			connection = nil
		end
	end)

	connection = RunService.Heartbeat:Connect(function(dt)
		adjustWalkSpeed(character, dt)
	end)
end

local function handleConnections()
	localPlayer.CharacterAdded:Connect(initCharacter)

	if localPlayer.Character then initCharacter(localPlayer.Character) end
end

return Schedules["Boot"].job(handleConnections)
