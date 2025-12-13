local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AerialInputs = require(ReplicatedStorage.Modules.Character.Parkour.Aerial.AerialInputs)
local SettingsUtils = require(ReplicatedStorage.Modules.Settings.SettingsUtils)
local Schedules = require(ReplicatedStorage.Shared.Schedules)
local SettingsInterface = require(ReplicatedStorage.Modules.Settings.SettingsInterface)
local InputsManager = require(ReplicatedStorage.Modules.Inputs.InputsManager)

local localPlayer = Players.LocalPlayer

local function upd(key)
    InputsManager.RemoveInput("JumpRequest")
    InputsManager.AddInput("JumpRequest", {
        Keys = {key},
        OnBegan = AerialInputs.JumpRequest
    })
end

local function init()
	local Frame = localPlayer.PlayerGui.SettingsUI.Main.Frames.Keybinds.vaultAndSwing

	Frame.Button.Text = SettingsInterface.keybinds.vaultAndSwing.Name

    SettingsUtils.KeybindButton(Frame.Button, upd)

	SettingsInterface.updateSignal:Connect(function()
        local key = SettingsInterface.keybinds.vaultAndSwing
        Frame.Button.Text = ({MouseButton1="LMB", MouseButton2="RMB", MouseButton3="MMB"})[key.Name] or key.Name

        upd(SettingsInterface.keybinds.vaultAndSwing)
	end)
end

return Schedules.Boot.job(init)
