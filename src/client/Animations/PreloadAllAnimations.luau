local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationManager = require(ReplicatedStorage.Modules.Animations.AnimationManager)
local Schedules = require(ReplicatedStorage.Shared.Schedules)

local Assets = ReplicatedStorage.Assets

local localPlayer = Players.LocalPlayer

local function preloadAnims(character)
	local animationList = {}

	for _, animation in Assets.Animations:GetDescendants() do
		if not animation:IsA("Animation") then continue end

		table.insert(animationList, animation)
	end

	ContentProvider:PreloadAsync(animationList)
	AnimationManager.Preload(character.Humanoid.Animator, animationList)
end

local function init()
	local character = localPlayer.Character
	if character then preloadAnims(character) end

	localPlayer.CharacterAdded:Connect(preloadAnims)
end

return Schedules.Boot.job(init)
