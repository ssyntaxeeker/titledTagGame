local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Crouch = require(ReplicatedStorage.Modules.Character.Parkour.Landing.Crouch)
local RollInterface = require(ReplicatedStorage.Modules.Character.Parkour.Landing.RollInterface)
local Slide = require(ReplicatedStorage.Modules.Character.Parkour.Landing.Slide)

local localPlayer = Players.LocalPlayer

local LandingInputs = {}

function LandingInputs.Roll()
	local character = localPlayer.Character
	if not character then return end

	RollInterface.lastPressed = os.clock()
end

function LandingInputs.StartSlide()
	local character = localPlayer.Character
	if not character then return end

	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end
	if humanoid.FloorMaterial == Enum.Material.Air then return end

	if character:GetAttribute("Sliding") then
		Slide.Stop()
	elseif Slide.CanStart(character) then
		Slide.Start()
	else
		Crouch.Start()
	end
end

function LandingInputs.StopSlide()
	local character = localPlayer.Character
	if not character then return end

	if not character:GetAttribute("Crouching") then return end

	Crouch.Stop()
end

return LandingInputs
