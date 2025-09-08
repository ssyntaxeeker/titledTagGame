local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Crouch = require(ReplicatedStorage.Modules.Character.Parkour.Landing.Crouch)
local InputsManager = require(ReplicatedStorage.Modules.Inputs.InputsManager)
local RollInterface = require(ReplicatedStorage.Modules.Character.Parkour.Landing.RollInterface)
local Slide = require(ReplicatedStorage.Modules.Character.Parkour.Landing.Slide)

local localPlayer = Players.LocalPlayer

InputsManager.AddInput("CrouchOrSlide", {
	Keys = { Enum.KeyCode.C },
	OnBegan = function()
		local character = localPlayer.Character
		if not character then return end

		RollInterface.lastPressed = os.clock()

		local humanoid = character:FindFirstChild("Humanoid")
		if not humanoid then return end

		if humanoid.FloorMaterial == Enum.Material.Air then return end

		if humanoid.MoveDirection.Magnitude > 0 and humanoid.WalkSpeed > 24 then
			if character:GetAttribute("Sliding") then
				Slide.Stop()
			else
				Slide.Start()
			end
		else
			Crouch.Start()
		end
	end,

	OnEnded = function()
		local character = localPlayer.Character
		if not character then return end

		if not character:GetAttribute("Crouching") then return end

		Crouch.Stop()
	end,
})

return 0
