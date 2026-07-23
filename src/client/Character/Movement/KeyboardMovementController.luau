local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local MovementInterface = require(ReplicatedStorage.Modules.Character.Movement.MovementInterface)
local MovementMotor = require(ReplicatedStorage.Modules.Character.Movement.MovementMotor)

local localPlayer = Players.LocalPlayer
local ZERO_VECTOR3 = Vector3.new()

local KeyboardController = {
	Enabled = false,
	ControlPriority = Enum.ContextActionPriority.High.Value,
	JumpEnabled = true,
}

local inputValues = {
	Forward = 0,
	Backward = 0,
	Left = 0,
	Right = 0,
}

local jumpRequested = false

local function updateMovement(state)
	if state == Enum.UserInputState.Cancel then
		MovementInterface.MoveVector = ZERO_VECTOR3
	else
		MovementInterface.MoveVector = Vector3.new(inputValues.Left + inputValues.Right, 0, inputValues.Forward + inputValues.Backward)
	end
end

local function updateJump()
	local character = localPlayer.Character
	if not character then return end

	if character:GetAttribute("Crouching") then jumpRequested = false end
	MovementInterface.IsJumping = jumpRequested
end

local function setInput(direction, axis, value)
	inputValues[direction] = (axis == Enum.UserInputState.Begin) and value or 0

	local character = localPlayer.Character
	if character then character:SetAttribute("ForwardHeld", inputValues.Forward > 0) end

	updateMovement(axis)

	return Enum.ContextActionResult.Pass
end

local actions = {
	{
		"moveForwardAction",
		function(_, s)
			return setInput("Forward", s, 1)
		end,
		Enum.PlayerActions.CharacterForward,
	},
	{
		"moveBackwardAction",
		function(_, s)
			return setInput("Backward", s, -1)
		end,
		Enum.PlayerActions.CharacterBackward,
	},
	{
		"moveLeftAction",
		function(_, s)
			return setInput("Left", s, -1)
		end,
		Enum.PlayerActions.CharacterLeft,
	},
	{
		"moveRightAction",
		function(_, s)
			return setInput("Right", s, 1)
		end,
		Enum.PlayerActions.CharacterRight,
	},
	{
		"jumpAction",
		function(_, s)
			jumpRequested = KeyboardController.JumpEnabled and (s == Enum.UserInputState.Begin)
			updateJump()
			return Enum.ContextActionResult.Pass
		end,
		Enum.PlayerActions.CharacterJump,
	},
}

local function bindActions()
	for _, action in actions do
		ContextActionService:BindActionAtPriority(action[1], action[2], false, KeyboardController.ControlPriority, action[3])
	end
end

local function unbindActions()
	for _, action in actions do
		ContextActionService:UnbindAction(action[1])
	end
end

local function resetInputs()
	MovementInterface.MoveVector = ZERO_VECTOR3

	for k in inputValues do
		inputValues[k] = 0
	end
	jumpRequested = false
	updateJump()
end

local renderSteppedConnection

local function onRenderStepped(dt)
	local character = localPlayer.Character
	if not character or not KeyboardController.Enabled then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or not character:FindFirstChild("HumanoidRootPart") then return end
	MovementMotor.step(character, dt)
	humanoid.Jump = MovementInterface.IsJumping and character:GetAttribute("Walljumping") ~= true
end

local function connectFocusEvents()
	UserInputService.TextBoxFocusReleased:Connect(resetInputs)
	UserInputService.TextBoxFocused:Connect(function()
		jumpRequested = false
		updateJump()
	end)
	UserInputService.WindowFocused:Connect(resetInputs)
end

function KeyboardController.Enable(enable, priority)
	if enable == KeyboardController.Enabled then return true end
	resetInputs()
	if enable then
		if priority then KeyboardController.ControlPriority = priority end
		bindActions()
		connectFocusEvents()
		renderSteppedConnection = RunService.RenderStepped:Connect(onRenderStepped)
	else
		unbindActions()
		resetInputs()
		if renderSteppedConnection then
			renderSteppedConnection:Disconnect()
			renderSteppedConnection = nil
		end
	end
	KeyboardController.Enabled = enable
	return true
end

return KeyboardController
