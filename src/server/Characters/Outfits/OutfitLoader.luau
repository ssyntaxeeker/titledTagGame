local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local CharacterUtils = require(ReplicatedStorage.Vendor.CharacterUtils)
local OutfitFunctions = require(script.Parent.OutfitFunctions)
local Profiles = require(ServerStorage.Modules.Data.Profiles)

local function characterAdded(character)
	local player = Players:GetPlayerFromCharacter(character)
	if not player then return end

	local playerProxy = Profiles.ReturnProxy(player) or {}

	task.spawn(function()
		task.wait(1)

		if not player:HasAppearanceLoaded() then player.CharacterAppearanceLoaded:Wait() end

		if player.UserId ~= 18522312 then CharacterUtils.RemoveExtraAccessories(character) end
		OutfitFunctions.ShowOutfit(character, playerProxy.Outfit)
	end)
end

local function playerAdded(player)
	player.CharacterAdded:Connect(characterAdded)
end

Players.PlayerAdded:Connect(playerAdded)

return 0
