local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LandingInputs = require(ReplicatedStorage.Modules.Character.Parkour.Landing.LandingInputs)
local SettingsUtils = require(ReplicatedStorage.Modules.Settings.SettingsUtils)
local Schedules = require(ReplicatedStorage.Shared.Schedules)
local SettingsInterface = require(ReplicatedStorage.Modules.Settings.SettingsInterface)
local InputsManager = require(ReplicatedStorage.Modules.Inputs.InputsManager)

local localPlayer = Players.LocalPlayer

local function upd(key)
    InputsManager.RemoveInput("Roll")
    InputsManager.AddInput("Roll", {
        Keys = {key},
        OnBegan = LandingInputs.Roll,
    })
end

local function init()
	local Frame = localPlayer.PlayerGui.SettingsUI.Main.Frames.Keybinds.roll

	Frame.Button.Text = SettingsInterface.keybinds.roll.Name

    SettingsUtils.KeybindButton(Frame.Button, upd)

	SettingsInterface.updateSignal:Connect(function()
        local key = SettingsInterface.keybinds.roll
        Frame.Button.Text = ({MouseButton1="LMB", MouseButton2="RMB", MouseButton3="MMB"})[key.Name] or key.Name

        upd(SettingsInterface.keybinds.roll)
	end)
end

return Schedules.Boot.job(init)
