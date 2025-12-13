local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InputsManager = require(ReplicatedStorage.Modules.Inputs.InputsManager)
local MatchUIFunctions = require(ReplicatedStorage.Modules.Matchmaking.UI.MatchUIFunctions)
local Schedules = require(ReplicatedStorage.Shared.Schedules)
local SettingsInterface = require(ReplicatedStorage.Modules.Settings.SettingsInterface)
local SettingsUtils = require(ReplicatedStorage.Modules.Settings.SettingsUtils)
local UpdateSideButtons = require(ReplicatedStorage.Modules.SideButtons.UpdateSideButtons)

local localPlayer = Players.LocalPlayer

local function upd(key)
	UpdateSideButtons()

	InputsManager.RemoveInput("ToggleMatchmaking")
	InputsManager.AddInput("ToggleMatchmaking", {
		Keys = { key },
		OnBegan = function()
			MatchUIFunctions.ToggleUI(not MatchUIFunctions.IsOpen())
		end,
	})
end

local function init()
	local Frame = localPlayer.PlayerGui.SettingsUI.Main.Frames.Keybinds.toggleMatchmaking

	Frame.Button.Text = SettingsInterface.keybinds.toggleMatchmaking.Name

	SettingsUtils.KeybindButton(Frame.Button, upd)

	SettingsInterface.updateSignal:Connect(function()
		local key = SettingsInterface.keybinds.toggleMatchmaking
		Frame.Button.Text = ({ MouseButton1 = "LMB", MouseButton2 = "RMB", MouseButton3 = "MMB" })[key.Name] or key.Name

		upd(SettingsInterface.keybinds.toggleMatchmaking)
	end)
end

return Schedules.Boot.job(init)
