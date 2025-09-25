local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchUIFunctions = require(ReplicatedStorage.Modules.Matchmaking.UI.MatchUIFunctions)
local SettingsInterface = require(ReplicatedStorage.Modules.Settings.SettingsInterface)
local UIFunctions = require(ReplicatedStorage.Modules.Settings.UIFunctions)

local Assets = ReplicatedStorage.Assets

local localPlayer = Players.LocalPlayer

local SideButtonsUI = Assets.UI.SideButtonsUI:Clone()
SideButtonsUI.Parent = localPlayer.PlayerGui

local bar = SideButtonsUI.Bar

local function update()
	bar.Settings.ButtonKeybind.Text = SettingsInterface.keybinds.toggleSettings.Name
	bar.Matchmaking.ButtonKeybind.Text = SettingsInterface.keybinds.toggleMatchmaking.Name
end

bar.Settings.MouseButton1Up:Connect(function()
	if UIFunctions.IsOpen() then
		UIFunctions.Close()
	else
		UIFunctions.Open()
	end
end)

bar.Matchmaking.MouseButton1Up:Connect(function()
	MatchUIFunctions.ToggleUI(not MatchUIFunctions.IsOpen())
end)

return update
