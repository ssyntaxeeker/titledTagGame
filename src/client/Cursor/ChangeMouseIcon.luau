local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Schedules = require(ReplicatedStorage.Shared.Schedules)

local localPlayer = Players.LocalPlayer

local updatedMouse = false
local originalMouseX, originalMouseY

local function init()
	local mouse = localPlayer:GetMouse()

	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end

		if
			UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCurrentPosition
			and UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter
		then
			return
		end

		if not updatedMouse then
			updatedMouse = true

			originalMouseX = mouse.X
			originalMouseY = mouse.Y
		end

		if math.abs(mouse.X - originalMouseX) <= 2 and math.abs(mouse.Y - originalMouseY) <= 2 then
			UserInputService.MouseIconEnabled = false
		else
			UserInputService.MouseIconEnabled = true
		end
	end)
end

return Schedules.Boot.job(init)
