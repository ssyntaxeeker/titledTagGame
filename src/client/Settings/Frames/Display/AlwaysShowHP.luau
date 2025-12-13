local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Packages.Net)
local Schedules = require(ReplicatedStorage.Shared.Schedules)
local SettingsInterface = require(ReplicatedStorage.Modules.Settings.SettingsInterface)
local UpdateHealthBarUI = require(ReplicatedStorage.Modules.HealthBar.UpdateHealthBarUI)

local ChangeSettingsRE = Net:RemoteEvent("ChangeSettings")

local localPlayer = Players.LocalPlayer

local function init()
	local Frame = localPlayer.PlayerGui.SettingsUI.Main.Frames.Display.alwaysShowHP

	Frame.Button.Text = SettingsInterface.display.alwaysShowHP == true and "X" or ""

	Frame.Button.MouseButton1Up:Connect(function()
		local newSettingsValue = not SettingsInterface.display.alwaysShowHP

		SettingsInterface.display.alwaysShowHP = newSettingsValue
		Frame.Button.Text = newSettingsValue == true and "X" or ""

		UpdateHealthBarUI()
		ChangeSettingsRE:FireServer("display", "alwaysShowHP", newSettingsValue)
	end)

	SettingsInterface.updateSignal:Connect(function()
		Frame.Button.Text = SettingsInterface.display.alwaysShowHP == true and "X" or ""
		UpdateHealthBarUI()
	end)
end

return Schedules.Boot.job(init)
