--!strict
--[[
    MovementMotor (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/18

    Converts local player input into UTG-style camera-relative movement and
    velocity-following slide steering. Input devices remain separate owners.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CameraModule = require(ReplicatedStorage.Modules.Camera.CameraModule)
local MovementConfig = require(ReplicatedStorage.Modules.Character.Movement.MovementConfig)
local MovementInterface = require(ReplicatedStorage.Modules.Character.Movement.MovementInterface)

local MovementMotor = {}
local worldMoveDirection = Vector3.zero
local activeCharacter: Model? = nil

local function deltaLerp(response: number, dt: number): number
	return math.min(1 - math.exp(-response * dt), 1)
end

function MovementMotor.reset(character: Model)
	activeCharacter = character
	worldMoveDirection = Vector3.zero
end

-- Applies one input frame. The caller owns render-step scheduling.
function MovementMotor.step(character: Model, dt: number)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	assert(humanoid, "[MovementMotor.step] character has no Humanoid")
	assert(rootPart and rootPart:IsA("BasePart"), "[MovementMotor.step] character has no HumanoidRootPart")
	if activeCharacter ~= character then MovementMotor.reset(character) end

	local moveInput = MovementInterface.MoveVector
	if moveInput.Magnitude > 1 then moveInput = moveInput.Unit end
	character:SetAttribute("ForwardHeld", moveInput.Z > 0.25)

	if MovementInterface.LockMoveVector then
		worldMoveDirection = MovementInterface.LockedMoveDirection
		humanoid:Move(worldMoveDirection, false)
		return
	end
	if character:GetAttribute("Ziplining") then
		worldMoveDirection = Vector3.zero
		humanoid:Move(Vector3.zero, false)
		return
	end
	if character:GetAttribute("Wallrunning") then
		local wallrunDirection = character:GetAttribute("WallrunDirection")
		assert(typeof(wallrunDirection) == "Vector3", "[MovementMotor.step] wallrun has no movement direction")
		worldMoveDirection = wallrunDirection
		humanoid:Move(worldMoveDirection, false)
		return
	end

	if character:GetAttribute("Sliding") then
		local horizontalVelocity = rootPart.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
		if horizontalVelocity.Magnitude > 0.05 and not humanoid.SeatPart then
			if not CameraModule.RMB then
				local frameAlpha = math.min(dt * 60, 1)
				rootPart.CFrame *= CFrame.new(moveInput.X * 0.02 * frameAlpha, 0, 0)
				local localSteer = Vector3.new(
					moveInput.X * 0.5 * MovementConfig.slideSteerMultiplier * frameAlpha,
					0,
					-1
				)
				worldMoveDirection = worldMoveDirection:Lerp(
					rootPart.CFrame:VectorToWorldSpace(localSteer),
					deltaLerp(MovementConfig.slideSteerResponse, dt)
				)
			end

			local velocityDirection = horizontalVelocity.Unit
			local targetRotation = CFrame.lookAt(Vector3.zero, velocityDirection).Rotation
			rootPart.CFrame = rootPart.CFrame.Rotation:Lerp(
				targetRotation,
				deltaLerp(MovementConfig.slideVelocityTurnResponse, dt)
			) + rootPart.Position
		end
	else
		local cameraYaw = CameraModule.FreelookY or CameraModule.CameraY
		-- MovementInterface uses positive Z for forward, while CFrame local
		-- forward is negative Z. Preserve the shared input convention and only
		-- convert the axis at the camera-to-world boundary.
		local cameraInput = Vector3.new(moveInput.X, 0, -moveInput.Z)
		worldMoveDirection = cameraYaw:VectorToWorldSpace(cameraInput)
	end

	humanoid:Move(worldMoveDirection, false)
end

return table.freeze(MovementMotor)
