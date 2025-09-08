local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local SettingsInterface = require(ReplicatedStorage.Modules.Settings.SettingsInterface)

local CameraModule = {}
CameraModule.FirstPerson = true
CameraModule.RMB = false
CameraModule.LockVector = false

CameraModule.ResetCamera = false
CameraModule.SaveCameraDirection = false

CameraModule.CameraOffset = Vector3.new(2, 0.5, 5)

local yOffset = CameraModule.CameraOffset * Vector3.yAxis
local xzOffset = CFrame.new(CameraModule.CameraOffset * (Vector3.xAxis + Vector3.zAxis))

local camera = workspace.CurrentCamera
local initCameraCFrame = camera.CFrame
local savedCameraOffset

local renderConnection
local humanoid, rootPart, head

function CameraModule.SetCharacter(character)
	humanoid = character:WaitForChild("Humanoid")
	rootPart = character:WaitForChild("HumanoidRootPart")
	head = character:WaitForChild("Head")

	if renderConnection then renderConnection:Disconnect() end

	renderConnection = RunService.RenderStepped:Connect(function()
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		initCameraCFrame = camera.CFrame

		if CameraModule.FirstPerson then
			humanoid.CameraOffset = Vector3.new(0, 0, -0.3)

			if SettingsInterface.gameplay.moveCameraY == false then
				camera.CFrame = initCameraCFrame * CFrame.new(0, 0, 0)
			else
				camera.CFrame = CFrame.new(head.Position, head.Position + initCameraCFrame.LookVector)
			end
		else
			camera.CFrame = initCameraCFrame * xzOffset
			humanoid.CameraOffset = yOffset
		end

		if CameraModule.SaveCameraDirection then
			savedCameraOffset = rootPart.CFrame:ToObjectSpace(camera.CFrame)
			CameraModule.SaveCameraDirection = false
		end
		if CameraModule.ResetCamera and savedCameraOffset then
			camera.CFrame = rootPart.CFrame:ToWorldSpace(savedCameraOffset)
			CameraModule.ResetCamera = false
		end

		if CameraModule.RMB or CameraModule.LockVector then return end

		humanoid.AutoRotate = false

		local rootCFrame = CFrame.Angles(0, select(2, camera.CFrame:ToEulerAnglesYXZ()), 0)
		rootPart.CFrame = rootCFrame + rootPart.Position
	end)

	humanoid.Died:Connect(function()
		if renderConnection then
			renderConnection:Disconnect()
			renderConnection = nil
		end
	end)
end

return CameraModule
