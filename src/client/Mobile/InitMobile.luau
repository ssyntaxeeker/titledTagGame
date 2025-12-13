local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local MobileFunctions = require(ReplicatedStorage.Modules.Mobile.MobileFunctions)
local Schedules = require(ReplicatedStorage.Shared.Schedules)

local Assets = ReplicatedStorage.Assets

local localPlayer = Players.LocalPlayer

local function init()
	if UserInputService.TouchEnabled == false then return end

	local MobileUI = Assets.UI.MobileUI:Clone()
	MobileUI.Parent = localPlayer.PlayerGui

	MobileFunctions.HookButtons()
end

return Schedules.Boot.job(init)
