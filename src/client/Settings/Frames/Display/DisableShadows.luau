local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Packages.Net)
local Schedules = require(ReplicatedStorage.Shared.Schedules)
local SettingsInterface = require(ReplicatedStorage.Modules.Settings.SettingsInterface)

local ChangeSettingsRE = Net:RemoteEvent("ChangeSettings")

local localPlayer = Players.LocalPlayer

local function init()
	local Frame = localPlayer.PlayerGui.SettingsUI.Main.Frames.Display.disableShadows

	Frame.Button.Text = SettingsInterface.display.disableShadows == true and "X" or ""

	Frame.Button.MouseButton1Up:Connect(function()
		local newSettingsValue = not SettingsInterface.display.disableShadows

		SettingsInterface.display.disableShadows = newSettingsValue
		Frame.Button.Text = newSettingsValue == true and "X" or ""

		Lighting.GlobalShadows = not newSettingsValue
		ChangeSettingsRE:FireServer("display", "disableShadows", newSettingsValue)
	end)

	SettingsInterface.updateSignal:Connect(function()
		Frame.Button.Text = SettingsInterface.display.disableShadows == true and "X" or ""
		Lighting.GlobalShadows = not SettingsInterface.display.disableShadows
	end)
end

return Schedules.Boot.job(init)
