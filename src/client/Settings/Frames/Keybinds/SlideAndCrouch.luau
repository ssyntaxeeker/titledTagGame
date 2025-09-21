local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LandingInputs = require(ReplicatedStorage.Modules.Character.Parkour.Landing.LandingInputs)
local SettingsUtils = require(ReplicatedStorage.Modules.Settings.SettingsUtils)
local Schedules = require(ReplicatedStorage.Shared.Schedules)
local SettingsInterface = require(ReplicatedStorage.Modules.Settings.SettingsInterface)
local InputsManager = require(ReplicatedStorage.Modules.Inputs.InputsManager)

local localPlayer = Players.LocalPlayer

local function upd(key)
    InputsManager.RemoveInput("SlideAndCrouch")
    InputsManager.AddInput("SlideAndCrouch", {
        Keys = {key},
        OnBegan = LandingInputs.StartSlide,
        OnEnded = LandingInputs.StopSlide
    })
end

local function init()
	local Frame = localPlayer.PlayerGui.SettingsUI.Main.Frames.Keybinds.slideAndCrouch

	Frame.Button.Text = SettingsInterface.keybinds.slideAndCrouch.Name

    SettingsUtils.KeybindButton(Frame.Button, upd)

	SettingsInterface.updateSignal:Connect(function()
        local key = SettingsInterface.keybinds.slideAndCrouch
        Frame.Button.Text = ({MouseButton1="LMB", MouseButton2="RMB", MouseButton3="MMB"})[key.Name] or key.Name

        upd(SettingsInterface.keybinds.slideAndCrouch)
	end)
end

return Schedules.Boot.job(init)
