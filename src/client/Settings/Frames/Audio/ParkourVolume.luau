local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Schedules = require(ReplicatedStorage.Shared.Schedules)
local SettingsInterface = require(ReplicatedStorage.Modules.Settings.SettingsInterface)
local SettingsUtils = require(ReplicatedStorage.Modules.Settings.SettingsUtils)

local localPlayer = Players.LocalPlayer

local function init()
	local Frame = localPlayer.PlayerGui.SettingsUI.Main.Frames.Audio.parkour
	local Marker = Frame.Slider.Marker

	Marker.Position = UDim2.new(SettingsInterface.audio.parkourVolume, 0, Marker.Position.Y.Scale, Marker.Position.Y.Offset)

	SettingsUtils.SlideMarker(Marker, function(value)
		SettingsInterface.audio.parkourVolume = value

		SoundService.Parkour.Volume = value

		return value
	end)

	SettingsInterface.updateSignal:Connect(function()
		Marker.Position = UDim2.new(SettingsInterface.audio.parkourVolume, 0, Marker.Position.Y.Scale, Marker.Position.Y.Offset)
		SoundService.Parkour.Volume = SettingsInterface.audio.parkourVolume
	end)
end

return Schedules.Boot.job(init)
