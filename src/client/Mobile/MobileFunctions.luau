--!strict
--[[
    MobileFunctions (Client)
    ========================
    Author: Sol (3693744006)
    Updated: 26/07/20

    Owns mobile action-button input capture without blocking simultaneous
    camera touches.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Buttons = require(ReplicatedStorage.Modules.Mobile.Buttons)

local localPlayer = Players.LocalPlayer
local MobileFunctions = {}
local connections = {}
local activeButtonInputs = {}

function MobileFunctions.HookButtons()
	local MobileUI = localPlayer.PlayerGui:WaitForChild("MobileUI")

	for buttonName, callback in Buttons.GetList() do
		local button = MobileUI.Buttons:FindFirstChild(buttonName)
		if not button or not button:IsA("GuiObject") then continue end
		button.Active = true
		if button:IsA("GuiButton") then button.Modal = false end

		if callback.OnBegan then
			table.insert(
				connections,
				button.InputBegan:Connect(function(input)
					if input.UserInputType ~= Enum.UserInputType.Touch or activeButtonInputs[button] then return end
					activeButtonInputs[button] = input
					callback.OnBegan()
				end)
			)
		end

		table.insert(
			connections,
			button.InputEnded:Connect(function(input)
				if input ~= activeButtonInputs[button] then return end
				activeButtonInputs[button] = nil
				if callback.OnEnded then callback.OnEnded() end
			end)
		)
	end
end

function MobileFunctions.HasActiveButtonInput(): boolean
	return next(activeButtonInputs) ~= nil
end

function MobileFunctions.UnhookButtons()
	table.clear(activeButtonInputs)
	for _, callback in Buttons.GetList() do
		if callback.OnDisabled then
			callback.OnDisabled()
		elseif callback.OnEnded then
			callback.OnEnded()
		end
	end
	for _, c in connections do
		c:Disconnect()
	end
	connections = {}
end

return MobileFunctions
