local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterUtils = require(ReplicatedStorage.Vendor.CharacterUtils)
local OutfitFunctions = require(script.Parent.OutfitFunctions)

local function characterAdded(character)
	local player = Players:GetPlayerFromCharacter(character)

	task.spawn(function()
		task.wait(0.5)

		if not player:HasAppearanceLoaded() then player.CharacterAppearanceLoaded:Wait() end

		CharacterUtils.RemoveExtraAccessories(character)
		OutfitFunctions.ShowOutfit(character, player:GetAttribute("Outfit"))
	end)
end

local function playerAdded(player)
	player.CharacterAdded:Connect(characterAdded)
end

Players.PlayerAdded:Connect(playerAdded)

return 0
