local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SettingsUtils = require(ReplicatedStorage.Modules.Settings.SettingsUtils)
local Schedules = require(ReplicatedStorage.Shared.Schedules)
local SettingsInterface = require(ReplicatedStorage.Modules.Settings.SettingsInterface)
local InputsManager = require(ReplicatedStorage.Modules.Inputs.InputsManager)
local CameraInputs = require(ReplicatedStorage.Modules.Camera.CameraInputs)

local localPlayer = Players.LocalPlayer

local function upd(key)
    InputsManager.RemoveInput("ChangeCameraPerspective")
    InputsManager.AddInput("ChangeCameraPerspective", {
        Keys = {key},
        OnBegan = CameraInputs.ChangeCameraPerspective.OnBegan
    })
end

local function init()
	local Frame = localPlayer.PlayerGui.SettingsUI.Main.Frames.Keybinds.changeCameraPerspective

	Frame.Button.Text = SettingsInterface.keybinds.changeCameraPerspective.Name

    SettingsUtils.KeybindButton(Frame.Button, upd)

	SettingsInterface.updateSignal:Connect(function()
        local key = SettingsInterface.keybinds.changeCameraPerspective
        Frame.Button.Text = ({MouseButton1="LMB", MouseButton2="RMB", MouseButton3="MMB"})[key.Name] or key.Name


        upd(SettingsInterface.keybinds.changeCameraPerspective)
	end)
end

return Schedules.Boot.job(init)
