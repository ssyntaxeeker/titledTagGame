--!strict
--[[
    ChangeMouseIcon (Client)
    =================
    Author: Sol (3693744006)
    Updated: 26/07/21

    Hides the cursor near the locked-camera center while respecting mouse
    visibility claimed by voting and other interactive interfaces.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local MouseVisibilityService = require(ReplicatedStorage.Modules.Cursor.MouseVisibilityService)
local Schedules = require(ReplicatedStorage.Shared.Schedules)

local localPlayer = Players.LocalPlayer

local updatedMouse = false
local originalMouseX = 0
local originalMouseY = 0

local function init()
	local mouse = localPlayer:GetMouse()

	UserInputService.InputChanged:Connect(function(input: InputObject)
		if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
		if MouseVisibilityService.shouldShowMouse() then
			updatedMouse = false
			UserInputService.MouseIconEnabled = true
			return
		end

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

		if math.abs(mouse.X - originalMouseX) <= 5 and math.abs(mouse.Y - originalMouseY) <= 5 then
			UserInputService.MouseIconEnabled = false
		else
			UserInputService.MouseIconEnabled = true
		end
	end)
end

return Schedules.Boot.job(init)
