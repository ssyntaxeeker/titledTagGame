--!strict
--[[
    InitMobile (Client)
    ===================
    Author: Sol (3693744006)
    Updated: 26/07/20

    Creates mobile controls and starts the global mobile touch recognizer.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local MobileFunctions = require(ReplicatedStorage.Modules.Mobile.MobileFunctions)
local MobileTapTag = require(ReplicatedStorage.Modules.Mobile.MobileTapTag)
local Schedules = require(ReplicatedStorage.Shared.Schedules)

local Assets = ReplicatedStorage.Assets

local localPlayer = Players.LocalPlayer

local function init()
	if UserInputService.TouchEnabled == false then return end

	local MobileUI = Assets.UI.MobileUI:Clone()
	MobileUI.Parent = localPlayer.PlayerGui

	MobileFunctions.HookButtons()
	MobileTapTag.init()
end

return Schedules.Boot.job(init)
