local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MovementController = require(ReplicatedStorage.Modules.Character.Movement.MovementController)
local Schedules = require(ReplicatedStorage.Shared.Schedules)

local localPlayer = Players.LocalPlayer

local GroundRayParams = RaycastParams.new()
GroundRayParams.RespectCanCollide = true
GroundRayParams.CollisionGroup = "Player"

-- cached base root joint C0 (filled on first run)
local RootJointBaseC0 = nil

-- rotating CFrames only (no translations) to avoid lifting character
local SlopeTiltCFrame = CFrame.new()
local LeanCFrame = CFrame.new()
local SwingCFrame = CFrame.new()

-- tuning
local crazyFlips = false
local tiltSwingEnabled = true
local tiltSwingSpeed = 1
local tiltSwingAmplitudeDeg = 3

-- multipliers you can tune
local pitchMultiplier = -16.5 / 32 -- forward/back pitch intensity
local yawMultiplier = 18 / 32 -- small yaw offset (optional)
local rollMultiplier = 45 / 32 -- sideways tilt intensity

local resetMovementThreshold = 0.1 -- movement magnitude under this is "idle"
local resetLerpSpeed = 10 -- how fast to lerp back to neutral when idle

-- internal
local tiltPhase = 0
local running = false
local platformLoopActive = false
local DEBUG = false

local function deltaLerp(speed, dt)
	return math.min(1 - math.exp(-speed * dt), 1)
end

-- Safe move vector getter: works if MovementController.MoveVector is a Vector3Value, a Vector3, or falls back to Humanoid.MoveDirection
local function getMoveVector(character)
	local mv = MovementController and MovementController.MoveVector
	if mv then
		if typeof(mv) == "Vector3" then return mv end
	end

	-- fallback to humanoid MoveDirection if available
	if character then
		local humanoid = character:FindFirstChild("Humanoid")
		if humanoid then
			-- MoveDirection is a Vector3, magnitude 0 when idle
			return humanoid.MoveDirection or Vector3.new()
		end
	end

	return Vector3.new()
end

-- camera yaw utility (degrees)
local function getCameraYawDegrees()
	local cam = workspace.CurrentCamera
	if not cam then return 0 end
	local lv = cam.CFrame.LookVector
	local yawRad = math.atan2(lv.X, lv.Z)
	return math.deg(yawRad)
end

local function UpdatePlatform()
	local character = localPlayer.Character
	if not character then return end
	if character:GetAttribute("AnimationPaused") then return end

	local humanoid = character:FindFirstChild("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart or not humanoid then return end

	GroundRayParams.FilterDescendantsInstances = { workspace.CurrentCamera, character }

	if humanoid.FloorMaterial == Enum.Material.Air then
		SlopeTiltCFrame = CFrame.new()
		character:SetAttribute("SlopeTilt", nil)
		return
	end

	local charCFrame = rootPart.CFrame
	local rayOrigin = charCFrame.Position + charCFrame.LookVector * 0.5 + charCFrame.UpVector * 3
	local rayDirection = charCFrame.UpVector * -12
	local rayResult = workspace:Raycast(rayOrigin, rayDirection, GroundRayParams)

	if rayResult and rayResult.Instance and rayResult.Instance.CanCollide then
		if math.abs(rayResult.Normal.Y) < 0.98 then
			local backOrigin = charCFrame.Position - charCFrame.LookVector + charCFrame.UpVector * 3
			local backResult = workspace:Raycast(backOrigin, rayDirection, GroundRayParams)

			if backResult and backResult.Instance and backResult.Instance.CanCollide then
				local tiltX, _, _ = CFrame.lookAt(backResult.Position, rayResult.Position):ToOrientation()

				if character:GetAttribute("Sliding") == true then
					SlopeTiltCFrame = CFrame.Angles(tiltX, 0, 0)
				else
					local moveVec = getMoveVector(character)
					if moveVec.Magnitude < 0.25 then tiltX = tiltX * 0.6 end
					local clampedDeg = math.clamp(math.deg(tiltX * 0.65), -35, 3.5)
					SlopeTiltCFrame = CFrame.Angles(math.rad(clampedDeg), 0, 0)
				end

				character:SetAttribute("SlopeTilt", tiltX)
			else
				SlopeTiltCFrame = CFrame.new()
				character:SetAttribute("SlopeTilt", nil)
			end
		end
	else
		SlopeTiltCFrame = CFrame.new()
		character:SetAttribute("SlopeTilt", nil)
	end
end

local lastDiag = 0
local function UpdateLean(dt)
	local character = localPlayer.Character
	if not character then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChild("Humanoid")
	if not rootPart or not humanoid then return end
	if character:GetAttribute("AnimationPaused") then return end

	-- cache original base C0 once
	if not RootJointBaseC0 then
		local rootJoint = rootPart:FindFirstChild("RootJoint") or rootPart:FindFirstChildWhichIsA("Motor6D")
		if rootJoint and rootJoint.C0 then
			RootJointBaseC0 = rootJoint.C0
		else
			RootJointBaseC0 = CFrame.new(0, 0, 0) * CFrame.Angles(-math.pi / 2, -math.pi, 0)
		end
	end

	-- velocities (local)
	local velocity = rootPart.AssemblyLinearVelocity
	local localVelocity = rootPart.CFrame:VectorToObjectSpace(velocity)

	-- movement and run checks
	local moveVec = getMoveVector(character)
	local isRunning = humanoid:GetState() == Enum.HumanoidStateType.Running or character:GetAttribute("Sliding") or character:GetAttribute("Rolling")
	local shouldResetLean = (moveVec.Magnitude < resetMovementThreshold) or not isRunning

	-- sinusoidal swing (no accumulation)
	if tiltSwingEnabled then
		tiltPhase = tiltPhase + dt * tiltSwingSpeed * (2 * math.pi)
		local ampRad = math.rad(tiltSwingAmplitudeDeg)
		local swingX = math.sin(tiltPhase) * ampRad
		tiltPhase = tiltPhase % (2 * math.pi)
		-- Swing is rotational only (X-axis)
		local computedSwing = CFrame.Angles(swingX, 0, 0)
		SwingCFrame = SwingCFrame:Lerp(computedSwing, deltaLerp(4, dt))
	else
		SwingCFrame = SwingCFrame:Lerp(CFrame.new(), deltaLerp(4, dt))
	end

	-- choose pitch/yaw/roll direction factors
	local directionFactor = (moveVec.Z > 0) and -1 or 1

	-- compute target rotation only (no translations)
	local targetLean = CFrame.new()
	if not shouldResetLean then
		targetLean = CFrame.Angles(
			math.rad(localVelocity.Z * pitchMultiplier),
			math.rad(localVelocity.X * yawMultiplier),
			math.rad(localVelocity.X * (rollMultiplier * directionFactor))
		) * SlopeTiltCFrame:Inverse()
	end

	-- use faster lerp to neutral when resetting so it snaps back nicely
	local lerpSpeed = (humanoid.FloorMaterial == Enum.Material.Air) and 12.5 or 5
	local usedSpeed = shouldResetLean and resetLerpSpeed or lerpSpeed
	LeanCFrame = LeanCFrame:Lerp(targetLean, deltaLerp(usedSpeed, dt))

	-- crazy flips (kept optional)
	local crazyFlipAngle = 0
	if crazyFlips then
		local camYaw = getCameraYawDegrees()
		local t = 0
		if camYaw >= 90 and camYaw <= 180 then
			t = (1 - math.cos((camYaw - 90) / 90 * math.pi)) / 2
			crazyFlipAngle = -360 * t
		elseif camYaw <= -90 and camYaw >= -180 then
			t = (1 - math.cos((camYaw + 90) / -90 * math.pi)) / 2
			crazyFlipAngle = 360 * t
		end
		crazyFlipAngle = math.clamp(crazyFlipAngle, -180, 180)
	end

	-- diagnostics
	if DEBUG then
		lastDiag = lastDiag + dt
		if lastDiag >= 0.25 then
			lastDiag = 0
			print(
				("Lean diag: reset=%s moveMag=%.3f run=%s camYaw=%.1f"):format(
					tostring(shouldResetLean),
					moveVec.Magnitude,
					tostring(isRunning),
					getCameraYawDegrees()
				)
			)
		end
	end

	-- apply rotation-only CFrames to the joint; this preserves base joint position and avoids vertical offsets
	local rootJoint = rootPart:FindFirstChild("RootJoint") or rootPart:FindFirstChildWhichIsA("Motor6D")
	if rootJoint and RootJointBaseC0 then
		-- Apply base C0 then apply rotations (no extra translations)
		rootJoint.C0 = RootJointBaseC0 * CFrame.Angles(math.rad(crazyFlipAngle), 0, 0) * LeanCFrame * SwingCFrame
	end
end

-- Start/Stop helpers and boot job
local function Stop()
	if running then
		pcall(function()
			RunService:UnbindFromRenderStep("LeanUpdate")
		end)
		running = false
	end
	platformLoopActive = false
end

local function Start()
	if running then return end
	running = true
	pcall(function()
		RunService:UnbindFromRenderStep("LeanUpdate")
	end)
	RunService:BindToRenderStep("LeanUpdate", Enum.RenderPriority.Character.Value + 1, UpdateLean)

	if not platformLoopActive then
		platformLoopActive = true
		task.spawn(function()
			while platformLoopActive do
				UpdatePlatform()
				task.wait(0.1)
			end
		end)
	end
end

local function init()
	Start()
	return {
		Start = Start,
		Stop = Stop,
		SetDebug = function(v)
			DEBUG = v
		end,
		SetCrazyFlips = function(v)
			crazyFlips = v
		end,
		SetTiltSwing = function(enabled, speed, ampDeg)
			tiltSwingEnabled = enabled ~= false
			if speed then tiltSwingSpeed = speed end
			if ampDeg then tiltSwingAmplitudeDeg = ampDeg end
		end,
	}
end

return Schedules.Boot.job(init)
