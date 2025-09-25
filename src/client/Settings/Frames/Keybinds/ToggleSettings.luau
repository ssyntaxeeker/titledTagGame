local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InputsManager = require(ReplicatedStorage.Modules.Inputs.InputsManager)
local Schedules = require(ReplicatedStorage.Shared.Schedules)
local SettingsInterface = require(ReplicatedStorage.Modules.Settings.SettingsInterface)
local SettingsUtils = require(ReplicatedStorage.Modules.Settings.SettingsUtils)
local UIFunctions = require(ReplicatedStorage.Modules.Settings.UIFunctions)
local UpdateSideButtons = require(ReplicatedStorage.Modules.SideButtons.UpdateSideButtons)

local localPlayer = Players.LocalPlayer

local function upd(key)
	UpdateSideButtons()

	InputsManager.RemoveInput("ToggleSettings")
	InputsManager.AddInput("ToggleSettings", {
		Keys = { key },
		OnBegan = function()
			if UIFunctions.IsOpen() then
				UIFunctions.Close()
			else
				UIFunctions.Open()
			end
		end,
	})
end

local function init()
	local Frame = localPlayer.PlayerGui.SettingsUI.Main.Frames.Keybinds.toggleSettings

	Frame.Button.Text = SettingsInterface.keybinds.toggleSettings.Name

	SettingsUtils.KeybindButton(Frame.Button, upd)

	SettingsInterface.updateSignal:Connect(function()
		local key = SettingsInterface.keybinds.toggleSettings
		Frame.Button.Text = ({ MouseButton1 = "LMB", MouseButton2 = "RMB", MouseButton3 = "MMB" })[key.Name] or key.Name

		upd(SettingsInterface.keybinds.toggleSettings)
	end)
end

return Schedules.Boot.job(init)
