local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = ReplicatedStorage.Assets

local localPlayer = Players.LocalPlayer

local SettingsUI = Assets.UI.SettingsUI:Clone()
SettingsUI.Parent = localPlayer.PlayerGui

local Main = SettingsUI.Main

local UIFunctions = {}

function UIFunctions.Open()
	SettingsUI.Enabled = true
end

function UIFunctions.Close()
	SettingsUI.Enabled = false
end

function UIFunctions.ChangeTab(newTabName)
	for _, frame in Main.Frames:GetChildren() do
		if not frame:IsA("ScrollingFrame") then continue end

		frame.Visible = false
	end

	Main.Frames[newTabName].Visible = true
	Main.CurrentTab.Text = newTabName:lower()
end

function UIFunctions.IsOpen()
	return SettingsUI.Enabled
end

function UIFunctions.ReturnUI()
	return SettingsUI
end

return UIFunctions
