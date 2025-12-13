local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local KeyboardMovementController = require(ReplicatedStorage.Modules.Character.Movement.KeyboardMovementController)
local Schedules = require(ReplicatedStorage.Shared.Schedules)
local ThumbstickMovementController = require(ReplicatedStorage.Modules.Character.Movement.ThumbstickMovementController)

local function enableMovement()
	if UserInputService.KeyboardEnabled == true then KeyboardMovementController.Enable(true) end
	if UserInputService.TouchEnabled == true then ThumbstickMovementController.Enable(true) end
end

return Schedules.Boot.job(enableMovement)
