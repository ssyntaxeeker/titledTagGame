local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local LeaderboardFunctions = require(ReplicatedStorage.Modules.Leaderboard.LeaderboardFunctions)
local Net = require(ReplicatedStorage.Packages.Net)
local Schedules = require(ReplicatedStorage.Shared.Schedules)
local SettingsInterface = require(ReplicatedStorage.Modules.Settings.SettingsInterface)

local ChangeSettingsRE = Net:RemoteEvent("ChangeSettings")

local localPlayer = Players.LocalPlayer

local function init()
	local Frame = localPlayer.PlayerGui.SettingsUI.Main.Frames.Mobile.toggleLeaderboard

	Frame.Button.Text = SettingsInterface.mobile.toggleLeaderboard == true and "X" or ""

	Frame.Button.MouseButton1Up:Connect(function()
		local newSettingsValue = not SettingsInterface.mobile.toggleLeaderboard

		SettingsInterface.mobile.toggleLeaderboard = newSettingsValue
		Frame.Button.Text = newSettingsValue == true and "X" or ""

		ChangeSettingsRE:FireServer("mobile", "toggleLeaderboard", newSettingsValue)
		LeaderboardFunctions.SetUIEnabled(newSettingsValue)
	end)

	SettingsInterface.updateSignal:Connect(function()
		if UserInputService.TouchEnabled == false then return end

		Frame.Button.Text = SettingsInterface.mobile.toggleLeaderboard == true and "X" or ""
		LeaderboardFunctions.SetUIEnabled(SettingsInterface.mobile.toggleLeaderboard)
	end)
end

return Schedules.Boot.job(init)
