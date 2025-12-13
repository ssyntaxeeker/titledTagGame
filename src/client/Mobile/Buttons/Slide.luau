local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Buttons = require(ReplicatedStorage.Modules.Mobile.Buttons)
local LandingInputs = require(ReplicatedStorage.Modules.Character.Parkour.Landing.LandingInputs)

local localPlayer = Players.LocalPlayer

local function slide()
	LandingInputs.Roll()

	local character = localPlayer.Character
	if not character then return end

	LandingInputs.StartSlide()
end

local function stopCrouch()
	local character = localPlayer.Character
	if not character then return end

	task.wait(0.1)

	if character:GetAttribute("Sliding") then LandingInputs.StartSlide() end
	LandingInputs.StopSlide()
end

return Buttons.Register("Slide", { OnBegan = slide, OnEnded = stopCrouch })
