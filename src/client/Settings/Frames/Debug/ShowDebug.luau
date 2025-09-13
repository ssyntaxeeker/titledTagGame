local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Packages.Net)
local Schedules = require(ReplicatedStorage.Shared.Schedules)
local SettingsInterface = require(ReplicatedStorage.Modules.Settings.SettingsInterface)

local ChangeSettingsRE = Net:RemoteEvent("ChangeSettings")

local localPlayer = Players.LocalPlayer

local function init()
	local Frame = localPlayer.PlayerGui.SettingsUI.Main.Frames.Debug.debug

	Frame.Button.Text = SettingsInterface.debug.showDebug == true and "X" or ""

	Frame.Button.MouseButton1Click:Connect(function()
		local newSettingsValue = not SettingsInterface.debug.showDebug

		SettingsInterface.debug.showDebug = newSettingsValue
		Frame.Button.Text = newSettingsValue == true and "X" or ""

		ChangeSettingsRE:FireServer("debug", "showDebug", newSettingsValue)
	end)

	SettingsInterface.updateSignal:Connect(function()
		Frame.Button.Text = SettingsInterface.debug.showDebug == true and "X" or ""
	end)
end

return Schedules.Boot.job(init)
