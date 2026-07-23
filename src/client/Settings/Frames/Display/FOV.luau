local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Schedules = require(ReplicatedStorage.Shared.Schedules)
local SettingsInterface = require(ReplicatedStorage.Modules.Settings.SettingsInterface)
local SettingsUtils = require(ReplicatedStorage.Modules.Settings.SettingsUtils)

local localPlayer = Players.LocalPlayer

local function init()
	local Frame = localPlayer.PlayerGui.SettingsUI.Main.Frames.Display.fov
	local Marker = Frame.Slider.Marker

	Marker.Position = UDim2.new(SettingsInterface.display.fov, 0, Marker.Position.Y.Scale, Marker.Position.Y.Offset)
	workspace.CurrentCamera.FieldOfView = SettingsInterface.display.fov * 120

	SettingsUtils.SlideMarker(Marker, function(value)
		SettingsInterface.display.fov = value
		workspace.CurrentCamera.FieldOfView = value * 120

		return value
	end)

	SettingsInterface.updateSignal:Connect(function()
		Marker.Position = UDim2.new(SettingsInterface.display.fov, 0, Marker.Position.Y.Scale, Marker.Position.Y.Offset)

		workspace.CurrentCamera.FieldOfView = SettingsInterface.display.fov * 120
	end)
end

return Schedules.Boot.job(init)
