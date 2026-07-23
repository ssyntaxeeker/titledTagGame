local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AerialInputs = require(ReplicatedStorage.Modules.Character.Parkour.Aerial.AerialInputs)
local Buttons = require(ReplicatedStorage.Modules.Mobile.Buttons)
local MovementInterface = require(ReplicatedStorage.Modules.Character.Movement.MovementInterface)

local function jump()
	if not AerialInputs.JumpRequest() then return end

	MovementInterface.IsJumping = true
end

local function stopJump()
	AerialInputs.JumpReleased()
	task.wait(0.1)
	MovementInterface.IsJumping = false
end

return Buttons.Register("Jump", { OnBegan = jump, OnEnded = stopJump })
