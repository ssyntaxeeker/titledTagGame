local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SettingsUtils = require(ReplicatedStorage.Modules.Settings.SettingsUtils)
local Schedules = require(ReplicatedStorage.Shared.Schedules)
local SettingsInterface = require(ReplicatedStorage.Modules.Settings.SettingsInterface)
local InputsManager = require(ReplicatedStorage.Modules.Inputs.InputsManager)
local TagFunctions = require(ReplicatedStorage.Modules.Tag.TagFunctions)

local localPlayer = Players.LocalPlayer

local function upd(key)
    InputsManager.RemoveInput("Tag")
    InputsManager.AddInput("Tag", {
        Keys = {key},
        OnBegan = TagFunctions.Tag,
    })
end

local function init()
	local Frame = localPlayer.PlayerGui.SettingsUI.Main.Frames.Keybinds.tag

	Frame.Button.Text = SettingsInterface.keybinds.tag.Name

    SettingsUtils.KeybindButton(Frame.Button, upd)

	SettingsInterface.updateSignal:Connect(function()
        local key = SettingsInterface.keybinds.tag
        Frame.Button.Text = ({MouseButton1="LMB", MouseButton2="RMB", MouseButton3="MMB"})[key.Name] or key.Name

        upd(SettingsInterface.keybinds.tag)
	end)
end

return Schedules.Boot.job(init)
