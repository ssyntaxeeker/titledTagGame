local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchUIFunctions = require(ReplicatedStorage.Modules.Matchmaking.UI.MatchUIFunctions)
local SettingsInterface = require(ReplicatedStorage.Modules.Settings.SettingsInterface)
local UIFunctions = require(ReplicatedStorage.Modules.Settings.UIFunctions)

local Assets = ReplicatedStorage.Assets

local localPlayer = Players.LocalPlayer

local SideButtonsUI = Assets.UI.SideButtonsUI:Clone()
SideButtonsUI.Parent = localPlayer:WaitForChild("PlayerGui")

local bar = SideButtonsUI:WaitForChild("Bar")

local function update()
	if not bar:FindFirstChild("Settings") then return end

	bar.Settings.ButtonKeybind.Text = SettingsInterface.keybinds.toggleSettings.Name
	bar.Matchmaking.ButtonKeybind.Text = SettingsInterface.keybinds.toggleMatchmaking.Name
end

task.spawn(function()
	bar:WaitForChild("Settings").MouseButton1Down:Connect(function()
		if UIFunctions.IsOpen() then
			UIFunctions.Close()
		else
			UIFunctions.Open()
		end
	end)

	bar:WaitForChild("Matchmaking").MouseButton1Down:Connect(function()
		MatchUIFunctions.ToggleUI(not MatchUIFunctions.IsOpen())
	end)
end)

return update
