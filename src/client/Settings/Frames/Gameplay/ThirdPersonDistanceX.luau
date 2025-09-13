local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CameraModule = require(ReplicatedStorage.Modules.Camera.CameraModule)
local Schedules = require(ReplicatedStorage.Shared.Schedules)
local SettingsInterface = require(ReplicatedStorage.Modules.Settings.SettingsInterface)
local SettingsUtils = require(ReplicatedStorage.Modules.Settings.SettingsUtils)

local localPlayer = Players.LocalPlayer

local function init()
	local Frame = localPlayer.PlayerGui.SettingsUI.Main.Frames.Gameplay.tpdX
	local Marker = Frame.Slider.Marker

	Marker.Position = UDim2.new(SettingsInterface.gameplay.thirdPersonDistanceX, 0, Marker.Position.Y.Scale, Marker.Position.Y.Offset)

	SettingsUtils.SlideMarker(Marker, function(value)
		SettingsInterface.gameplay.thirdPersonDistanceX = value

		local oldCameraOffset = CameraModule.CameraOffset
		CameraModule.CameraOffset = Vector3.new(-4 + (8 * SettingsInterface.gameplay.thirdPersonDistanceX), oldCameraOffset.Y, oldCameraOffset.Z)

		return value
	end)

	SettingsInterface.updateSignal:Connect(function()
		Marker.Position = UDim2.new(SettingsInterface.gameplay.thirdPersonDistanceX, 0, Marker.Position.Y.Scale, Marker.Position.Y.Offset)

		local oldCameraOffset = CameraModule.CameraOffset
		CameraModule.CameraOffset = Vector3.new(-4 + (8 * SettingsInterface.gameplay.thirdPersonDistanceX), oldCameraOffset.Y, oldCameraOffset.Z)
	end)
end

return Schedules.Boot.job(init)
