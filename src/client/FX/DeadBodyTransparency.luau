local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Schedules = require(ReplicatedStorage.Shared.Schedules)

local function setBodyTransparency(character)
	local player = Players:GetPlayerFromCharacter(character)

	task.spawn(function()
		repeat
			task.wait(0.1)
		until player:HasAppearanceLoaded()

		for _, part in character:GetDescendants() do
			if part:IsA("BasePart") then part.Transparency = 0.6 end
		end
	end)
end

local function checkCharacterRole(character)
	if character:GetAttribute("Role") == "Dead" then setBodyTransparency(character) end
end

local function initPlayer(player)
	local function onCharacterAdded(character)
		checkCharacterRole(character)
	end

	player.CharacterAdded:Connect(onCharacterAdded)

	if player.Character then onCharacterAdded(player.Character) end
end

local function init()
	for _, player in Players:GetPlayers() do
		initPlayer(player)
	end

	Players.PlayerAdded:Connect(initPlayer)
end

return Schedules.Boot.job(init)
