local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local SettingsInterface = require(ReplicatedStorage.Modules.Settings.SettingsInterface)

local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

local CameraModule = {}
CameraModule.FirstPerson = true
CameraModule.RMB = false
CameraModule.LockVector = false
CameraModule.ResetCamera = false
CameraModule.StartRMB = false
CameraModule.CameraOffset =
	Vector3.new(-4 + (8 * SettingsInterface.gameplay.thirdPersonDistanceX), 0.5, 2 + (8 * SettingsInterface.gameplay.thirdPersonDistanceZ))

local initCameraCFrame = camera.CFrame
local savedCameraOffset

local humanoid, rootPart, head

function CameraModule.SetCharacter(character)
	humanoid = character:WaitForChild("Humanoid", 15)
	rootPart = character:WaitForChild("HumanoidRootPart", 15)
	head = character:WaitForChild("Head")

	RunService:UnbindFromRenderStep("CustomCamera")

	local function UpdateCamera()
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		initCameraCFrame = camera.CFrame

		if CameraModule.FirstPerson then
			localPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
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
			localPlayer.CameraMode = Enum.CameraMode.Classic

			local yOffset = CameraModule.CameraOffset * Vector3.yAxis
			local xzOffset = CFrame.new(CameraModule.CameraOffset * (Vector3.xAxis + Vector3.zAxis))

			camera.CFrame = initCameraCFrame * xzOffset
			humanoid.CameraOffset = yOffset
		end

		if CameraModule.StartRMB then
			savedCameraOffset = rootPart.CFrame:ToObjectSpace(camera.CFrame)
			CameraModule.StartRMB = false

			if SettingsInterface.gameplay.turn180OnFreeLook then
				camera.CFrame *= CFrame.Angles(0, math.rad(180), 0)
			end
		end

		if CameraModule.ResetCamera and savedCameraOffset then
			camera.CFrame = rootPart.CFrame:ToWorldSpace(savedCameraOffset)
			CameraModule.ResetCamera = false
		end

		if not (CameraModule.RMB or CameraModule.LockVector) then
			humanoid.AutoRotate = false
			local rootCFrame = CFrame.Angles(0, select(2, camera.CFrame:ToEulerAnglesYXZ()), 0)
			rootPart.CFrame = rootCFrame + rootPart.Position
		end
	end

	RunService:BindToRenderStep("CustomCamera", Enum.RenderPriority.Camera.Value, UpdateCamera)

	humanoid.Died:Connect(function()
		RunService:UnbindFromRenderStep("CustomCamera")
	end)
end

return CameraModule
