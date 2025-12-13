local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Customization = require(ReplicatedStorage.Modules.Mobile.Customization)
local MovementInterface = require(ReplicatedStorage.Modules.Character.Movement.MovementInterface)

local localPlayer = Players.LocalPlayer
local ZERO_VECTOR3 = Vector3.new()

local ThumbstickController = {
	Enabled = false,
	ControlPriority = Enum.ContextActionPriority.High.Value,
	UIFrame = nil,
	StickImage = nil,
	MoveTouchObject = nil,
	MaxRadius = 0,
	CenterPosition = Vector2.new(),
}

local function resetThumbstick()
	ThumbstickController.MoveTouchObject = nil
	MovementInterface.MoveVector = ZERO_VECTOR3
	if ThumbstickController.StickImage then ThumbstickController.StickImage.Position = UDim2.new(0.5, 0, 0.5, 0) end
end

local function createUI()
	if ThumbstickController.UIFrame then
		ThumbstickController.UIFrame:Destroy()
		ThumbstickController.UIFrame = nil
	end

	local MobileUI = localPlayer:WaitForChild("PlayerGui"):WaitForChild("MobileUI")
	local frame = MobileUI.ThumbstickFrame
	local stick = frame.StickImage

	ThumbstickController.UIFrame = frame
	ThumbstickController.StickImage = stick
	ThumbstickController.MaxRadius = frame.Size.X.Offset / 2

	local function updateCenter()
		ThumbstickController.CenterPosition =
			Vector2.new(frame.AbsolutePosition.X + frame.AbsoluteSize.X / 2, frame.AbsolutePosition.Y + frame.AbsoluteSize.Y / 2)
	end

	frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateCenter)
	UserInputService.WindowFocused:Connect(resetThumbstick)
	UserInputService.TextBoxFocused:Connect(resetThumbstick)
	UserInputService.TextBoxFocusReleased:Connect(resetThumbstick)

	frame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch and input.UserInputState == Enum.UserInputState.Begin then
			ThumbstickController.MoveTouchObject = input
			updateCenter()
		end
	end)

	UserInputService.TouchMoved:Connect(function(input)
		if input ~= ThumbstickController.MoveTouchObject or Customization.Active == true then return end
		updateCenter()

		local delta = Vector2.new(input.Position.X - ThumbstickController.CenterPosition.X, input.Position.Y - ThumbstickController.CenterPosition.Y)
		if delta.Magnitude > ThumbstickController.MaxRadius then delta = delta.Unit * ThumbstickController.MaxRadius end

		ThumbstickController.StickImage.Position = UDim2.new(0.5, delta.X, 0.5, delta.Y)

		if not MovementInterface.LockMoveVector then
			MovementInterface.MoveVector = Vector3.new(delta.X / ThumbstickController.MaxRadius, 0, -delta.Y / ThumbstickController.MaxRadius)
		end
	end)

	UserInputService.TouchEnded:Connect(function(input)
		if input == ThumbstickController.MoveTouchObject then resetThumbstick() end
	end)
end

local function onRenderStepped()
	if not ThumbstickController.Enabled then return end

	local character = localPlayer.Character
	if not character then return end

	local humanoid = character:FindFirstChild("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then return end

	local move = MovementInterface.MoveVector

	if move ~= ZERO_VECTOR3 then
		local cam = workspace.CurrentCamera
		local forward = cam.CFrame.LookVector
		local right = cam.CFrame.RightVector
		local moveDir = (right * move.X + forward * move.Z)

		moveDir = Vector3.new(moveDir.X, 0, moveDir.Z)
		if moveDir.Magnitude > 0 then humanoid:Move(moveDir.Unit, false) end
	else
		humanoid:Move(ZERO_VECTOR3, false)
	end

	humanoid.Jump = MovementInterface.IsJumping
end

local renderSteppedConnection

function ThumbstickController.Enable(enable)
	if enable == ThumbstickController.Enabled then return true end
	resetThumbstick()
	if enable then
		if not ThumbstickController.UIFrame then createUI() end
		ThumbstickController.UIFrame.Visible = true
		renderSteppedConnection = RunService.RenderStepped:Connect(onRenderStepped)
	else
		if ThumbstickController.UIFrame then ThumbstickController.UIFrame.Visible = false end
		if renderSteppedConnection then
			renderSteppedConnection:Disconnect()
			renderSteppedConnection = nil
		end
	end
	ThumbstickController.Enabled = enable
	return true
end

return ThumbstickController
