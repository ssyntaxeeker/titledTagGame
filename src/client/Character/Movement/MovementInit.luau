local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MovementController = require(script.Parent.MovementController)
local Schedules = require(ReplicatedStorage.Shared.Schedules)

local function enableMovement()
	MovementController.Enable(true)
end

return Schedules.Boot.job(enableMovement)
