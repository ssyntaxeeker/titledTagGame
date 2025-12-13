local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Customization = require(ReplicatedStorage.Modules.Mobile.Customization)
local Schedules = require(ReplicatedStorage.Shared.Schedules)
local SettingsInterface = require(ReplicatedStorage.Modules.Settings.SettingsInterface)
local UIFunctions = require(ReplicatedStorage.Modules.Settings.UIFunctions)

local localPlayer = Players.LocalPlayer

local function init()
	local Frame = localPlayer.PlayerGui.SettingsUI.Main.Frames.Mobile.customizeLayout

	Frame.Button.MouseButton1Up:Connect(function()
		Customization.Toggle(not Customization.Active)

		UIFunctions.Close()
	end)

	SettingsInterface.updateSignal:Connect(function()
		if UserInputService.TouchEnabled ~= true then return end

		local MobileUI = localPlayer.PlayerGui:WaitForChild("MobileUI")

		for name, value in SettingsInterface.mobile do
			local property
			if name:sub(-8) == "Position" then
				property = "Position"
			elseif name:sub(-4) == "Size" then
				property = "Size"
			else
				continue
			end

			local buttonName = name:sub(1, #name - #property)

			local target
			if buttonName == "ThumbstickFrame" then
				target = MobileUI:FindFirstChild("ThumbstickFrame")
			else
				target = MobileUI.Buttons:FindFirstChild(buttonName)
			end

			if target and typeof(value) == "UDim2" then target[property] = value end
		end
	end)
end

return Schedules.Boot.job(init)
