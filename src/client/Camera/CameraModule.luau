--!strict
--[[
    CameraModule (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/20

    Owns the local camera presentation and exposes the same pitch plus
    yaw-CFrame contract consumed by UTG movement and parkour.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local SettingsInterface = require(ReplicatedStorage.Modules.Settings.SettingsInterface)
local MouseVisibilityService = require(ReplicatedStorage.Modules.Cursor.MouseVisibilityService)

local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

local CameraModule = {}
CameraModule.FirstPerson = true
CameraModule.RMB = false
CameraModule.LockVector = false
CameraModule.ResetCamera = false
CameraModule.StartRMB = false
CameraModule.CameraX = 0
CameraModule.CameraY = CFrame.new()
CameraModule.FreelookX = nil :: number?
CameraModule.FreelookY = nil :: CFrame?
CameraModule.CameraOffset =
	Vector3.new(-4 + (8 * SettingsInterface.gameplay.thirdPersonDistanceX), 0.5, 2 + (8 * SettingsInterface.gameplay.thirdPersonDistanceZ))

local initCameraCFrame = camera.CFrame

local function readCameraRotation(): (number, CFrame)
	local cameraCFrame = camera.CFrame
	local pitch = math.deg(math.asin(math.clamp(cameraCFrame.LookVector.Y, -1, 1)))
	local look = cameraCFrame.LookVector
	local yaw = math.atan2(-look.X, -look.Z)
	return pitch, CFrame.Angles(0, yaw, 0)
end

local humanoid, rootPart, head

function CameraModule.SetCharacter(character)
	humanoid = character:WaitForChild("Humanoid", 15)
	rootPart = character:WaitForChild("HumanoidRootPart", 15)
	head = character:WaitForChild("Head")

	RunService:UnbindFromRenderStep("CustomCamera")

	local function UpdateCamera()
		local shouldShowMouse = MouseVisibilityService.shouldShowMouse()
		initCameraCFrame = camera.CFrame
		local configuredFieldOfView = SettingsInterface.display.fov * 120
		if camera.FieldOfView ~= configuredFieldOfView then
			camera.FieldOfView = configuredFieldOfView
		end

		if CameraModule.FirstPerson then
			if localPlayer.CameraMode ~= Enum.CameraMode.LockFirstPerson then
				localPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
			end
			humanoid.CameraOffset = Vector3.new(0, 0, -0.3)

			if not SettingsInterface.gameplay.moveCameraY then
				local startY = rootPart.Position.Y + (rootPart.Size.Y / 2) + (head.Size.Y / 2)
				local targetY = head.Position.Y
				local constrainedY = math.clamp(targetY, startY - 0.3, startY + 0.3)
				local camPos = Vector3.new(camera.CFrame.Position.X, constrainedY, camera.CFrame.Position.Z)
				camera.CFrame = CFrame.new(camPos, camPos + initCameraCFrame.LookVector)
			else
				local headPos = Vector3.new(rootPart.Position.X, head.Position.Y, rootPart.Position.Z)
				camera.CFrame = CFrame.new(headPos, headPos + initCameraCFrame.LookVector)
			end
		else
			if localPlayer.CameraMode ~= Enum.CameraMode.Classic then
				localPlayer.CameraMode = Enum.CameraMode.Classic
			end

			local yOffset = CameraModule.CameraOffset * Vector3.yAxis
			local xzOffset = CFrame.new(CameraModule.CameraOffset * (Vector3.xAxis + Vector3.zAxis))

			camera.CFrame = initCameraCFrame * xzOffset
			humanoid.CameraOffset = yOffset
		end

		CameraModule.CameraX, CameraModule.CameraY = readCameraRotation()

		if CameraModule.StartRMB then
			CameraModule.FreelookX = CameraModule.CameraX
			CameraModule.FreelookY = CameraModule.CameraY
			CameraModule.StartRMB = false

			if SettingsInterface.gameplay.turn180OnFreeLook then
				camera.CFrame *= CFrame.Angles(0, math.rad(180), 0)
			end
		end

		if CameraModule.ResetCamera then
			local freelookX = CameraModule.FreelookX
			local freelookY = CameraModule.FreelookY
			if freelookX and freelookY then
				local cameraPosition = camera.CFrame.Position
				camera.CFrame = (freelookY * CFrame.Angles(math.rad(freelookX), 0, 0)) + cameraPosition
				CameraModule.CameraX = freelookX
				CameraModule.CameraY = freelookY
			end
			CameraModule.FreelookX = nil
			CameraModule.FreelookY = nil
			CameraModule.ResetCamera = false
		end

		if not (CameraModule.RMB or CameraModule.LockVector or shouldShowMouse) then
			humanoid.AutoRotate = false
			rootPart.CFrame = CameraModule.CameraY + rootPart.Position
		end

		if UserInputService.MouseEnabled then
			-- CameraMode can relock the cursor, so interactive UI ownership wins last.
			UserInputService.MouseBehavior = if shouldShowMouse then Enum.MouseBehavior.Default else Enum.MouseBehavior.LockCenter
			UserInputService.MouseIconEnabled = shouldShowMouse
		end
	end

	RunService:BindToRenderStep("CustomCamera", Enum.RenderPriority.Camera.Value, UpdateCamera)

	humanoid.Died:Connect(function()
		RunService:UnbindFromRenderStep("CustomCamera")
	end)
end

return CameraModule
