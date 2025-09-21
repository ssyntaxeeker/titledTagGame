local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SettingsUtils = require(ReplicatedStorage.Modules.Settings.SettingsUtils)
local Schedules = require(ReplicatedStorage.Shared.Schedules)
local SettingsInterface = require(ReplicatedStorage.Modules.Settings.SettingsInterface)
local InputsManager = require(ReplicatedStorage.Modules.Inputs.InputsManager)
local CameraInputs = require(ReplicatedStorage.Modules.Camera.CameraInputs)

local localPlayer = Players.LocalPlayer

local function upd(key)
    InputsManager.RemoveInput("UnlockCamera")
    InputsManager.AddInput("UnlockCamera", {
        Keys = {key},
        OnBegan = CameraInputs.UnlockCamera.OnBegan,
        OnEnded = CameraInputs.UnlockCamera.OnEnded
    })
end

local function init()
	local Frame = localPlayer.PlayerGui.SettingsUI.Main.Frames.Keybinds.unlockCamera

	Frame.Button.Text = SettingsInterface.keybinds.unlockCamera.Name

    SettingsUtils.KeybindButton(Frame.Button, upd)

	SettingsInterface.updateSignal:Connect(function()
        local key = SettingsInterface.keybinds.unlockCamera
        Frame.Button.Text = ({MouseButton1="LMB", MouseButton2="RMB", MouseButton3="MMB"})[key.Name] or key.Name

        upd(SettingsInterface.keybinds.unlockCamera)
	end)
end

return Schedules.Boot.job(init)
