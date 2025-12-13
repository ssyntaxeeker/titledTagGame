local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Schedules = require(ReplicatedStorage.Shared.Schedules)
local UpdateHealthBarUI = require(ReplicatedStorage.Modules.HealthBar.UpdateHealthBarUI)

local localPlayer = Players.LocalPlayer

local function initCharacter(character)
	local humanoid = character:WaitForChild("Humanoid")

	humanoid:GetPropertyChangedSignal("Health"):Connect(UpdateHealthBarUI)
	humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(UpdateHealthBarUI)

	UpdateHealthBarUI()
end

local function init()
	localPlayer.CharacterAdded:Connect(initCharacter)

	local character = localPlayer.Character
	if character then initCharacter(character) end
end

return Schedules.Boot.job(init)
