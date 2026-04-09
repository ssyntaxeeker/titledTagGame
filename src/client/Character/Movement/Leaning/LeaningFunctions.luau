local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LeaningInterface = require(ReplicatedStorage.Modules.Character.Movement.Leaning.LeaningInterface)
local MovementInterface = require(ReplicatedStorage.Modules.Character.Movement.MovementInterface)
local LeaningFunctions = {}

local slopeTiltRayParams = RaycastParams.new()
slopeTiltRayParams.RespectCanCollide = true
slopeTiltRayParams.CollisionGroup = "Players"

local function deltaLerp(n1, n2)
	return math.min(1 - math.exp(-n1 * n2), 1)
end

function LeaningFunctions.UpdateSlopeTilt(character)
	if character:GetAttribute("AnimationPaused") then return end

	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	if humanoid.FloorMaterial == Enum.Material.Air then
		LeaningInterface.slopeTiltCFrame = CFrame.new()
		return
	end

	local rootCF = rootPart.CFrame

	slopeTiltRayParams.FilterDescendantsInstances = { character, workspace.CurrentCamera }

	local forwardRay = workspace:Raycast(rootCF.Position + rootCF.LookVector * 0.5 + rootCF.UpVector * 3, -rootCF.UpVector * 12, slopeTiltRayParams)

	if not forwardRay or not forwardRay.Instance.CanCollide then
		LeaningInterface.slopeTiltCFrame = CFrame.new()
		return
	end

	-- Ignore flat ground
	if math.abs(forwardRay.Normal.Y) >= 0.98 then
		LeaningInterface.slopeTiltCFrame = CFrame.new()
		return
	end

	local backRay = workspace:Raycast(rootCF.Position - rootCF.LookVector + rootCF.UpVector * 3, -rootCF.UpVector * 12, slopeTiltRayParams)

	if not backRay or not backRay.Instance.CanCollide then
		LeaningInterface.slopeTiltCFrame = CFrame.new()
		return
	end

	local pitch = select(1, CFrame.lookAt(backRay.Position, forwardRay.Position):ToOrientation())

	if character:GetAttribute("Sliding") then
		LeaningInterface.slopeTiltCFrame = CFrame.Angles(pitch, 0, 0)
	else
		if humanoid.MoveDirection.Magnitude < 0.25 then
			pitch *= 0.6
		end

		local clamped = math.clamp(math.deg(pitch * 0.65), -35, 3.5)
		LeaningInterface.slopeTiltCFrame = CFrame.Angles(math.rad(clamped), 0, 0)
	end

	return pitch
end

function LeaningFunctions.UpdateLean(character, deltaTime)
	if character:GetAttribute("AnimationPaused") then return end

	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local velocity = rootPart.AssemblyLinearVelocity
	local localVelocity = rootPart.CFrame:VectorToObjectSpace(velocity)

	local moveVector = MovementInterface.MoveVector
	if moveVector.Magnitude > 1 then moveVector = moveVector.Unit end

	local isAir = humanoid.FloorMaterial == Enum.Material.Air

	local lerpSpeed = isAir and 12.5 or 5

	if humanoid.FloorMaterial == Enum.Material.Air or character:GetAttribute("Sliding") then
		LeaningInterface.velocityLeanCFrame = LeaningInterface.velocityLeanCFrame:Lerp(CFrame.new(), deltaLerp(6, deltaTime))
	else
		local forwardDir = (localVelocity.Z > 0) and -1 or 1

		local targetLean = CFrame.Angles(
			math.rad(localVelocity.Z * -16.5 / 32),
			math.rad(localVelocity.X * -18 / 32),
			math.rad(localVelocity.X * (-45 * forwardDir) / 32)
		) * LeaningInterface.slopeTiltCFrame:Inverse()

		LeaningInterface.velocityLeanCFrame = LeaningInterface.velocityLeanCFrame:Lerp(targetLean, deltaLerp(lerpSpeed, deltaTime))
	end

	-- Swing lerp
	LeaningInterface.swingLeanCFrame = LeaningInterface.swingLeanCFrame:Lerp(LeaningInterface.tiltSwingAngle, deltaLerp(4, deltaTime))

	local cameraFlip = 0
	--[[
		local camX = camera.CFrame.X

		if camX >= 90 and camX <= 270 then
			cameraFlip = (1 - math.cos((camX - 90) / 180 * math.pi)) / 2 * -360
		elseif camX <= -90 and camX >= -270 then
			cameraFlip = (1 - math.cos((camX + 90) / -180 * math.pi)) / 2 * 360
		end
	--]]

	local rootJoint = rootPart.RootJoint
	local originalC0 = rootJoint:GetAttribute("OriginalC0")
	if not originalC0 then return end

	rootJoint.C0 = originalC0
		* CFrame.Angles(math.rad(cameraFlip), 0, 0)
		* (LeaningInterface.velocityLeanCFrame * CFrame.new(0, 0, 3) + Vector3.new(0, 0, -3))
		* (LeaningInterface.swingLeanCFrame * CFrame.new(0, 0, -2.5) + Vector3.new(0, 0, 2.5))
end

return LeaningFunctions
